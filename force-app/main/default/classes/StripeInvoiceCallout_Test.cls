@IsTest
private class StripeInvoiceCallout_Test {
    
    // --- Fake HTTP Mock (Success) ---
    private class StripeHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setBody('{"id":"price_fake123"}');
            }
            else if (req.getEndpoint().contains('/add_lines')) {
                res.setBody('{"id":"in_fake123","object":"invoice"}');
            }
            else if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setBody('{\"id\":\"in_fake123\",\"object\":\"invoice\",\"account_country\":\"US\",\"account_name\":\"Displai\",\"account_tax_ids\":null,\"amount_due\":28800,\"amount_overpaid\":0,\"amount_paid\":28800,\"amount_remaining\":0,\"amount_shipping\":0,\"application\":null,\"attempt_count\":0,\"attempted\":true,\"auto_advance\":false,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null,\"provider\":null,\"status\":null},\"automatically_finalizes_at\":null,\"billing_reason\":\"subscription_create\",\"collection_method\":\"charge_automatically\",\"created\":1756801474,\"currency\":\"usd\",\"custom_fields\":null,\"customer\":\"cus_SweIjgQ67uYqLs\",\"customer_address\":null,\"customer_email\":\"johndoe08272025@test.test\",\"customer_name\":\"QuotetoCash08/27/2025\",\"customer_phone\":null,\"customer_shipping\":null,\"customer_tax_exempt\":\"none\",\"customer_tax_ids\":[],\"default_payment_method\":null,\"default_source\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"due_date\":null,\"effective_at\":1756801474,\"ending_balance\":0,\"footer\":null,\"from_invoice\":null,\"hosted_invoice_url\":\"https://invoice.stripe.com/i/acct_1R1YquPuJCefzpgm/test_YWNjdF8xUjFZcXVQdUpDZWZ6cGdtLF9TeW42UUtBQ2JnMGd6eHpqa0tneWg3YXV5Y2hsdXpnLDE0NzM1MTYwNg0200J535luVi?s=ap\",\"invoice_pdf\":\"https://pay.stripe.com/invoice/acct_1R1YquPuJCefzpgm/test_YWNjdF8xUjFZcXVQdUpDZWZ6cGdtLF9TeW42UUtBQ2JnMGd6eHpqa0tneWg3YXV5Y2hsdXpnLDE0NzM1MTYwNg0200J535luVi/pdf?s=ap\",\"issuer\":{\"type\":\"self\"},\"last_finalization_error\":null,\"latest_revision\":null,\"lines\":{\"object\":\"list\",\"data\":[{\"id\":\"il_fake1\",\"object\":\"line_item\",\"amount\":19900,\"currency\":\"usd\",\"description\":\"RaydiantScreenRayStandardN100\",\"discount_amounts\":[],\"discountable\":true,\"discounts\":[],\"invoice\":\"in_1S2pW2PuJCefzpgmpGy8biLr\",\"livemode\":false,\"metadata\":{},\"parent\":{\"invoice_item_details\":{\"invoice_item\":\"ii_1S2pW2PuJCefzpgmalwLeIuN\",\"proration\":false,\"proration_details\":{\"credited_items\":null},\"subscription\":\"sub_1S2pW3PuJCefzpgmjhIIz1nS\"},\"subscription_item_details\":null,\"type\":\"invoice_item_details\"},\"period\":{\"end\":1759393474,\"start\":1756801474},\"pretax_credit_amounts\":[],\"price\":{\"price_details\":{\"price\":\"price_1S2pV6PuJCefzpgmdsjFgoe8\",\"product\":\"prod_Squ82cbwNtiR6Q\"},\"type\":\"price_details\",\"unit_amount_decimal\":\"19900\"},\"quantity\":1,\"taxes\":[]}],\"has_more\":false,\"total_count\":3,\"url\":\"/v1/invoices/in_1S2pW2PuJCefzpgmpGy8biLr/lines\"},\"livemode\":false,\"metadata\":{},\"next_payment_attempt\":null,\"number\":\"FR0INIGA-0012\",\"on_behalf_of\":null,\"parent\":{\"quote_details\":null,\"subscription_details\":{\"metadata\":{},\"subscription\":\"sub_1S2pW3PuJCefzpgmjhIIz1nS\"},\"type\":\"subscription_details\"},\"payment_settings\":{\"default_mandate\":null,\"payment_method_options\":{\"acss_debit\":null,\"bancontact\":null,\"card\":{\"request_three_d_secure\":\"automatic\"},\"customer_balance\":null,\"konbini\":null,\"sepa_debit\":null,\"us_bank_account\":null},\"payment_method_types\":[\"card\"]},\"payments\":{\"object\":\"list\",\"data\":[{\"id\":\"inpay_1S2pW4PuJCefzpgm2gzoOR3P\",\"object\":\"invoice_payment\",\"amount_paid\":28800,\"amount_requested\":28800,\"created\":1756801474,\"currency\":\"usd\",\"invoice\":\"in_1S2pW2PuJCefzpgmpGy8biLr\",\"is_default\":true,\"livemode\":false,\"payment\":{\"payment_intent\":\"pi_3S2pW2PuJCefzpgm27pYjTZ1\",\"type\":\"payment_intent\"},\"status\":\"paid\",\"status_transitions\":{\"canceled_at\":null,\"paid_at\":1756801474}}],\"has_more\":false,\"url\":\"/v1/invoices/payments\"},\"period_end\":1756801474,\"period_start\":1756801474,\"post_payment_credit_notes_amount\":0,\"pre_payment_credit_notes_amount\":0,\"receipt_number\":null,\"rendering\":null,\"shipping_cost\":null,\"shipping_details\":null,\"starting_balance\":0,\"statement_descriptor\":null,\"status\":\"paid\",\"status_transitions\":{\"finalized_at\":1756801474,\"marked_uncollectible_at\":null,\"paid_at\":1756801474,\"voided_at\":null},\"subtotal\":28800,\"subtotal_excluding_tax\":28800,\"test_clock\":null,\"total\":28800,\"total_discount_amounts\":[],\"total_excluding_tax\":28800,\"total_pretax_credit_amounts\":[],\"total_taxes\":[],\"webhooks_delivered_at\":1756801474}');
            }
            return res;
        }
    }
    
    // --- Fake HTTP Mock (Error 500) ---
    private class StripeHttpMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Error"}');
            return res;
        }
    }
    
    // --- Fake HTTP Mock (No Line Items) ---
    private class StripeHttpMockNoLines implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{' +
                        '"id":"in_fake_empty",' +
                        '"total":0,' +
                        '"subtotal":0,' +
                        '"amount_paid":0,' +
                        '"amount_due":0,' +
                        '"amount_remaining":0,' +
                        '"currency":"usd",' +
                        '"status":"draft",' +
                        '"lines":{"data":[]}' +
                        '}');
            return res;
        }
    }
    
    // --- Missing extra mocks for negative paths ---
    private class StripeHttpMockPriceFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setStatusCode(500); // fail price fetch
                res.setBody('{"error":"Price API failed"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    private class StripeHttpMockAddLinesFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/add_lines')) {
                res.setStatusCode(400);
                res.setBody('{"error":"Failed to add lines"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    private class StripeHttpMockInvoiceUpdateFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setStatusCode(400);
                res.setBody('{"error":"Invoice update failed"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    private class StripeHttpMockHappyFlowNoLines implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{' +
                        '"id":"in_termselse",' +
                        '"total":100,' +
                        '"subtotal":100,' +
                        '"amount_paid":0,' +
                        '"amount_due":100,' +
                        '"amount_remaining":100,' +
                        '"currency":"usd",' +
                        '"status":"open",' +
                        '"lines":{"data":[]}' +
                        '}');
            return res;
        }
    }
    
    private class StripeHttpMockBadJson implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('INVALID_JSON_RESPONSE'); // malformed
            return res;
        }
    }
    
    // --- Test Data Setup ---
    @TestSetup
    static void setupData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
        
        Account testAccount = new Account(Name = 'Test Account', BillingCountry = 'United States');
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
            SBQQ__SubscriptionType__c = 'One-Time',
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
    
    // ----------------------
    // New / Rewritten Tests
    // ----------------------

    // Happy path: prices + add_lines + invoice update all return 200
    @IsTest
    static void testHappyPath_AllCalloutsSucceed() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        List<Logger__c> allLoggers = [SELECT Id FROM Logger__c];
        delete allLoggers;
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_happy_1', q.Id));
        Test.stopTest();
        
        // No logger record on success
        Integer logs = [SELECT COUNT() FROM Logger__c];
        System.assertEquals(0, logs, 'No errors should be logged in happy path');
    }
    
    // Price API fails -> should be handled and logger created (your code attempts prices then proceeds)
    @IsTest
    static void testPriceApiFailure_Graceful() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockPriceFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_price_fail', q.Id));
        Test.stopTest();
        
        // Expect at least one logger entry because price creation failed in callouts and code logs exceptions
        Integer logs = [SELECT COUNT() FROM Logger__c];
        System.assert(logs > 0, 'Expected logger entry when price API fails');
    }
    
    // add_lines returns 400 - should lead to logger entry (your code throws CalloutException which is caught & logged)
    @IsTest
    static void testAddLinesFailure_Logged() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockAddLinesFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_addlines_fail', q.Id));
        Test.stopTest();
        
        Integer logs = [SELECT COUNT() FROM Logger__c];
        System.assert(logs > 0, 'Expected logger entry when add_lines fails');
    }
    
    // invoice update returns 400 - ensure logged
    @IsTest
    static void testInvoiceUpdateFailure_Logged() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockInvoiceUpdateFail());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_update_fail', q.Id));
        Test.stopTest();
        
        Integer logs = [SELECT COUNT() FROM Logger__c];
        System.assert(logs > 0, 'Expected logger entry when invoice update fails');
    }
    
    // Malformed JSON -> catch block should log error
    @IsTest
    static void testMalformedJson_TriggersLogger() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockBadJson());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_bad_json', q.Id));
        Test.stopTest();
        
        Logger__c log = [SELECT Id, Status__c, Apex_Class__c FROM Logger__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Error', log.Status__c, 'Bad JSON should create an Error logger');
        System.assertEquals('StripeInvoiceCallout', log.Apex_Class__c);
    }
    
    // Global error from Stripe (500) -> logged and no Stripe_Invoice__c created
    @IsTest
    static void testGlobalStripeError_NoInvoiceCreated() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
            System.enqueueJob(new StripeInvoiceCallout('inv_500_error', q.Id));
        Test.stopTest();
        
        // Expect logger present and no Stripe_Invoice__c for that id (if your org creates such records)
        Integer logs = [SELECT COUNT() FROM Logger__c];
        System.assert(logs > 0, 'Expected logger entry when Stripe returns 500');
        
        // Defensive assertion: if org has Stripe_Invoice__c, ensure none created with that id
        Integer siCount = 0;
        try { siCount = [SELECT COUNT() FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'inv_500_error']; }
        catch (Exception e) { /* object may not exist in some orgs; ignore */ }
        System.assertEquals(0, siCount);
    }
}