public class StripeInvoicePreview implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    public enum PreviewType {
        SUBSCRIPTION,
        SUBSCRIPTION_SCHEDULE
    }

    private String stripeId;
    private PreviewType previewType;

    public StripeInvoicePreview(String stripeId, PreviewType previewType) {
        this.stripeId = stripeId;
        this.previewType = previewType;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/invoices/create_preview');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            if (previewType == StripeInvoicePreview.PreviewType.SUBSCRIPTION) {
                req.setBody('subscription=' + EncodingUtil.urlEncode(stripeId, 'UTF-8'));
            } else if (previewType == StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE) {
                req.setBody('schedule=' + EncodingUtil.urlEncode(stripeId, 'UTF-8'));
            }

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getstatusCode() == 200) {
                Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                handlePreviewResponse(preview);
            } else if (res.getstatusCode() == 404) {
                System.debug('No upcoming invoice preview for Stripe ID: ' + stripeId);
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

    private void handlePreviewResponse(Map<String, Object> preview) {
        Decimal nextBillingAmount = ((Decimal) preview.get('amount_due')) / 100;
        Long nextBillingTimestamp = (Long) preview.get('created');
        Date nextBillingDate = DateTime.newInstance(nextBillingTimestamp * 1000).date();
        System.debug('Next Billing Date: ' + nextBillingDate);

        List<Contract> contracts;

        if (previewType == StripeInvoicePreview.PreviewType.SUBSCRIPTION) {
            contracts = [
                SELECT Id, Next_Billing_Date__c, Next_Billing_Amount__c
                FROM Contract
                WHERE Stripe_Subscription_ID__c = :stripeId
                LIMIT 1
            ];
        } else if (previewType == StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE) {
            contracts = [
                SELECT Id, Next_Billing_Date__c, Next_Billing_Amount__c
                FROM Contract
                WHERE Stripe_Subscription_Schedule_ID__c = :stripeId
                LIMIT 1
            ];
        }

        if (!contracts.isEmpty()) {
            Contract contractToUpdate = contracts[0];
            contractToUpdate.Next_Billing_Amount__c = nextBillingAmount;
            contractToUpdate.Next_Billing_Date__c = nextBillingDate;
            update contractToUpdate;

            System.debug(
                'Updated Contract ' +
                    contractToUpdate.Id +
                    ' | Next Billing Date=' +
                    nextBillingDate +
                    ' | Amount=' +
                    nextBillingAmount
            );
        } else {
            System.debug('No Contract found for Stripe ID: ' + stripeId + ' | Type=' + previewType);
        }
    }
}