@IsTest
private class StripeInvoiceQueueable_Test {

    @TestSetup
    static void setupData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );

        Account acc = new Account(
            Name = 'Test Acc',
            Stripe_Customer_ID__c = 'cus_test_123456'
        );
        insert acc;

        Product2 prod = new Product2(
            Name = 'Test Product',
            SBQQ__SubscriptionType__c = 'One-time',
            Stripe_Product_Id__c = 'prod_test_123'
        );
        insert prod;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id
        );
        insert quote;

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c = 100
        );
        insert ql;

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_123',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
    }

    private class StripeMock_Success implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();

            r.setStatusCode(200);
            r.setBody(
                '{' +
                    '"id":"inv_test_123",' +
                    '"customer":"cus_test_123456",' +
                    '"effective_at":1700000000,' +
                    '"period_start":1700000000,' +
                    '"period_end":1700003600,' +
                    '"webhooks_delivered_at":1700004000,' +
                    '"due_date":1700005000,' +
                    '"automatically_finalizes_at":1700006000,' +
                    '"currency":"usd",' +
                    '"total":10000,' +
                    '"total_excluding_tax":9000,' +
                    '"subtotal":8000,' +
                    '"amount_paid":2000,' +
                    '"amount_due":6000,' +
                    '"amount_remaining":4000,' +
                    '"tax":500,' +
                    '"paid":true,' +
                    '"invoice_pdf":"https://stripe.com/pdf",' +
                    '"hosted_invoice_url":"https://stripe.com/inv",' +
                    '"number":"INV-001",' +
                    '"status":"paid",' +
                    '"payments":{"data":[{' +
                        '"payment":{"payment_intent":"pi_test_555"}' +
                    '}]},' +
                    '"parent":{"subscription_details":{"subscription":"sub_789"}},' +
                    '"lines":{"data":[{' +
                        '"id":"li_test_1",' +
                        '"amount":10000,' +
                        '"quantity":1,' +
                        '"description":"Test Product",' +
                        '"pricing":{"price_details":{"product":"prod_test_123"}},' +
                        '"period":{"start":1700000000,"end":1700003600}' +
                    '}]}' +
                '}'
            );

            return r;
        }
    }

    private class StripeMock_ErrorStatus implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('{"error":"server"}');
            return r;
        }
    }

    private class StripeMock_BadJson implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('INVALID_JSON');
            return r;
        }
    }

    private class StripeMock_NoAccount implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody(
                '{' +
                    '"id":"inv_x",' +
                    '"customer":"cus_NOT_EXIST",' +
                    '"lines":{"data":[]}' +
                '}'
            );
            return r;
        }
    }

    private class StripePaymentIntentMock implements Queueable {
        public void execute(QueueableContext qc) {}
    }

    @IsTest
    static void testHappyFlow() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_Success());

        Contract con = [SELECT Stripe_Subscription_ID__c FROM Contract LIMIT 1];
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        List<Logger__c> allLoggers = [SELECT Id FROM Logger__c];
        delete allLoggers;

        Test.startTest();
        System.enqueueJob(new StripeInvoiceQueueable(
            'inv_test_123',
            con.Stripe_Subscription_ID__c,
            q.Id,
            true,
            true
        ));
        Test.stopTest();

        // Assert invoice created
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'inv_test_123']
        );

        // Assert line item created
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Stripe_Invoice_Line_Item__c WHERE Stripe_Invoice_line_Item_Id__c = 'li_test_1']
        );

        // No errors expected (This should be uncommented)
        // System.assertEquals(0, [SELECT COUNT() FROM Logger__c]);
    }

    @IsTest
    static void testErrorStatusLogs() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_ErrorStatus());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new StripeInvoiceQueueable('inv_FAIL', null, q.Id, false, false));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Non-200 must log error'
        );
    }

    @IsTest
    static void testBadJsonLogs() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_BadJson());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new StripeInvoiceQueueable('inv_BADJSON', null, q.Id, false, false));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Bad JSON must log error'
        );
    }

    @IsTest
    static void testNoAccountFoundLogs() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_NoAccount());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        // Force CustomerId mismatch by clearing Stripe_Customer_ID__c
        Account a = [SELECT Id FROM Account LIMIT 1];
        a.Stripe_Customer_ID__c = 'SOMETHING_ELSE';
        update a;

        Test.startTest();
        System.enqueueJob(new StripeInvoiceQueueable('inv_NOACC', null, q.Id, false, false));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Missing account must log error'
        );
    }
}