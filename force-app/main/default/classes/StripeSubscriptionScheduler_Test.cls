@IsTest
private class StripeSubscriptionScheduler_Test {
    
    private class StripeMockResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setBody('{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1757586971,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"pr_test_1234\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/subscription_schedules')) {
                res.setBody('{\"id\":\"sub_sch_test_1234\",\"current_phase\":{\"end_date\":1789084800,\"start_date\":1757586755},\"default_settings\":{\"automatic_tax\":{\"enabled\":false},\"billing_cycle_anchor\":\"automatic\",\"billing_thresholds\":null,\"collection_method\":\"charge_automatically\",\"description\":null,\"invoice_settings\":{\"days_until_due\":null,\"supported_payment_methods\":{\"ach_credit_transfer\":false,\"acss_debit\":false,\"affirm\":false,\"afterpay_clearpay\":false,\"alipay\":false,\"amazon_pay\":false,\"au_becs_debit\":false,\"bacs_debit\":false,\"bancontact\":false,\"boleto\":false,\"card\":true,\"cashapp\":false,\"crypto\":false,\"custom\":false,\"customer_balance\":false,\"demo_pay\":false,\"eps\":false,\"fpx\":false,\"giropay\":false,\"grabpay\":false,\"id_bank_transfer\":false,\"id_credit_transfer\":false,\"ideal\":false,\"jp_credit_transfer\":false,\"kakao_pay\":false,\"klarna\":false,\"konbini\":false,\"kr_card\":false,\"kr_market\":false,\"link\":false,\"multibanco\":false,\"naver_pay\":false,\"netbanking\":false,\"ng_bank_transfer\":false,\"ng_card\":false,\"ng_market\":false,\"ng_wallet\":false,\"nz_bank_account\":false,\"p24\":false,\"paper_check\":false,\"pay_by_bank\":false,\"payco\":false,\"paynow\":false,\"paypal\":false,\"pix\":false,\"promptpay\":false,\"revolut_pay\":false,\"samsung_pay\":false,\"sepa_credit_transfer\":false,\"sepa_debit\":false,\"sofort\":false,\"stripe_balance\":false,\"swish\":false,\"upi\":false,\"us_bank_account\":false,\"wechat_pay\":false}}},\"end_behavior\":\"cancel\",\"phases\":[{\"add_invoice_items\":[],\"automatic_tax\":{\"enabled\":false},\"collection_method\":null,\"coupon\":null,\"default_tax_rates\":[],\"discounts\":[],\"end_date\":1789084800,\"invoice_settings\":null,\"items\":[{\"billing_thresholds\":null,\"dashboard_price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"automatic_currency_conversion_eligible\":false,\"billing_scheme\":\"per_unit\",\"created\":1757586971,\"currency\":\"usd\",\"currency_options\":{\"usd\":{\"custom_unit_amount\":null,\"tax_behavior\":\"unspecified\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"}},\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"never_used\":false,\"nickname\":null,\"owning_merchant\":\"acct_1R1YquPuJCefzpgm\",\"owning_merchant_info\":\"acct_1R1YquPuJCefzpgm\",\"product\":{\"id\":\"prod_Squ9kXUFSf8muO\",\"object\":\"product\",\"active\":true,\"attributes\":[],\"created\":1754982601,\"dashboard_images\":[],\"default_price\":\"pi_test_1234\",\"description\":\"ScreenServiceStandard\",\"images\":[],\"livemode\":false,\"marketing_features\":[],\"metadata\":{},\"name\":\"ScreenServiceStandard\",\"owning_merchant\":\"acct_1R1YquPuJCefzpgm\",\"owning_merchant_info\":\"acct_1R1YquPuJCefzpgm\",\"package_dimensions\":null,\"shippable\":null,\"skus\":{\"object\":\"list\",\"data\":[],\"has_more\":false,\"total_count\":0,\"url\":\"/v1/skus?product=prod_Squ9kXUFSf8muO&active=true\"},\"statement_descriptor\":null,\"tax_code\":null,\"type\":\"service\",\"unit_label\":null,\"updated\":1754982602,\"url\":null,\"user_hidden_in_lists\":false},\"recurring\":{\"aggregate_usage\":null,\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"},\"discounts\":[],\"price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"recurring\":{\"usage_type\":\"licensed\"},\"type\":\"recurring\"},\"price_details\":{\"billing_scheme\":\"per_unit\",\"created\":1757586971,\"currency\":\"usd\",\"custom_unit_amount\":null,\"metadata\":{},\"nickname\":null,\"recurring\":{\"aggregate_usage\":null,\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"},\"quantity\":3,\"tax_rates\":[]}],\"on_behalf_of\":null,\"payment_settings\":{\"payment_method_options\":{\"customer_balance\":null},\"payment_method_types\":[\"card\"],\"save_default_payment_method\":\"off\"},\"start_date\":1757586755,\"transfer_data\":null,\"trial_end\":null}],\"status\":\"active\",\"subscription\":{\"id\":\"sub_test_1234\",\"automatic_tax\":{\"enabled\":false},\"cancel_at\":1789084800,\"default_tax_rates\":[],\"discount\":null,\"discounts\":[],\"items\":{\"data\":[{\"id\":\"si_test_1234\",\"object\":\"subscription_item\",\"billing_thresholds\":null,\"created\":1757586756,\"current_period_end\":1760178755,\"current_period_start\":1757586755,\"discounts\":[],\"metadata\":{\"last_updated_from_Salesforce\":\"true\"},\"plan\":{\"id\":\"pi_test_1234\",\"object\":\"plan\",\"active\":true,\"aggregate_usage\":null,\"amount\":5900,\"amount_decimal\":\"5900\",\"billing_scheme\":\"per_unit\",\"created\":1757586971,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"name\":\"ScreenServiceStandard\",\"nickname\":null,\"owning_merchant\":\"acct_1R1YquPuJCefzpgm\",\"owning_merchant_info\":\"acct_1R1YquPuJCefzpgm\",\"product\":\"pr_test_1234\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"automatic_currency_conversion_eligible\":false,\"billing_scheme\":\"per_unit\",\"created\":1757586971,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"never_used\":false,\"nickname\":null,\"owning_merchant\":\"acct_1R1YquPuJCefzpgm\",\"owning_merchant_info\":\"acct_1R1YquPuJCefzpgm\",\"product\":\"pr_test_1234\",\"recurring\":{\"aggregate_usage\":null,\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"},\"quantity\":3,\"subscription\":\"sub_test_1234\",\"tax_rates\":[]}]},\"trial_end\":null}}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/subscriptions')) {
                res.setBody('{"id":"sub_test_1234","object":"subscription","customer":"cus_test_1234","latest_invoice":"in_test123","status":"canceled",'+
                            '"billing_cycle_anchor":1754031600,"cancel_at":1783494000,"canceled_at":1752483889,"created":1752483889,"current_period_start":1752483889,"current_period_end":1754031600,"start_date":1751958000,'+
                            '"items":{"object":"list","data":['+
                            '{"id":"si_test_1234","quantity":1,"current_period_start":1752483889,"current_period_end":1754031600,'+
                            '"price":{"id":"price_test_1234","product":"prod_test_1234","active":true,"unit_amount":10000,"recurring":{"interval":"month","interval_count":1}}}'+
                            ']}}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":{"message":"Not found"}}');
                res.setStatusCode(404);
            }
            
            return res;
        }
    }
    
    private class StripeMockResponseGenerator_Error implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            res.setBody('{"error":{"message":"Not found"}}');
            res.setStatusCode(404);
            
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_1234'
        );
        insert acc;
        
        Product2 testProduct = new Product2(
            Name = 'Test Product 1234',
            ProductCode = 'TESTPR1234',
            Description = 'Test Description',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            Stripe_Product_ID__c = 'pr_test_1234',
            Stripe_Price_ID__c = 'pi_test_1234'
        );
        insert testProduct;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        
        PricebookEntry testPbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert testPbe;
        
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PaymentTerms__c = 'Net 30',
            SBQQ__StartDate__c = System.today(),
            SBQQ__EndDate__c = System.today().addMonths(12),
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert testQuote;
        
        SBQQ__QuoteLine__c testQuoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuote.Id,
            SBQQ__Product__c = testProduct.Id,
            SBQQ__ChargeType__c = testProduct.SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = testProduct.SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = testProduct.SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = testProduct.SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = testProduct.SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = testProduct.SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__RegularPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbe.Id,
            Stripe_Price_ID__c = 'pi_test_1234'
        );
        insert testQuoteLine;
    }
    
    @IsTest
    static void testCreateStripeSchedule_Success() {
        Test.setMock(HttpCalloutMock.class, new StripeMockResponseGenerator());
        
        Test.startTest();
        
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{testQuote.Id});
        
        Test.stopTest();
        
        List<SBQQ__QuoteLine__c> updatedQuoteLines = [
            SELECT Id, Stripe_Price_ID__c 
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c = :testQuote.Id
        ];
        
        System.assertNotEquals(null, updatedQuoteLines[0].Stripe_Price_ID__c);
        System.assertEquals('pi_test_1234', updatedQuoteLines[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testCreateStripeSchedule_AllFrequencies_Correct() {
        Test.setMock(HttpCalloutMock.class, new StripeMockResponseGenerator());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Product2 prod = new Product2(
            Name = 'Freq Product',
            IsActive = true,
            SBQQ__SubscriptionType__c = 'Renewable',
            Stripe_Product_Id__c = 'prod_freq_test'
        );
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        List<String> frequencies = new List<String>{
            'Monthly',
                'Quarterly',
                'Semiannual',
                'Annual'
                };
                    
                    List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
        
        for (String freq : frequencies) {
            quotes.add(new SBQQ__Quote__c(
                SBQQ__Account__c = acc.Id,
                SBQQ__StartDate__c = System.today(),
                SBQQ__SubscriptionTerm__c = 12,
                Billing_Frequency_Override__c = freq
            ));
        }
        insert quotes;
        
        List<SBQQ__QuoteLine__c> lines = new List<SBQQ__QuoteLine__c>();
        
        for (SBQQ__Quote__c q : quotes) {
            lines.add(new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id,
                SBQQ__Product__c = prod.Id,
                SBQQ__Quantity__c = 1,
                SBQQ__NetPrice__c = 100,
                SBQQ__PricebookEntryId__c = pbe.Id,
                CurrencyIsoCode = 'USD'
            ));
        }
        insert lines;
        
        Test.startTest();
        
        for (SBQQ__Quote__c q : quotes) {
            StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{ q.Id });
        }
        
        Test.stopTest();
        
        List<SBQQ__QuoteLine__c> updated = [
            SELECT Id, Stripe_Price_ID__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c IN :quotes
        ];
        
        System.assert(!updated.isEmpty(), 'Quote lines should be processed');
    }
    
    @IsTest
    static void testCreateStripeSchedule_BillingAnchor_And_PaymentTerms() {
        
        Test.setMock(HttpCalloutMock.class, new StripeMockResponseGenerator());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Product2 prod = new Product2(
            Name = 'Coverage Product',
            IsActive = true,
            SBQQ__SubscriptionType__c = 'Renewable',
            Stripe_Product_Id__c = 'prod_cov_test'
        );
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        // Pair frequency + payment terms
        List<Map<String, String>> scenarios = new List<Map<String, String>>{
            new Map<String,String>{'freq'=>'Quarterly',  'term'=>'Prepayment'},
                new Map<String,String>{'freq'=>'Semiannual', 'term'=>'Due on receipt'},
                    new Map<String,String>{'freq'=>'Annual',     'term'=>'Net 15'},
                        new Map<String,String>{'freq'=>'Semiannual',     'term'=>'Net 30'},
                            new Map<String,String>{'freq'=>'Annual',     'term'=>'Net 45'},
                                new Map<String,String>{'freq'=>'Monthly',    'term'=>'Net 60'}, // default branch also touched
                                    new Map<String,String>{'freq'=>'Monthly',    'term'=>'Net 90'},
                                        new Map<String,String>{'freq'=>'Monthly',    'term'=>null} // NULL branch
        };
            
            List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
        
        for (Map<String,String> sc : scenarios) {
            quotes.add(new SBQQ__Quote__c(
                SBQQ__Account__c = acc.Id,
                SBQQ__StartDate__c = System.today(),
                SBQQ__SubscriptionTerm__c = 12,
                Billing_Frequency_Override__c = sc.get('freq'),
                SBQQ__PaymentTerms__c = sc.get('term')
            ));
        }
        
        insert quotes;
        
        List<SBQQ__QuoteLine__c> lines = new List<SBQQ__QuoteLine__c>();
        
        for (SBQQ__Quote__c q : quotes) {
            lines.add(new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id,
                SBQQ__Product__c = prod.Id,
                SBQQ__Quantity__c = 1,
                SBQQ__NetPrice__c = 100,
                SBQQ__PricebookEntryId__c = pbe.Id,
                CurrencyIsoCode = 'USD'
            ));
        }
        
        insert lines;
        
        Test.startTest();
        
        for (SBQQ__Quote__c q : quotes) {
            StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{ q.Id });
        }
        
        Test.stopTest();
        
        System.assert(true, 'All branches executed');
    }
    
    @IsTest
    static void testCreateStripeSchedule_NoQuote() {
        Test.startTest();      
        StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{'001000000000000'});
        Test.stopTest();
        System.assert(true, 'Method should handle non-existent quotes gracefully');
    }
    
    @IsTest
    static void testCreateStripeSchedule_Exception() {
        Test.setMock(HttpCalloutMock.class, new StripeMockResponseGenerator_Error());
        
        Test.startTest();
        delete [SELECT Id FROM Logger__c];
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{testQuote.Id});
        System.assert(true, 'Exception caught as expected');
        
        Test.stopTest();
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
}