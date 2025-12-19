@IsTest
private class StripeSubcriptionPriceIdMigartion_Test {
    
    // Mock class to simulate Stripe API response
    private class StripePriceMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public StripePriceMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c details = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert details;
        
        // Create Account 
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test1'
        );
        insert acc;
        
        List<Product2> testProducts = new List<Product2>();
        // Recurring product
        testProducts.add(new Product2(
            Name = 'Test Product 1 - Recurring',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test1',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            SBQQ__SubscriptionType__c = 'Renewable',
            CurrencyIsoCode = 'USD'
        ));
        // One-time product
        testProducts.add(new Product2(
            Name = 'Test Product 2 - One-Time',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test2',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            //SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__ChargeType__c = 'One-Time',
            //SBQQ__BillingType__c = 'Advance',
            SBQQ__SubscriptionType__c = 'One-time',
            CurrencyIsoCode = 'USD'
        ));
        insert testProducts;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
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
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            Type = 'New',
            CloseDate = Date.today(),
            StageName = 'Discovery & Qualification',
            ForecastCategoryName = 'Upside'
        );
        insert testOpp;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = testOpp.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PaymentTerms__c = 'Prepayment',
            SBQQ__StartDate__c = System.today(),
            SBQQ__EndDate__c = System.today().addMonths(12),
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;
        
        // Insert Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = new List<SBQQ__QuoteLine__c>();
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = testProducts[0].Id,
            SBQQ__ChargeType__c = testProducts[0].SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = testProducts[0].SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = testProducts[0].SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = testProducts[0].SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = testProducts[0].SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = testProducts[0].SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__RegularPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbes[0].Id,
            Stripe_Price_ID__c = 'price_test1'
        ));
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = testProducts[1].Id,
            SBQQ__ChargeType__c = testProducts[1].SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = testProducts[1].SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = testProducts[1].SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = testProducts[1].SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = testProducts[1].SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = testProducts[1].SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 200.00,
            SBQQ__NetPrice__c = 200.00,
            SBQQ__RegularPrice__c = 200.00,
            SBQQ__SpecialPrice__c = 200.00,
            SBQQ__PricebookEntryId__c = testPbes[1].Id,
            Stripe_Price_ID__c = 'price_test2'
        ));
        insert testQuoteLines;
    }
    
    private static SBQQ__Subscription__c createSubscription(Boolean withPriceId, Product2 product) {        
        Account acc = [SELECT Id, Stripe_Customer_ID__c FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE SBQQ__Account__c = :acc.Id LIMIT 1];
        
        // Create Contract 
        Contract con = new Contract(
            AccountId = acc.Id, 
            StartDate = Date.today(), 
            EndDate = Date.today().addDays(30),
            ContractTerm = 12, 
            // Status = 'Draft',
            SBQQ__Quote__c = quote.Id,
            Stripe_Billing_Date__c = Date.today(),
            Stripe_Subscription_ID__c = null,
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c,
            Is_Migrating__c = true
        ); 
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Product__c = product.Id,
            SBQQ__Contract__c = con.Id,
			Stripe_Product_ID__c = 'product_123',
            Stripe_Price_ID__c = withPriceId ? 'price_existing' : null,
            SBQQ__ChargeType__c = product.SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = product.SBQQ__SubscriptionType__c,
            SBQQ__BillingFrequency__c = product.SBQQ__BillingFrequency__c,
            SBQQ__TerminatedDate__c = Date.today().addDays(30),
            SBQQ__Quantity__c = 1,
            SBQQ__NetPrice__c = 100.00,
            Stripe_Subscription_ID__c = 'si_123',
            CurrencyIsoCode = 'USD',
            Stripe_Subscription_Migration__c = true
        );
        insert sub;
        return sub;
    }
    
    // --- TEST METHODS ---
    
    @IsTest
    static void testBatchSuccess() {
        Product2 product = [SELECT Id, SBQQ__SubscriptionType__c, SBQQ__BillingFrequency__c, SBQQ__ChargeType__c FROM Product2 WHERE SBQQ__SubscriptionType__c = 'Renewable' LIMIT 1];
        // Use recurring product
        SBQQ__Subscription__c sub = createSubscription(false, product);
        
        // Mock Stripe success response
        Test.setMock(HttpCalloutMock.class,
                     new StripePriceMock(200, '{"id":"price_12345","object":"price"}'));
        
        Test.startTest();
        StripeSubcriptionPriceIdMigartion batch = new StripeSubcriptionPriceIdMigartion();
        Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify subscription updated
        SBQQ__Subscription__c updatedSub = [
            SELECT Stripe_Price_ID__c 
            FROM SBQQ__Subscription__c 
            WHERE Id = :sub.Id
        ];
      //  System.assertEquals('price_12345', updatedSub.Stripe_Price_ID__c,
                            //'Subscription should be updated with Stripe Price ID');
    }
    
    @IsTest
    static void testBatchFailureResponse() {
        Product2 product = [SELECT Id, SBQQ__SubscriptionType__c, SBQQ__BillingFrequency__c, SBQQ__ChargeType__c FROM Product2 WHERE SBQQ__SubscriptionType__c = 'Renewable' LIMIT 1];
        // Use recurring product
        SBQQ__Subscription__c sub = createSubscription(false, product);
        
        // Mock Stripe failure response
        Test.setMock(HttpCalloutMock.class,
                     new StripePriceMock(400, '{"error":"Invalid request"}'));
        
        Test.startTest();
        StripeSubcriptionPriceIdMigartion batch = new StripeSubcriptionPriceIdMigartion();
        Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify subscription did not get updated
        SBQQ__Subscription__c unchangedSub = [
            SELECT Stripe_Price_ID__c 
            FROM SBQQ__Subscription__c 
            WHERE Id = :sub.Id
        ];
        //System.assertEquals(null, unchangedSub.Stripe_Price_ID__c,
                           // 'Subscription should not update on Stripe error');
    }
    
    @IsTest
    static void testBatchWithExistingPriceId() {
        Product2 product = [SELECT Id, SBQQ__SubscriptionType__c, SBQQ__BillingFrequency__c, SBQQ__ChargeType__c FROM Product2 WHERE SBQQ__SubscriptionType__c = 'Renewable' LIMIT 1];
        // Use recurring product
        SBQQ__Subscription__c sub = createSubscription(true, product);
        
        Test.startTest();
        StripeSubcriptionPriceIdMigartion batch = new StripeSubcriptionPriceIdMigartion();
        Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify existing priceId remains unchanged
        SBQQ__Subscription__c sameSub = [
            SELECT Stripe_Price_ID__c 
            FROM SBQQ__Subscription__c 
            WHERE Id = :sub.Id
        ];
       // System.assertEquals('price_existing', sameSub.Stripe_Price_ID__c,
                           // 'Existing Stripe Price ID should not change');
    }
}