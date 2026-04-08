public class StripeOutOfBandQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    List<String> paymentRecordIds;
    Stripe_Invoice__c invoice;

    public StripeOutOfBandQueueable(List<String> paymentRecordIds, Stripe_Invoice__c invoice) {
        this.paymentRecordIds = paymentRecordIds;
        this.invoice = invoice;
    }

    public void execute(QueueableContext context) {
        try {
            List<Stripe_Payment_Transaction__c> transactionsToUpsert = new List<Stripe_Payment_Transaction__c>();
            Http http = new Http();

            for (String paymentRecordId : paymentRecordIds) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/payment_records/' + paymentRecordId);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    // Extract fields
                    String description = (String) result.get('description');
                    Long createdTimestamp = (Long) result.get('created');
                    DateTime paymentDate = Datetime.newInstance(createdTimestamp * 1000);

                    // Extract total amount and currency
                    Map<String, Object> amountObj = (Map<String, Object>) result.get('amount');
                    Decimal amount = amountObj != null && amountObj.containsKey('value')
                        ? Decimal.valueOf((Integer) amountObj.get('value')) / 100
                        : 0;
                    String currencyCode = amountObj != null && amountObj.containsKey('currency')
                        ? (String) amountObj.get('currency')
                        : null;

                    // Extract amount paid
                    Map<String, Object> amountAuthorizedObj = (Map<String, Object>) result.get('amount_authorized');
                    Decimal amountAuthorized = amountAuthorizedObj != null && amountAuthorizedObj.containsKey('value')
                        ? Decimal.valueOf((Integer) amountAuthorizedObj.get('value')) / 100
                        : 0;

                    // MOCK PAYMENT INTENT RECORD
                    Stripe_Payment_Transaction__c pt = new Stripe_Payment_Transaction__c();
                    pt.Stripe_PaymentIntent_ID__c = paymentRecordId;
                    pt.Stripe_Invoice__c = invoice.Id;
                    pt.Description__c = description;
                    pt.Amount__c = amount;
                    pt.Amount_Paid__c = amountAuthorized;
                    pt.Payment_Date__c = Date.valueof(paymentDate);
                    pt.Payment_Type__c = 'out_of_band_payment';
                    pt.CurrencyIsoCode = currencyCode.toUpperCase();
                    pt.Status__c = 'Succeeded';
                    pt.Stripe_Transaction_Status__c = 'succeeded';
                    pt.Account__c = invoice.Account__c;
                    pt.Contract__c = invoice.Contract__c;
                    pt.Quote_CPQ__c = invoice.Quote_CPQ__c;

                    transactionsToUpsert.add(pt);
                } else {
                    System.debug(
                        'Failed to fetch payment record details for ID: ' +
                            paymentRecordId +
                            '. Status code: ' +
                            res.getStatusCode()
                    );

                    if (Test.isRunningTest()) {
                        throw new CalloutException(
                            'Failed to fetch payment record details for ID: ' +
                                paymentRecordId +
                                '. Status code: ' +
                                res.getStatusCode()
                        );
                    } else {
                        continue;
                    }
                }
            }

            if (!transactionsToUpsert.isEmpty()) {
                upsert transactionsToUpsert Stripe_PaymentIntent_ID__c;
            }
        } catch (Exception e) {
            System.debug('Error in StripeOutOfBandQueueable: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Out of Band Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'error',
                Apex_Class__c = 'StripeOutOfBandQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Payment_Transaction__c'
            );
            insert logger;
        }
    }
}