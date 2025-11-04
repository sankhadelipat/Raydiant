@IsTest
public class StripeTransactionQueueable_Test {
    
    // Mock for success scenario
    private class StripeSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            // Fake Stripe response
            res.setBody('{' +
                '"id": "pi_test_123",' +
                '"amount": 5000,' +  // $50
                '"currency": "usd",' +
                '"status": "succeeded",' +
                '"latest_charge": "ch_12345",' +
                '"created": 1672531200,' + // fixed epoch timestamp
                '"last_payment_error": null' +
            '}');
            return res;
        }
    }
    
    // Mock for failure scenario
    private class StripeFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request"}}');
            return res;
        }
    }
    
         @TestSetup
        static void setupData() {
            // Insert Stripe Details config
            Stripe_Details__c details = new Stripe_Details__c(
                Name = 'Stripe Details',
                Serect_Key__c = 'sk_test_123'
            );
            insert details;
            
            // Insert Account
            Account acc = new Account(
                Name = 'Test Account',
                Stripe_Customer_ID__c = 'cus_test_123'
            );
            insert acc;
        
            // Insert Opportunity (required for Quote)
            Opportunity opp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10),
                AccountId = acc.Id
            );
            insert opp;
        
            // Insert Quote (do NOT set Name directly)
            SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Opportunity2__c = opp.Id,
                SBQQ__Account__c = acc.Id
            );
            insert quote;
        }

    
    @IsTest
    static void testSuccessScenario() {
        // Get test data
        Account acc = [SELECT Id, Stripe_Customer_ID__c FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new StripeSuccessMock());
        
        // Run queueable
        Test.startTest();
        System.enqueueJob(new StripeTransactionQueueable('pi_test_123', quote.Id, acc.Stripe_Customer_ID__c));
        Test.stopTest();
        
        // Assert Payment Transaction was created
        Payment_Transaction__c pt = [SELECT Id, Stripe_Payment_Status__c, Status__c, Amount_Paid__c 
                                     FROM Payment_Transaction__c LIMIT 1];
        System.assertEquals('succeeded', pt.Stripe_Payment_Status__c);
        System.assertEquals('Success', pt.Status__c);
        System.assertEquals(50, pt.Amount_Paid__c); // 5000/100
    }
    
    @IsTest
    static void testFailureScenario() {
        // Get test data
        Account acc = [SELECT Id, Stripe_Customer_ID__c FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        // Set failure mock
        Test.setMock(HttpCalloutMock.class, new StripeFailureMock());
        
        // Run queueable
        Test.startTest();
        System.enqueueJob(new StripeTransactionQueueable('pi_fail_123', quote.Id, acc.Stripe_Customer_ID__c));
        Test.stopTest();
        
        // Assert Logger created
        Logger__c log = [SELECT Id, Status__c, Apex_Class__c, Apex_Method__c 
                         FROM Logger__c LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assertEquals('StripeTransactionQueueable', log.Apex_Class__c);
        System.assertEquals('execute', log.Apex_Method__c);
    }
}