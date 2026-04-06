@isTest
public class StripeInvoicePreview_Test {

    private class PreviewMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"upcoming_in_123","created":1767527975,"amount_due":10000}');
            return res;
        }
    }

    // 404 → No upcoming invoice
    private class NotFoundMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{"error":"not_found"}');
            return res;
        }
    }

    // Real error (should not clear values)
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

        insert new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            ContractTerm = 12,
            Stripe_Subscription_ID__c = 'sub_123',
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c
        );

        insert new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            ContractTerm = 12,
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_123',
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c
        );
    }

    @isTest
    static void testQueueableSuccess_Subscription() {

        Test.setMock(HttpCalloutMock.class, new PreviewMock());

        Test.startTest();
        System.enqueueJob(
            new StripeInvoicePreview(
                'sub_123',
                StripeInvoicePreview.PreviewType.SUBSCRIPTION
            )
        );
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        Date expected = DateTime.newInstance(1767527975000L).date();

        System.assertEquals(expected, c.Next_Billing_Date__c);
        System.assertEquals(100, c.Next_Billing_Amount__c);
    }

    @isTest
    static void testQueueableSuccess_Schedule() {

        Test.setMock(HttpCalloutMock.class, new PreviewMock());

        Test.startTest();
        System.enqueueJob(
            new StripeInvoicePreview(
                'sub_sched_123',
                StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE
            )
        );
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c = 'sub_sched_123'
            LIMIT 1
        ];

        Date expected = DateTime.newInstance(1767527975000L).date();

        System.assertEquals(expected, c.Next_Billing_Date__c);
        System.assertEquals(100, c.Next_Billing_Amount__c);
    }

    @isTest
    static void testQueueable_404_Subscription() {

        // First set some values manually
        Contract c = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        c.Next_Billing_Date__c = Date.today();
        c.Next_Billing_Amount__c = 500;
        update c;

        Test.setMock(HttpCalloutMock.class, new NotFoundMock());

        Test.startTest();
        System.enqueueJob(
            new StripeInvoicePreview(
                'sub_123',
                StripeInvoicePreview.PreviewType.SUBSCRIPTION
            )
        );
        Test.stopTest();

        Contract updated = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Id = :c.Id
        ];

        System.assertEquals(null, updated.Next_Billing_Date__c);
        System.assertEquals(null, updated.Next_Billing_Amount__c);
    }
    
    @isTest
    static void testQueueable_404_Schedule() {

        // First set some values manually
        Contract c = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c = 'sub_sched_123'
            LIMIT 1
        ];

        c.Next_Billing_Date__c = Date.today();
        c.Next_Billing_Amount__c = 500;
        update c;

        Test.setMock(HttpCalloutMock.class, new NotFoundMock());

        Test.startTest();
        System.enqueueJob(
            new StripeInvoicePreview(
                'sub_sched_123',
                StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE
            )
        );
        Test.stopTest();

        Contract updated = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Id = :c.Id
        ];

        System.assertEquals(null, updated.Next_Billing_Date__c);
        System.assertEquals(null, updated.Next_Billing_Amount__c);
    }

    @isTest
    static void testQueueable_400_ShouldNotClearFields() {

        Contract c = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_123'
            LIMIT 1
        ];

        c.Next_Billing_Date__c = Date.today();
        c.Next_Billing_Amount__c = 500;
        update c;

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(
            new StripeInvoicePreview(
                'sub_123',
                StripeInvoicePreview.PreviewType.SUBSCRIPTION
            )
        );
        Test.stopTest();

        Contract updated = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Id = :c.Id
        ];

        // Should remain unchanged
        System.assertNotEquals(null, updated.Next_Billing_Date__c);
        System.assertEquals(500, updated.Next_Billing_Amount__c);
    }
}