@IsTest
public class StripeDeleteSubscriptionItems_Test {
    
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c sd = new Stripe_Details__c(Name = 'Stripe Details', Serect_Key__c = 'sk_test_abc123');
        insert sd;
        
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            Stripe_Customer_Id__c = 'cus_test123'
        );
        insert testAccount;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TPR001',
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
        
        // Create test Contract with Stripe Subscription ID
        Contract testContract = new Contract(
            AccountId = testAccount.Id,
            Stripe_Subscription_ID__c = 'sub_test123',
            Status = 'Draft',
            StartDate = Date.today().addMonths(-1),
            EndDate = Date.today().addMonths(11),
            ContractTerm = 12
        );
        insert testContract;
        
        testContract.Status = 'Activated';
        update testContract;
        
        // Create test Subscriptions with Stripe Subscription Item IDs
        List<SBQQ__Subscription__c> testSubscriptions = new List<SBQQ__Subscription__c>();
        
        testSubscriptions.add(new SBQQ__Subscription__c(
            Stripe_Subscription_ID__c = 'si_test1',
            SBQQ__Contract__c = testContract.Id,
            SBQQ__Account__c = testAccount.Id,
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 1,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__Product__c = prod.Id,
            Stripe_Price_ID__c = 'pi_test_1234',
            Stripe_Product_ID__c = 'pr_test_1234',
            CurrencyIsoCode = 'USD'
        ));
        
        testSubscriptions.add(new SBQQ__Subscription__c(
            Stripe_Subscription_ID__c = 'si_test2',
            SBQQ__Contract__c = testContract.Id,
            SBQQ__Account__c = testAccount.Id,
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 2,
            SBQQ__NetPrice__c = 200.00,
            SBQQ__Product__c = prod.Id,
            Stripe_Price_ID__c = 'pi_test_1234',
            Stripe_Product_ID__c = 'pr_test_1234',
            CurrencyIsoCode = 'USD'
        ));
        
        testSubscriptions.add(new SBQQ__Subscription__c(
            Stripe_Subscription_ID__c = 'si_test3',
            SBQQ__Contract__c = testContract.Id,
            SBQQ__Account__c = testAccount.Id,
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 3,
            SBQQ__NetPrice__c = 300.00,
            SBQQ__Product__c = prod.Id,
            Stripe_Price_ID__c = 'pi_test_1234',
            Stripe_Product_ID__c = 'pr_test_1234',
            CurrencyIsoCode = 'USD'
        ));
        
        insert testSubscriptions;
    }
    
    @IsTest
    static void testQueueableDeletesSubscriptions() {
        // Get the test contract
        Contract testContract = [SELECT Id, Stripe_Subscription_ID__c FROM Contract LIMIT 1];
        
        // Set up deleted item IDs
        String stripeSubscriptionId = testContract.Stripe_Subscription_ID__c;
        List<String> deletedItemIds = new List<String>{'si_test1', 'si_test2'};
        
        Test.startTest();
        // Execute the queueable
        StripeDeleteSubscriptionItemsQueueable queueable = new StripeDeleteSubscriptionItemsQueueable(
            stripeSubscriptionId, 
            deletedItemIds
        );
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify that the specified subscriptions were deleted
        List<SBQQ__Subscription__c> remainingSubscriptions = [
            SELECT Id, Stripe_Subscription_ID__c 
            FROM SBQQ__Subscription__c 
            WHERE SBQQ__Contract__c = :testContract.Id
        ];
        
        // Should have 1 remaining subscription (si_test3)
        System.assertEquals(1, remainingSubscriptions.size(), 'Should have 1 remaining subscription');
        System.assertEquals('si_test3', remainingSubscriptions[0].Stripe_Subscription_ID__c, 'Remaining subscription should be si_test3');
    }
    
    @IsTest
    static void testQueueableWithNoMatchingContract() {
        String nonExistentSubscriptionId = 'sub_nonexistent';
        List<String> deletedItemIds = new List<String>{'si_test1', 'si_test2'};
        
        Test.startTest();
        StripeDeleteSubscriptionItemsQueueable queueable = new StripeDeleteSubscriptionItemsQueueable(
            nonExistentSubscriptionId, 
            deletedItemIds
        );
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify no subscriptions were deleted
        List<SBQQ__Subscription__c> allSubscriptions = [SELECT Id FROM SBQQ__Subscription__c];
        System.assertEquals(3, allSubscriptions.size(), 'No subscriptions should be deleted when contract not found');
    }
}