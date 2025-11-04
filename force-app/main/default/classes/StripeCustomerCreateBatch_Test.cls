@isTest
public class StripeCustomerCreateBatch_Test {

    // Mock class to simulate Stripe API response
    private class StripeMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"cus_test123"}'); // fake Stripe customer ID
            res.setStatusCode(200);
            return res;
        }
    }

    private class StripeMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Invalid request"}');
            res.setStatusCode(400);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Create required Stripe Details custom setting
        Stripe_Details__c details = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert details;

        // Create required Stripe Org Account
        insert new stripeGC__Stripe_Account__c(Name = 'Test Org Stripe Account');
    }

    @isTest
    static void testBatchSuccess() {
        // Create an Account without Stripe_Customer_ID__c
        Account acc = new Account(
            Name = 'Test Account Success',
            //Bill_To_Email__c = 'test@example.com',
            Phone = '1234567890',
            Description = 'Test description'
            //Account_Number__c = 'ACC123',
            //Account_Record_URL__c = 'https://test.com/account/123'
        );
        insert acc;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeMockSuccess());

        // Run the batch
        Database.executeBatch(new StripeCustomerCreateBatch(), 1);
        Test.stopTest();

        // Verify Account updated with Stripe ID
        acc = [SELECT Stripe_Customer_ID__c, Stripe_Customer_URL__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, acc.Stripe_Customer_ID__c, 'Stripe ID should be populated');
        System.assert(acc.Stripe_Customer_URL__c.contains(acc.Stripe_Customer_ID__c), 'Stripe URL should contain customer ID');
    }

    @isTest
    static void testBatchError() {
        // Create an Account without Stripe_Customer_ID__c
        Account acc = new Account(
            Name = 'Test Account Error'
            //Bill_To_Email__c = 'error@example.com'
        );
        insert acc;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeMockError());

        // Run the batch
        Database.executeBatch(new StripeCustomerCreateBatch(), 1);
        Test.stopTest();

        // Verify Stripe_Customer_ID__c not updated
        acc = [SELECT Stripe_Customer_ID__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, acc.Stripe_Customer_ID__c, 'Stripe ID should not be populated');

        // Verify logger record inserted
        Logger__c log = [SELECT Id, Status__c, Apex_Class__c FROM Logger__c LIMIT 1];
        System.assertEquals('Error', log.Status__c, 'Logger should capture error');
        System.assertEquals('StripeCustomerCreateBatch', log.Apex_Class__c, 'Logger should reference batch class');
    }
}