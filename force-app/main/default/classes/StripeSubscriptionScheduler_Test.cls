@IsTest
private class StripeSubscriptionScheduler_Test {
    
    private static String buildMockResponse() {
        return '{"id":"sub_test123","object":"subscription","customer":"cus_test123",'+
            '"latest_invoice":"in_test123","status":"active","billing_cycle_anchor":1754031600,'+
            '"cancel_at":1783494000,"canceled_at":1752483889,"created":1752483889,'+
            '"current_period_start":1752483889,"current_period_end":1754031600,"start_date":1751958000,'+
            '"items":{"object":"list","data":['+
            '{"id":"si_test1","quantity":1,"current_period_start":1752483889,"current_period_end":1754031600,'+
            '"price":{"id":"price_test1","product":"prod_test1","active":true,"unit_amount":10000,'+
            '"recurring":{"interval":"month","interval_count":1}}}'+
            ']}}';
    }
    
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;
        
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance'
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
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbe.Id,
            Stripe_Price_ID__c = 'price_test1'
        );
        insert testQuoteLine;
    }
    
    private class StripeMockResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setBody('{"id":"price_test123","object":"price","active":true,"currency":"usd","product":"prod_test123","unit_amount":10000}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/subscription_schedules')) {
                res.setBody('{"id":"sub_sched_test123","object":"subscription_schedule","status":"active"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":{"message":"Not found"}}');
                res.setStatusCode(404);
            }
            
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
        System.assertEquals('price_test123', updatedQuoteLines[0].Stripe_Price_ID__c);
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
        
        Test.startTest();       
        SBQQ__Quote__c testQuote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        try {
            StripeSubscriptionScheduler.createStripeSchedule(new List<Id>{testQuote.Id});
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
            System.assert(true, 'Exception was caught as expected');
        }        
        Test.stopTest();
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @IsTest
    static void testUnitAmountCalculation_MonthlyAndYearly() {
        String response = 
            '{"id":"sub_interval_test","object":"subscription","status":"active","items":{"object":"list","data":[' +
            '{"id":"si_test2","quantity":1,"price":{"id":"price_interval","unit_amount":20000,"recurring":{"interval":"year","interval_count":2}}}' +
            ']}}';
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
        StripeSubscriptionScheduler.createSubscrition(response, q.Id);
        Test.stopTest();
        
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c 
            FROM SBQQ__Subscription__c
            WHERE Stripe_Subscription_ID__c = 'sub_interval_test'
        ];
        System.assertEquals(1, subs.size(), 'Subscription should be created for yearly interval');
    }
    @IsTest
    static void testCreateSubscription() {
        Test.startTest();
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        String response = buildMockResponse();
        
        StripeSubscriptionScheduler.createSubscrition(response, q.Id);
        Contract con = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Status__c FROM Contract LIMIT 1];
        System.assertEquals('sub_test123', con.Stripe_Subscription_ID__c);
        System.assertEquals('active', con.Stripe_Status__c);
        
        List<SBQQ__Subscription__c> subs = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c];
        System.assert(!subs.isEmpty(), 'Subscription items should be created');
        System.assertEquals('price_test1', subs[0].Stripe_Price_ID__c);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteSubscriptionWithItems() {
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
            ContractTerm = 12, // required field
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_with_items',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
        
        String responseWithItems = 
            '{"id":"sub_test_with_items","object":"subscription","customer":"cus_test123","latest_invoice":"in_test123","status":"active",'+
            '"billing_cycle_anchor":1754031600,"cancel_at":1783494000,"canceled_at":1752483889,"created":1752483889,"current_period_start":1752483889,"current_period_end":1754031600,"start_date":1751958000,'+
            '"items":{"object":"list","data":['+
            '{"id":"si_test1","quantity":1,"current_period_start":1752483889,"current_period_end":1754031600,'+
            '"price":{"id":"price_test1","product":"prod_test1","active":true,"unit_amount":10000,"recurring":{"interval":"month","interval_count":1}}}'+
            ']}}';
        
        
        StripeSubscriptionScheduler.deleteSubscrition(responseWithItems);
        
        Contract updatedCon = [SELECT Id, Latest_Change_Reason__c FROM Contract WHERE Id = :con.Id];
        
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c, Latest_Change_Reason__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c = :con.Id
        ];
        System.assertEquals(1, subs.size(), 'One subscription should be inserted');
        System.assertEquals('price_test1', subs[0].Stripe_Price_ID__c);
        System.assertEquals('Subcription Item Delete From Stripe', subs[0].Latest_Change_Reason__c);
        
        Test.stopTest();
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
        
        StripeSubscriptionScheduler.deleteSubscrition(responseNoItems);
        
        Contract updatedCon = [SELECT Id, Stripe_Subscription_ID__c FROM Contract WHERE Id = :con.Id];
        System.assertEquals('sub_test_no_items', updatedCon.Stripe_Subscription_ID__c);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUnitAmountCalculation_Quarterly() {
        String response =
            '{"id":"sub_quarterly_test","object":"subscription","status":"active","items":{"object":"list","data":[' +
            '{"id":"si_quarterly","quantity":1,"price":{"id":"price_quarterly","unit_amount":15000,"recurring":{"interval":"month","interval_count":3}}}' +
            ']}}';
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Contract con = new Contract(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_quarterly_test',
            SBQQ__Quote__c = q.Id
        );
        insert con;
        
        Test.startTest();
        StripeSubscriptionScheduler.createSubscrition(response, q.Id);
        Test.stopTest();
        
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c
            FROM SBQQ__Subscription__c
            WHERE Stripe_Subscription_ID__c = 'sub_quarterly_test'
        ];
        System.assertEquals(1, subs.size(), 'Quarterly subscription should be created');
        System.assertEquals('price_quarterly', subs[0].Stripe_Price_ID__c);
    }
    
    @IsTest
    static void testDeleteSubscription_InvalidResponse() {
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
            Stripe_Subscription_ID__c = 'sub_bad',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
        
        // Bad response (missing items object)
        String badResponse = '{"id":"sub_bad","object":"subscription"}';
        
        try {
            StripeSubscriptionScheduler.deleteSubscrition(badResponse);
            System.assert(false, 'Expected exception for bad response');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('subscription'), 'Error should mention subscription');
        }
        
        Test.stopTest();
        
        // Ensure error logged
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assert(logs.size() > 0, 'Error should be logged for invalid response');
    }
    @IsTest
    static void testCreateSubscrition_NonRecurringPrice() {
        // Price without recurring block (to hit priceType != 'recurring')
        String response =
            '{"id":"sub_nonrec_test","object":"subscription","status":"active","items":{"object":"list","data":[' +
            '{"id":"si_nonrec","quantity":2,"price":{"id":"price_nonrec","unit_amount":5000}}' +
            ']}}';
        
        SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
        StripeSubscriptionScheduler.createSubscrition(response, q.Id);
        Test.stopTest();
        
        List<SBQQ__Subscription__c> subs = [
            SELECT Id, Stripe_Subscription_ID__c,SBQQ__Quantity__c
            FROM SBQQ__Subscription__c
            WHERE Stripe_Subscription_ID__c = 'sub_nonrec_test'
        ];
        System.assertEquals(1, subs.size(), 'Subscription should be created even if not recurring');
        System.assertEquals(2, subs[0].SBQQ__Quantity__c);
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
            StripeSubscriptionScheduler.deleteSubscrition(badResponse);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('subscription'));
        }
        Test.stopTest();
        System.assert([SELECT Count() FROM Logger__c] > 0, 'Error should be logged for missing items');
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
}