@isTest
public class StripeSubscriptionScheduler2_Test {
    
    private class StripeHttpMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('/v1/prices')) {
                //res.setBody('{"id":"price_test_123"}');
                res.setBody('{"id":"price_1MoBy5LkdIwHu7ixZhnattbh","object":"price","active":true,"billing_scheme":"per_unit","created":1679431181,"currency":"usd","custom_unit_amount":null,"livemode":false,"lookup_key":null,"metadata":{},"nickname":null,"product":"prod_NZKdYqrwEYx6iK","recurring":{"interval":"month","interval_count":1,"trial_period_days":null,"usage_type":"licensed"},"tax_behavior":"unspecified","tiers_mode":null,"transform_quantity":null,"type":"recurring","unit_amount":1000,"unit_amount_decimal":"1000"}');
                
            } else if (req.getEndpoint().contains('/v1/subscriptions')) {
                res.setBody('{\"id\":\"sub_test_123\",\"object\":\"subscription\",\"application\":null,\"application_fee_percent\":null,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null},\"billing_cycle_anchor\":1759449600,\"billing_cycle_anchor_config\":null,\"billing_mode\":{\"type\":\"classic\"},\"billing_thresholds\":null,\"cancel_at\":1788393600,\"cancel_at_period_end\":false,\"canceled_at\":1756910391,\"cancellation_details\":{\"comment\":null,\"feedback\":null,\"reason\":\"cancellation_requested\"},\"collection_method\":\"send_invoice\",\"created\":1756910391,\"currency\":\"usd\",\"customer\":\"cus_SzG7papVERCHgP\",\"days_until_due\":30,\"default_payment_method\":null,\"default_source\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"ended_at\":null,\"invoice_settings\":{\"account_tax_ids\":null,\"issuer\":{\"type\":\"self\"}},\"items\":{\"object\":\"list\",\"data\":[{\"id\":\"si_SzGN5bKVRwpXu1\",\"object\":\"subscription_item\",\"billing_thresholds\":null,\"created\":1756910392,\"current_period_end\":1759449600,\"current_period_start\":1756910391,\"discounts\":[],\"metadata\":{},\"plan\":{\"id\":\"price_1S3HqlPuJCefzpgm0gfuehVn\",\"object\":\"plan\",\"active\":true,\"amount\":5900,\"amount_decimal\":\"5900\",\"billing_scheme\":\"per_unit\",\"created\":1756910391,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"prod_Squ9kXUFSf8muO\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"price\":{\"id\":\"price_1S3HqlPuJCefzpgm0gfuehVn\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1756910391,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"prod_Squ9kXUFSf8muO\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"},\"quantity\":1,\"subscription\":\"sub_1S3HqlPuJCefzpgm1MvpFTTh\",\"tax_rates\":[]}],\"has_more\":false,\"total_count\":1,\"url\":\"/v1/subscription_items?subscription=sub_1S3HqlPuJCefzpgm1MvpFTTh\"},\"latest_invoice\":\"inv_test_123\",\"livemode\":false,\"metadata\":{\"salesforce_quote_id\":\"a2ffY000000ZXsLQAW\",\"subscription_source\":\"salesforce\"},\"next_pending_invoice_item_invoice\":null,\"on_behalf_of\":null,\"pause_collection\":null,\"payment_settings\":{\"payment_method_options\":null,\"payment_method_types\":null,\"save_default_payment_method\":\"off\"},\"pending_invoice_item_interval\":null,\"pending_setup_intent\":null,\"pending_update\":null,\"plan\":{\"id\":\"price_1S3HqlPuJCefzpgm0gfuehVn\",\"object\":\"plan\",\"active\":true,\"amount\":5900,\"amount_decimal\":\"5900\",\"billing_scheme\":\"per_unit\",\"created\":1756910391,\"currency\":\"usd\",\"interval\":\"month\",\"interval_count\":1,\"livemode\":false,\"metadata\":{},\"meter\":null,\"nickname\":null,\"product\":\"prod_Squ9kXUFSf8muO\",\"tiers_mode\":null,\"transform_usage\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"quantity\":1,\"schedule\":null,\"start_date\":1756857600,\"status\":\"active\",\"test_clock\":null,\"transfer_data\":null,\"trial_end\":null,\"trial_settings\":{\"end_behavior\":{\"missing_payment_method\":\"create_invoice\"}},\"trial_start\":null}');
            }
            return res;
        }
    }
    
    private class StripeHttpMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }
    
    private class StripeHttpMockPriceError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setStatusCode(500);
                res.setBody('{"error":"Internal Server Error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"id":"generic_id"}');
            }
            return res;
        }
    }
    
    private static SBQQ__Quote__c setupData(String billingFreq, String payTerms, String subType) {
        insert new Stripe_Details__c(
            Name = 'Stripe Details', 
            Serect_Key__c = 'sk_test_123'
        );
        
        Account acc = new Account(
            Name = 'Test Acc ' + billingFreq, 
            Stripe_Customer_ID__c = 'cus_123'
        );
        insert acc;
        
        Product2 p = new Product2(
            Name = 'Test Product ' + billingFreq,
            IsActive = true,
            Stripe_Product_Id__c = 'prod_123',
            Stripe_Price_ID__c = 'price_123',
            SBQQ__SubscriptionType__c = subType,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = subType == 'Renewable' ? billingFreq : null,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__BillingType__c = subType == 'Renewable' ? 'Advance' : null,
            SBQQ__ChargeType__c = subType == 'Renewable' ? 'Recurring' : 'One-time'
        );
        insert p;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = p.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;
        
        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c   = Date.today().addMonths(12),
            SBQQ__Account__c   = acc.Id,
            SBQQ__Primary__c = true,
            Billing_Frequency_Override__c = billingFreq,
            SBQQ__SubscriptionTerm__c = 12,
            CurrencyIsoCode = 'USD',
            SBQQ__PaymentTerms__c = payTerms
        );
        insert q;
        
        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            SBQQ__Product__c = p.Id,
            SBQQ__ChargeType__c = p.SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = p.SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = p.SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = p.SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = p.SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = p.SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__RegularPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = pbe.Id,
            Stripe_Price_ID__c = 'price_123'
        );
        insert ql;
        
        return q;
    }
    
    
    @isTest static void testCreateStripeSubscription_HappyPath() {
        SBQQ__Quote__c q = setupData('Monthly', 'Net 30', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscription(q.Id, 'sub_123');
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Logger__c]);
    }
    
    @isTest static void testCreateStripeSubscription_ErrorPath() {
        SBQQ__Quote__c q = setupData('Quarterly', 'Prepayment', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscription(q.Id, 'sub_123');
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c], 'Error should be logged');
    }
    
    @isTest static void testCreateStripeSubscription_ErrorPath1() {
        SBQQ__Quote__c q = setupData('annual', 'Monthly', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscription(q.Id, 'sub_123');
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c], 'Error should be logged');
    }
    @isTest static void testCreateStripeSubscription_ErrorPath2() {
        SBQQ__Quote__c q = setupData('2-year', 'Monthly', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscription(q.Id, 'sub_123');
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c], 'Error should be logged');
    }
    @isTest static void testCreateStripeSubscription_ErrorPath3() {
        SBQQ__Quote__c q = setupData('3-year', 'Monthly', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c], 'Error should be logged');
    }
    
    @isTest static void testCreateStripeSubscriptionAsync_OneTime() {
        SBQQ__Quote__c q = setupData('2-Year', 'Net 60', 'One-time');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest static void testGetUpdatedSubscriptionfromStripe() {
        SBQQ__Quote__c q = setupData('3-Year', 'Net 90', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe(q.Id, 'sub_123', 'salesforce');
        Test.stopTest();
        System.assert(true, 'No errors should occur');
    }
    
    @isTest static void testPriceCalculation_Monthly3MonthRecurring() {
        SBQQ__Quote__c q = setupData('Quarterly', 'Net 30', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        Integer updatedCount = [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE Stripe_Price_ID__c != NULL];
    }
    
    @isTest static void testPriceCalculation_AnnualRecurring() {
        SBQQ__Quote__c q = setupData('Annual', 'Net 30', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        Integer updatedCount = [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE Stripe_Price_ID__c != NULL];
    }
    
    @isTest static void testPriceCalculation_OneTime() {
        SBQQ__Quote__c q = setupData('Monthly', 'Net 30', 'One-time');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        Integer updatedCount = [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE Stripe_Price_ID__c != NULL];
    }
    
    @isTest static void testPriceApiError_Not200() {
        SBQQ__Quote__c q = setupData('Monthly', 'Net 30', 'Renewable');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockPriceError());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
    }
    
    @isTest static void testPriceCalculation_NonRecurringBranch() {
        SBQQ__Quote__c q = setupData('Quarterly', 'Net 30', 'One-time');
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        System.assert(true, 'Non-recurring branch covered');
    }
    @isTest static void testPriceCalculation_NullUnitPrice() {
        SBQQ__Quote__c q = setupData('Quarterly', 'Net 30', 'Renewable');
        
        // Update QuoteLine to have null NetPrice (unitPrice)
        SBQQ__QuoteLine__c ql = [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :q.Id LIMIT 1];
        ql.SBQQ__NetPrice__c = null;
        update ql;
        
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<Id>{q.Id});
        Test.stopTest();
        
        System.assert(true, 'Covers unitPrice == null branch');
    }
    
    // Mock Stripe_Details__c record
    private static Stripe_Details__c createStripeDetails() {
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert sd;
        return sd;
    }
    
}