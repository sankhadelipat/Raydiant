//Description: Updates the email address associated with an accounts accounts


public without sharing class RestAPIEmailChangeHandler extends RestAPIHandler {
    public RestAPIEmailChangeHandler() {
        super();
        operation = 'RestAPIEmailChangeHandler';
        className = 'RestApiEmailChangeHandler';
    }

    private void processGET() {

    }
        
    private void processPOST() {
        //initialize save point
        initializeSavePoint();

        if ( String.isBlank(requestBody) ) {
            throw new InvalidInputException('No request body specified.');
        }
        InboundRequest request;

        try {
            request = (InboundRequest)JSON.deserialize(requestBody, InboundRequest.class);
        } catch ( Exception e ) {
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }

        if(String.isBlank(request.accountId)) {
        
            throw new InvalidInputException('Account Id cannot be blank.');
        }   
    
        List<Account> accountList;
        try {
            accountList = [SELECT Id, Dashboard_Email__c FROM Account WHERE Id =: request.accountId];
            if (accountList.size() ==0){
                throw new InvalidInputException('No account found for given account ID. ');
            }
            for(Account accVar: accountList) {
                accVar.Dashboard_Email__c = request.email;
            }
            
        update accountList;
        } catch (Exception e) {
            throw new InvalidInputException('Unable to update email. ' + e.getMessage());
        } 

        generateResponse();
    
   }
        
    private void generateResponse() {
        response = new RestAPIResponse('The email has been updated successfully.');
    }
        
    public class InboundRequest {
        public String accountId;
        public String email;
    }   
}