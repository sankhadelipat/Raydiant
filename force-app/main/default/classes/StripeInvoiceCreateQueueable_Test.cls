@IsTest
private class StripeInvoiceCreateQueueable_Test {
    @TestSetup
    static void setupData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        insert stripeSetting;
        
        Account acc = new Account(
            Name = 'Test Account',
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
            HttpResponse res = new HttpResponse();

            // Invoice GET
            if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setStatusCode(200);
                res.setBody('{' +
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
                    '"invoice_pdf":"https://stripe.com/invoice.pdf",' +
                    '"hosted_invoice_url":"https://stripe.com/invoice",' +
                    '"number":"INV-100",' +
                    '"status":"paid",' +
                    '"lines":{"data":[{' +
                    '"id":"li_test_1",' +
                    '"quantity":1,' +
                    '"amount":10000,' +
                    '"description":"Test Product",' +
                    '"pricing":{"price_details":{"product":"prod_test_123"}},' +
                    '"period":{"start":1700000000,"end":1700003600}' +
                    '}]}' +
                '}');
                return res;
            }

            // DEFAULT
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class StripeMock_ErrorStatus implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"server"}');
            return res;
        }
    }

    private class StripeMock_BadJson implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('INVALID_JSON');
            return res;
        }
    }

    private class StripeMock_NoCustomerAccount implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{' +
                '"id":"inv_x",' +
                '"customer":"cus_DOESNOTEXIST",' +
                '"lines":{"data":[]}' +
            '}');
            return res;
        }
    }

    @IsTest
    static void testHappyFlow() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_Success());

        Contract c = [SELECT Stripe_Subscription_ID__c FROM Contract LIMIT 1];
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        List<Logger__c> allLoggers = [SELECT Id FROM Logger__c];
        delete allLoggers;

        Test.startTest();
        System.enqueueJob(new StripeInvoiceCreateQueueable(
            'inv_test_123', 
            c.Stripe_Subscription_ID__c, 
            q.Id
        ));
        Test.stopTest();

        // Should not log errors
        System.assertEquals(0, [SELECT COUNT() FROM Logger__c], 'No errors expected');

        // Invoice should be created
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'inv_test_123']
        );

        // Line item should be created
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Stripe_Invoice_Line_Item__c WHERE Stripe_Invoice_line_Item_Id__c = 'li_test_1']
        );
    }

    @IsTest
    static void testErrorStatusCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_ErrorStatus());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new StripeInvoiceCreateQueueable('inv_FAIL', null, q.Id));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Error status must create logger'
        );
    }

    @IsTest
    static void testInvalidJsonCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_BadJson());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new StripeInvoiceCreateQueueable('inv_BAD', null, q.Id));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Bad JSON should create log entry'
        );
    }

    @IsTest
    static void testNoAccountFoundCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_NoCustomerAccount());

        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        System.enqueueJob(new StripeInvoiceCreateQueueable('inv_X', null, q.Id));
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Missing account should log error'
        );
    }
}