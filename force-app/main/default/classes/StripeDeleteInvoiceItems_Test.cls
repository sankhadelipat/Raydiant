@IsTest
public class StripeDeleteInvoiceItems_Test {
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_1234567890abcdef'
        );
        insert sd;

        // Create test Account
        Account testAccount = new Account(Name = 'Test Account', Stripe_Customer_Id__c = 'cus_test123');
        insert testAccount;

        // Create test Stripe Invoice
        Stripe_Invoice__c testInvoice = new Stripe_Invoice__c(
            Name = 'Test Invoice',
            Stripe_Invoice_ID__c = 'in_test123',
            Account__c = testAccount.Id,
            Amount_Due__c = 5000,
            CurrencyIsoCode = 'USD',
            Payment_Status__c = 'open'
        );
        insert testInvoice;

        // Create test Stripe Invoice Line Items
        List<Stripe_Invoice_Line_Item__c> invoiceItems = new List<Stripe_Invoice_Line_Item__c>();
        invoiceItems.add(
            new Stripe_Invoice_Line_Item__c(
                Name = 'Test Invoice Item 1',
                Stripe_Invoice_line_Item_Id__c = 'ii_test1',
                Stripe_Invoice__c = testInvoice.Id,
                Unit_Price__c = 2000,
                CurrencyIsoCode = 'USD'
            )
        );
        invoiceItems.add(
            new Stripe_Invoice_Line_Item__c(
                Name = 'Test Invoice Item 2',
                Stripe_Invoice_line_Item_Id__c = 'ii_test2',
                Stripe_Invoice__c = testInvoice.Id,
                Unit_Price__c = 3000,
                CurrencyIsoCode = 'USD'
            )
        );
        insert invoiceItems;
    }

    @IsTest
    static void testStripeDeleteInvoiceItemsQueueable() {
        // Prepare test data
        String stripeInvoiceId = 'in_test123';
        List<String> deletedItemIds = new List<String>{ 'ii_test1', 'ii_test2' };
        Test.startTest();
        // Enqueue the Queueable class
        StripeDeleteInvoiceItemsQueueable queueableJob = new StripeDeleteInvoiceItemsQueueable(
            stripeInvoiceId,
            deletedItemIds
        );
        System.enqueueJob(queueableJob);
        Test.stopTest();
        // Verify the results
        List<Stripe_Invoice_Line_Item__c> deletedItems = [
            SELECT Id
            FROM Stripe_Invoice_Line_Item__c
            WHERE Stripe_Invoice_line_Item_Id__c IN :deletedItemIds
        ];
        System.assertEquals(0, deletedItems.size(), 'Invoice items should be deleted');
    }
    
    @IsTest
    static void testStripeDeleteInvoiceItemsWithoutParentInvoice() {
        // Prepare test data with non-existing invoice ID
        String stripeInvoiceId = 'in_nonexistent';
        List<String> deletedItemIds = new List<String>{ 'ii_test1', 'ii_test2' };
        Test.startTest();
        // Enqueue the Queueable class
        StripeDeleteInvoiceItemsQueueable queueableJob = new StripeDeleteInvoiceItemsQueueable(
            stripeInvoiceId,
            deletedItemIds
        );
        System.enqueueJob(queueableJob);
        Test.stopTest();
        // Since the parent invoice does not exist, no deletion should occur
        List<Stripe_Invoice_Line_Item__c> remainingItems = [
            SELECT Id
            FROM Stripe_Invoice_Line_Item__c
            WHERE Stripe_Invoice_line_Item_Id__c IN :deletedItemIds
        ];
        System.assertEquals(2, remainingItems.size(), 'No invoice items should be deleted');
    }
}