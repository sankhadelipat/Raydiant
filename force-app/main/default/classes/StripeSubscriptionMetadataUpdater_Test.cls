@isTest
private class StripeSubscriptionMetadataUpdater_Test {

    // Mock Stripe callout
    private class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(
                req.getEndpoint().contains('/v1/subscriptions/sub_123'),
                'Endpoint mismatch'
            );

            // Validate body contains metadata fields
            System.assert(req.getBody().contains('metadata[subscription_source]=salesforce'));
            System.assert(req.getBody().contains('metadata[Contract_ID]'));
            System.assert(req.getBody().contains('metadata[Contract_Number]'));
            System.assert(req.getBody().contains('metadata[Contract_Record_URL]'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"sub_123","object":"subscription","status":"active"}');
            return res;
        }
    }
    
    // Mock Stripe callout
    private class ErrorStripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Metdata error","message":"Invalid JSON body"}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Stripe Settings
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123',
            Publishable_Key__c = 'pk_test_123'
        );
        insert stripeSetting;
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_1234'
        );
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            ContractTerm = 12,
            Stripe_Subscription_ID__c = 'sub_123',
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c
        );
        insert con;
    }

    @isTest
    static void testMetadataUpdate() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());

        // Execute Queueable
        Test.startTest();
        System.enqueueJob(new StripeSubscriptionMetadataUpdater('sub_123', 'salesforce'));
        Test.stopTest();
    }
    
    @isTest
    static void testMetadataUpdateError() {
        Test.setMock(HttpCalloutMock.class, new ErrorStripeMock());

        // Execute Queueable
        Test.startTest();
        System.enqueueJob(new StripeSubscriptionMetadataUpdater('sub_123', 'stripe'));
        Test.stopTest();

        // Validate Logger created
        Integer logCount = [SELECT COUNT() FROM Logger__c];
        System.assert(logCount > 0, 'Logger should have created.');
    }
}