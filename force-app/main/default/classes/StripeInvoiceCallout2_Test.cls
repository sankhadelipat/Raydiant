@IsTest
private class StripeInvoiceCallout2_Test {
    @TestSetup
    static void setupData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
        
        Account testAccount = new Account(
            Name = 'Test Account', 
            BillingCountry = 'United States',
            Stripe_Customer_ID__c = 'cus_123'
        );
        insert testAccount;
        
        List<Product2> testProducts = new List<Product2>();
        testProducts.add(new Product2(
            Name = 'Test Product 1',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            Stripe_Product_Id__c = 'pr_1234'
        ));
        testProducts.add(new Product2(
            Name = 'Test Product 2',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'One-time',
            SBQQ__ChargeType__c = 'One-time',
            Stripe_Product_Id__c = 'pr_5678'
        ));
        insert testProducts;
        
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update standardPricebook;
        
        List<PricebookEntry> testPbes = new List<PricebookEntry>();
        testPbes.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProducts[0].Id,
            UnitPrice = 100.00,
            IsActive = true
        ));
        testPbes.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProducts[1].Id,
            UnitPrice = 200.00,
            IsActive = true
        ));
        insert testPbes;
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            // Name = 'Test Quote',
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PaymentTerms__c = 'Net 30',
            SBQQ__StartDate__c = System.today(),
            SBQQ__PriceBook__c = standardPricebook.Id,
            SBQQ__PricebookId__c = standardPricebook.Id,
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert testQuote;
        
        List<SBQQ__QuoteLine__c> testQuoteLines = new List<SBQQ__QuoteLine__c>();
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = testProducts[0].Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbes[0].Id
        ));
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = testProducts[1].Id,
            SBQQ__ListPrice__c = 200.00,
            SBQQ__NetPrice__c = 200.00,
            SBQQ__SpecialPrice__c = 200.00,
            SBQQ__PricebookEntryId__c = testPbes[1].Id
        ));
        insert testQuoteLines;
    }
    
    private class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/v1/invoices') && !req.getEndpoint().contains('/send')) {
                res.setBody('{"id": "inv_123"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/prices')) {
                res.setBody('{"id": "price_123"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/add_lines')) {
                res.setBody('{"success": true}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/send')) {
                res.setBody('{"id": "inv_123","effective_at":1700000000,"period_start":1700000000,'
                            + '"period_end":1700003600,"webhooks_delivered_at":1700004000,"due_date":1700005000,'
                            + '"automatically_finalizes_at":1700006000,"currency":"usd","total":10000,'
                            + '"total_excluding_tax":9000,"subtotal":8000,"amount_paid":2000,"amount_due":6000,'
                            + '"amount_remaining":4000,"tax":500,"billing_reason":"subscription_create","paid":true,'
                            + '"invoice_pdf":"https://stripe.com/inv.pdf","hosted_invoice_url":"https://stripe.com/inv",'
                            + '"number":"INV-001","status":"open","lines":{"data":[{"id":"line_1","quantity":1,'
                            + '"description":"Test Product","period":{"start":1700000000,"end":1700003600},'
                            + '"price":{"unit_amount_decimal":"100.00"},"unit_amount_excluding_tax":"90.00"}]}}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":"unknown"}');
                res.setStatusCode(400);
            }
            
            return res;
        }
    }

    @IsTest
    static void testHappyFlow() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        List<Logger__c> allLoggers = [SELECT Id FROM Logger__c];
        delete allLoggers;

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Logger__c],
            'No errors should be logged in the happy path'
        );
    }

    private class StripeMock_PriceFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            if (req.getEndpoint().contains('/v1/prices')) {
                r.setStatusCode(500);
                r.setBody('{"error":"price failed"}');
            } else if (req.getEndpoint().contains('/v1/invoices') && !req.getEndpoint().contains('/send')) {
                r.setStatusCode(200);
                r.setBody('{"id":"inv_123"}');
            } else if (req.getEndpoint().contains('/add_lines')) {
                r.setStatusCode(200);
                r.setBody('{"success":true}');
            } else if (req.getEndpoint().contains('/send')) {
                r.setStatusCode(200);
                r.setBody('{"status":"sent"}');
            }
            return r;
        }
    }

    @IsTest
    static void testPriceFailCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_PriceFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Price failure should create a logger record'
        );
    }

    private class StripeMock_AddLinesFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();

            if (req.getEndpoint().contains('/add_lines')) {
                r.setStatusCode(400);
                r.setBody('{"error":"add lines failed"}');
            } else if (req.getEndpoint().contains('/v1/invoices') && !req.getEndpoint().contains('/send')) {
                r.setStatusCode(200);
                r.setBody('{"id":"inv_123"}');
            } else if (req.getEndpoint().contains('/v1/prices')) {
                r.setStatusCode(200);
                r.setBody('{"id":"price_123"}');
            } else if (req.getEndpoint().contains('/send')) {
                r.setStatusCode(200);
                r.setBody('{"status":"sent"}');
            }

            return r;
        }
    }

    @IsTest
    static void testAddLinesFailureCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_AddLinesFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Add line failure should insert a logger'
        );
    }

    private class StripeMock_SendFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();

            if (req.getEndpoint().contains('/send')) {
                r.setStatusCode(400);
                r.setBody('{"error":"send failed"}');
            } else if (req.getEndpoint().contains('/v1/invoices') && !req.getEndpoint().contains('/send')) {
                r.setStatusCode(200);
                r.setBody('{"id":"inv_123"}');
            } else if (req.getEndpoint().contains('/v1/prices')) {
                r.setStatusCode(200);
                r.setBody('{"id":"price_123"}');
            } else if (req.getEndpoint().contains('/add_lines')) {
                r.setStatusCode(200);
                r.setBody('{"success":true}');
            }

            return r;
        }
    }

    @IsTest
    static void testSendFailureCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_SendFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Send failure should create a logger record'
        );
    }

    private class StripeMock_InvoiceCreateFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();

            if (req.getEndpoint().contains('/v1/invoices') && !req.getEndpoint().contains('/send')) {
                r.setStatusCode(500);
                r.setBody('{"error":"invoice create failed"}');
            } else {
                r.setStatusCode(200);
                r.setBody('{"id":"dummy"}');
            }

            return r;
        }
    }

    @IsTest
    static void testInvoiceCreateFailureCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_InvoiceCreateFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Invoice creation fail should create a logger'
        );
    }

    private class StripeMock_BadJson implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('INVALID_JSON_123');
            return r;
        }
    }

    @IsTest
    static void testMalformedJsonCreatesLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeMock_BadJson());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Malformed JSON should create logger entry'
        );
    }

    @IsTest
    static void testMissingCustomerIdCreatesLogger() {
        Account a = [SELECT Id, Stripe_Customer_ID__c FROM Account LIMIT 1];
        a.Stripe_Customer_ID__c = null;
        update a;

        Test.setMock(HttpCalloutMock.class, new StripeMock());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ q.Id }, false);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM Logger__c] > 0,
            'Missing customer ID should create a logger entry'
        );
    }
}