trigger StripeRefundConsumer on Stripe_Capture_Refund__e(after insert) {
    for (Stripe_Capture_Refund__e evt : Trigger.New) {
        System.enqueueJob(new StripeRefundProcessorQueueable(evt.StripePaymentIntentId__c, evt.RefundedAmount__c), 1);
    }
}