public class StripePaymentIntentQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    Id invoiceId;
    String paymentIntentId;
    String stripeSubscriptionId;
    String quoteId;
    Boolean paymentCaptured;
    Boolean invoiceCaptured;

    public StripePaymentIntentQueueable(
        Id invoiceId,
        String paymentIntentId,
        String stripeSubscriptionId,
        String quoteId,
        Boolean paymentCaptured,
        Boolean invoiceCaptured
    ) {
        this.invoiceId = invoiceId;
        this.paymentIntentId = paymentIntentId;
        this.stripeSubscriptionId = stripeSubscriptionId;
        this.quoteId = quoteId;
        this.paymentCaptured = paymentCaptured;
        this.invoiceCaptured = invoiceCaptured;
    }

    public void execute(QueueableContext context) {
        try {
            List<Contract> contracts = new List<Contract>();
            if (stripeSubscriptionId != null) {
                contracts = [
                    SELECT id, Stripe_Subscription_ID__c, SBQQ__Quote__c
                    FROM Contract
                    WHERE Stripe_Subscription_ID__c = :stripeSubscriptionId
                ];
            }

            List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
            if (!contracts.isEmpty()) {
                quoteList = [
                    SELECT
                        Id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE id = :contracts[0].SBQQ__Quote__c
                ];
            } else if (quoteId != null) {
                quoteList = [
                    SELECT
                        Id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :quoteId
                ];
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/payment_intents/' + paymentIntentId + '?expand[]=latest_charge');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> intentData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('intentData--' + intentData);

                Map<String, Object> lastPaymentError = (Map<String, Object>) intentData.get('last_payment_error');
                String errorMessage = lastPaymentError != null ? (String) lastPaymentError.get('message') : null;
                String errorCode = lastPaymentError != null ? (String) lastPaymentError.get('code') : null;
                String declineCode = lastPaymentError != null ? (String) lastPaymentError.get('decline_code') : null;
                String currencyCode = (String) intentData.get('currency');
                String stripeInvoiceId = (String) intentData.get('invoice');
                String stripeCustomerId = (String) intentData.get('customer');
                String paymentMethodId = (String) intentData.get('payment_method');
                String paymentStatus = (String) intentData.get('status');
                Long createdTimestamp = (Long) intentData.get('created');
                DateTime paymentDate = DateTime.newInstance(createdTimestamp * 1000); // convert seconds to ms
                String chargeId;
                String receiptUrl;
                Id accountId;
                Id billToContactId;

                // Fetch Account based on Customer ID
                List<Account> accts = [
                    SELECT Id, Name, blng__BillToContact__c
                    FROM Account
                    WHERE Stripe_Customer_ID__c = :stripeCustomerId
                ];
                System.debug('accts--' + accts);

                // Determine Account and Bill To Contact
                if (!accts.isEmpty()) {
                    accountId = accts[0].Id;
                    billToContactId = accts[0].blng__BillToContact__c;
                } else if (!quoteList.isEmpty()) {
                    accountId = quoteList[0].SBQQ__Account__c;
                    billToContactId = quoteList[0].Bill_To_Contact__c != null
                        ? quoteList[0].Bill_To_Contact__c
                        : quoteList[0].SBQQ__Account__r.blng__BillToContact__c;
                } else {
                    throw new DmlException('No Account found: ' + stripeCustomerId);
                }
                System.debug('accountId--' + accountId);

                if (intentData.containsKey('latest_charge') && intentData.get('latest_charge') != null) {
                    Map<String, Object> latestCharge = (Map<String, Object>) intentData.get('latest_charge');
                    chargeId = (String) latestCharge.get('id');
                    receiptUrl = (String) latestCharge.get('receipt_url');
                }

                System.debug('Status: ' + paymentStatus);
                System.debug('Payment Date: ' + paymentDate);

                Payment_Transaction__c pt = new Payment_Transaction__c();
                pt.Name = 'TRX-' + paymentIntentId;
                pt.Stripe_Payment_ID__c = paymentIntentId;
                pt.Stripe_Charge_ID__c = chargeId;
                pt.Amount_Paid__c = Decimal.valueOf(String.valueOf(intentData.get('amount'))) / 100;
                pt.CurrencyIsoCode = currencyCode.toUpperCase();
                pt.Stripe_Payment_Status__c = paymentStatus;
                pt.Status__c = paymentStatus == 'canceled' ? 'Failed' : 'Success';
                pt.Payment_Date__c = date.valueof(paymentDate);
                pt.Stripe_Payment_Receipt_URL__c = receiptUrl;
                pt.Stripe_Invoice__c = invoiceId;
                pt.Quote_CPQ__c = quoteList.isEmpty() ? null : quoteList[0].Id;
                pt.Account__c = accountId;
                pt.Error_Message__c = errorMessage;
                pt.Error_Code__c = errorCode;
                pt.Decline_Code__c = declineCode;
                pt.First_Payment_Capture__c = paymentCaptured;
                pt.First_Invoice_Capture__c = invoiceCaptured;

                insert pt;

                if (paymentMethodId != null) {
                    StripePaymentMethodCreator.createPaymentMethod(
                        paymentMethodId,
                        pt.Id,
                        quoteId,
                        stripeSubscriptionId
                    );
                }
            } else {
                System.debug('Failed to retrieve payment intent: ' + res.getBody());
                throw new CalloutException('Failed to retrieve payment intent: ' + res.getBody());
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