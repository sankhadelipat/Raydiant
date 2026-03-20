trigger StripeScheduleDeletionConsumer on Stripe_Capture_Schedule_Deletion__e(after insert) {
    for (Stripe_Capture_Schedule_Deletion__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeSubscriptionScheduleId__c)) {
            StripeSubscriptionHandler.deleteSchedule(evt.StripeSubscriptionScheduleId__c);
        }
    }
}