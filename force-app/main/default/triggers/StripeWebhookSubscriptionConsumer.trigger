trigger StripeWebhookSubscriptionConsumer on Stripe_Capture_Subscription__e(after insert) {
    for (Stripe_Capture_Subscription__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeSubscriptionId__c)) {
            StripeSubscriptionScheduler2.handleSubscriptionFromStripe(
                evt.Salesforce_Quote_Id__c,
                evt.StripeSubscriptionId__c,
                evt.Subscription_Source__c,
                evt.Subscription_Schedule__c
            );
        }

        if (evt.Event_Type__c == 'customer.subscription.created') {
            System.enqueueJob(
                new StripeSubscriptionMetadataUpdater(evt.StripeSubscriptionId__c, evt.Subscription_Source__c),
                2
            );
        }
    }
}