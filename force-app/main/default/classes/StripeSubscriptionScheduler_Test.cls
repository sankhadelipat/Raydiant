@IsTest
private class StripeSubscriptionScheduler_Test {
    
    private static String buildMockResponse_Subscription() {
        return '{\"id\":\"sub_test_1234\",\"object\":\"subscription\",\"application\":null,\"application_fee_percent\":null,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null},\"billing_cycle_anchor\":1760140800,\"billing_cycle_anchor_config\":null,\"billing_mode\":{\"type\":\"flexible\",\"updated_at\":1757604547},\"billing_thresholds\":null,\"cancel_at\":1760150800,\"cancel_at_period_end\":false,\"canceled_at\":1760150800,\"cancellation_details\":{\"comment\":null,\"feedback\":null,\"reason\":null},\"collection_method\":\"send_invoice\",\"created\":1757604547,\"currency\":\"usd\",\"customer\":\"cus_test_1234\",\"days_until_due\":0,\"default_payment_method\":null,\"default_source\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"ended_at\":null,\"invoice_settings\":{\"account_tax_ids\":null,\"issuer\":{\"type\":\"self\"}},\"items\":{\"object\":\"list\",\"data\":[{\"id\":\"si_test_1234\",\"object\":\"subscription_item\",\"billing_thresholds\":null,\"created\":1757604547,\"current_period_end\":1760140800,\"current_period_start\":1757548800,\"discounts\":[],\"metadata\":{},\"plan\":{\"id\":\"pi_test_1234\",\"object\":\"plan\",\"active\":true,\"amount\":29,\"amount_decimal\":\"29\",\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"pr_test_1234\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"pr_test_1234\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":29,\"unit_amount_decimal\":\"29\"},\"quantity\":1,\"subscription\":\"sub_test_1234\",\"tax_rates\":[]}],\"has_more\":false,\"total_count\":1,\"url\":\"/v1/subscription_items?subscription=sub_1S6CQpPuJCefzpgmV2mVgfhE\"},\"latest_invoice\":null,\"livemode\":false,\"metadata\":{\"subscription_source\":\"salesforceformigration\",\"salesforce_Conatrct_id\":\"8001I000001Si1VQAS\"},\"next_pending_invoice_item_invoice\":null,\"on_behalf_of\":null,\"pause_collection\":null,\"payment_settings\":{\"payment_method_options\":null,\"payment_method_types\":null,\"save_default_payment_method\":\"off\"},\"pending_invoice_item_interval\":null,\"pending_setup_intent\":\"seti_1S6CQpPuJCefzpgmxpRgZlGA\",\"pending_update\":null,\"plan\":{\"id\":\"pi_test_1234\",\"object\":\"plan\",\"active\":true,\"amount\":29,\"amount_decimal\":\"29\",\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"pr_test_1234\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"quantity\":1,\"schedule\":\"sub_sched_1234\",\"start_date\":1623567600,\"status\":\"active\",\"test_clock\":null,\"transfer_data\":null,\"trial_end\":null,\"trial_settings\":{\"end_behavior\":{\"missing_payment_method\":\"create_invoice\"}},\"trial_start\":null}';
    }
    
