@isTest
global with sharing class RestAPIEmailChangeTest {
    @isTest
    static void PostPositiveEmailChange(){
            
            Account a = new Account(Name = 'Test Account');
            INSERT a;
            SBQQ__Quote__c q = new SBQQ__Quote__c(RAY_Contract_Status__c = 'Activated');
            INSERT q;
            Contract c = new Contract(AccountId = a.Id, Status = 'Draft', SBQQ__Quote__c = q.Id, RAY_Dashboard_Email__c = 'testapi@test.com');
            INSERT c;
        
            String originalEmail = 'testapi@test.com';
            String updatedEmail = 'test-updated@test.com';

            //TODO create an account with and email
            //TODO create contract with a different email
            RestRequest req = new RestRequest(); 
            RestResponse res = new RestResponse();
           
            RestApiEmailChangeHandler.InboundRequest body = new RestApiEmailChangeHandler.InboundRequest();
            //OuterClass.InnerClass VariableName = value
            body.email = updatedEmail;
            body.accountId = a.Id;
            
            req.requestURI = '/services/apexrest/Account/UpdateEmail';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serializePretty(Body));
            
            RestContext.request = req;
            RestContext.response= res;

       
            Test.startTest();
            RestAPIEmailChange.doPost();
            
            Test.stopTest();
            //assert value of contract email AFTER API call
            Account queryAccount = [SELECT Dashboard_Email__c FROM Account WHERE Id =: body.accountId];
            system.assertEquals(queryAccount.Dashboard_Email__c, updatedEmail);
    }
    @IsTest
    static void PostNoAccountEmailChange(){
            

    
        String originalEmail = 'testapi@test.com';
        String updatedEmail = 'test-updated@test.com';

        //TODO create an account with and email
        //TODO create contract with a different email
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
       
        RestApiEmailChangeHandler.InboundRequest body = new RestApiEmailChangeHandler.InboundRequest();
        //OuterClass.InnerClass VariableName = value
        body.email = updatedEmail;
        body.accountId = '';
        
        req.requestURI = '/services/apexrest/Account/UpdateEmail';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(Body));
        
        RestContext.request = req;
        RestContext.response= res;

   
        Test.startTest();
        RestAPIEmailChange.doPost();
        
        Test.stopTest();
    }

}