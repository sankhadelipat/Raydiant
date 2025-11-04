public class StripeSubscriptionItemUpdater {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    //Subscription Update  & Cancell
    // Trigger handler method
    public static void handleStatusChanges(List<SBQQ__Subscription__c> newSubs, Map<Id, SBQQ__Subscription__c> oldMap) {
        boolean isPriceChange;
        // First get all parent Contract IDs
        Set<Id> contractIds = new Set<Id>();
        for (SBQQ__Subscription__c sub : newSubs) {
            if (sub.SBQQ__Contract__c != null) {
                contractIds.add(sub.SBQQ__Contract__c);
            }
        }
        System.debug('Contract IDs: ' + contractIds);

        // Query Contracts with their active subscription count
        Map<Id, Contract> contractsWithSubCounts = new Map<Id, Contract>(
            [
                SELECT Id, (SELECT Id FROM SBQQ__Subscriptions__r WHERE Status__c != 'Cancelled')
                FROM Contract
                WHERE Id IN :contractIds
            ]
        );
        System.debug('Contracts with active subscriptions: ' + contractsWithSubCounts);
        map<id, SBQQ__Subscription__c> oldMapSubs = new Map<id, SBQQ__Subscription__c>();
        List<SBQQ__Subscription__c> subsToUpdate = new List<SBQQ__Subscription__c>();
        List<SBQQ__Subscription__c> subsToCancel = new List<SBQQ__Subscription__c>();
        List<SBQQ__Subscription__c> invalidCancellations = new List<SBQQ__Subscription__c>();

        // Identify subscriptions that need processing
        for (SBQQ__Subscription__c newSub : newSubs) {
            SBQQ__Subscription__c oldSub = oldMap.get(newSub.Id);
            oldMapSubs.put(oldSub.id, oldSub);

            if (oldSub.Status__c != newSub.Status__c) {
                if (newSub.Status__c == 'Updated') {
                    subsToUpdate.add(newSub);
                } else if (newSub.Status__c == 'canceled' && newSub.Canceled_From_Stripe__c != true) {
                    // Check if this is the only subscription under the Contract
                    Integer activeSubCount = contractsWithSubCounts.get(newSub.SBQQ__Contract__c)
                        ?.SBQQ__Subscriptions__r
                        ?.size() ?? 0;

                    if (activeSubCount > 0) {
                        subsToCancel.add(newSub);
                    } else {
                        invalidCancellations.add(newSub);
                        newSub.addError(
                            'Cannot cancel the only subscription under this Contract. Cancel the entire Contract instead.'
                        );
                    }
                }
            }
        }

        // Process updates asynchronously
        if (!subsToUpdate.isEmpty()) {
            System.enqueueJob(new StripeUpdateQueueable(subsToUpdate, oldMapSubs));
        }

        // Process cancellations immediately
        if (!subsToCancel.isEmpty()) {
            System.enqueueJob(new StripeCancelQueueable(subsToCancel));
        }
    }

    // Queueable class for async processing of updates
    public class StripeUpdateQueueable implements System.Queueable, Database.AllowsCallouts {
        private List<SBQQ__Subscription__c> subscriptions;
        private Map<id, SBQQ__Subscription__c> oldsubscriptions;
        public StripeUpdateQueueable(
            List<SBQQ__Subscription__c> subscriptions,
            Map<Id, SBQQ__Subscription__c> oldsubscriptions
        ) {
            this.subscriptions = subscriptions;
            this.oldsubscriptions = oldsubscriptions;
        }

        public void execute(QueueableContext context) {
            updateSubscriptionItems(subscriptions, oldsubscriptions);
        }
    }

    // Queueable class for async processing of cancellations
    public class StripeCancelQueueable implements System.Queueable, Database.AllowsCallouts {
        private List<SBQQ__Subscription__c> subscriptions;

        public StripeCancelQueueable(List<SBQQ__Subscription__c> subscriptions) {
            this.subscriptions = subscriptions;
        }

        public void execute(QueueableContext context) {
            processCancellations(subscriptions);
        }
    }

    // Main method for updating subscription items
    @TestVisible
    private static void updateSubscriptionItems(
        List<SBQQ__Subscription__c> subscriptions,
        Map<Id, SBQQ__Subscription__c> oldMapsub
    ) {
        Http http = new Http();
        List<SBQQ__Subscription__c> subsToUpdate = new List<SBQQ__Subscription__c>();

        for (SBQQ__Subscription__c sub : subscriptions) {
            try {
                String newPriceId = sub.Stripe_Price_ID__c;
                SBQQ__Subscription__c oldSub = oldMapsub.get(Sub.Id);
                //if(oldSub.SBQQ__NetPrice__c != Sub.SBQQ__NetPrice__c)
                //  {
                system.debug('Price Change');
                newPriceId = createStripePrice(sub.id, sub.Stripe_Product_ID__c, sub.SBQQ__NetPrice__c);

                // }

                // Now updating the subscription item
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscription_items/' + sub.Stripe_Subscription_ID__c);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                // Build the request body
                Map<String, String> params = new Map<String, String>{
                    'quantity' => String.valueOf(Math.round(sub.SBQQ__Quantity__c)),
                    'price' => newPriceId,
                    'proration_behavior' => 'always_invoice',
                    'payment_behavior' => 'default_incomplete'
                };
                params.put('metadata[last_updated_from_Salesforce]', 'true');
                req.setBody(encodeParameters(params));
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    System.debug('Subscription item updated successfully: ' + sub.Stripe_Subscription_ID__c);

                    subsToUpdate.add(
                        new SBQQ__Subscription__c(
                            Id = sub.Id,
                            Status__c = 'active',
                            Stripe_Price_ID__c = newPriceId
                            //  Latest_Change_Reason__c = 'FROM STRIPE'
                        )
                    );
                } else {
                    System.debug('Error updating subscription item: ' + res.getBody());
                    throw new CalloutException('Failed to update subscription item: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Error updating subscription: ' + e.getMessage());
                Logger__c logger = new Logger__c(
                    Name = 'Stripe Subscription Update Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeSubscriptionItemUpdater',
                    Apex_Method__c = 'updateSubscriptionItems',
                    Object_Name__c = 'SBQQ__Subscription__c',
                    User_Email__c = UserInfo.getUserEmail()
                );
                insert logger;
            }
        }

        // Update all subscriptions with results
        if (!subsToUpdate.isEmpty()) {
            Database.update(subsToUpdate, false); // Allow partial success
        }
    }

    // Method for processing cancellations
    @TestVisible
    private static void processCancellations(List<SBQQ__Subscription__c> subscriptions) {
        Http http = new Http();
        List<SBQQ__Subscription__c> subsToUpdate = new List<SBQQ__Subscription__c>();

        for (SBQQ__Subscription__c sub : subscriptions) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscription_items/' + sub.Stripe_Subscription_ID__c);
                req.setMethod('DELETE');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                    System.debug('Subscription item cancelled successfully: ' + sub.Stripe_Subscription_ID__c);

                    subsToUpdate.add(
                        new SBQQ__Subscription__c(Id = sub.Id, Status__c = 'Cancelled', Stripe_Activate__c = false)
                    );
                } else {
                    System.debug('Error cancelling subscription: ' + res.getBody());
                    throw new CalloutException('Failed to cancel subscription item: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Error cancelling subscription: ' + e.getMessage());
                Logger__c logger = new Logger__c(
                    Name = 'Stripe Subscription Cancellation Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeSubscriptionItemUpdater',
                    Apex_Method__c = 'processCancellations',
                    Object_Name__c = 'SBQQ__Subscription__c',
                    User_Email__c = UserInfo.getUserEmail()
                );
                insert logger;
            }
        }

        // Update all cancelled subscriptions
        if (!subsToUpdate.isEmpty()) {
            Database.update(subsToUpdate, false); // Allow partial success
        }
    }

    // Helper method to create Stripe price
    private static String createStripePrice(id subid, String productId, Decimal amount) {
        SBQQ__Subscription__c subs = [
            SELECT
                id,
                Stripe_Subscription_Term__c,
                Billing_Frequency_Override__c,
                SBQQ__Contract__r.SBQQ__Quote__r.Billing_Frequency_Override__c
            FROM SBQQ__Subscription__c
            WHERE id = :subid
        ];

        string interval;
        INTEGER intervalCount;
        if (subs.SBQQ__Contract__r.SBQQ__Quote__r.Billing_Frequency_Override__c != null) {
            SYSTEM.debug(
                'subs.SBQQ__Contract__r.SBQQ__Quote__r.Billing_Frequency_Override__c' +
                subs.SBQQ__Contract__r.SBQQ__Quote__r.Billing_Frequency_Override__c
            );
            String freq = subs.SBQQ__Contract__r.SBQQ__Quote__r.Billing_Frequency_Override__c; //subs.Billing_Frequency_Override__c.toLowerCase();
            if (freq == 'monthly') {
                interval = 'month';
                intervalCount = 1;
            } else if (freq == 'quarterly') {
                interval = 'month';
                intervalCount = 3;
            } else if (freq == 'yearly') {
                interval = 'year';
                intervalCount = 1;
            } else {
                // Fallback default
                interval = 'month';
                intervalCount = 1;
            }
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // Convert amount to cents
        Integer unitAmount = (amount * 100).intValue();

        req.setEndpoint('https://api.stripe.com/v1/prices');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Build the request body
        Map<String, String> params = new Map<String, String>{
            'billing_scheme' => 'per_unit',
            'unit_amount' => String.valueOf(unitAmount),
            'currency' => 'usd',
            'product' => productId,
            'recurring[interval]' => interval,
            'recurring[interval_count]' => string.valueof(intervalCount),
            'active' => 'true'
        };
        req.setBody(encodeParameters(params));

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) response.get('id');
        } else {
            System.debug('Error creating Stripe price: ' + res.getBody());
            throw new CalloutException('Failed to create Stripe price: ' + res.getBody());
        }
    }

    // Helper method to encode parameters for Stripe API
    private static String encodeParameters(Map<String, String> params) {
        List<String> encodedParams = new List<String>();
        for (String key : params.keySet()) {
            if (params.get(key) != null) {
                encodedParams.add(
                    EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8')
                );
            }
        }
        return String.join(encodedParams, '&');
    }
}