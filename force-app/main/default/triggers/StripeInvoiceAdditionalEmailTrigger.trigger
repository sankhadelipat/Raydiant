trigger StripeInvoiceAdditionalEmailTrigger on Stripe_Invoice__c(after insert) {
    Set<Id> invoiceIds = new Set<Id>();

    for (Stripe_Invoice__c inv : Trigger.New) {
        if (inv.Account__c != null && inv.Status__c == 'Open' && inv.Invoice_PDF_URL__c != null) {
            invoiceIds.add(inv.Id);
        }
    }

    if (!invoiceIds.isEmpty()) {
        Database.executeBatch(new StripeInvoiceAdditionalEmailBatch(invoiceIds), 10);
    }
}