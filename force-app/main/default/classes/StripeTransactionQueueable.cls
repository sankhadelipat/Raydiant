public class StripeTransactionQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String paymentIntentId;
    String customerId;
    String quoteId;
    String eventType;

    public StripeTransactionQueueable(String paymentIntentId, String customerId, String quoteId, String eventType) {
        this.paymentIntentId = paymentIntentId;
        this.customerId = customerId;
        this.quoteId = quoteId;
        this.eventType = eventType;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/payment_intents/' + paymentIntentId + '?expand[]=latest_charge');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> intentData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('Payment Intent Data: ' + intentData);
                String paymentMethodId = (String) intentData.get('payment_method');

                // Fetch related Quote, Account & Payment Method
                List<SBQQ__Quote__c> quoteList = [
                    SELECT Id, SBQQ__Account__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :quoteId
                    LIMIT 1
                ];
                System.debug('quoteList--' + quoteList);

                List<Account> accts = [SELECT Id FROM Account WHERE Stripe_Customer_ID__c = :customerId LIMIT 1];
                System.debug('accts--' + accts);

                List<Stripe_Payment_Method__c> paymentMethods = [
                    SELECT Id
                    FROM Stripe_Payment_Method__c
                    WHERE Stripe_Payment_Method_ID__c = :paymentMethodId
                    LIMIT 1
                ];
                System.debug('paymentMethods--' + paymentMethods);

                // Process the intentData as needed
                Map<String, Object> lastPaymentError = (Map<String, Object>) intentData.get('last_payment_error');
                System.debug('lastPaymentError--' + lastPaymentError);

                String errorMessage = lastPaymentError != null ? (String) lastPaymentError.get('message') : null;
                String errorCode = lastPaymentError != null ? (String) lastPaymentError.get('code') : null;
                String declineCode = lastPaymentError != null ? (String) lastPaymentError.get('decline_code') : null;

                Map<String, Object> chargeData = (Map<String, Object>) intentData.get('latest_charge');
                System.debug('chargeData--' + chargeData);

                String latestChargeId = chargeData != null ? (String) chargeData.get('id') : null;
                String reciptUrl = chargeData != null ? (String) chargeData.get('receipt_url') : null;
                Decimal amount = (Decimal) intentData.get('amount') / 100;
                Decimal amountPaid = (Decimal) intentData.get('amount_received') / 100;
                Long createdTimestamp = (Long) intentData.get('created');
                Datetime paymentDate = DateTime.newInstance(createdTimestamp * 1000);
                String currencyCode = (String) intentData.get('currency');
                Id accountId;
                String Status;

                // Determine Account Id
                if (!accts.isEmpty()) {
                    accountId = accts[0].Id;
                } else if (!quoteList.isEmpty()) {
                    accountId = quoteList[0].SBQQ__Account__c;
                } else {
                    throw new DmlException('No Account found: ' + customerId);
                }
                System.debug('accountId--' + accountId);

                // Determine Status based on event type
                if (eventType == 'payment_intent.succeeded') {
                    Status = 'Succeeded';
                } else if (eventType == 'payment_intent.payment_failed') {
                    Status = 'Failed';
                } else if (eventType == 'payment_intent.canceled') {
                    Status = 'Canceled';
                }

                Stripe_Payment_Transaction__c pt = new Stripe_Payment_Transaction__c();
                pt.Stripe_PaymentIntent_ID__c = paymentIntentId;
                pt.Amount__c = amount;
                pt.Amount_Paid__c = amountPaid;
                pt.CurrencyIsoCode = currencyCode.toUpperCase();
                pt.Stripe_Transaction_Status__c = (String) intentData.get('status');
                pt.Status__c = Status;
                pt.Payment_Date__c = Date.valueOf(paymentDate);
                pt.Quote_CPQ__c = quoteList.isEmpty() ? null : quoteList[0].Id;
                pt.Account__c = accountId;
                pt.Stripe_Payment_Method__c = paymentMethods.isEmpty() ? null : paymentMethods[0].Id;

                if (chargeData != null) {
                    pt.Stripe_Charge_ID__c = latestChargeId;
                    pt.Receipt_URL__c = reciptUrl;
                }

                if (lastPaymentError != null) {
                    pt.Error_Message__c = errorMessage;
                    pt.Error_Code__c = errorCode;
                    pt.Decline_Code__c = declineCode;
                }

                upsert pt Stripe_PaymentIntent_ID__c;
                System.debug('Payment Transaction upserted: ' + pt.Id);
            } else {
                System.debug('Failed to retrieve payment intent: ' + res.getBody());
                throw new CalloutException('Stripe callout failed: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in StripeTransactionQueueable: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Transaction Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeTransactionQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Payment_Transaction__c'
            );
            insert logger;
        }
    }
}