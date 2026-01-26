trigger StripeIntentConsumer on Stripe_Capture_Intent__e(after insert) {
    for (Stripe_Capture_Intent__e evt : Trigger.New) {
        System.enqueueJob(new StripePaymentIntentQueueable(evt.Stripe_Invoice_ID__c), 5);
    }
}