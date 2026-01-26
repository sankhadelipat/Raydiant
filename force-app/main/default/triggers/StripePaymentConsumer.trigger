trigger StripePaymentConsumer on Stripe_Capture_Payment__e(after insert) {
    for (Stripe_Capture_Payment__e evt : Trigger.New) {
        System.enqueueJob(new StripeCheckoutSessionService(evt.CheckoutSessionId__c));

        if (evt.StripeSubscriptionId__c != null) {
            System.enqueueJob(
                new StripeSubscriptionScheduler2.PostCheckoutSubscriptionHandler(
                    evt.SalesforceQuoteId__c,
                    evt.StripeSubscriptionId__c
                ),
                2
            );
        }

        if (evt.SalesforceQuoteId__c != null) {
            Map<String, Object> flowInputs = new Map<String, Object>{ 'quoteId' => evt.SalesforceQuoteId__c };

            Flow.Interview.Checkout_Session_Accept_Quote_Close_Won_Opp flow = new Flow.Interview.Checkout_Session_Accept_Quote_Close_Won_Opp(
                flowInputs
            );

            flow.start();
        }
    }
}