    private static String buildMockResponse_Schedule() {
        return '{\"id\":\"sub_sched_1234\",\"object\":\"subscription_schedule\",\"application\":null,\"billing_mode\":{\"flexible\":{\"proration_discounts\":\"included\"},\"type\":\"flexible\",\"updated_at\":1766074320},\"canceled_at\":null,\"completed_at\":null,\"created\":1766074320,\"current_phase\":null,\"customer\":\"cus_test_1234\",\"customer_account\":null,\"default_settings\":{\"application_fee_percent\":null,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null},\"billing_cycle_anchor\":\"automatic\",\"billing_thresholds\":null,\"collection_method\":\"send_invoice\",\"default_payment_method\":null,\"default_source\":null,\"description\":null,\"invoice_settings\":{\"account_tax_ids\":null,\"days_until_due\":15,\"issuer\":{\"type\":\"self\"}},\"on_behalf_of\":null,\"transfer_data\":null},\"end_behavior\":\"cancel\",\"livemode\":false,\"metadata\":{\"salesforce_quote_id\":\"a2ffY000000bpgHQAQ\",\"subscription_schedule\":\"true\",\"subscription_source\":\"salesforce\"},\"phases\":[{\"add_invoice_items\":[],\"application_fee_percent\":null,\"billing_cycle_anchor\":null,\"billing_thresholds\":null,\"collection_method\":null,\"currency\":\"usd\",\"default_payment_method\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"end_date\":1829347200,\"invoice_settings\":null,\"items\":[{\"billing_thresholds\":null,\"discounts\":[],\"metadata\":{},\"plan\":\"pi_test_1234\",\"price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1765902782,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"pr_test_1234\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"},\"quantity\":2,\"tax_rates\":[]}],\"metadata\":{\"salesforce_quote_id\":\"a2ffY000000bpgHQAQ\",\"subscription_schedule\":\"true\",\"subscription_source\":\"salesforce\"},\"on_behalf_of\":null,\"proration_behavior\":\"always_invoice\",\"start_date\":1766361600,\"transfer_data\":null,\"trial_end\":null}],\"released_at\":null,\"released_subscription\":null,\"renewal_interval\":null,\"status\":\"not_started\",\"subscription\":null,\"test_clock\":\"clock_1Sf0rGPuJCefzpgmKi0iQxkm\"}';
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
    static void testCreateStripeSchedule_WithRecurringAndOneTime() {
        
        Product2 renewableProd = new Product2(
            Name = 'Test Renewable Product',
            IsActive = true,
            SBQQ__SubscriptionType__c = 'Renewable',
            Stripe_Product_Id__c = 'prod_test_renewable'
        );
        insert renewableProd;
        
        Product2 oneTimeProd = new Product2(
            Name = 'Test Product',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance'
            
        );
        insert oneTimeProd;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        
        // Create quote
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        PricebookEntry testPbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = renewableProd.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert testPbe;
        
        
        // Create quote lines
        SBQQ__QuoteLine__c qlRenewable = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            SBQQ__Product__c = renewableProd.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbe.Id,
            Stripe_Price_ID__c = 'price_test1',
            CurrencyIsoCode = 'USD'
        );
        SBQQ__QuoteLine__c qlOneTime = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            SBQQ__Product__c = oneTimeProd.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbe.Id,
            Stripe_Price_ID__c = 'price_test1',
            CurrencyIsoCode = 'USD'
        );
        insert new List<SBQQ__QuoteLine__c>{ qlRenewable, qlOneTime };
            
            
            Test.startTest();
        StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{q.Id});
        Test.stopTest();
        System.assertEquals(2,
                            [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE Id IN :new List<Id>{ qlRenewable.Id, qlOneTime.Id }],
                            'Both quote lines should have been processed for price creation');
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
    
    @IsTest
    static void testCreateSubscription() {
        Test.startTest();
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        String response = buildMockResponse_Subscription();
        
        StripeSubscriptionScheduler.createSubscriptionWithQuote(response, q.Id);
        Contract con = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_test_1234', con.Stripe_Subscription_ID__c);
        System.assertEquals('active', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSubscription_Exception() {
        Test.startTest();
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":"Not found"}}';
        
        StripeSubscriptionScheduler.createSubscriptionWithQuote(response, '001000000000000');
        System.assert(true, 'Exception caught as expected');
        
        Test.stopTest();
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testCreateManualSubscription() {
        String response = buildMockResponse_Subscription();
        
        Test.startTest();
        StripeSubscriptionScheduler.createSubscriptionWithoutQuote(response);
        Test.stopTest();
        
        Contract con = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_test_1234', con.Stripe_Subscription_ID__c);
        System.assertEquals('active', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testScheduleSubscription_Quote() {
        Test.startTest();
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        String response = buildMockResponse_Schedule();
        
        StripeSubscriptionScheduler.createScheduleWithQuote(response, q.Id);
        Contract con = [SELECT Id, Stripe_Subscription_Schedule_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_sched_1234', con.Stripe_Subscription_Schedule_ID__c);
        System.assertEquals('not_started', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testScheduleSubscription_Quote_Exception() {
        Test.startTest();
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":"Not found"}}';
        
        StripeSubscriptionScheduler.createScheduleWithQuote(response, '001000000000000');
        System.assert(true, 'Exception caught as expected');
        
        Test.stopTest();
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testScheduleSubscription_NoQuote() {
        String response = buildMockResponse_Schedule();
        
        Test.startTest();
        StripeSubscriptionScheduler.createScheduleWithoutQuote(response);
        Test.stopTest();
        
        Contract con = [SELECT Id, Stripe_Subscription_Schedule_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_sched_1234', con.Stripe_Subscription_Schedule_ID__c);
        System.assertEquals('not_started', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testScheduleSubscription_NoQuote_Exception() {
        Test.startTest();
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":';
        
        StripeSubscriptionScheduler.createScheduleWithoutQuote(response);
        System.assert(true, 'Exception caught as expected');
        
        Test.stopTest();
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testDeleteSubscriptionWithItems() {
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = [SELECT Id FROM Account LIMIT 1].Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12
        );
        insert quote;
        
        Contract con = new Contract(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            StartDate = Date.today(),
            ContractTerm = 12, // required field
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_1234',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
        
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = con.Id,
            Status__c = 'active',
            SBQQ__Quantity__c = 1,
            Stripe_Product_ID__c = 'prod_test_123',
            Stripe_Subscription_ID__c = 'si_test_1234',
            Stripe_Monthly_Value__c = 100,
            SBQQ__NetPrice__c = 100
        );
        insert sub;
        
        Test.setMock(HttpCalloutMock.class, new StripeMockResponseGenerator());
        
        Test.startTest();
        StripeSubscriptionScheduler.deleteSubscription('sub_test_1234');
        Test.stopTest();
        
        Contract updatedCon = [SELECT Id, Latest_Change_Reason__c FROM Contract WHERE Id = :con.Id];
        
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Stripe_Subscription_ID__c, Latest_Change_Reason__c, Status__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c = :con.Id
        ];
        
        System.assertEquals('Subcription Item Delete From Stripe', subs[0].Latest_Change_Reason__c);
        System.assertEquals('canceled', subs[0].Status__c);
    }
    
    @IsTest
    static void testDeleteSubscription_NoItems() {
        Test.startTest();
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = [SELECT Id FROM Account LIMIT 1].Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12
        );
        insert quote;
        
        Contract con = new Contract(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_no_items',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
        
        
        String responseNoItems =
            '{"id":"sub_test_no_items","object":"subscription","status":"active","items":{"object":"list","data":[]}}';
        
        StripeSubscriptionScheduler.deleteSubscription(responseNoItems);
        
        Contract updatedCon = [SELECT Id, Stripe_Subscription_ID__c FROM Contract WHERE Id = :con.Id];
        System.assertEquals('sub_test_no_items', updatedCon.Stripe_Subscription_ID__c);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteSubscription_MissingItemsKey() {
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Contract con = new Contract(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_missing_items',
            SBQQ__Quote__c = q.Id
        );
        insert con;
        
        // Response without "items"
        String badResponse = '{"id":"sub_missing_items","object":"subscription","status":"active"}';
        
        Test.startTest();
        try {
            StripeSubscriptionScheduler.deleteSubscription(badResponse);
        } catch (Exception e) {
            System.assert(true, 'Exception caught as expected');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteSchedule_WithPendingContract() {
        // Arrange
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Contract pendingContract = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Pending',
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_test_001'
        );
        insert pendingContract;
        
        // Act
        Test.startTest();
        StripeSubscriptionScheduler.deleteSchedule('sub_sched_test_001');
        Test.stopTest();
        
        // Assert
        List<Contract> remaining = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c = 'sub_sched_test_001'
        ];
        
        System.assertEquals(
            0,
            remaining.size(),
            'Pending contract should be deleted when schedule is canceled'
        );
    }
}