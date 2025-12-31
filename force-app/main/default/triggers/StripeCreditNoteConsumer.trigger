trigger StripeCreditNoteConsumer on Stripe_Capture_Credit_Note__e(after insert) {
    for (Stripe_Capture_Credit_Note__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeInvoiceId__c) && String.isNotBlank(evt.CustomerId__c)) {
            System.enqueueJob(new StripeCreditNoteQueueable(evt.StripeCreditNoteId__c, evt.StripeInvoiceId__c));
        }
    }
}