trigger StripePaymentMethodConsumer on Stripe_Capture_Payment_Method__e(after insert) {
    for (Stripe_Capture_Payment_Method__e evt : Trigger.New) {
        System.enqueueJob(new StripePaymentMethodQueueable(evt.StripePaymentMethodId__c), 1);
    }
}