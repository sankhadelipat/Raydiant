trigger StripeWebhookSubscriptionConsumer on Stripe_Capture_Subscription__e(after insert) {
    for (Stripe_Capture_Subscription__e evt : Trigger.New) {
        if (String.isNotBlank(evt.StripeSubscriptionId__c)) {
            StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe(
                evt.Salesforce_Quote_Id__c,
                evt.StripeSubscriptionId__c,
                evt.Subscription_Source__c
            );
        }

        if (String.isNotBlank(evt.Latest_invoiceId__c)) {
            System.enqueueJob(
                new StripeInvoiceCreateQueueable(
                    evt.Latest_invoiceId__c,
                    evt.StripeSubscriptionId__c,
                    evt.Salesforce_Quote_Id__c
                ),
                1
            );
        }

        if (evt.Event_Type__c == 'customer.subscription.created') {
            System.enqueueJob(
                new StripeSubscriptionMetadataUpdater(evt.StripeSubscriptionId__c, evt.Subscription_Source__c),
                2
            );
        }
    }
}
