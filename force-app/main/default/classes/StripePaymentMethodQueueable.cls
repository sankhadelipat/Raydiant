public class StripePaymentMethodQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String paymentMethodId;
    Id transactionId;
    Id quoteId;

    public StripePaymentMethodQueueable(String paymentMethodId, Id transactionId, Id quoteId) {
        this.paymentMethodId = paymentMethodId;
        this.transactionId = transactionId;
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/payment_methods/' + paymentMethodId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> pmData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                Stripe_Payment_Method__c pm = buildPayementMethodRecord(
                    pmData,
                    paymentMethodId,
                    transactionId,
                    quoteId
                );
                upsert pm Stripe_Payment_Method_ID__c;
            } else {
                System.debug('Failed to retrieve payment method: ' + res.getBody());
                throw new CalloutException('Failed to retrieve payment method: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error creating payment method: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Method Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentMethodQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Payment_Method__c'
            );
            insert logger;
        }
    }

    private static Stripe_Payment_Method__c buildPayementMethodRecord(
        Map<String, Object> pmData,
        String pmId,
        Id transactionId,
        Id quoteId
    ) {
        SBQQ__Quote__c quoteList = [
            SELECT Id, SBQQ__Account__c, Bill_To_Contact__c, Billing_Frequency_Override__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
        ];

        String pmType = (String) pmData.get('type');
        Map<String, Object> billingDetails = (Map<String, Object>) pmData.get('billing_details');

        Map<String, Object> addressObj = billingDetails != null
            ? (Map<String, Object>) billingDetails.get('address')
            : new Map<String, Object>();

        Map<String, String> address = new Map<String, String>();
        if (addressObj != null) {
            for (String key : addressObj.keySet()) {
                if (addressObj.get(key) != null) {
                    address.put(key, String.valueOf(addressObj.get(key)));
                }
            }
        }

        String payerEmail = billingDetails != null ? (String) billingDetails.get('email') : null;
        String payerPhone = billingDetails != null ? (String) billingDetails.get('phone') : null;
        String payerName = billingDetails != null ? (String) billingDetails.get('name') : null;
        DateTime createdAt = DateTime.newInstance((Long) pmData.get('created') * 1000); // Convert seconds to milliseconds
        String customerId = (String) pmData.get('customer');

        Stripe_Payment_Method__c pm = new Stripe_Payment_Method__c(
            Payment_Method_Type__c = pmType,
            Account__c = quoteList.SBQQ__Account__c,
            Stripe_Payment_Transaction__c = transactionId,
            Stripe_Payment_Method_ID__c = pmId,
            Payer_Name__c = payerName,
            Payer_Email__c = payerEmail,
            Payer_Phone__c = payerPhone,
            Billing_Address__CountryCode__s = address.get('country'),
            // Billing_Address__StateCode__s = address.get('state'),
            Billing_Address__City__s = address.get('city'),
            Billing_Address__PostalCode__s = address.get('postal_code'),
            Billing_Address__Street__s = address.get('line1'),
            Payment_Method_Created__c = createdAt,
            Stripe_Customer_ID__c = customerId,
            CPQ_Quote__c = quoteId
        );

        // Card-specific fields
        if (pmType == 'card' && pmData.containsKey('card')) {
            Map<String, Object> card = (Map<String, Object>) pmData.get('card');
            pm.Name = (String) card.get('brand') + ' - ' + (String) card.get('last4');
            pm.Card_Brand__c = (String) card.get('brand');
            pm.Card_Country__c = (String) card.get('country');
            pm.Card_Expiry_Month__c = String.valueOf(card.get('exp_month'));
            pm.Card_Expiry_Year__c = String.valueOf(card.get('exp_year'));
            pm.Card_Funding__c = (String) card.get('funding');
            pm.Card_Last_4__c = (String) card.get('last4');
        }
        // Bank account fields
        else if (pmType == 'us_bank_account' && pmData.containsKey('us_bank_account')) {
            Map<String, Object> bank = (Map<String, Object>) pmData.get('us_bank_account');
            pm.Name = (String) bank.get('bank_name') + ' - ' + (String) bank.get('last4');
            pm.Bank_Account_Type__c = (String) bank.get('account_type');
            pm.Bank_Account_Holder_Type__c = (String) bank.get('account_holder_type');
            pm.Bank_Name__c = (String) bank.get('bank_name');
            pm.Bank_Last_4__c = (String) bank.get('last4');
            pm.Bank_Fingerprint__c = (String) bank.get('fingerprint');
        }

        return pm;
    }
}
