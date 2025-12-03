trigger StripeInvoiceConsumer on Stripe_Capture_Invoice__e(after insert) {
    for (Stripe_Capture_Invoice__e evt : Trigger.New) {
        if (String.isNotBlank(evt.Stripe_Invoice_ID__c)) {
            System.enqueueJob(
                new StripeInvoiceCreateQueueable(
                    evt.Stripe_Invoice_ID__c,
                    evt.Stripe_Subscription_ID__c,
                    evt.Quote_ID_From_Stripe__c
                )
            );
        }
    }
}
