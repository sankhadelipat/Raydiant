public class StripeSubscriptionHandler {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    @future(callout=true)
    public static void handleSubscriptionFromStripe(
        String quoteId,
        String subcriptionId,
        String subscriptionSource,
        Boolean isSchedule
    ) {
        HttpRequest subReq = new HttpRequest();
        subReq.setEndpoint('https://api.stripe.com/v1/subscriptions/' + subcriptionId);
        subReq.setMethod('GET');
        subReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
        subReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        Http http = new Http();
        HttpResponse subRes = http.send(subReq);

        if (subRes.getStatusCode() == 200) {
            Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(subRes.getBody());
            System.debug('subResponse---' + subResponse);

            String subSchedId = (String) (subResponse.containsKey('schedule') ? subResponse.get('schedule') : null);
            System.debug('subSchedId---' + subSchedId);

            if ((isSchedule && subSchedId != null) || subSchedId != null) {
                Contract existingContract;

                List<Contract> pending = [
                    SELECT Id, Stripe_Subscription_ID__c
                    FROM Contract
                    WHERE
                        Stripe_Subscription_Schedule_ID__c = :subSchedId
                        AND Stripe_Subscription_ID__c = NULL
                        AND Status = 'Pending'
                    LIMIT 1
                ];

                if (!pending.isEmpty()) {
                    existingContract = pending[0];
                    existingContract.Stripe_Subscription_ID__c = subcriptionId;
                    
                    StripeTriggerHandler.enableBypass('Contract');
                    update existingContract;
                    StripeTriggerHandler.disableBypass('Contract');

                    // Delete All SBQQ_Subscription__c records related to this contract
                    List<SBQQ__Subscription__c> subsToDelete = [
                        SELECT Id
                        FROM SBQQ__Subscription__c
                        WHERE SBQQ__Contract__c = :existingContract.Id AND Stripe_Subscription_ID__c = NULL
                    ];

                    if (!subsToDelete.isEmpty()) {
                        StripeTriggerHandler.enableBypass('SBQQ__Subscription__c');
                        delete subsToDelete;
                        StripeTriggerHandler.disableBypass('SBQQ__Subscription__c');
                        
                        System.debug('Deleted ' + subsToDelete.size() + ' SBQQ__Subscription__c records.');
                    }
                }
            }

            // Upsert Subscription record
            if (subscriptionSource == 'amazon' || subscriptionSource == 'self_service') {
                System.enqueueJob(new StripeSubscriptionQueueable(subRes.getBody(), quoteId), 1);
            } else {
                System.enqueueJob(new StripeSubscriptionQueueable(subRes.getBody(), quoteId));
            }
        }
    }

    @future(callout=true)
    public static void handleScheduleFromStripe(
        String quoteId,
        String subcriptionScheduleId,
        String subscriptionSource
    ) {
        HttpRequest subReq = new HttpRequest();
        subReq.setEndpoint(
            'https://api.stripe.com/v1/subscription_schedules/' + subcriptionScheduleId + '?expand[]=phases.items.price'
        );
        subReq.setMethod('GET');
        subReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
        subReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        Http http = new Http();
        HttpResponse subRes = http.send(subReq);

        if (subRes.getStatusCode() == 200) {
            Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(subRes.getBody());
            System.debug('subResponse---' + subResponse);

            // Upsert Subscription record
            System.enqueueJob(new StripeScheduleQueueable(subRes.getBody(), quoteId));
        }
    }

    // Method to cancel Contract when Subscription is canceled from Stripe
    public static void deleteSubscription(String subscriptionId) {
        try {
            List<Contract> activeContracts = [
                SELECT Id
                FROM Contract
                WHERE Stripe_Subscription_ID__c = :subscriptionId AND Status = 'Activated'
            ];

            if (!activeContracts.isEmpty()) {
                // Update and cancel the Contract
                Contract updatedContract = new Contract(
                    Id = activeContracts[0].Id,
                    Stripe_Status__c = 'canceled',
                    Status = 'canceled',
                    Latest_Change_Reason__c = 'Subscription Canceled'
                );

                StripeTriggerHandler.enableBypass('Contract');
                update updatedContract;
                StripeTriggerHandler.disableBypass('Contract');
                System.debug('Updated Contract: ' + updatedContract);

                // Cancel related subscription items
                List<SBQQ__Subscription__c> subsToCancel = [
                    SELECT Id, Status__c
                    FROM SBQQ__Subscription__c
                    WHERE SBQQ__Contract__c = :updatedContract.Id
                ];

                for (SBQQ__Subscription__c sub : subsToCancel) {
                    sub.Status__c = 'canceled';
                    sub.Canceled_From_Stripe__c = true;
                    sub.Latest_Change_Reason__c = 'Subscription Item Canceled Due to Contract Cancellation';
                }

                if (!subsToCancel.isEmpty()) {
                    StripeTriggerHandler.enableBypass('SBQQ__Subscription__c');
                    update subsToCancel;
                    StripeTriggerHandler.disableBypass('SBQQ__Subscription__c');
                    
                    System.debug('Canceled ' + subsToCancel.size() + ' SBQQ__Subscription__c records');
                }
            } else {
                System.debug('No active contracts found for Stripe Subscription: ' + subscriptionId);
            }
        } catch (Exception e) {
            System.debug('Error in deleteSubscription: ' + e.getMessage());

            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Deletion Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionHandler',
                Apex_Method__c = 'deleteSubscription',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    // Method to cancel Contract when Subscription Schedule is deleted from Stripe
    public static void deleteSchedule(String scheduleId) {
        try {
            List<Contract> pendingContracts = [
                SELECT Id
                FROM Contract
                WHERE Stripe_Subscription_Schedule_ID__c = :scheduleId AND Status = 'Pending'
            ];

            if (!pendingContracts.isEmpty()) {
                // Update and cancel the Contract
                Contract updatedContract = new Contract(
                    Id = pendingContracts[0].Id,
                    Stripe_Status__c = 'canceled',
                    Status = 'canceled',
                    Latest_Change_Reason__c = 'Subscription Canceled'
                );

                StripeTriggerHandler.enableBypass('Contract');
                update updatedContract;
                StripeTriggerHandler.disableBypass('Contract');
                System.debug('Updated Contract: ' + updatedContract);

                // Cancel related subscription items
                List<SBQQ__Subscription__c> subsToCancel = [
                    SELECT Id, Status__c
                    FROM SBQQ__Subscription__c
                    WHERE SBQQ__Contract__c = :updatedContract.Id
                ];

                for (SBQQ__Subscription__c sub : subsToCancel) {
                    sub.Status__c = 'canceled';
                    sub.Canceled_From_Stripe__c = true;
                    sub.Latest_Change_Reason__c = 'Subscription Item Canceled Due to Schedule Cancellation';
                }

                if (!subsToCancel.isEmpty()) {
                    StripeTriggerHandler.enableBypass('SBQQ__Subscription__c');
                    update subsToCancel;
                    StripeTriggerHandler.disableBypass('SBQQ__Subscription__c');

                    System.debug('Canceled ' + subsToCancel.size() + ' SBQQ__Subscription__c records');
                }
            } else {
                System.debug('No pending contracts found for Stripe Schedule: ' + scheduleId);
            }
        } catch (Exception e) {
            System.debug('Error deleting pending contracts for schedule ' + scheduleId + ': ' + e.getMessage());

            insert new Logger__c(
                Name = 'Stripe Schedule Deletion Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionHandler',
                Apex_Method__c = 'deleteSchedule',
                Object_Name__c = 'Contract'
            );
        }
    }
}