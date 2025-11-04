@isTest
public class StripeMetadataUpdater_Test {
 // Mock class for successful callout
    private class StripeHttpMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cus_12345","object":"customer"}');
            return res;
        }
    }

    // Mock class for failed callout
    private class StripeHttpMockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad request"}');
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Insert Stripe Details record
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_12345'
        );
        insert sd;
    }

    @IsTest
    static void testUpdateMetadataInvocableMethod() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());

        StripeMetadataUpdater.MetadataInput input = new StripeMetadataUpdater.MetadataInput();
        input.stripeCustomerId = 'cus_test123';
        input.accountRecordUrl = 'https://example.com/account/001xx';
        input.internalId = 'INT-001';
        input.accountNumber = 'AC-123';

        List<StripeMetadataUpdater.MetadataInput> inputs = new List<StripeMetadataUpdater.MetadataInput>{ input };

        Test.startTest();
        StripeMetadataUpdater.updateMetadata(inputs);
        Test.stopTest();
    }

    @IsTest
    static void testUpdateStripeCustomerMetadataFutureSuccess() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());

        Test.startTest();
        StripeMetadataUpdater.updateStripeCustomerMetadata(
            'cus_test123',
            'https://example.com/account/001xx',
            'INT-001',
            'AC-123'
        );
        Test.stopTest();

        // Ensure no Logger__c record was created
        Integer loggerCount = [SELECT COUNT() FROM Logger__c WHERE Apex_Class__c='StripeMetadataUpdater'];
        System.assertEquals(0, loggerCount);
    }

    @IsTest
    static void testUpdateStripeCustomerMetadataFutureFailure() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());

        Test.startTest();
        StripeMetadataUpdater.updateStripeCustomerMetadata(
            'cus_test123',
            'https://example.com/account/001xx',
            'INT-001',
            'AC-123'
        );
        Test.stopTest();

        // Ensure Logger__c record was created
        Integer loggerCount = [SELECT COUNT() FROM Logger__c WHERE Apex_Class__c='StripeMetadataUpdater'];
        System.assertEquals(1, loggerCount);
    }
}