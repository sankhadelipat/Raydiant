/*Need to go over the "email", "id" issue when testing for address update. 
It will update if I add the acct id to the "email" field when updating.*/

public without sharing class RestAPIUpdateAccountAddressHandler extends RestAPIHandler {
    
    public RestAPIUpdateAccountAddressHandler() {
        super();
        operation = 'RestAPIUpdateAccountAddressHandler';
        className = 'RestAPIUpdateAccountAddressHandler';
    }

    // override GET
    private void processGET() {
      
    }
        
    // override POST
    private void processPOST() {
        //initialize save point
        initializeSavePoint();
        
        system.debug(uriParts);
        
        String operationVar = getParamFromUri(2);
        if (operationVar != 'UpdateAddress') {
            throw new InvalidInputException('Invalid address post request URI. Valid format is /Account/UpdateAddress/');
        } 
        system.debug(operationVar);

        if ( String.isBlank(requestBody) ) {
            throw new InvalidInputException('No request body specified.');
        }
        
        inboundRequest request;
        try {
            request = (inboundRequest)JSON.deserialize(requestBody, inboundRequest.class);
        } catch ( Exception e ) {
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }

        if(String.isBlank(request.accountId)) {
            throw new InvalidInputException('Account Id cannot be blank.');
        }   
    
        Account acct;
        try {
            acct = RestApiUtility.getAccount(request.accountId);
        } catch (Exception e) {
            throw new InvalidInputException('No Account found. Exception: ' + e.getMessage());
        }

       
        try {
            acct.BillingStreet = request.BillingStreet;
            acct.BillingCity = request.BillingCity;
            acct.BillingState = request.BillingState;
            acct.BillingCountry = request.BillingCountry;
            acct.BillingPostalCode = request.BillingPostalCode;
            acct.ShippingStreet = request.ShippingStreet;
            acct.ShippingCity = request.ShippingCity;
            acct.ShippingState = request.ShippingState;
            acct.ShippingCountry = request.ShippingCountry;
            acct.ShippingPostalCode = request.ShippingPostalCode;
            update acct;
        } catch (Exception e) {
            throw new InvalidInputException('Error occurred');
        }
        generateResponse(request.accountId);

   }
        
    private void generateResponse(String accountId) {
        Account myAccount = RestAPIUtility.getAccount(accountId);
        response = new RestAPIResponse(new RestAPIGetAccountAddressHandler.RestAPIGetAccountAddressResponse(myAccount, null, null));
    }
        
    public class inboundRequest {
        public String accountId;
        public String billingStreet;
        public String billingCity;
        public String billingState;
        public String billingCountry;
        public String billingPostalCode;
        public String shippingStreet;
        public String shippingCity;
        public String shippingState;
        public String shippingCountry;
        public String shippingPostalCode;
    }
    
}