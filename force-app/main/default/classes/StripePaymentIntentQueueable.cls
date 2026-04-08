public class StripePaymentIntentQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String stripeInvoiceId;

    public StripePaymentIntentQueueable(String stripeInvoiceId) {
        this.stripeInvoiceId = stripeInvoiceId;
    }

    public void execute(QueueableContext context) {
        try {
            List<Stripe_Invoice__c> invoices = [
                SELECT Id, Contract__c, Quote_CPQ__c, Account__c
                FROM Stripe_Invoice__c
                WHERE Stripe_Invoice_ID__c = :stripeInvoiceId
                LIMIT 1
            ];
            system.debug('invoices---' + invoices);

            if (invoices.isEmpty()) {
                throw new DmlException('Invoice not found');
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/invoices/' + stripeInvoiceId + '?expand[]=payments');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('result---' + result);

                // ================= PROCESS ALL PAYMENTS =================
                if (result.containsKey('payments') && result.get('payments') != null) {
                    Map<String, Object> payments = (Map<String, Object>) result.get('payments');

                    if (payments.containsKey('data') && payments.get('data') != null) {
                        List<Object> paymentData = (List<Object>) payments.get('data');

                        List<Stripe_Payment_Transaction__c> transactionsToUpsert = new List<Stripe_Payment_Transaction__c>();
                        List<String> outOfBandPaymentRecordIds = new List<String>();

                        for (Object obj : paymentData) {
                            Map<String, Object> paymentWrapper = (Map<String, Object>) obj;

                            if (!paymentWrapper.containsKey('payment') || paymentWrapper.get('payment') == null)
                                continue;

                            Map<String, Object> paymentDetails = (Map<String, Object>) paymentWrapper.get('payment');

                            // ================= PAYMENT INTENT =================
                            if (
                                paymentDetails.containsKey('payment_intent') &&
                                paymentDetails.get('payment_intent') != null
                            ) {
                                String paymentIntentId = (String) paymentDetails.get('payment_intent');
                                String paymentType = (String) paymentDetails.get('type');

                                // ================= UPSERT RECORD =================
                                Stripe_Payment_Transaction__c pt = new Stripe_Payment_Transaction__c();
                                pt.Stripe_PaymentIntent_ID__c = paymentIntentId;
                                pt.Stripe_Invoice__c = invoices[0].Id;
                                pt.Contract__c = invoices[0].Contract__c;
                                pt.Quote_CPQ__c = invoices[0].Quote_CPQ__c;
                                pt.Payment_Type__c = paymentType;

                                transactionsToUpsert.add(pt);
                            }
                            // ================= PAYMENT RECORD =================
                            else if (
                                paymentDetails.containsKey('payment_record') &&
                                paymentDetails.get('payment_record') != null
                            ) {
                                String paymentRecordId = (String) paymentDetails.get('payment_record');

                                outOfBandPaymentRecordIds.add(paymentRecordId);
                            } else {
                                continue;
                            }
                        }

                        if (!transactionsToUpsert.isEmpty()) {
                            upsert transactionsToUpsert Stripe_PaymentIntent_ID__c;
                        }

                        if (!outOfBandPaymentRecordIds.isEmpty()) {
                            System.enqueueJob(new StripeOutOfBandQueueable(outOfBandPaymentRecordIds, invoices[0]));
                        }
                    }
                }
            } else {
                System.debug('Failed to retrieve invoice. Status Code: ' + res.getStatusCode());
                throw new CalloutException('Failed to retrieve invoice. Status Code: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error in StripePaymentIntentQueueable: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Intent Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'error',
                Apex_Class__c = 'StripePaymentIntentQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Payment_Transaction__c'
            );
            insert logger;
        }
    }
}