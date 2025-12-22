trigger SubscriptionItemUpdateTrigger on SBQQ__Subscription__c(after update) {
    if (StripeTriggerHandler.isBypassEnabled('SBQQ__Subscription__c')) {
        return;
    }

    List<SBQQ__Subscription__c> subscriptionItemsToUpdate = new List<SBQQ__Subscription__c>();

    for (SBQQ__Subscription__c sub : Trigger.new) {
        SBQQ__Subscription__c oldSub = Trigger.oldMap.get(sub.Id);

        if (sub.Status__c == oldSub.Status__c) {
            continue;
        }

        // Only process subscriptions linked to Stripe
        if (sub.Stripe_Subscription_ID__c != null) {
            subscriptionItemsToUpdate.add(sub);
        }
    }

    if (!subscriptionItemsToUpdate.isEmpty()) {
        StripeSubscriptionItemUpdater.handleStatusChanges(subscriptionItemsToUpdate, Trigger.oldMap);
    }
}