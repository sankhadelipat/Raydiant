@IsTest
public class StripeInvoicePreviewBatch_Test {

    // 200 Success
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"upcoming_in_123","created":1767527975,"amount_due":20000}');
            return res;
        }
    }

    // 404 No Upcoming Invoice
    private class NotFoundMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{"error":"not_found"}');
            return res;
        }
    }

    // 400 Error
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"bad_request"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_999'
        );

        Account acc = new Account(
            Name = 'Batch Test Account',
            Stripe_Customer_ID__c = 'cus_batch_1'
        );
        insert acc;

        // Contract with billing values (should be processed)
        insert new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            ContractTerm = 12,
            Stripe_Subscription_ID__c = 'sub_batch_1',
            Next_Billing_Date__c = Date.today(),
            Next_Billing_Amount__c = 50
        );
    }

    @IsTest
    static void testBatchSuccess_200() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new StripeInvoicePreviewBatch(), 1);
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_batch_1'
            LIMIT 1
        ];

        Date expectedDate = DateTime.newInstance(1767527975000L).date();

        System.assertEquals(expectedDate, c.Next_Billing_Date__c);
        System.assertEquals(200, c.Next_Billing_Amount__c);
    }

    @IsTest
    static void testBatch404_ShouldClearFields() {

        Test.setMock(HttpCalloutMock.class, new NotFoundMock());

        Test.startTest();
        Database.executeBatch(new StripeInvoicePreviewBatch(), 1);
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_batch_1'
            LIMIT 1
        ];

        System.assertEquals(null, c.Next_Billing_Date__c);
        System.assertEquals(null, c.Next_Billing_Amount__c);
    }

    @IsTest
    static void testBatch400_ShouldNotClearFields() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Database.executeBatch(new StripeInvoicePreviewBatch(), 1);
        Test.stopTest();

        Contract c = [
            SELECT Next_Billing_Date__c, Next_Billing_Amount__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = 'sub_batch_1'
            LIMIT 1
        ];

        // Original values should remain
        System.assertNotEquals(null, c.Next_Billing_Date__c);
        System.assertEquals(50, c.Next_Billing_Amount__c);
    }
}