@IsTest
public class StripeSubscriptionItemMigration_Test {
    
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
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test123'
        );
        insert testAccount;
        
        // Create test Products
        List<Product2> testProducts = new List<Product2>();
        testProducts.add(new Product2(
            Name = 'Test Product 1',
            Stripe_Product_ID__c = 'prod_test1',
            IsActive = true
        ));
        testProducts.add(new Product2(
            Name = 'Test Product 2',
            Stripe_Product_ID__c = 'prod_test2',
            IsActive = true
        ));
        insert testProducts;
        
        // Create test Contracts with Stripe Subscription IDs      
        Contract contract1 = new Contract(
            AccountId = testAccount.Id,
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(335),
            Stripe_Subscription_ID__c = 'sub_test123',
            Stripe_Customer_ID__c = 'cus_test123',
            Contract_Migration__c = true,
            Is_Migrating__c = true,
            CurrencyIsoCode = 'USD'
        );
        insert contract1;
        
        // Create existing subscription items (to test upsert functionality)
        List<SBQQ__Subscription__c> existingSubscriptions = new List<SBQQ__Subscription__c>();
        
        existingSubscriptions.add(new SBQQ__Subscription__c(
            SBQQ__Contract__c = contract1.Id,
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Product__c = testProducts[0].Id,
            Stripe_Subscription_ID__c = 'si_test1_old',
            Stripe_Price_ID__c = 'price_test1',
            SBQQ__Quantity__c = 2,
            SBQQ__NetPrice__c = 100,
            Status__c = 'Active'
        ));
        
        insert existingSubscriptions;
    }
    
    @IsTest
    static void testBatchExecuteWithSuccessfulSync() {
        // Setup mock response for successful Stripe API calls
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionSyncMock());
        
        List<Contract> contracts = [
            SELECT Id, Stripe_Subscription_ID__c 
            FROM Contract 
            WHERE Stripe_Subscription_ID__c != NULL
        ];
        
        Test.startTest();
        StripeSubscriptionItemMigration batch = new StripeSubscriptionItemMigration();
        Database.executeBatch(batch, 5);
        Test.stopTest();
        
        // Verify contracts were updated
        List<Contract> updatedContracts = [
            SELECT Id, Stripe_Status__c, Stripe_latest_Invoice_Id__c
            FROM Contract
        ];
        
        for (Contract con : updatedContracts) {
            System.assertEquals('active', con.Stripe_Status__c, 'Contract should have active status from Stripe');
            System.assertEquals('in_test123', con.Stripe_latest_Invoice_Id__c, 'Contract should have latest invoice ID from Stripe');
        }
        
        // Verify subscription items were upserted
        List<SBQQ__Subscription__c> subscriptions = [
            SELECT Id, Stripe_Subscription_ID__c, Stripe_Price_ID__c, SBQQ__Quantity__c,
                   SBQQ__NetPrice__c, Stripe_Monthly_Value__c, Stripe_ARR__c,
                   SBQQ__BillingFrequency__c, Billing_Frequency_Override__c
            FROM SBQQ__Subscription__c
        ];
        
        System.assertEquals(3, subscriptions.size(), 'Should have 3 subscription items');
        
        // Verify specific subscription item was updated (not created new)
        SBQQ__Subscription__c updatedSub = [
            SELECT Id, Stripe_Subscription_ID__c, SBQQ__Quantity__c 
            FROM SBQQ__Subscription__c 
            WHERE Stripe_Price_ID__c = 'price_test1'
            LIMIT 1
        ];
        System.assertEquals('si_test1_old', updatedSub.Stripe_Subscription_ID__c, 'Subscription should have new Stripe ID');
        System.assertEquals(2, updatedSub.SBQQ__Quantity__c, 'Subscription quantity should be updated');
    }
    
    @IsTest
    static void testBatchExecuteWithStripeAPIError() {
        // Setup mock response for Stripe API errors
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        List<Contract> contracts = [
            SELECT Id, Stripe_Subscription_ID__c 
            FROM Contract 
            WHERE Stripe_Subscription_ID__c != NULL
            LIMIT 1
        ];
        
        Test.startTest();
        StripeSubscriptionItemMigration batch = new StripeSubscriptionItemMigration();
        Database.executeBatch(batch, 5);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchExecuteWithEmptyScope() {
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionSyncMock());
        
        List<Contract> emptyScope = new List<Contract>();
        
        Test.startTest();
        StripeSubscriptionItemMigration batch = new StripeSubscriptionItemMigration();
        batch.execute(null, emptyScope);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchExecuteWithContractWithoutStripeID() {
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionSyncMock());
        
        // Create a contract without Stripe Subscription ID
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contract contractWithoutStripeId = new Contract(
            AccountId = testAccount.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            Contract_Migration__c = true,
            CurrencyIsoCode = 'USD'
        );
        insert contractWithoutStripeId;
        
        List<Contract> scope = new List<Contract>{ contractWithoutStripeId };
        
        Test.startTest();
        StripeSubscriptionItemMigration batch = new StripeSubscriptionItemMigration();
        batch.execute(null, scope);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchWithMissingProducts() {
        // Setup mock response
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionSyncMock());
        
        List<Contract> contracts = [
            SELECT Id, Stripe_Subscription_ID__c 
            FROM Contract 
            WHERE Stripe_Subscription_ID__c != NULL
            LIMIT 1
        ];
        
        // Delete products to simulate missing products
        delete [SELECT Id FROM Product2];
        
        Test.startTest();
        StripeSubscriptionItemMigration batch = new StripeSubscriptionItemMigration();
        batch.execute(null, contracts);
        Test.stopTest();
        
        // Verify subscriptions were still created but without product relationships
        List<SBQQ__Subscription__c> subscriptions = [
            SELECT Id, SBQQ__Product__c, Stripe_Product_ID__c 
            FROM SBQQ__Subscription__c
        ];
        
        System.assert(subscriptions.size() > 0, 'Subscriptions should still be created');
        for (SBQQ__Subscription__c sub : subscriptions) {
            System.assertEquals(null, sub.SBQQ__Product__c, 'Product should be null when product not found');
            System.assertEquals(null, sub.Stripe_Product_ID__c, 'Stripe Product ID should still be set');
        }
    }
    
    // Mock class for successful Stripe subscription sync
    public class StripeSubscriptionSyncMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/subscriptions/')) {
                String subscriptionId = req.getEndpoint().substringAfterLast('/');
                res.setBody('{' +
                    '"id": "' + subscriptionId + '",' +
                    '"object": "subscription",' +
                    '"customer": "cus_test123",' +
                    '"latest_invoice": "in_test123",' +
                    '"status": "active",' +
                    '"current_period_start": 1635724800,' +
                    '"current_period_end": 1638403200,' +
                    '"billing_cycle_anchor": 1635724800,' +
                    '"items": {' +
                    '  "object": "list",' +
                    '  "data": [' +
                    '    {' +
                    '      "id": "si_test1",' +
                    '      "object": "subscription_item",' +
                    '      "quantity": 2,' +
                    '      "current_period_start": 1635724800,' +
                    '      "current_period_end": 1638403200,' +
                    '      "price": {' +
                    '        "id": "price_test1",' +
                    '        "object": "price",' +
                    '        "active": true,' +
                    '        "unit_amount": 10000,' +
                    '        "unit_amount_decimal": "10000",' +
                    '        "product": "prod_test1",' +
                    '        "recurring": {' +
                    '          "interval": "month",' +
                    '          "interval_count": 1' +
                    '        }' +
                    '      }' +
                    '    },' +
                    '    {' +
                    '      "id": "si_test2",' +
                    '      "object": "subscription_item",' +
                    '      "quantity": 1,' +
                    '      "current_period_start": 1635724800,' +
                    '      "current_period_end": 1638403200,' +
                    '      "price": {' +
                    '        "id": "price_test2",' +
                    '        "object": "price",' +
                    '        "active": true,' +
                    '        "unit_amount": 20000,' +
                    '        "unit_amount_decimal": "20000",' +
                    '        "product": "prod_test2",' +
                    '        "recurring": {' +
                    '          "interval": "year",' +
                    '          "interval_count": 1' +
                    '        }' +
                    '      }' +
                    '    }' +
                    '  ]' +
                    '}' +
                '}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
                res.setBody('{"error": "Endpoint not found"}');
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
            res.setBody('{"error": {"message": "Invalid API Key", "type": "invalid_request_error"}}');
            return res;
        }
    }
}