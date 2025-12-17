trigger StripeSubSchedConsumer on Stripe_Capture_Subscription_Schedule__e(after insert) {
    for (Stripe_Capture_Subscription_Schedule__e evt : Trigger.New) {
        StripeSubscriptionScheduler2.handleScheduleFromStripe(
            evt.Salesforce_Quote_Id__c,
            evt.StripeSubscriptionScheduleId__c,
            evt.Subscription_Source__c
        );
    }
}