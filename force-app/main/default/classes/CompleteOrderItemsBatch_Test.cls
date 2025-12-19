@IsTest
public class CompleteOrderItemsBatch_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test contacts
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'testemail' + i + '@test.com'
            ));
        }
        insert testContacts;
        
        // Create test Accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < testContacts.size(); i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
                blng__BillToContact__c = testContacts[i].Id,
                F52_Primary_Contact__c = testContacts[i].Id,
                ShippingCity = 'Brooklyn',
                ShippingCountry = 'US',
                ShippingState = 'NY',
                ShippingStreet = '213-Downtown',
                BillingCity = 'Brooklyn',
                BillingCountry = 'US',
                BillingState = 'NY',
                BillingStreet = '213-Downtown'
            ));
        }
        insert testAccounts;
        
        // Create test Orders
        List<Order> testOrders = new List<Order>();
        for (Account acc : testAccounts) {
            testOrders.add(new Order(
                AccountId = acc.Id,
                Status = 'Draft',
                EffectiveDate = System.today(),
                blng__BillingDayOfMonth__c = '1',
                Pricebook2Id = Test.getStandardPricebookId(),
                BillToContactId = acc.blng__BillToContact__c,
                ShipToContactId = acc.F52_Primary_Contact__c,
                ShippingCity = 'Brooklyn',
                ShippingCountry = 'US',
                ShippingState = 'NY',
                ShippingStreet = '213-Downtown',
                BillingCity = 'Brooklyn',
                BillingCountry = 'US',
                BillingState = 'NY',
                BillingStreet = '213-Downtown'
            ));
        }
        insert testOrders;
        
        // Create test Contracts with migration flags
        List<Contract> testContracts = new List<Contract>();
        for (Integer i = 0; i < testOrders.size(); i++) {
            testContracts.add(new Contract(
                AccountId = testAccounts[i].Id,
                SBQQ__Order__c = testOrders[i].Id,
                Contract_Migration__c = true,
                Stripe_Subscription_ID__c = 'sub_test_' + i,
                Status = 'Draft',
                StartDate = System.today()
            ));
        }
        insert testContracts;
        
        // Create a test product
        List<Product2> testProds = new List<Product2>();
        testProds.add(new Product2(
            Name = 'Test Product 1', 
            IsActive = true
        ));
        testProds.add(new Product2(
            Name = 'Test Product 2', 
            IsActive = true
        ));
        insert testProds;
        
        List<PricebookEntry> testPbes = new List<PricebookEntry>();
        testPbes.add(new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = testProds[0].Id,
            UnitPrice = 100,
            IsActive = true
        ));
        testPbes.add(new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = testProds[1].Id,
            UnitPrice = 200,
            IsActive = true
        ));
        insert testPbes;
        
        blng__BillingRule__c billingRule = new blng__BillingRule__c(
            Name = 'Test Billing Rule',
            blng__Active__c = true,
            blng__AmendmentBillCycleDateAlignment__c = 'Do not align amended Order Product',
            blng__GenerateInvoices__c = 'Yes',
            blng__InitialBillingTrigger__c = 'Order Product Activation Date',
            blng__PartialPeriodTreatment__c = 'Separate'
        );
        insert billingRule;
        
        blng__RevenueRecognitionRule__c revenueRecognitionRule = new blng__RevenueRecognitionRule__c(
            Name = 'Test Revenue Recognition Rule',
            blng__Active__c = true,
            blng__CreateRevenueSchedule__c = 'Yes'
        );
        insert revenueRecognitionRule;
        
        blng__TaxRule__c taxRule = new blng__TaxRule__c(
            Name = 'Test Tax Rule',
            blng__Active__c = true,
            blng__TaxableYesNo__c = 'No'
        );
        insert taxRule;
        
        // Create test Order Items with different statuses
        List<OrderItem> testOrderItems = new List<OrderItem>();
        for (Order ord : testOrders) {
            // Add some items with 'Completed' status
            testOrderItems.add(new OrderItem(
                OrderId = ord.Id,
                blng__InvoiceRunProcessingStatus__c = 'Completed',
                Quantity = 1,
                UnitPrice = 100,
                Product2Id = testProds[0].Id,
                PricebookEntryId = testPbes[0].Id,
                SBQQ__Activated__c = true,
                SBQQ__ChargeType__c = 'Recurring',
                SBQQ__BillingFrequency__c = 'Monthly',
                SBQQ__BillingType__c = 'Advance',
                SBQQ__SubscriptionType__c = 'Renewable',
                SBQQ__ProductSubscriptionType__c = 'Renewable',
                SBQQ__SubscriptionTerm__c = 12
                //is_Test__c = false,
                //blng__BillingRule__c = billingRule.Id, 
                //blng__RevenueRecognitionRule__c = revenueRecognitionRule.Id, 
                //blng__TaxRule__c = taxRule.Id
            ));
            // Add some items with other statuses (to be updated)
            testOrderItems.add(new OrderItem(
                OrderId = ord.Id,
                blng__InvoiceRunProcessingStatus__c = 'Pending Billing',
                Quantity = 2,
                UnitPrice = 200,
                Product2Id = testProds[1].Id,
                PricebookEntryId = testPbes[1].Id,
                SBQQ__Activated__c = true,
                SBQQ__ChargeType__c = 'One-Time',
                SBQQ__SubscriptionType__c = 'One-time',
                SBQQ__ProductSubscriptionType__c = 'One-time',
                SBQQ__SubscriptionTerm__c = 12
                //is_Test__c = false,
                //blng__BillingRule__c = billingRule.Id, 
                //blng__RevenueRecognitionRule__c = revenueRecognitionRule.Id, 
                //blng__TaxRule__c = taxRule.Id
            ));
        }
        insert testOrderItems;
    }
    
    @IsTest
    static void testBatchExecute() {
        Test.startTest();
        CompleteOrderItemsBatch batch = new CompleteOrderItemsBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify that order items with non-Completed status were updated
        List<OrderItem> updatedItems = [
            SELECT Id, blng__InvoiceRunProcessingStatus__c 
            FROM OrderItem 
            WHERE blng__InvoiceRunProcessingStatus__c = 'Completed'
        ];
        
        // We created 3 orders, each with 2 items (1 Completed, 1 Pending Billing)
        // So after batch runs, all 6 items should be 'Completed'
        System.assertEquals(6, updatedItems.size(), 'All order items should be marked as Completed');
        
        // Verify logger was created
        List<Logger__c> logs = [SELECT Id, Message__c FROM Logger__c];
        System.assertEquals(1, logs.size(), 'Logger should be created');
        System.assert(logs[0].Message__c.contains('Successfully processed'), 'Logger message should contain success info');
    }
    
    @IsTest
    static void testBatchWithNoRecordsToUpdate() {
        // First update all order items to 'Completed' so nothing needs updating
        List<OrderItem> allItems = [SELECT Id FROM OrderItem];
        for (OrderItem item : allItems) {
            item.blng__InvoiceRunProcessingStatus__c = 'Completed';
        }
        update allItems;
        
        Test.startTest();
        CompleteOrderItemsBatch batch = new CompleteOrderItemsBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify no changes were made (all items were already 'Completed')
        List<OrderItem> itemsAfterBatch = [
            SELECT Id, blng__InvoiceRunProcessingStatus__c 
            FROM OrderItem 
            WHERE blng__InvoiceRunProcessingStatus__c = 'Completed'
        ];
        System.assertEquals(6, itemsAfterBatch.size(), 'No items should change status');
    }
}