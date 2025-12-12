public class StripeInvoicePreview implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String subscriptionId;

    public StripeInvoicePreview(String subscriptionId) {
        this.subscriptionId = subscriptionId;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/invoices/create_preview');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('subscription=' + EncodingUtil.urlEncode(subscriptionId, 'UTF-8'));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getstatusCode() == 200) {
                Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                Long nextBillingTimestamp;

                if (preview.containsKey('next_payment_attempt') && preview.get('next_payment_attempt') != null) {
                    nextBillingTimestamp = (Long) preview.get('next_payment_attempt');
                } else if (preview.containsKey('created') && preview.get('created') != null) {
                    nextBillingTimestamp = (Long) preview.get('created');
                } else if (preview.containsKey('period_end') && preview.get('period_end') != null) {
                    nextBillingTimestamp = (Long) preview.get('period_end');
                } else {
                    System.debug('No next billing date found in preview response.');
                    return;
                }

                Date nextBillingDate = DateTime.newInstance(nextBillingTimestamp * 1000).date();
                System.debug('Next Billing Date: ' + nextBillingDate);

                List<Contract> contracts = [
                    SELECT Id, Next_Billing_Date__c
                    FROM Contract
                    WHERE Stripe_Subscription_ID__c = :subscriptionId
                    LIMIT 1
                ];

                if (!contracts.isEmpty()) {
                    Contract contractToUpdate = contracts[0];
                    contractToUpdate.Next_Billing_Date__c = nextBillingDate;
                    update contractToUpdate;
                    System.debug(
                        'Updated Contract Id: ' + contractToUpdate.Id + ' with Next Billing Date: ' + nextBillingDate
                    );
                } else {
                    System.debug('No Contract found with Subscription ID: ' + subscriptionId);
                }
            } else if (res.getstatusCode() == 404) {
                System.debug('No upcoming invoices for subscription: ' + subscriptionId);
            } else {
                System.debug('Failed to create invoice preview: ' + res.getBody());
                throw new CalloutException('Stripe API error: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error during invoice preview creation: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Preview Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoicePreview',
                Apex_Method__c = 'updateNextBillingDate',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }
}