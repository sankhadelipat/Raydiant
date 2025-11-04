public class StripeTransactionQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;
    
    String paymentIntentId;
    String quoteId;
    
    public StripeTransactionQueueable(String paymentIntentId, String quoteId) {
        this.paymentIntentId = paymentIntentId;
        this.quoteId = quoteId;
    }
    
    public void execute(QueueableContext context) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/payment_intents/' + paymentIntentId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> intentData = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> lastPaymentError = (Map<String, Object>)intentData.get('last_payment_error');
                String errorMessage = lastPaymentError != null ? (String)lastPaymentError.get('message') : null;
                String errorCode = lastPaymentError != null ? (String)lastPaymentError.get('code') : null;
                String declineCode = lastPaymentError != null ? (String)lastPaymentError.get('decline_code') : null;
                Long createdTimestamp = (Long) intentData.get('created');
                DateTime paymentDate = DateTime.newInstance(createdTimestamp * 1000); // convert seconds to ms
                String currencyCode = (String)intentData.get('currency');
                // Process the intentData as needed
                System.debug('Payment Intent Data: ' + intentData);
                
                List<SBQQ__Quote__c> quoteList = [SELECT Id, SBQQ__Account__c, Bill_To_Contact__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
                
                if (quoteList.isEmpty()) {
                    System.debug('No quote found for ID: ' + quoteId);
                    return;
                }
                
                Payment_Transaction__c pt = new Payment_Transaction__c();
                pt.Name = 'TRX-' + paymentIntentId;
                pt.Stripe_Payment_ID__c = paymentIntentId;
                pt.Stripe_Charge_ID__c = (String)intentData.get('latest_charge');
                pt.Amount_Paid__c = Decimal.valueOf(String.valueOf(intentData.get('amount')))/100;
                pt.CurrencyIsoCode = currencyCode.toUpperCase();
                pt.Stripe_Payment_Status__c = (String)intentData.get('status');
                pt.Status__c = (String)intentData.get('status') == 'succeeded' ? 'Success' : 'Failed';
                pt.Payment_Date__c = Date.valueOf(paymentDate);
                pt.Quote_CPQ__c = quoteList[0].Id;
                pt.Account__c = quoteList[0].SBQQ__Account__c;
                pt.Error_Message__c = errorMessage;
                pt.Error_Code__c = errorCode;
                pt.Decline_Code__c = declineCode;
                pt.First_Payment_Capture__c = false;
                
                insert pt;
                System.debug('Payment Transaction created: ' + pt.Id);
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
            Object_Name__c = 'Payment_Transaction__c',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
        }
    }
}