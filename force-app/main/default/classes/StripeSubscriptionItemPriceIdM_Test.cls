@IsTest
public class StripeSubscriptionItemPriceIdM_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create custom setting for Stripe Details
        Stripe_Details__c stripeDetails = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_1234567890'
        );
        insert stripeDetails;
        
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test Contract with migration flag
        Contract testContract = new Contract(
            AccountId = testAccount.Id,
            Contract_Migration__c = true,
            Stripe_Subscription_ID__c = 'sub_test123',
            Status = 'Draft',
            StartDate = System.today(),
            EndDate = System.today().addMonths(12)
        );
        insert testContract;
        
        testContract.Status = 'Activated';
        update testContract;
        
        // Create test Subscriptions
        List<SBQQ__Subscription__c> testSubscriptions = new List<SBQQ__Subscription__c>();
        
        // Eligible subscription (should be processed)
        testSubscriptions.add(new SBQQ__Subscription__c(
            SBQQ__Contract__c = testContract.Id,
            SBQQ__Account__c = testAccount.Id,
            Stripe_Subscription_ID__c = 'si_test1',
            Stripe_Price_ID__c = 'price_test1',
            SBQQ__Quantity__c = 2,
            Stripe_Subscription_Migration__c = true
        ));
        
        // Another eligible subscription
        testSubscriptions.add(new SBQQ__Subscription__c(
            SBQQ__Contract__c = testContract.Id,
            SBQQ__Account__c = testAccount.Id,
            Stripe_Subscription_ID__c = 'si_test2',
            Stripe_Price_ID__c = 'price_test2',
            SBQQ__Quantity__c = 1,
            Stripe_Subscription_Migration__c = true
        ));
        
        insert testSubscriptions;
    }
    
    @IsTest
    static void testBatchExecuteMethod() {
        // Setup mock response
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionItemMock());
        
        Test.startTest();
        StripeSubscriptionItemPriceIdMigration batch = new StripeSubscriptionItemPriceIdMigration();
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Verify logger was created
        List<Logger__c> logs = [SELECT Id, Status__c FROM Logger__c];
        System.assertEquals(0, logs.size(), 'Logger should not be created');
    }
    
    @IsTest
    static void testBatchWithStripeError() {
        // Setup error mock response
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        Test.startTest();
        StripeSubscriptionItemPriceIdMigration batch = new StripeSubscriptionItemPriceIdMigration();
        Database.executeBatch(batch, 10);
        Test.stopTest();
    }
    
    // Mock class for successful Stripe subscription item updates
    public class StripeSubscriptionItemMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/subscription_items/')) {
                res.setBody('{' +
                    '"id": "si_test",' +
                    '"object": "subscription_item",' +
                    '"price": {"id": "price_test"},' +
                    '"quantity": 2,' +
                    '"subscription": "sub_test"' +
                '}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            
            return res;
        }
    }
    
    // Mock class for Stripe errors
    public class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request", "type": "invalid_request_error"}}');
            return res;
        }
    }
    
    // Mock class for mixed responses (one success, one error)
    public class StripeMixedResponseMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            callCount++;
            
            if (callCount == 1) {
                // First call - success
                res.setBody('{' +
                    '"id": "si_test1",' +
                    '"object": "subscription_item",' +
                    '"price": {"id": "price_test1"},' +
                    '"quantity": 2,' +
                    '"subscription": "sub_test"' +
                '}');
                res.setStatusCode(200);
            } else {
                // Second call - error
                res.setStatusCode(400);
                res.setBody('{"error": {"message": "Invalid request", "type": "invalid_request_error"}}');
            }
            
            return res;
        }
    }
}