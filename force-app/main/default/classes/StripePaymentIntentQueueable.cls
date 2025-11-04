public class StripePaymentIntentQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c testPub = Stripe_Details__c.getInstance('Stripe Details');
    private static final String Secret_Key = testPub.Serect_Key__c;
    private static final String Publish_Key = testPub.Publishable_Key__c;

    Id stripeInvoiceId;
    String paymentIntentId;
    string subcritionId;
    String quoteId;
    Boolean PaymentCaptured;
    Boolean InvoiceCaptured;

    public StripePaymentIntentQueueable(
        Id stripeInvoiceId,
        String paymentIntentId,
        string subcritionId,
        String quoteId,
        Boolean PaymentCaptured,
        Boolean InvoiceCaptured
    ) {
        this.stripeInvoiceId = stripeInvoiceId;
        this.paymentIntentId = paymentIntentId;
        this.subcritionId = subcritionId;
        this.quoteId = quoteId;
        this.paymentCaptured = PaymentCaptured;
        this.InvoiceCaptured = InvoiceCaptured;
    }

    public void execute(QueueableContext context) {
        List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
        quoteList = [
            SELECT
                id,
                SBQQ__NetAmount__c,
                SBQQ__Account__c,
                Is_Stripe_Payment_Done__c,
                Bill_To_Contact__c,
                Stripe_Payment_Intent__c
            FROM SBQQ__Quote__c
            WHERE id = :quoteId
            LIMIT 1
        ];
        system.debug('quoteList==' + quoteList);
        List<SBQQ__Quote__c> updateQuoteList = new List<SBQQ__Quote__c>();

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.stripe.com/v1/payment_intents/' + paymentIntentId);
        // req.setEndpoint('https://api.stripe.com/v1/charges/ch_3S2S1EPuJCefzpgm1zfOUAiQ?expand[]=invoice');
        req.setMethod('POST'); // make it get
        Blob headerValuereqProduct = Blob.valueOf(Secret_Key + ':' + Publish_Key);
        String authorizationHeaderProduct = 'BASIC ' + EncodingUtil.base64Encode(headerValuereqProduct);
        req.setHeader('Authorization', authorizationHeaderProduct);

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
            String invoiceId = (String) intentData.get('invoice');
            String paymentMethodId = (String) intentData.get('payment_method');
            String paymentStatus = (String) intentData.get('status');
            Long createdTimestamp = (Long) intentData.get('created');
            DateTime paymentDate = DateTime.newInstance(createdTimestamp * 1000); // convert seconds to ms

            String receiptUrl = null;

            /* Navigate into charges → data → [0] → receipt_url
            if (intentData.containsKey('charges')) {
                Map<String, Object> chargesMap = (Map<String, Object>) intentData.get('charges');
                List<Object> dataList = (List<Object>) chargesMap.get('data');
                if (!dataList.isEmpty()) {
                    Map<String, Object> firstCharge = (Map<String, Object>) dataList[0];
                    receiptUrl = (String) firstCharge.get('receipt_url');
                }
            }*/

            System.debug('Status: ' + paymentStatus);
            System.debug('Payment Date: ' + paymentDate);

            Payment_Transaction__c pt = new Payment_Transaction__c();
            pt.Name = 'TRX-' + paymentIntentId;
            pt.Stripe_Payment_ID__c = paymentIntentId;
            pt.Stripe_Charge_ID__c = (String) intentData.get('latest_charge');
            pt.Amount_Paid__c = Decimal.valueOf(String.valueOf(intentData.get('amount'))) / 100;
            pt.CurrencyIsoCode = currencyCode.toUpperCase();
            pt.Stripe_Payment_Status__c = paymentStatus;
            pt.Status__c = paymentStatus == 'canceled' ? 'Failed' : 'Success';
            pt.Payment_Date__c = date.valueof(paymentDate);
            //   pt.Stripe_Payment_Receipt_URL__c = receiptUrl;
            pt.Stripe_Invoice__c = stripeInvoiceId;
            pt.Quote_CPQ__c = quoteList[0].id;
            pt.Account__c = quoteList[0].SBQQ__Account__c;
            pt.Error_Message__c = errorMessage;
            pt.Error_Code__c = errorCode;
            pt.Decline_Code__c = declineCode;
            pt.First_Payment_Capture__c = PaymentCaptured;
            pt.First_Invoice_Capture__c = InvoiceCaptured;

            insert pt;
            system.debug('pt--' + pt);

            //  System.enqueueJob(new StripeInvoiceQueueable(invoiceId, quoteList[0].id));
            if (paymentMethodId != null) {
                StripePaymentMethodCreator.createPaymentMethod(paymentMethodId, pt.Id, quoteList[0].id, subcritionId);
            }
        } else {
            System.debug('Stripe callout failed: ' + res.getBody());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Intent Error',
                Message__c = 'Stripe callout failed: ' + res.getBody(),
                StackTrace__c = res.getStatus(),
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentIntentQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Payment_Transaction__c'
                //User_Email__c = UserInfo.getUserEmail()
            );
            insert logger;
        }
    }
}
