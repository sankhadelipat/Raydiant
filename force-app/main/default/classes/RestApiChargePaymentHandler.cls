public without sharing class RestApiChargePaymentHandler extends RestAPIHandler {
    
    public RestApiChargePaymentHandler() {
        super();
        operation = 'RestApiChargePaymentHandler';
        className = 'RestApiChargePaymentHandler';
    }

    public void processGET() {
        
    }

    public void processPost() {

    }

    blng__PaymentMethod__c paymentMethod;
    blng__PaymentGateway__c paymentGateway;
    blng.TransactionResult theResult;
    blng__Payment__c payment;
    blng__PaymentTransaction__c paymentTransaction;
    Account accountVar;
    blng__Invoice__c invoice;

    protected override void processPUTWithoutRollback() {
        
        //1 - Validate URI Params.
        validateUriParamValues();

        //2 - Validate if Transaction ID is already used.
        validateExistingPaymentTransaction();

        //3 - Check if Account exists.
        fetchAccount();

        //4 - Check if Invoice exists against the account.
        fetchInvoice();

        //5 - Check if Payment Method exists against the account.
        fetchPaymentMethod();

        //6 - Check if Payment Gateway exists for the Payment method.
        fetchPaymentGateway();

        payment = initializePayment();

        //make billing callout.
        chargeTransaction();

        //initialize save point - after callout.
        initializeSavePoint();

        paymentTransaction = initializePaymentTransaction();    
        try {
            insert paymentTransaction;
        } catch (Exception ex) {
            throw new ValidationException('Unable to create the Payment Transaction record. Error: ' + ex.getMessage());
        }        

        if ( fetchGatewayStatus() == 'Success' ) {
            payment.blng__Transaction__c = paymentTransaction.Id;        
            payment.blng__Status__c = 'Posted';

            try {
                insert payment;
    
                List<blng__PaymentAllocationInvoiceLine__c> paymentAllocationInvoiceLines = createPaymentAllocationInvoiceLines(payment.Id, Decimal.valueOf(uriParams.get('amount')), invoice.blng__InvoiceInvoiceLines__r);
                if ( paymentAllocationInvoiceLines.size() > 0 ) {
                    insert paymentAllocationInvoiceLines;
                }

            } catch (Exception ex) {
                throw new ValidationException('Card was charged, but unable to create the Payment record/Update Invoice with Charge. Error: ' + ex.getMessage());
            }
        }

        generateResponse();
    }

    private void validateUriParamValues() {
        String accountId = uriParams.get('accountId');
        String paymentMethodId = uriParams.get('paymentMethodId');
        String amount = uriParams.get('amount');
        String invoiceId = uriParams.get('invoiceId');
        String transactionId = uriParams.get('transactionId');
        String currencyCodeId = uriParams.get('currencyCodeId');

        Set<String> requiredFields = new Set<String>();
        if(String.isBlank(accountId)) {
            requiredFields.add('accountId');
        }
        if(String.isBlank(paymentMethodId)) {
            requiredFields.add('paymentMethodId');
        }
        if(String.isBlank(amount)) {
            requiredFields.add('amount');
        }
        if(String.isBlank(invoiceId)) {
            requiredFields.add('invoiceId');
        }
        if(String.isBlank(transactionId)) {
            requiredFields.add('transactionId');
        }
        if(String.isBlank(currencyCodeId)) {
            requiredFields.add('currencyCodeId');
        }

        if(!requiredFields.isEmpty()) {
            throw new InvalidInputException('Missing required fields: [' + GeneralUtility.joinSet(requiredFields, ',') + ']');
        }
    }

    private void validateExistingPaymentTransaction() {
        String transactionId = uriParams.get('transactionId');
        List<blng__PaymentTransaction__c> existingPaymentTransactions = [SELECT Id FROM blng__PaymentTransaction__c 
                                                                        WHERE blng__SourceTransactionId__c =: transactionId];
        if(existingPaymentTransactions.size() > 0) {
            throw new ValidationException('Transaction Id already used.');
        }
    }

    private void fetchAccount() {
        String accountId = uriParams.get('accountId');
        try {
            accountVar = RestAPIUtility.getAccount(accountId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Account found for given accountId.');
        }
    }

    private void fetchInvoice() {
        String invoiceId = uriParams.get('invoiceId');
        try {
            invoice = RestAPIUtility.getInvoiceById(invoiceId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Invoice found for given invoiceId.');
        }

        if ( invoice.blng__Account__c != accountVar.Id ) {
            throw new ValidationException('Invoice does not belong to the Account provided.');
        }

        if ( invoice.blng__Balance__c == null || invoice.blng__Balance__c <= 0 ) {
            throw new ValidationException('Requested invoice does not have any balance. Invoice Balance: ' + invoice.blng__Balance__c);
        }

        if ( invoice.blng__Balance__c < Decimal.valueOf(uriParams.get('amount')) ) {
            throw new ValidationException('Amount being paid is more than the Invoice balance. Invoice Balance: ' + invoice.blng__Balance__c);
        }

        if ( invoice.blng__PaymentStatus__c == 'Paid' ) {
            throw new ValidationException('Invoice is already Paid.');
        }
    }

    private void fetchPaymentMethod() {
        String paymentMethodId = uriParams.get('paymentMethodId');
        try {
            paymentMethod = RestAPIUtility.getPaymentMethodById(paymentMethodId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Payment Method found for given paymentMethodId.');
        }

        if ( !paymentMethod.blng__Active__c ) {
            throw new ValidationException('Payment method is inactive for given paymentMethodId. Please use an active payment method.');
        }
    }

    private void fetchPaymentGateway() {
        String paymentGatewayId = paymentMethod.blng__PaymentGateway__c;        
        try {
            paymentGateway = RestAPIUtility.getPaymentGatewayById(paymentGatewayId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Payment Gateway found for given paymentMethodId.');
        }
    }

    private blng__Payment__c initializePayment() {
        blng__Payment__c paymentVar = new blng__Payment__c();
        paymentVar.blng__Account__c = uriParams.get('accountId');
        paymentVar.blng__Amount__c = Decimal.valueOf(uriParams.get('amount'));
        paymentVar.blng__PaymentGateway__c = paymentGateway.Id;
        paymentVar.blng__PaymentMethod__c = paymentMethod.Id;
        paymentVar.blng__Invoice__c = uriParams.get('invoiceId');

        return paymentVar;
    }

    private void chargeTransaction() {
        try{
            Account accountInstance = new Account(Id = uriParams.get('accountId'));
            blng.TransactionParameter tp = new blng.TransactionParameter();
            tp.setAccount(accountInstance);
            tp.setAmount(uriParams.get('amount'));
            tp.setPaymentMethod(paymentMethod);
            tp.setGateway(paymentGateway);
            //tp.setRequestingInvoiceId(uriParams.get('invoiceId'));
            tp.setCurrencyId(uriParams.get('currencyCodeId'));
    		tp.setInvoice(invoice);

            Map<String, blng.TransactionParameter> mapOfTransactionParameterById = new Map<String, blng.TransactionParameter>();
            //Setting key to 1, but ideally the key should be the invoice ID. If there are multiple invoices being paid, 
            //set blng.TransactionParameter for each invoice, and have a map of Invoice Id, TransactionParameter.
            mapOfTransactionParameterById.put('1', tp);
            
            Map<String, blng.TransactionResult> mapOfResults = new Map<String, blng.TransactionResult>();
            if ( Test.isRunningTest() ) {
                theResult = fetchMockSuccessResult();
            }
            else {
                System.debug(mapOfTransactionParameterById);
                mapOfResults = csblng.CyberSourceAPI.chargeTransaction(mapOfTransactionParameterById); //This performs callout
                System.debug(mapOfResults);
                System.debug(mapOfResults.get('1'));
                theResult = mapOfResults.get('1');
            } 
            
        } catch (Exception ex) {
            throw new ValidationException('An error occured while initiating the transaction. Error: ' + ex.getMessage());
        }        
    }

    private blng__PaymentTransaction__c initializePaymentTransaction() {
        blng__PaymentTransaction__c paymentTransaction = new blng__PaymentTransaction__c();
        
        paymentTransaction.blng__PaymentMethod__c = paymentMethod.Id;
        paymentTransaction.blng__Amount__c = payment.blng__Amount__c;
        paymentTransaction.blng__Account__c = uriParams.get('accountId');
        
        paymentTransaction.blng__CardCodeResponse__c = theResult.getCardCodeResponse();
        paymentTransaction.blng__GatewayStatus__c = fetchGatewayStatus();
        paymentTransaction.blng__ResponseCode__c = theResult.getResponseCode();
        paymentTransaction.blng__GatewayID__c = theResult.getGatewayId();
        paymentTransaction.blng__ResponseMessage__c = theResult.getResponseCodeMessage();
        paymentTransaction.blng__Type__c = 'Charge';
        paymentTransaction.blng__Response__c = theResult.getResponseMessage();
        paymentTransaction.blng__ResponseStatus__c = theResult.getResponseStatus();
        paymentTransaction.blng__RequestTypeOfPayment__c = theResult.getRequestTypeofPayment();
        paymentTransaction.blng__RequestTransactionType__c = theResult.getRequestTransactionType();
        paymentTransaction.blng__IsPaymentProcessedSuccessfully__c = theResult.getIsSuccess();

        paymentTransaction.blng__CardExpirationYear__c = paymentMethod.blng__CardExpirationYear__c;
        paymentTransaction.blng__CardExpirationMonth__c = paymentMethod.blng__CardExpirationMonth__c;
        paymentTransaction.blng__RequestCreditCardNumber__c = paymentMethod.blng__CardLastFour__c;
        paymentTransaction.blng__RequestTypeOfPayment__c = paymentMethod.blng__PaymentType__c;
        paymentTransaction.blng__RequestTransactionType__c = 'Charge';
        paymentTransaction.blng__CardType__c = paymentMethod.blng__CardType__c;

        
        String errorMessage;
        if ( theResult.getErrors().size() > 0 ) {
            errorMessage = String.join(theResult.getErrors(), '\n');
        }
        paymentTransaction.blng__ExceptionMessage__c = errorMessage?.left(32768);   //not sure if the correct field.

        paymentTransaction.blng__Status__c = 'Completed';
        paymentTransaction.blng__SourceTransactionId__c = uriParams.get('transactionId');
        paymentTransaction.blng__RequestInvoice__c = uriParams.get('invoiceId');

        return paymentTransaction;
    }

    private void generateResponse() {
        //response = new RestAPIResponse(new ChargePaymentResponse(payment.Id, paymentTransaction.Id, fetchGatewayStatus(), paymentTransaction.blng__ResponseCode__c, paymentTransaction.blng__ResponseMessage__c));
        response = new RestAPIResponse(new ChargePaymentResponse(payment.Id, fetchGatewayStatus(),paymentTransaction));
    }
        
    private String fetchGatewayStatus() {
        System.debug(theResult.getGatewayStatus());
        System.debug(theResult.getMessage());
        String gatewayStatusValue = '';
        if ( blng.TransactionResult.GatewayStatusType.Decline == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'Decline';
        }
        if ( blng.TransactionResult.GatewayStatusType.ValidationError == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'ValidationError';
        }
        if ( blng.TransactionResult.GatewayStatusType.PermanentFail == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'PermanentFail';
        }
        if ( blng.TransactionResult.GatewayStatusType.RequiresReview == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'RequiresReview';
        }
        if ( blng.TransactionResult.GatewayStatusType.Indeterminate == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'Indeterminate';
        }
        if ( blng.TransactionResult.GatewayStatusType.SystemError == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'SystemError';
        }
        if ( blng.TransactionResult.GatewayStatusType.Success == theResult.getGatewayStatus() ) {
            gatewayStatusValue = 'Success';
        }
        return gatewayStatusValue;
    }

    private List<blng__PaymentAllocationInvoiceLine__c> createPaymentAllocationInvoiceLines(Id paymentId, Decimal paidAmount, List<blng__InvoiceLine__c> invoiceLines) {
        List<blng__PaymentAllocationInvoiceLine__c> paymentAllocationInvoiceLines = new List<blng__PaymentAllocationInvoiceLine__c>();
        Boolean allocationComplete = false;

        for ( blng__InvoiceLine__c invoiceLineVar : invoiceLines) {
            
            blng__PaymentAllocationInvoiceLine__c paymentAllocationVar = new blng__PaymentAllocationInvoiceLine__c();
            paymentAllocationVar.blng__InvoiceLine__c = invoiceLineVar.Id;
            paymentAllocationVar.blng__Payment__c = paymentId;
            paymentAllocationVar.blng__Type__c = 'Allocation';
            
            if ( invoiceLineVar.blng__Balance__c <= paidAmount ) {
                paymentAllocationVar.blng__Amount__c = invoiceLineVar.blng__Balance__c;
                paidAmount = paidAmount - invoiceLineVar.blng__Balance__c;
            } else {
                paymentAllocationVar.blng__Amount__c = paidAmount;
                paidAmount = 0;
            }

            paymentAllocationInvoiceLines.add(paymentAllocationVar);
            if ( paidAmount == 0 ) {
                break;
            }

        }

        return paymentAllocationInvoiceLines;
    }

    public class ChargePaymentResponse {
        public String paymentId;
        public String paymentTransactionId;
        public String message;
        public String status;
        public String gatewayResponseCode;
        public String gatewayResponseMessage;

        public ChargePaymentResponse(String paymentId, String status, blng__PaymentTransaction__c paymentTransaction ) {
            this.paymentId = paymentId;
            this.paymentTransactionId = paymentTransaction?.Id;
            this.status = status;
            this.gatewayResponseCode = paymentTransaction?.blng__ResponseCode__c;
            this.gatewayResponseMessage = paymentTransaction?.blng__ResponseMessage__c;

            if ( status == 'Success' ) {
                this.message = 'The transaction was successful.';
            } else {
                this.message = 'Error charging.';
            }
        }
    }

    private blng.TransactionResult fetchMockSuccessResult() {
        blng.TransactionResult theResult = new blng.TransactionResult();
        
        theResult.setResponseCodeMessage('Successful transaction');
        theResult.setResponseMessage('Success');
        theResult.setResponseStatus('Success');
        theResult.setResponseCode('100');
        theResult.setIsSuccess(true);
        theResult.setGatewayStatus(blng.TransactionResult.GatewayStatusType.Success);

        return theResult;
        //return '{ "Id": 1, "cardCodeRespons": null, "customerProfileToken" : null, "entityName":null, "errors": (), "gatewayId" : null, "gatewayRequest" : null, "gatewayResponse" : null, "gatewayStatus":"Indeterminate", "isSuccess":false, "mapOfResponseValueByKey" : {}, "message":null, "paymentId":null, "paymentMethodId":null, "paymentToken":null, "paymentTransactionId":null, "requestTransactionType":null, "requestTypeOfPayment":null, "responseCode":null, "responseCodeMessage":null, "responseMessage":null, "responseStatus":null, "responseToValidate":null, "type":null}';
    }
}