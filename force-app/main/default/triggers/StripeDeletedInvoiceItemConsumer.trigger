trigger StripeDeletedInvoiceItemConsumer on Stripe_Capture_Deleted_Invoice_Item__e(after insert) {
    // Group events by Invoice ID
    Map<String, List<String>> invoiceToDeletedItemIds = new Map<String, List<String>>();

    for (Stripe_Capture_Deleted_Invoice_Item__e event : Trigger.New) {
        String invoiceId = event.Stripe_Invoice_ID__c;
        String deletedItemId = event.Deleted_Invoice_Item_ID__c;

        if (String.isNotBlank(invoiceId) && String.isNotBlank(deletedItemId)) {
            if (!invoiceToDeletedItemIds.containsKey(invoiceId)) {
                invoiceToDeletedItemIds.put(invoiceId, new List<String>());
            }
            invoiceToDeletedItemIds.get(invoiceId).add(deletedItemId);
        }
    }

    // Process deletions for each invoice
    for (String invoiceId : invoiceToDeletedItemIds.keySet()) {
        List<String> deletedItemIds = invoiceToDeletedItemIds.get(invoiceId);
        System.enqueueJob(new StripeDeleteInvoiceItemsQueueable(invoiceId, deletedItemIds));
    }
}