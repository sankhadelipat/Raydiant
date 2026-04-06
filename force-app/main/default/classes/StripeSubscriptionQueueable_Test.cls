@IsTest
public class StripeSubscriptionQueueable_Test {
    
    private static String buildMockResponse() {
        return '{\"id\":\"sub_test_1234\",\"object\":\"subscription\",\"application\":null,\"application_fee_percent\":null,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null},\"billing_cycle_anchor\":1760140800,\"billing_cycle_anchor_config\":null,\"billing_mode\":{\"type\":\"flexible\",\"updated_at\":1757604547},\"billing_thresholds\":null,\"cancel_at\":1760150800,\"cancel_at_period_end\":false,\"canceled_at\":1760150800,\"cancellation_details\":{\"comment\":null,\"feedback\":null,\"reason\":null},\"collection_method\":\"send_invoice\",\"created\":1757604547,\"currency\":\"usd\",\"customer\":\"cus_test_1234\",\"days_until_due\":0,\"default_payment_method\":null,\"default_source\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"ended_at\":null,\"invoice_settings\":{\"account_tax_ids\":null,\"issuer\":{\"type\":\"self\"}},\"items\":{\"object\":\"list\",\"data\":[{\"id\":\"si_test_1234\",\"object\":\"subscription_item\",\"billing_thresholds\":null,\"created\":1757604547,\"current_period_end\":1760140800,\"current_period_start\":1757548800,\"discounts\":[],\"metadata\":{},\"plan\":{\"id\":\"pi_test_1234\",\"object\":\"plan\",\"active\":true,\"amount\":29,\"amount_decimal\":\"29\",\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"pr_test_1234\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"price\":{\"id\":\"pi_test_1234\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"pr_test_1234\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":29,\"unit_amount_decimal\":\"29\"},\"quantity\":1,\"subscription\":\"sub_test_1234\",\"tax_rates\":[]}],\"has_more\":false,\"total_count\":1,\"url\":\"/v1/subscription_items?subscription=sub_1S6CQpPuJCefzpgmV2mVgfhE\"},\"latest_invoice\":null,\"livemode\":false,\"metadata\":{\"subscription_source\":\"salesforceformigration\",\"salesforce_Conatrct_id\":\"8001I000001Si1VQAS\"},\"next_pending_invoice_item_invoice\":null,\"on_behalf_of\":null,\"pause_collection\":null,\"payment_settings\":{\"payment_method_options\":null,\"payment_method_types\":null,\"save_default_payment_method\":\"off\"},\"pending_invoice_item_interval\":null,\"pending_setup_intent\":\"seti_1S6CQpPuJCefzpgmxpRgZlGA\",\"pending_update\":null,\"plan\":{\"id\":\"pi_test_1234\",\"object\":\"plan\",\"active\":true,\"amount\":29,\"amount_decimal\":\"29\",\"billing_scheme\":\"per_unit\",\"created\":1757604457,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"pr_test_1234\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"quantity\":1,\"schedule\":\"sub_sched_1234\",\"start_date\":1623567600,\"status\":\"active\",\"test_clock\":null,\"transfer_data\":null,\"trial_end\":null,\"trial_settings\":{\"end_behavior\":{\"missing_payment_method\":\"create_invoice\"}},\"trial_start\":null}';
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
    static void testCreateSubscription() {
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        String response = buildMockResponse();
        
        Test.startTest();
        System.enqueueJob(new StripeSubscriptionQueueable(response, q.Id));
        Test.stopTest();
        
        Contract con = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_test_1234', con.Stripe_Subscription_ID__c);
        System.assertEquals('active', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testCreateSubscription_Exception() {
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":"Not found"}}';
        
        Test.startTest();
        System.enqueueJob(new StripeSubscriptionQueueable(response, '001000000000000'));        
        Test.stopTest();
        
        System.assert(true, 'Exception caught as expected');
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testCreateManualSubscription() {
        String response = buildMockResponse();
        
        Test.startTest();
        System.enqueueJob(new StripeSubscriptionQueueable(response, null));
        Test.stopTest();
        
        Contract con = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_test_1234', con.Stripe_Subscription_ID__c);
        System.assertEquals('active', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
    }
}