trigger StripePromotionConsumer on Stripe_Capture_Subscription_Promotion__e(after insert) {
    for (Stripe_Capture_Subscription_Promotion__e event : Trigger.New) {
        System.enqueueJob(
            new StripeSubscriptionPromotion(event.Stripe_Subscription_Id__c, event.Stripe_Customer_Id__c),
            3
        );
    }
}