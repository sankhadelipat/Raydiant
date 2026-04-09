trigger StripeInvoicePreviewConsumer on Stripe_Capture_Invoice_Preview__e(after insert) {
    for (Stripe_Capture_Invoice_Preview__e evt : Trigger.New) {
        System.enqueueJob(new StripeInvoicePreview(evt.StripeId__c, evt.PreviewType__c), 1);
    }
}