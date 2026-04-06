@IsTest
public class StripeScheduleQueueable_Test {
    
    private static String buildMockResponse() {
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
    
    @IsTest
    static void testScheduleSubscription_Quote() {
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        String response = buildMockResponse();
        
        Test.startTest();
        System.enqueueJob(new StripeScheduleQueueable(response, q.Id));
        Test.stopTest();
        
        Contract con = [SELECT Id, Stripe_Subscription_Schedule_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_sched_1234', con.Stripe_Subscription_Schedule_ID__c);
        System.assertEquals('not_started', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('pi_test_1234', subs[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testScheduleSubscription_Quote_Exception() {
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":"Not found"}}';
        
        Test.startTest();
        System.enqueueJob(new StripeScheduleQueueable(response, '001000000000000'));
        Test.stopTest();
        
        System.assert(true, 'Exception caught as expected');
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testScheduleSubscription_NoQuote() {
        String response = buildMockResponse();
        
        Test.startTest();
        System.enqueueJob(new StripeScheduleQueueable(response, null));
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
        delete [SELECT Id FROM Logger__c];
        String response = '{"error":{"message":';
        
        Test.startTest();
        System.enqueueJob(new StripeScheduleQueueable(response, null));
        Test.stopTest();
        
        System.assert(true, 'Exception caught as expected');
        
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
}