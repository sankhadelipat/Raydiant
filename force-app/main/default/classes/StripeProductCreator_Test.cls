@IsTest
public class StripeProductCreator_Test {

    // Mock successful Stripe Product creation response
    private class StripeProductHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"prod_12345"}'); // Mock Stripe product ID
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Create Account and Quote (if needed)
        Account acc = new Account(Name='Test Account');
        insert acc;

        // Create Stripe Details record for test
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        insert sd;

        // Create a Product2 record to test
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP001',
            IsActive = true,
            
                 RAY_JSON_Text__c = 'test',
                SBQQ__SubscriptionPricing__c  ='Fixed Price',
            SBQQ__SubscriptionType__c = 'Renewable',
                Customer_Facing_Pricing__c ='$59 / 12 Mths / Screen / Billable Monthly',
                RAY_Category__c ='SW',
                Product_Line__c  ='CX'
        );
        insert prod;
    }

    @IsTest
    static void testCreateStripeProduct_Success() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeProductHttpMock());

       Product2 prod = [SELECT Id, Name, ProductCode FROM Product2 LIMIT 1];


        // Prepare Invocable request
        StripeProductCreator.Request req = new StripeProductCreator.Request();
        req.productId = prod.Id;
        req.productName = prod.Name;
        req.description = 'Test Description';
        req.productCode = prod.ProductCode;
        req.isActive = true;

        List<StripeProductCreator.Request> requests = new List<StripeProductCreator.Request>{ req };

        // Call the invocable method
        List<StripeProductCreator.Response> responses = StripeProductCreator.createStripeProduct(requests);

        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assert(responses[0].success, 'Response should be successful');

        // Verify Product2 record was updated with Stripe Product ID
        Product2 updatedProd = [SELECT Stripe_Product_ID__c FROM Product2 WHERE Id = :prod.Id];
        System.assertEquals('prod_12345', updatedProd.Stripe_Product_ID__c);
    }

    // Mock failure response for callout
    private class StripeProductHttpMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }

    @IsTest
    static void testCreateStripeProduct_Failure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeProductHttpMockFailure());

       Product2 prod = [SELECT Id, Name, ProductCode FROM Product2 LIMIT 1];

        StripeProductCreator.Request req = new StripeProductCreator.Request();
        req.productId = prod.Id;
        req.productName = prod.Name;
        req.description = 'Test Description';
        req.productCode = prod.ProductCode;
        req.isActive = true;

        List<StripeProductCreator.Request> requests = new List<StripeProductCreator.Request>{ req };

        List<StripeProductCreator.Response> responses = StripeProductCreator.createStripeProduct(requests);

        Test.stopTest();

        // Response should indicate failure
        System.assertEquals(1, responses.size());
        System.assert(!responses[0].success, 'Response should be failure');

        // Check that a logger record was created
        Logger__c log = [SELECT Name, Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripeProductCreator' LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Message__c.contains('Failed to create product'));
    }
}