trigger StripeWebhookSubscriptionConsumer on Stripe_Capture_Subscription__e(after insert) {
    for (Stripe_Capture_Subscription__e evt : Trigger.New) {
        if (String.isNotBlank(evt.Latest_invoiceId__c)) {
            System.enqueueJob(
                new StripeInvoiceScheduler(
                    evt.Latest_invoiceId__c,
                    evt.StripeSubscriptionId__c,
                    evt.Salesforce_Quote_Id__c,
                    evt.Subscription_Schedule__c
                )
            );
        }
        //always For Subscrition Create from stripe (schedule subscription) & for Updated subscription from stripe
        StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe(
            evt.Salesforce_Quote_Id__c,
            evt.StripeSubscriptionId__c,
            evt.Subscription_Source__c
        );
    }
}
