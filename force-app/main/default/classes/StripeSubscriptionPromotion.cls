public class StripeSubscriptionPromotion implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private String subscriptionId;
    private String customerId;

    public StripeSubscriptionPromotion(String subscriptionId, String customerId) {
        this.subscriptionId = subscriptionId;
        this.customerId = customerId;
    }

    public void execute(QueueableContext context) {
        try {
            Boolean isEligible = isSubscriptionEligibleForPromotion(subscriptionId);

            if (isEligible) {
                Boolean hasDefaultPM = hasCustomerDefaultPaymentMethod(customerId);

                if (hasDefaultPM) {
                    HttpRequest request = new HttpRequest();
                    request.setEndpoint('https://api.stripe.com/v1/subscriptions/' + subscriptionId);
                    request.setMethod('POST');
                    request.setHeader(
                        'Authorization',
                        'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                    );
                    request.setBody('collection_method=charge_automatically');

                    Http http = new Http();
                    HttpResponse response = http.send(request);

                    if (response.getStatusCode() == 200) {
                        System.debug('Subscription promoted successfully: ' + response.getBody());
                    } else {
                        System.debug('Failed to promote subscription: ' + response.getBody());
                    }
                } else {
                    System.debug('No default payment method available for customer: ' + customerId);
                }
            }
        } catch (Exception e) {
            System.debug('Error promoting subscription: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Promotion Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionPromotion',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    private static Boolean isSubscriptionEligibleForPromotion(String subscriptionId) {
        List<Contract> contracts = [
            SELECT Id, Collection_Method__c
            FROM Contract
            WHERE Stripe_Subscription_Id__c = :subscriptionId AND Status != 'Cancelled'
            LIMIT 1
        ];

        if (contracts.isEmpty()) {
            return false;
        } else {
            Contract contract = contracts[0];
            return contract.Collection_Method__c == 'send_invoice';
        }
    }

    // private static Boolean hasPaymentMethod(String customerId) {
    //     HttpRequest request = new HttpRequest();
    //     request.setEndpoint('https://api.stripe.com/v1/customers/' + customerId + '/payment_methods');
    //     request.setMethod('GET');
    //     request.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

    //     Http http = new Http();
    //     HttpResponse response = http.send(request);

    //     if (response.getStatusCode() == 200) {
    //         Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    //         List<Object> paymentMethods = (List<Object>) responseBody.get('data');
    //         return !paymentMethods.isEmpty();
    //     } else {
    //         throw new CalloutException('Failed to fetch payment methods');
    //     }
    // }

    private static Boolean hasCustomerDefaultPaymentMethod(String customerId) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://api.stripe.com/v1/customers/' + customerId);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

        Http http = new Http();
        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return responseBody.containsKey('invoice_settings') &&
                ((Map<String, Object>) responseBody.get('invoice_settings')).get('default_payment_method') != null;
        } else {
            throw new CalloutException('Failed to fetch customer details');
        }
    }
}