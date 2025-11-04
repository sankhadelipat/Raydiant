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
                Map<String, Object> pmData = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                
                Stripe_Payment_Method__c pm = buildPayementMethodRecord(pmData, paymentMethodId, transactionId, quoteId);
                insert pm;
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
                Object_Name__c = 'Stripe_Payment_Method__c',
                User_Email__c = UserInfo.getUserEmail()
            );
            insert logger;
        }
    }
    
    private static Stripe_Payment_Method__c buildPayementMethodRecord(Map<String, Object> pmData, String pmId, Id transactionId, Id quoteId) {
        SBQQ__Quote__c quoteList = [SELECT Id, SBQQ__Account__c,Bill_To_Contact__c,Billing_Frequency_Override__c FROM SBQQ__Quote__c WHERE Id =:quoteId];
        
        String pmType = (String)pmData.get('type');
        Map<String, String> address = (Map<String, String>)pmData.get('billing_details') != null ? (Map<String, String>)((Map<String, Object>)pmData.get('billing_details')).get('address') : new Map<String, String>();
        String payerEmail = (String)pmData.get('billing_details') != null ? (String)((Map<String, Object>)pmData.get('billing_details')).get('email') : null;
        String payerPhone = (String)pmData.get('billing_details') != null ? (String)((Map<String, Object>)pmData.get('billing_details')).get('phone') : null;
        String payerName = (String)pmData.get('billing_details') != null ? (String)((Map<String, Object>)pmData.get('billing_details')).get('name') : null;
        DateTime createdAt = DateTime.newInstance((Long)pmData.get('created') * 1000); // Convert seconds to milliseconds
        String customerId = (String)pmData.get('customer');
        
        Stripe_Payment_Method__c pm = new Stripe_Payment_Method__c(
            Name = 'PMR - ' + pmId,
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
        Stripe_Customer_ID__c = customerId
            );
        
        // Card-specific fields
        if (pmType == 'card' && pmData.containsKey('card')) {
            Map<String, Object> card = (Map<String, Object>)pmData.get('card');
            pm.Card_Brand__c = (String)card.get('brand');
            pm.Card_Country__c = (String)card.get('country');
            pm.Card_Expiry_Month__c = String.valueOf(card.get('exp_month'));
            pm.Card_Expiry_Year__c = String.valueOf(card.get('exp_year'));
            pm.Card_Funding__c = (String)card.get('funding');
        }
        
        // Bank account fields
        else if (pmType == 'us_bank_account' && pmData.containsKey('us_bank_account')) {
            Map<String, Object> bank = (Map<String, Object>)pmData.get('us_bank_account');
            pm.Bank_Account_Type__c = (String)bank.get('account_type');
            pm.Bank_Account_Holder_Type__c = (String)bank.get('account_holder_type');
            pm.Bank_Name__c = (String)bank.get('bank_name');
        }
        
        // Klarna fields
        else if (pmType == 'klarna' && pmData.containsKey('klarna')) {
            Map<String, Object> klarna = (Map<String, Object>)pmData.get('klarna');
            String dobDay = (String)klarna.get('dob') != null ? (String)((Map<String, Object>)klarna.get('dob')).get('day') : null;
            String dobMonth = (String)klarna.get('dob') != null ? (String)((Map<String, Object>)klarna.get('dob')).get('month') : null;
            String dobYear = (String)klarna.get('dob') != null ? (String)((Map<String, Object>)klarna.get('dob')).get('year') : null;
            Date dateOfBirth = Date.newInstance(Integer.valueOf(dobYear), Integer.valueOf(dobMonth), Integer.valueOf(dobDay));
            
            pm.Klarna_DOB__c = dateOfBirth;
        }
        
        return pm;
    }
}