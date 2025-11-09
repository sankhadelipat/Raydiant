public class StripeSubscriptionUpdater {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    public static void handleStatusChanges(List<Contract> newContracts, Map<Id, Contract> oldMap) {
        List<Contract> contractsToUpdate = new List<Contract>();
        List<Contract> contractsToCancel = new List<Contract>();

        // Identify contracts that need processing
        for (Contract newContract : newContracts) {
            Contract oldContract = oldMap.get(newContract.Id);

            if (oldContract.Status != newContract.Status && newContract.Stripe_Subscription_ID__c != null) {
                if (newContract.Status == 'Updated') {
                    contractsToUpdate.add(newContract);
                } else if (newContract.Status == 'canceled') {
                    contractsToCancel.add(newContract);
                }
            }
        }

        // Process updates asynchronously
        if (!contractsToUpdate.isEmpty()) {
            System.enqueueJob(new StripeUpdateQueueable(contractsToUpdate));
        }

        // Process cancellations immediately
        if (!contractsToCancel.isEmpty()) {
            System.enqueueJob(new StripeCancelQueueable(contractsToCancel));
        }
    }

    // Queueable class for async processing of updates
    public class StripeUpdateQueueable implements System.Queueable, Database.AllowsCallouts {
        private List<Contract> contracts;
        public StripeUpdateQueueable(List<Contract> contracts) {
            this.contracts = contracts;
        }
        public void execute(QueueableContext context) {
            updateSubscriptions(contracts);
        }
    }

    // Queueable class for async processing of cancellations
    public class StripeCancelQueueable implements System.Queueable, Database.AllowsCallouts {
        private List<Contract> contracts;
        public StripeCancelQueueable(List<Contract> contracts) {
            this.contracts = contracts;
        }
        public void execute(QueueableContext context) {
            processCancellations(contracts);
        }
    }

    @TestVisible
    private static void updateSubscriptions(List<Contract> contracts) {
        Http http = new Http();
        List<Contract> contractsToUpdate = new List<Contract>();

        for (Contract con : contracts) {
            try {
                Long endDateUnix = null;
                if (con.EndDate != null) {
                    Datetime endDt = Datetime.newInstance(con.EndDate.year(), con.EndDate.month(), con.EndDate.day());
                    endDateUnix = endDt.getTime() / 1000;
                }

                Boolean updated = false;

                // 1️⃣ Case A: If Schedule ID is already stored in Salesforce → update schedule directly
                if (String.isNotBlank(con.Stripe_Subscription_Schedule_ID__c)) {
                    updated = updateSchedule(
                        http,
                        con.Stripe_Subscription_Schedule_ID__c,
                        endDateUnix,
                        con,
                        contractsToUpdate
                    );
                }
                // 2️⃣ Case B: No schedule ID → try updating subscription
                else {
                    updated = updateSubscription(http, con, endDateUnix, contractsToUpdate);
                }

                if (!updated) {
                    throw new CalloutException('Failed to update subscription or schedule for contract: ' + con.Id);
                }
            } catch (Exception e) {
                System.debug('Error updating subscription: ' + e.getMessage());
                insert new Logger__c(
                    Name = 'Stripe Subscription Update Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeSubscriptionUpdater',
                    Apex_Method__c = 'updateSubscriptions',
                    Object_Name__c = 'Contract',
                    User_Email__c = UserInfo.getUserEmail()
                );
            }
        }

        // 🔹 Bulk update Contracts
        if (!contractsToUpdate.isEmpty()) {
            Database.update(contractsToUpdate, false); // partial success
        }
    }

    //
    // 🔹 Helper: Update Subscription directly
    //
    private static Boolean updateSubscription(
        Http http,
        Contract con,
        Long endDateUnix,
        List<Contract> contractsToUpdate
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + con.Stripe_Subscription_ID__c);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            Map<String, String> params = new Map<String, String>{
                'proration_behavior' => 'create_prorations',
                'payment_behavior' => 'default_incomplete',
                'metadata[salesforce_contract_id]' => con.Id,
                'metadata[last_updated]' => String.valueOf(System.now()),
                'metadata[last_updated_from_Salesforce]' => 'true'
            };

            if (endDateUnix != null) {
                params.put('cancel_at', String.valueOf(endDateUnix));
            }

            req.setBody(encodeParameters(params));
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                contractsToUpdate.add(new Contract(Id = con.Id, Status = 'Activated'));
                return true;
            }
        } catch (Exception e) {
            System.debug('Subscription update failed: ' + e.getMessage());
        }
        return false;
    }

    //
    // 🔹 Helper: Update Subscription Schedule
    //
    private static Boolean updateSchedule(
        Http http,
        String scheduleId,
        Long endDateUnix,
        Contract con,
        List<Contract> contractsToUpdate
    ) {
        try {
            List<SBQQ__Subscription__c> sublist = [
                SELECT id, SBQQ__Quantity__c, Stripe_Price_ID__c, SBQQ__Contract__c
                FROM SBQQ__Subscription__c
                WHERE SBQQ__Contract__c = :con.id AND Stripe_Price_ID__c != NULL
            ];

            HttpRequest schedReq = new HttpRequest();
            schedReq.setEndpoint('https://api.stripe.com/v1/subscription_schedules/' + scheduleId);
            schedReq.setMethod('POST');
            schedReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            schedReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            List<String> bodyParts = new List<String>();

            // Metadata
            bodyParts.add('metadata[salesforce_contract_id]=' + EncodingUtil.urlEncode(con.Id, 'UTF-8'));
            bodyParts.add('metadata[last_updated]=' + EncodingUtil.urlEncode(String.valueOf(System.now()), 'UTF-8'));
            bodyParts.add('metadata[last_updated_from_Salesforce]=true');

            // If you want to update end date
            if (endDateUnix != null) {
                bodyParts.add('phases[0][end_date]=' + String.valueOf(endDateUnix));
            }

            // Now add phases[0][items] from QuoteLines
            Integer index = 0;
            for (SBQQ__Subscription__c ql : sublist) {
                // Always define billing_cycle_anchor or start_date if you’re overriding
                // bodyParts.add('phases[0][billing_cycle_anchor]=automatic');

                // Add price + quantity
                bodyParts.add(
                    'phases[0][items][' + index + '][price]=' + EncodingUtil.urlEncode(ql.Stripe_Price_ID__c, 'UTF-8')
                );
                bodyParts.add(
                    'phases[0][items][' +
                        index +
                        '][quantity]=' +
                        String.valueOf(ql.SBQQ__Quantity__c.setScale(0, RoundingMode.HALF_UP))
                );
                bodyParts.add('phases[0][start_date]=' + String.valueOf(con.Stripe_Subscription_Start_Date__c));
                // bodyParts.add('phases[0][start_date]=1755858007');
                index++;
            }

            schedReq.setBody(String.join(bodyParts, '&'));
            HttpResponse schedRes = http.send(schedReq);

            if (schedRes.getStatusCode() == 200) {
                contractsToUpdate.add(
                    new Contract(Id = con.Id, Status = 'Activated', Stripe_Subscription_Schedule_ID__c = scheduleId)
                );
                return true;
            }
        } catch (Exception e) {
            System.debug('Schedule update failed: ' + e.getMessage());
        }
        return false;
    }

    // Method for processing cancellations
    @TestVisible
    private static void processCancellations(List<Contract> contracts) {
        Http http = new Http();

        for (Contract con : contracts) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + con.Stripe_Subscription_ID__c);
                req.setMethod('DELETE');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setBody('invoice_now=true'); // Immediately generate final invoice
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                    System.debug('Subscription cancelled successfully: ' + con.Stripe_Subscription_ID__c);
                } else {
                    System.debug('Error cancelling subscription: ' + res.getBody());
                    throw new CalloutException('Failed to cancel subscription: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Error cancelling subscription: ' + e.getMessage());

                Logger__c logger = new Logger__c(
                    Name = 'Stripe Subscription Cancel Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeSubscriptionUpdater',
                    Apex_Method__c = 'processCancellations',
                    Object_Name__c = 'Contract'
                );
                insert logger;
            }
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
    private static Integer calculateContractTerm(Date startDate, Date endDate) {
        return startDate.monthsBetween(endDate);
    }
    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer) unixTs);
    }
}
