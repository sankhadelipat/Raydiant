trigger SubscriptionItemUpdateTrigger on SBQQ__Subscription__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        StripeSubscriptionItemUpdater.handleStatusChanges(Trigger.new, Trigger.oldMap);
    }
}