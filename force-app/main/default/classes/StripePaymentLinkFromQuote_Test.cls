@IsTest
public class StripePaymentLinkFromQuote_Test {
    // Test setup: runs before all test methods
    @TestSetup
    static void setupData() {
        // Stripe Details (Hierarchy type)
        Stripe_Details__c stripeSetting = new Stripe_Details__c();
        stripeSetting.Name = 'Stripe Details';
        stripeSetting.Serect_Key__c = 'sk_test_123456';
        stripeSetting.Publishable_Key__c = 'pk_test_123456';
        insert stripeSetting;
        
        // Account
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123456'
        );
        insert acc;
        
        // Create test Products
        List<Product2> testProducts = new List<Product2>();
        testProducts.add(new Product2(
            Name = 'Test Product 1 - Recurring',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test1',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            Description = 'Test Product Description',
            CurrencyIsoCode = 'USD'
        ));
        testProducts.add(new Product2(
            Name = 'Test Product 2 - One-Time',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test2',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__SubscriptionType__c = 'One-time',
            SBQQ__ChargeType__c = 'One-Time',
            Description = 'Test One-Time Product',
            CurrencyIsoCode = 'USD'
        ));
        insert testProducts;
        
        // Create test Quotes
        List<SBQQ__Quote__c> testQuotes = new List<SBQQ__Quote__c>();
        testQuotes.add(new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            Submitted_Date__c = Date.today(),
            Billing_Frequency_Override__c = 'Monthly'
        ));
        testQuotes.add(new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            Billing_Frequency_Override__c = 'Quarterly'
        ));
        testQuotes.add(new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            Billing_Frequency_Override__c = 'Annual'
        ));
        testQuotes.add(new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            Billing_Frequency_Override__c = '2-Year'
        ));
        insert testQuotes;
        
        // Create test Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = new List<SBQQ__QuoteLine__c>();
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuotes[0].Id,
            SBQQ__Product__c = testProducts[0].Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c = 100
        ));
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuotes[0].Id,
            SBQQ__Product__c = testProducts[1].Id,
            SBQQ__ListPrice__c = 200,
            SBQQ__NetPrice__c = 200
        ));
        insert testQuoteLines;
    }
    
    // Mock for Stripe API responses
    class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{' +
                        '"id": "cs_test_123456",' +
                        '"url": "https://stripe.com/pay/checkout_test",' +
                        '"payment_intent": "pi_test_123456",' +
                        '"expires_at": 1700000000,' +
                        '"created": 1700000000' +
                        '}');
            return res;
        }
    }
    
    // Mock for Stripe API responses
    class StripeMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            String resBody = '{\"id\":\"price_1S3BECPuJCefzpgmABCNaML3\",\"object\":\"price\",\"active\":true,\"billing_scheme\":\"per_unit\",\"created\":1756884936,\"currency\":\"usd\",\"custom_unit_amount\":null,\"livemode\":false,\"lookup_key\":null,\"metadata\":{},\"nickname\":null,\"product\":\"prod_Squ9kXUFSf8muO\",\"recurring\":{\"interval\":\"month\",\"interval_count\":1,\"meter\":null,\"trial_period_days\":null,\"usage_type\":\"licensed\"},\"tax_behavior\":\"unspecified\",\"tiers_mode\":null,\"transform_quantity\":null,\"type\":\"recurring\",\"unit_amount\":5900,\"unit_amount_decimal\":\"5900\"}';
            res.setBody(resBody);
            return res;
        }
    }
    
    @IsTest
    static void testGetQuoteForQuoteToCash() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Submitted_Date__c = :Date.today() LIMIT 1];
        
        Test.startTest();
        StripePaymentLinkFromQuote.getQuoteForQuoteToCash(new List<Id>{quote.Id});
        Test.stopTest();
        
        SBQQ__Quote__c updatedQuote = [SELECT Stripe_Payment_Link__c, Stripe_Payment_Intent__c 
                                       FROM SBQQ__Quote__c 
                                       WHERE Id = :quote.Id];
        System.assertEquals('https://stripe.com/pay/checkout_test', updatedQuote.Stripe_Payment_Link__c);
        System.assertEquals('cs_test_123456', updatedQuote.Stripe_Payment_Intent__c);
    }
    
    @IsTest
    static void testGetQuoteForSelfService() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Submitted_Date__c = :Date.today() LIMIT 1];
        
        Test.startTest();
        String paymentLink = StripePaymentLinkFromQuote.getQuoteForSelfService(quote.Id);
        Test.stopTest();
        
        System.assertEquals('https://stripe.com/pay/checkout_test', paymentLink);
        
        SBQQ__Quote__c updatedQuote = [SELECT Stripe_Payment_Link__c, Stripe_Payment_Intent__c 
                                       FROM SBQQ__Quote__c 
                                       WHERE Id = :quote.Id];
        System.assertEquals('https://stripe.com/pay/checkout_test', updatedQuote.Stripe_Payment_Link__c);
        System.assertEquals('cs_test_123456', updatedQuote.Stripe_Payment_Intent__c);
    }
    
    @IsTest
    static void testGetQuoteForQuoteToCash_CalloutError() {
        Test.setMock(HttpCalloutMock.class, new StripeMockError());
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Test.startTest();
        StripePaymentLinkFromQuote.getQuoteForQuoteToCash(new List<Id>{quote.Id});
        Test.stopTest();
        
        SBQQ__Quote__c sameQuote = [SELECT Stripe_Payment_Link__c, Stripe_Payment_Intent__c 
                                    FROM SBQQ__Quote__c 
                                    WHERE Id = :quote.Id];
        System.assertEquals(null, sameQuote.Stripe_Payment_Link__c, 'No payment link should generate');
    }
    
    @IsTest
    static void testGetQuoteForSelfService_CalloutError() {
        Test.setMock(HttpCalloutMock.class, new StripeMockError());
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        String paymentLink;
        
        Test.startTest();
        try {
            paymentLink = StripePaymentLinkFromQuote.getQuoteForSelfService(quote.Id);   
        } catch (Exception e) {
            System.assertEquals(null, paymentLink);
            
            SBQQ__Quote__c sameQuote = [SELECT Stripe_Payment_Link__c, Stripe_Payment_Intent__c 
                                        FROM SBQQ__Quote__c 
                                        WHERE Id = :quote.Id];
            System.assertEquals(null, sameQuote.Stripe_Payment_Link__c, 'No payment link should generate');
        }
        Test.stopTest();
    }
}