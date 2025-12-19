public without sharing class RestAPIPaymentMethodHandler extends RestAPIHandler {
    
    public RestAPIPaymentMethodHandler() {
        super();
        operation = 'RestAPIPaymentMethodHandler';
        className = 'RestAPIPaymentMethodHandler';
    }

    String apiOperation;
    List<blng__PaymentGateway__c> defaultApiPaymentGateway;
    List<blng__LegalEntity__c> defaultApiLegalEntity;

    //Override GET
    private void processGET() {
        // throw new InvalidInputException('GET not allowed');        
    }

    private void processPOST() {

        //initialize save point 
        initializeSavePoint();

        if ( String.isBlank(requestBody) ) {
            throw new InvalidInputException('Please specify a valid request body');
        }
        PaymentMethodRequest inboundPaymentMethodRequest;
        try {
            inboundPaymentMethodRequest = (PaymentMethodRequest)JSON.deserialize(requestBody, PaymentMethodRequest.class);
        } catch ( Exception e ) {
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }
        
        //request would be of format /Account/AddPaymentMethod or /Account/UpdatePaymentMethod
        apiOperation = getParamFromUri(2);

        validateRequiredFields(inboundPaymentMethodRequest);

        //Check if Account Id is valid.
        validateAccount(inboundPaymentMethodRequest.accountId);

        

        if ( apiOperation == 'AddPaymentMethod' ) {
            
            //fetch Payment Gateway
            fetchDefaultApiPaymentGateway();

            //fetch Legal Entity
            fetchDefaultApiLegalEntity();
        }

        //get existing active OR NON Deleted payment methods.
        List<blng__PaymentMethod__c> existingPaymentMethods = RestAPIUtility.getActiveOrNonDeletedPaymentMethods(inboundPaymentMethodRequest.accountId);
        
        //populate paymentMethod object variable
        blng__PaymentMethod__c paymentMethod = populatePaymentMethod(inboundPaymentMethodRequest);

        List<blng__PaymentMethod__c> paymentMethodUpdateList = new List<blng__PaymentMethod__c>();

        for ( blng__PaymentMethod__c existingPaymentMethodVar : existingPaymentMethods ) {
            if ( existingPaymentMethodVar.Id != inboundPaymentMethodRequest.paymentMethodId ) {
                existingPaymentMethodVar.blng__Active__c = false;
                existingPaymentMethodVar.IsDeleted__c = true;
                existingPaymentMethodVar.blng__AutoPay__c = false;
                paymentMethodUpdateList.add(existingPaymentMethodVar);
            }
        }
        
        //deactivate records
        if ( paymentMethodUpdateList.size() > 0 ) {
            try {
                update paymentMethodUpdateList;
            } catch (Exception ex) {
                throw new ValidationException('Error deactivating other payment records. Error: ' + ex.getMessage());
            }            
        }

        //upsert record.
        try {
            upsert paymentMethod;
        } catch (Exception ex) {
            throw new ValidationException('Unable to save the payment method. Error: ' + ex.getMessage());
        }
        

        generateResponse(paymentMethod.Id);

    }

    private void validateRequiredFields(PaymentMethodRequest inboundPaymentMethodRequest) {
        Set<String> requiredFields = new Set<String>();

        if(String.isBlank(inboundPaymentMethodRequest.accountId)) {
            requiredFields.add('accountId');
        }

        //if(String.isBlank(inboundPaymentMethodRequest.billingCompany)) {
            //requiredFields.add('billingCompany');
        //}
        
        if(String.isBlank(inboundPaymentMethodRequest.billingFirstName)) {
            requiredFields.add('billingFirstName');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingLastName)) {
            requiredFields.add('billingLastName');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingEmail)) {
            requiredFields.add('billingEmail');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingPhone)) {
            requiredFields.add('billingPhone');
        }

        //if(String.isBlank(inboundPaymentMethodRequest.billingAddress)) {
        //    requiredFields.add('billingAddress');
        //}

        if(String.isBlank(inboundPaymentMethodRequest.streetAddress1)) {
            requiredFields.add('streetAddress1');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingCity)) {
            requiredFields.add('billingCity');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingStateProvince)) {
            requiredFields.add('billingStateProvince');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingZipPostal)) {
            requiredFields.add('billingZipPostal');
        }
        if(String.isBlank(inboundPaymentMethodRequest.billingCountry)) {
            requiredFields.add('billingCountry');
        }

        if(String.isBlank(inboundPaymentMethodRequest.cardExpirationMonth)) {
            requiredFields.add('cardExpirationMonth');
        }
        if(String.isBlank(inboundPaymentMethodRequest.cardExpirationYear)) {
            requiredFields.add('cardExpirationYear');
        }
        if(String.isBlank(inboundPaymentMethodRequest.cardLastFour)) {
            requiredFields.add('cardLastFour');
        }
        if(String.isBlank(inboundPaymentMethodRequest.cardType)) {
            requiredFields.add('cardType');
        }

        if(String.isBlank(inboundPaymentMethodRequest.nameoncard)) {
            requiredFields.add('nameoncard');
        }
        if(String.isBlank(inboundPaymentMethodRequest.nickName)) {
            requiredFields.add('nickName');
        }

        if(String.isBlank(inboundPaymentMethodRequest.paymentGatewayToken)) {
            requiredFields.add('paymentGatewayToken');
        }
        if(String.isBlank(inboundPaymentMethodRequest.paymentType)) {
            requiredFields.add('paymentType');
        }

        if ( apiOperation == 'UpdatePaymentMethod' ) {
            if(String.isBlank(inboundPaymentMethodRequest.paymentMethodId)) {
                requiredFields.add('paymentMethodId');
            }
        }

        if(!requiredFields.isEmpty()) {
            throw new InvalidInputException('Missing required fields: [' + GeneralUtility.joinSet(requiredFields, ',') + ']');
        }
    }

    private void validateAccount(String accountId) {
        try {
            Account accVar = RestApiUtility.getAccount(accountId);
        } catch (Exception e) {
            throw new InvalidInputException('No Account found for given Account Id. Exception: ' + e.getMessage());
        }
    }

    private void fetchDefaultApiPaymentGateway() {
        defaultApiPaymentGateway = RestApiUtility.getDefaultApiPaymentGateway();
        if ( defaultApiPaymentGateway.size() == 0 ) {
            throw new UnexpectedException('No Payment Gateway found. Please contact the Salesforce Administrator');
        }
    }

    private void fetchDefaultApiLegalEntity() {
        defaultApiLegalEntity = RestApiUtility.getDefaultApiLegalEntity();
        if ( defaultApiLegalEntity.size() == 0 ) {
            throw new UnexpectedException('No Legal Entity found. Please contact the Salesforce Administrator');
        }
    }

    private blng__PaymentMethod__c populatePaymentMethod(PaymentMethodRequest inboundPaymentMethodRequest) {
        blng__PaymentMethod__c paymentMethod = new blng__PaymentMethod__c();
        
        paymentMethod.blng__Account__c = inboundPaymentMethodRequest.accountId;
        paymentMethod.blng__Active__c = true;
        paymentMethod.blng__AutoPay__c = true;

        paymentMethod.blng__BillingCompany__c = inboundPaymentMethodRequest.billingCompany;
        paymentMethod.blng__BillingFirstName__c = inboundPaymentMethodRequest.billingFirstName;
        paymentMethod.blng__BillingLastName__c = inboundPaymentMethodRequest.billingLastName;
        paymentMethod.blng__BillingEmail__c = inboundPaymentMethodRequest.billingEmail;        
        paymentMethod.blng__BillingPhone__c = inboundPaymentMethodRequest.billingPhone;

        paymentMethod.blng__BillingAddress__c = inboundPaymentMethodRequest.billingAddress;
        paymentMethod.blng__BillingStreet__c = inboundPaymentMethodRequest.streetAddress1;
        paymentMethod.blng__StreetAddress2__c = inboundPaymentMethodRequest.streetAddress2;
        paymentMethod.blng__BillingCity__c = inboundPaymentMethodRequest.billingCity;
        paymentMethod.blng__BillingStateProvince__c = inboundPaymentMethodRequest.billingStateProvince;        
        paymentMethod.blng__BillingZipPostal__c = inboundPaymentMethodRequest.billingZipPostal;
        paymentMethod.blng__BillingCountry__c = inboundPaymentMethodRequest.billingCountry;
        

        paymentMethod.blng__CardExpirationMonth__c = inboundPaymentMethodRequest.cardExpirationMonth;
        paymentMethod.blng__CardExpirationYear__c = inboundPaymentMethodRequest.cardExpirationYear;
        paymentMethod.blng__CardLastFour__c = inboundPaymentMethodRequest.cardLastFour;
        paymentMethod.blng__CardType__c = inboundPaymentMethodRequest.cardType;

        paymentMethod.blng__Nameoncard__c = inboundPaymentMethodRequest.nameoncard;
        paymentMethod.blng__NickName__c = inboundPaymentMethodRequest.nickName;

        paymentMethod.blng__Notes__c = inboundPaymentMethodRequest.notes;
        paymentMethod.blng__PaymentGatewayToken__c = inboundPaymentMethodRequest.paymentGatewayToken;
        paymentMethod.blng__PaymentType__c = inboundPaymentMethodRequest.paymentType;

        if ( apiOperation == 'AddPaymentMethod' ) {
            paymentMethod.blng__LegalEntity__c = defaultApiLegalEntity[0].Id;
            paymentMethod.blng__PaymentGateway__c = defaultApiPaymentGateway[0].Id;
        }        
        
        if ( apiOperation == 'UpdatePaymentMethod' ) {
            paymentMethod.Id = inboundPaymentMethodRequest.paymentMethodId;
        }

        return paymentMethod;
    }

    private void generateResponse(Id paymentMethodId) {
        String message = 'The Payment method was updated successfully.';
        if ( apiOperation == 'AddPaymentMethod' ) {
            message = 'A new Payment method was added successfully.';
        }
        response = new RestAPIResponse(new PaymentMethodResponse(paymentMethodId,message));
    }

    public class PaymentMethodRequest {        
        public String accountId;
        
        public String billingCompany;
        public String billingFirstName;
        public String billingLastName;
        public String billingEmail;
        public String billingPhone;
        
        public String billingAddress;
        public String streetAddress1;
        public String streetAddress2;
        public String billingCity;
        public String billingStateProvince;
        public String billingZipPostal;
        public String billingCountry;

        public String cardExpirationMonth;
        public String cardExpirationYear;
        public String cardLastFour;
        public String cardType;
        
        public String nameoncard;
        public String nickName;

        public String notes;
        public String paymentGatewayToken;
        public String paymentType;
        public String paymentMethodId;      //required only when API is update payment method.
    }

    public class PaymentMethodResponse {
        public String paymentMethodId;
        public String message;

        public PaymentMethodResponse(String paymentMethodIdVar, String responseMessageVar) {
            this.paymentMethodId = paymentMethodIdVar;
            this.message = responseMessageVar;
        }
    }

}