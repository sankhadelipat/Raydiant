trigger StripeCustomerSyncTrigger on Account(after insert, after update) {
    if (StripeTriggerHandler.isBypassEnabled('Account')) {
        return;
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            System.enqueueJob(new StripeCustomerSyncQueueable('CREATE', Trigger.newMap.keySet()));
        } else if (Trigger.isUpdate) {
            StripeCustomerSyncHandler.syncCustomers(Trigger.newMap, Trigger.oldMap);
        }
        // else if (Trigger.isDelete) {
        //     System.enqueueJob(new StripeCustomerSyncQueueable('DELETE', Trigger.oldMap.keySet()));
        // }
    }
}
