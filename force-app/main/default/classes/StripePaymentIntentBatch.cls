public class StripePaymentIntentBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, Stripe_Invoice_ID__c, Contract__c, Quote_CPQ__c
                FROM Stripe_Invoice__c
                WHERE
                    Stripe_Invoice_ID__c != NULL
                    AND Id NOT IN (
                        SELECT Stripe_Invoice__c
                        FROM Stripe_Payment_Transaction__c
                        WHERE Stripe_Invoice__c != NULL
                    )
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Stripe_Invoice__c> scope) {
        List<Stripe_Payment_Transaction__c> transactionsToUpdate = new List<Stripe_Payment_Transaction__c>();

        for (Stripe_Invoice__c inv : scope) {
            processedCount++;

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(
                    'https://api.stripe.com/v1/invoices/' + inv.Stripe_Invoice_ID__c + '?expand[]=payments'
                );
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    String paymentIntentId;

                    if (result.containsKey('payments')) {
                        Map<String, Object> payments = (Map<String, Object>) result.get('payments');

                        List<Object> data = payments != null ? (List<Object>) payments.get('data') : null;

                        if (data != null && !data.isEmpty()) {
                            Map<String, Object> firstPayment = (Map<String, Object>) data[0];

                            Map<String, Object> payment = firstPayment != null
                                ? (Map<String, Object>) firstPayment.get('payment')
                                : null;

                            if (payment != null) {
                                paymentIntentId = (String) payment.get('payment_intent');
                            }
                        }
                    }

                    if (paymentIntentId != null) {
                        Stripe_Payment_Transaction__c pt = new Stripe_Payment_Transaction__c();

                        pt.Stripe_PaymentIntent_ID__c = paymentIntentId;
                        pt.Stripe_Invoice__c = inv.Id;
                        pt.Contract__c = inv.Contract__c;
                        pt.Quote_CPQ__c = inv.Quote_CPQ__c;

                        transactionsToUpdate.add(pt);
                        successCount++;
                    }
                } else {
                    errorCount++;
                    errorMessages.add(
                        'Invoice fetch failed: ' + inv.Stripe_Invoice_ID__c + ' | Status ' + res.getStatusCode()
                    );
                }
            } catch (Exception ex) {
                errorCount++;
                errorMessages.add('Invoice ' + inv.Stripe_Invoice_ID__c + ' failed: ' + ex.getMessage());
            }
        }

        if (!transactionsToUpdate.isEmpty()) {
            upsert transactionsToUpdate Stripe_PaymentIntent_ID__c;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'StripePaymentIntentBatch complete | ' +
                'Processed=' +
                processedCount +
                ', Success=' +
                successCount +
                ', Errors=' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe PaymentIntent Batch Error',
                Message__c = errorMessages.size() + ' errors occurred during Invoice → PaymentIntent linking.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentIntentBatch',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Payment_Transaction__c'
            );
            insert logger;
        }
    }
}