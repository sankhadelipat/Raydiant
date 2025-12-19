@isTest
public class StripeInvoicePreview_Test {

    private class PreviewMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"upcoming_in_123","created":1767527975}');
            return res;
        }
    }
    
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invoice error","message":"Invalid subscription Id"}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_999'
        );
        
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
    static void testQueueableSuccess() {

        Test.setMock(HttpCalloutMock.class, new PreviewMock());

        Test.startTest();
        System.enqueueJob(new StripeInvoicePreview('sub_123'));
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        Date expected = DateTime.newInstance(1767527975000L).date();

        System.assertEquals(expected, c.Next_Billing_Date__c);
    }
    
    @isTest
    static void testQueueableError() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(new StripeInvoicePreview('sub_123'));
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        System.assertEquals(null, c.Next_Billing_Date__c);
    }
    
    @isTest
    static void testBatchableSuccess() {

        Test.setMock(HttpCalloutMock.class, new PreviewMock());

        Test.startTest();
        StripeInvoicePreviewBatch batch = new StripeInvoicePreviewBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        Date expected = DateTime.newInstance(1767527975000L).date();

        System.assertEquals(expected, c.Next_Billing_Date__c);
    }
    
    @isTest
    static void testBatchableError() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        StripeInvoicePreviewBatch batch = new StripeInvoicePreviewBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        System.assertEquals(null, c.Next_Billing_Date__c);
    }
}