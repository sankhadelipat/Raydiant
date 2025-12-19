public with sharing class RestAPIEmailToggleHandler extends RestAPIHandler {
    public RestAPIEmailToggleHandler() {
        super();
        operation = 'RestAPIEmailToggleHandler';
        className = 'RestApiEmailToggleHandler';
    }
        
    // override GET
    private void processGET() {
    }

    // override POST
    private void processPOST() {
        //initialize save point
        initializeSavePoint();
        
        InboundRequest request;
        //putting a try catch around deserializing to catch errors such as sending a string in place of a boolean
        //and to throw a valid request instead of a 500 Internal Server error.
        try {
            request = (InboundRequest)JSON.deserialize(requestBody, InboundRequest.class);
        } catch ( Exception e ) {
            //TODO - Need a different exception type
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }
        //validate payload
        if(String.isBlank(request.accountId)) {
            throw new InvalidInputException('Account Id cannot be blank.');
        }
        List<Account> acctList;
        try {
            acctList = [SELECT Id,  Invoice_delivery_method__c FROM Account WHERE ID=:request.accountId FOR UPDATE];
        } catch(Exception e) {
            throw new InvalidInputException('Unable to query account' + e.getMessage());
        }
        if (acctList.size() == 1){
            if (request.toggle == True){
                acctList[0].Invoice_delivery_method__c = 'Email';
            } else {
                acctList[0].Invoice_delivery_method__c = 'Do not send invoices';
            }
        } else if(acctList.size() == 0)  {
            throw new InvalidInputException('No accounts found ');
        }
        
        try {
            update acctList;
        } catch (Exception e) {
            throw new InvalidInputException('Unable to update accounts. ' + e.getMessage());
        }
        Account a = [SELECT Invoice_delivery_method__c FROM Account WHERE Id = :acctList[0].Id];
        generateResponse(a);
    }
    
    private void generateResponse(Account a) {
        response = new RestAPIResponse(new Response(a));
    }
    public class InboundRequest {
        public String accountId;
        public Boolean toggle;
    }
    public class Response {
        public Boolean emailDeliveryOn;
        public Response(Account a) {
            this.emailDeliveryOn = a.Invoice_delivery_method__c == 'Email';
        }
    }
}