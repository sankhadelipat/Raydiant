trigger StripeCustomerConsumer on Stripe_Capture_Customer__e(after insert) {
    for (Stripe_Capture_Customer__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeCustomerId__c)) {
            System.enqueueJob(
                new StripeCustomerQueueable(evt.StripeCustomerId__c, evt.Raydiant_Signup_Type__c, evt.Event_Type__c)
            );
        }
    }
}