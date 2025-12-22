trigger SubscriptionUpdateTrigger on Contract(after update) {
    if (StripeTriggerHandler.isBypassEnabled('Contract')) {
        return;
    }

    List<Contract> scheduleContracts = new List<Contract>();
    List<Contract> subscriptionContracts = new List<Contract>();

    for (Contract con : Trigger.new) {
        Contract oldCon = Trigger.oldMap.get(con.Id);

        if (con.Status == oldCon.Status) {
            continue;
        }

        // Pending contract - schedule logic
        if (con.Stripe_Subscription_Schedule_ID__c != null && con.Stripe_Subscription_ID__c == null) {
            scheduleContracts.add(con);
        }

        // Active contract - subscription logic
        if (con.Stripe_Subscription_Id__c != null) {
            subscriptionContracts.add(con);
        }
    }

    if (!scheduleContracts.isEmpty()) {
        StripeScheduleUpdater.handleStatusChanges(scheduleContracts, Trigger.oldMap);
    }

    if (!subscriptionContracts.isEmpty()) {
        StripeSubscriptionUpdater.handleStatusChanges(subscriptionContracts, Trigger.oldMap);
    }
}