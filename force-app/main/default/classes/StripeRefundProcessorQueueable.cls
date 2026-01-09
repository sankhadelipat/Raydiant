public class StripeRefundProcessorQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private String paymentIntentId;
    private Decimal refundedAmount;

    public StripeRefundProcessorQueueable(String paymentIntentId, Decimal refundedAmount) {
        this.paymentIntentId = paymentIntentId;
        this.refundedAmount = refundedAmount;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest piReq = new HttpRequest();
            piReq.setEndpoint('https://api.stripe.com/v1/payment_intents/' + paymentIntentId);
            piReq.setMethod('GET');
            piReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse response = http.send(piReq);

            if (response.getStatusCode() == 200) {
                Map<String, Object> piData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> paymentDetails = (Map<String, Object>) piData.get('payment_details');

                String invoiceId = paymentDetails != null && paymentDetails.containsKey('order_reference')
                    ? (String) paymentDetails.get('order_reference')
                    : null;

                if (String.isNotBlank(invoiceId)) {
                    List<Stripe_Invoice__c> invoices = [
                        SELECT Id, Amount_Paid__c, Amount_Refunded__c, Status__c
                        FROM Stripe_Invoice__c
                        WHERE
                            Stripe_Invoice_Id__c LIKE :invoiceId + '%'
                            AND (Status__c = 'Paid'
                            OR Status__c = 'Credited')
                        LIMIT 1
                    ];

                    if (!invoices.isEmpty()) {
                        Stripe_Invoice__c invoice = invoices[0];
                        invoice.Amount_Refunded__c = refundedAmount;

                        System.debug(
                            'Refunded Amount & Invoice Amount Paid: ' + refundedAmount + ' : ' + invoice.Amount_Paid__c
                        );
                        if (refundedAmount > 0) {
                            invoice.Status__c = 'Refunded';
                        }

                        update invoice;
                    } else {
                        System.debug('No matching Stripe Invoice found for Invoice ID: ' + invoiceId);
                    }
                }
            } else {
                System.debug('Failed to retrieve Payment Intent. Status Code: ' + response.getStatusCode());
                throw new CalloutException('Failed to retrieve Payment Intent from Stripe.');
            }
        } catch (Exception e) {
            System.debug('Error processing Stripe refund: ' + e.getMessage());

            Logger__c logger = new Logger__c(
                Name = 'Stripe Refund Processor Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeRefundProcessorQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice__c'
            );
            insert logger;
        }
    }
}