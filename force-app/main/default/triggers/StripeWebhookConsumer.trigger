trigger StripeWebhookConsumer on Stripe_Capture_Payment__e(after insert) {
    for (Stripe_Capture_Payment__e evt : Trigger.New) {
        if (String.isNotBlank(evt.CheckoutSessionId__c) && evt.CheckoutSessionId__c != null) {
            StripeCheckoutSessionService.getCheckoutSession(evt.CheckoutSessionId__c);
        }
        if (String.isNotBlank(evt.Stripe_Subscription_ID__c) && evt.Stripe_Subscription_ID__c != null) {
            StripeSubscriptionScheduler2.createStripeSubscription(
                evt.Quote_Id_From_Stripe__c,
                evt.Stripe_Subscription_ID__c
            );
        }
        if (String.isNotBlank(evt.StripeInvoiceId__c) && evt.StripeInvoiceId__c != null) {
            System.enqueueJob(
                new StripeInvoiceQueueable(
                    evt.StripeInvoiceId__c,
                    evt.Stripe_Subscription_ID__c,
                    evt.Quote_Id_From_Stripe__c,
                    evt.Payment_Capture__c,
                    evt.Invoice_Capture__c
                )
            );
        }
    }
}
