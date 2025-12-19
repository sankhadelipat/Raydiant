trigger StripeTransactionConsumer on Stripe_Capture_Transaction__e (after insert) {
    for (Stripe_Capture_Transaction__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripePaymentIntentId__c) && String.isNotBlank(evt.CustomerId__c)) {
            System.enqueueJob(new StripeTransactionQueueable(evt.StripePaymentIntentId__c, evt.QuoteId__c, evt.CustomerId__c));
            System.debug('Triggering...');
        }
    }
}