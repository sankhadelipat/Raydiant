@isTest
public class StripePaymentIntentQueueable_Test {
    // Mock class to simulate successful Stripe PaymentIntent callout
    private class StripeHttpMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Sample response body simulating Stripe PaymentIntent
            res.setBody('{' +
                        '"id":"pi_12345",' +
                        '"amount":5000,' +
                        '"currency":"usd",' +
                        '"status":"succeeded",' +
                        '"latest_charge": {' +
                        '"id":"ch_12345",' +
                        '"receipt_url":"https://stripe.com/receipt"' +
                        '},' +
                        '"invoice":"in_12345",' +
                        '"payment_method":"pm_12345",' +
                        '"customer":"cus_12345",' +
                        '"created":1693234800' +
                        '}');
            return res;
        }
    }
    
    // // Mock class to simulate failed Stripe callout
    // private class StripeHttpMockFailure implements HttpCalloutMock {
    //     public HTTPResponse respond(HTTPRequest req) {
    //         HttpResponse res = new HttpResponse();
    //         res.setStatusCode(400);
    //         res.setBody('{"error":"Bad request"}');
    //         return res;
    //     }
    // }
    
    // @TestSetup
    // static void setupTestData() {
    //     // Create Stripe Details record
    //     Stripe_Details__c sd = new Stripe_Details__c(
    //         Name = 'Stripe Details',
    //         Serect_Key__c = 'sk_test_12345',
    //         Publishable_Key__c = 'pk_test_12345'
    //     );
    //     insert sd;
        
    //     // Create a test Account
    //     Account acct = new Account(
    //         Name = 'Test Account'
    //     );
    //     insert acct;
        
    //     // Create a test Quote
    //     SBQQ__Quote__c quote = new SBQQ__Quote__c(
    //         //Name = 'Test Quote',
    //         SBQQ__Account__c = acct.Id
    //         // SBQQ__NetAmount__c = 5000
    //     );
    //     insert quote;
        
    //     // Create test stripe invoice
    //     Stripe_Invoice__c inv = new Stripe_Invoice__c(
    //         Account__c = acct.Id,
    //         Amount_Paid__c = 100.00,
    //         Quote_CPQ__c = quote.Id
    //     );
    //     insert inv;
    // }
    
    // @IsTest
    // static void testExecuteQueueableSuccess() {
    //     SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
    //     Stripe_Invoice__c inv  =[SELECT Id FROM Stripe_Invoice__c LIMIT 1];
        
    //     Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
    //     StripePaymentIntentQueueable queueableJob = new StripePaymentIntentQueueable(
    //         inv.Id,
    //         'pi_12345',
    //         'sub_123',
    //         quote.Id,
    //         true,
    //         false
    //     );
        
    //     Test.startTest();
    //     System.enqueueJob(queueableJob);
    //     Test.stopTest();
        
    //     // Assert that Payment_Transaction__c record was inserted
    //     Payment_Transaction__c pt = [SELECT Id, Stripe_Payment_ID__c, Status__c, Amount_Paid__c FROM Payment_Transaction__c LIMIT 1];
    //     System.assertEquals('pi_12345', pt.Stripe_Payment_ID__c);
    //     System.assertEquals('Success', pt.Status__c);
    //     System.assertEquals(50, pt.Amount_Paid__c); // 5000 / 100
    // }
    
    // @IsTest
    // static void testExecuteQueueableFailure() {
    //     SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
    //     Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());
        
    //     StripePaymentIntentQueueable queueableJob = new StripePaymentIntentQueueable(
    //         null,
    //         'pi_fail',
    //         'sub_123',
    //         quote.Id,
    //         true,
    //         false
    //     );
        
    //     Test.startTest();
    //     System.enqueueJob(queueableJob);
    //     Test.stopTest();
        
    //     // Assert that Logger__c record was created
    //     Integer loggerCount = [SELECT COUNT() FROM Logger__c WHERE Apex_Class__c='StripePaymentIntentQueueable'];
    //     System.assertEquals(1, loggerCount);
    // }
}