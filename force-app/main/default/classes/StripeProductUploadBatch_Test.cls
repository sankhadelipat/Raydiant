@IsTest
public class StripeProductUploadBatch_Test {

    private class StripeProductHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"prod_12345"}');
            return res;
        }
    }

    private class StripeProductHttpMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        insert sd;

        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 3; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                ProductCode = 'TP00' + i,
                Description = 'Description ' + i,
                IsActive = true,
                 RAY_JSON_Text__c = 'test',
                SBQQ__SubscriptionPricing__c  ='Fixed Price',
            SBQQ__SubscriptionType__c = 'Renewable',
                Customer_Facing_Pricing__c ='$59 / 12 Mths / Screen / Billable Monthly',
                RAY_Category__c ='SW',
                Product_Line__c  ='CX'
            
            ));
        }
        insert products;
    }

    @IsTest
    static void testBatchSuccess() {
        Test.setMock(HttpCalloutMock.class, new StripeProductHttpMock());

        Test.startTest();
        StripeProductUploadBatch batch = new StripeProductUploadBatch();
        Database.executeBatch(batch, 50); // large batch size ensures single execute
        Test.stopTest();
        /*
        List<Product2> updatedProducts = [SELECT Name, Stripe_Product_ID__c FROM Product2];
        for (Product2 p : updatedProducts) {
            System.assertEquals('prod_12345', p.Stripe_Product_ID__c);
        }
       */
    }

    @IsTest
    static void testBatchFailure() {
        Test.setMock(HttpCalloutMock.class, new StripeProductHttpMockFailure());

        Test.startTest();
        StripeProductUploadBatch batch = new StripeProductUploadBatch();
        Database.executeBatch(batch, 50);
        Test.stopTest();
    
        List<Product2> failedProducts = [SELECT Name, Stripe_Product_ID__c FROM Product2];
        for (Product2 p : failedProducts) {
            System.assertEquals(null, p.Stripe_Product_ID__c);
        }
        
        Logger__c log = [SELECT Name, Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripeProductUploadBatch' LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }
}