@IsTest
private class StripeCheckoutController_Test {

    private class StripeSessionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cs_test_123","status":"complete"}');
            return res;
        }
    }

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
            SBQQ__StartDate__c = Date.today(),
            SBQQ__ExpirationDate__c = Date.today().addMonths(1),
            SBQQ__SubscriptionTerm__c = 12,
            Billing_Frequency_Override__c = 'Monthly',
            Stripe_Checkout_Session_ID__c = 'cs_test_123',
            CurrencyIsoCode = 'USD'
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
            Billing_Frequency_Override__c = 'Semiannual'
        ));
        insert testQuotes;
        
        // Create test Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = new List<SBQQ__QuoteLine__c>();
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuotes[0].Id,
            SBQQ__Product__c = testProducts[0].Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c = 100,
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance'
        ));
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = testQuotes[0].Id,
            SBQQ__Product__c = testProducts[1].Id,
            SBQQ__ListPrice__c = 200,
            SBQQ__NetPrice__c = 200,
            SBQQ__ChargeType__c = 'One-Time'
        ));
        insert testQuoteLines;
    }

    @IsTest
    static void testConstructorAndLoad() {

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Billing_Frequency_Override__c = 'Monthly' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new StripeSessionMock());

        Test.startTest();

        PageReference pageRef = new PageReference('/apex/StripeCheckoutPage');
        pageRef.getParameters().put('session', 'cs_test_123');
        pageRef.getParameters().put('client', 'secret_test_123');
        Test.setCurrentPage(pageRef);

        StripeCheckoutController controller =
            new StripeCheckoutController();

        Test.stopTest();

        System.assertEquals('complete', StripeCheckoutController.status);
        System.assertNotEquals(null, StripeCheckoutController.quoteData);
        System.assertEquals(1, StripeCheckoutController.recurringItemCount);
        System.assertEquals('Subscribe to Test Product 1 - Recurring',
            StripeCheckoutController.subscriptionHeadline);
    }

    @IsTest
    static void testHandleCheckoutCompletion() {

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Billing_Frequency_Override__c = 'Monthly' LIMIT 1];

        Test.startTest();

        StripeCheckoutController.handleCheckoutCompletion(
            quote.Id,
            'John Doe',
            '127.0.0.1',
            'Test Browser'
        );

        Test.stopTest();

        SBQQ__Quote__c updatedQuote = [
            SELECT Digital_Signature__c,
                   Signature_IP_Address__c,
                   Signature_User_Agent__c
            FROM SBQQ__Quote__c
            WHERE Id = :quote.Id
        ];

        System.assertEquals('John Doe', updatedQuote.Digital_Signature__c);
        System.assertEquals('127.0.0.1', updatedQuote.Signature_IP_Address__c);
        System.assertEquals('Test Browser', updatedQuote.Signature_User_Agent__c);
    }

    private class ExpiredSessionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('error');
            return res;
        }
    }

    @IsTest
    static void testExpiredSession() {

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c WHERE Billing_Frequency_Override__c = 'Monthly' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new ExpiredSessionMock());

        Test.startTest();

        PageReference pageRef = new PageReference('/apex/StripeCheckoutPage');
        pageRef.getParameters().put('session', 'cs_test_123');
        pageRef.getParameters().put('client', 'secret_test_123');
        Test.setCurrentPage(pageRef);

        StripeCheckoutController controller =
            new StripeCheckoutController();

        Test.stopTest();

        System.assertEquals('expired', StripeCheckoutController.status);
    }
}