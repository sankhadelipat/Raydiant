trigger StripeSubscriptionDeletionConsumer on Stripe_Capture_Subscription_Deletion__e(after insert) {
    for (Stripe_Capture_Subscription_Deletion__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeSubscriptionId__c)) {
            StripeSubscriptionScheduler.deleteSubscription(evt.StripeSubscriptionId__c);
        }
    }
}
