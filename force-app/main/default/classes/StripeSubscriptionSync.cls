public with sharing class StripeSubscriptionSync {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    // -------- Flow Input --------
    public class FlowInput {
        @InvocableVariable(required=true)
        public Id contractId;
    }

    // -------- Flow Result --------
    public class FlowResult {
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String message;
    }

    @InvocableMethod(
        callout=true
        label='Sync Stripe Subscriptions to Salesforce'
        description='Sync Stripe Subscriptions to Salesforce Contracts and SBQQ__Subscription__c records'
        category='Stripe'
    )
    public static List<FlowResult> syncContract(List<FlowInput> inputs) {
        FlowResult result = new FlowResult();
        List<FlowResult> results = new List<FlowResult>{ result };

        try {
            Contract con = [
                SELECT Id, Stripe_Subscription_ID__c, Stripe_Subscription_Schedule_ID__c, SBQQ__Quote__c
                FROM Contract
                WHERE Id = :inputs[0].contractId
                LIMIT 1
            ];

            Http http = new Http();

            if (con.Stripe_Subscription_ID__c != null) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + con.Stripe_Subscription_ID__c);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    System.debug('subResponse---' + subResponse);

                    String status = (String) subResponse.get('status');

                    if (status == 'canceled') {
                        StripeSubscriptionHandler.deleteSubscription(con.Stripe_Subscription_ID__c);
                    } else {
                        System.enqueueJob(new StripeSubscriptionQueueable(res.getBody(), con.SBQQ__Quote__c));
                    }
                } else {
                    throw new CalloutException('Failed subscription sync: ' + res.getStatusCode());
                }
            } else if (con.Stripe_Subscription_Schedule_ID__c != null) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(
                    'https://api.stripe.com/v1/subscription_schedules/' +
                        con.Stripe_Subscription_Schedule_ID__c +
                        '?expand[]=phases.items.price'
                );
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    System.debug('subResponse---' + subResponse);

                    String status = (String) subResponse.get('status');

                    if (status == 'canceled') {
                        StripeSubscriptionHandler.deleteSchedule(con.Stripe_Subscription_Schedule_ID__c);
                    } else {
                        System.enqueueJob(new StripeScheduleQueueable(res.getBody(), con.SBQQ__Quote__c));
                    }
                } else {
                    throw new CalloutException('Failed subscription schedule sync: ' + res.getStatusCode());
                }
            } else {
                throw new HandledException('No Stripe Subscription or Subscription Schedule ID found on the Contract.');
            }

            result.isSuccess = true;
            result.message = 'Subscription sync started ...';
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
        }

        return results;
    }
}