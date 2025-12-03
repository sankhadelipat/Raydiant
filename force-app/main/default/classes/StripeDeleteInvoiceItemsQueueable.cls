public class StripeDeleteInvoiceItemsQueueable implements Queueable {
    private String stripeInvoiceId;
    private List<String> deletedItemIds;

    public StripeDeleteInvoiceItemsQueueable(String stripeInvoiceId, List<String> deletedItemIds) {
        this.stripeInvoiceId = stripeInvoiceId;
        this.deletedItemIds = deletedItemIds;
    }

    public void execute(QueueableContext context) {
        System.debug('Processing deletion for invoice: ' + stripeInvoiceId);
        System.debug('Items to delete: ' + deletedItemIds);

        // Find the parent invoice
        List<Stripe_Invoice__c> parentInvoices = [
            SELECT Id, Stripe_Invoice_ID__c
            FROM Stripe_Invoice__c
            WHERE Stripe_Invoice_ID__c = :stripeInvoiceId
        ];

        if (parentInvoices.isEmpty()) {
            System.debug('No parent invoice found for Stripe invoice: ' + stripeInvoiceId);
            return;
        }

        Id invoiceId = parentInvoices[0].Id;

        // Find and deactivate the child invoice items
        List<Stripe_Invoice_Line_Item__c> invoiceItemsToDelete = [
            SELECT Id, Stripe_Invoice_line_Item_Id__c, Stripe_Invoice__c
            FROM Stripe_Invoice_Line_Item__c
            WHERE Stripe_Invoice_line_Item_Id__c IN :deletedItemIds AND Stripe_Invoice__c = :invoiceId
        ];

        System.debug('Found ' + invoiceItemsToDelete.size() + ' invoice items to deactivate');

        if (!invoiceItemsToDelete.isEmpty()) {
            delete invoiceItemsToDelete;
            System.debug(
                'Successfully deleted ' + invoiceItemsToDelete.size() + ' invoice items for invoice: ' + invoiceId
            );

            // Log the deletion
            Logger__c logger = new Logger__c(
                Name = 'Invoice Items Deleted - ' + System.now(),
                Message__c = 'Deleted ' +
                    invoiceItemsToDelete.size() +
                    ' invoice items from invoice ' +
                    invoiceId +
                    '. Stripe IDs: ' +
                    String.join(deletedItemIds, ', '),
                Status__c = 'success',
                Apex_Class__c = 'StripeDeleteInvoiceItemsQueueable',
                Apex_Method__c = 'execute'
            );
            insert logger;
        }
    }
}
