trigger SubscriptionUpdateTrigger on Contract (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        StripeSubscriptionUpdater.handleStatusChanges(Trigger.new, Trigger.oldMap);
    }
}