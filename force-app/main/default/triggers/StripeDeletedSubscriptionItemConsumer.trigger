trigger StripeDeletedSubscriptionItemConsumer on Stripe_Capture_Deleted_Subscription_Item__e(after insert) {
    // Group events by Subscription ID
    Map<String, List<String>> subscriptionToDeletedItemIds = new Map<String, List<String>>();

    for (Stripe_Capture_Deleted_Subscription_Item__e event : Trigger.New) {
        String subscriptionId = event.Stripe_Subscription_ID__c;
        String deletedItemId = event.Deleted_Subscription_Item_ID__c;

        if (String.isNotBlank(subscriptionId) && String.isNotBlank(deletedItemId)) {
            if (!subscriptionToDeletedItemIds.containsKey(subscriptionId)) {
                subscriptionToDeletedItemIds.put(subscriptionId, new List<String>());
            }
            subscriptionToDeletedItemIds.get(subscriptionId).add(deletedItemId);
        }
    }

    // Process deletions for each subscription
    for (String subscriptionId : subscriptionToDeletedItemIds.keySet()) {
        List<String> deletedItemIds = subscriptionToDeletedItemIds.get(subscriptionId);
        System.enqueueJob(new StripeDeleteSubscriptionItemsQueueable(subscriptionId, deletedItemIds));
    }
}
