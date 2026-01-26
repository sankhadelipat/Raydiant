trigger StripeTransactionConsumer on Stripe_Capture_Transaction__e(after insert) {
    for (Stripe_Capture_Transaction__e evt : Trigger.New) {
        System.enqueueJob(
            new StripeTransactionQueueable(
                evt.Stripe_Payment_Intent_ID__c,
                evt.Stripe_Customer_ID__c,
                evt.Salesforce_Quote_Id__c,
                evt.Event_Type__c
            ),
            2
        );
    }
}