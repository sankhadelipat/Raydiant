public class StripeInvoiceLineItemQueueable implements Queueable, Database.AllowsCallouts {
    
    String invoiceId;
    Id invoiceRecordId;
    
    public StripeInvoiceLineItemQueueable(String invoiceId, Id invoiceRecordId) {
        this.invoiceId = invoiceId;
        this.invoiceRecordId = invoiceRecordId;
    }
    
    public void execute(QueueableContext context) {
        Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
        String secretKey = stripeDetails.Serect_Key__c;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId + '/lines');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(secretKey + ':')));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        HttpResponse res = new Http().send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> lineData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            List<Object> lines = (List<Object>) lineData.get('data');
            List<Stripe_Invoice_Line_Item__c> lineItems = new List<Stripe_Invoice_Line_Item__c>();
            
            for (Object o : lines) {
                Map<String, Object> item = (Map<String, Object>) o;
                
                Stripe_Invoice_Line_Item__c line = new Stripe_Invoice_Line_Item__c();
                line.Stripe_Invoice__c = invoiceRecordId;
                // line.Name = String.valueOf(item.get('id'));
                // line.Description__c = String.valueOf(item.get('description'));
                //   line.Amount__c = Decimal.valueOf(String.valueOf(item.get('amount'))) / 100;
                //  line.Quantity__c = (Integer) item.get('quantity');
                //  line.Invoice__c = invoiceRecordId;
                
                lineItems.add(line);
            }
            
            if (!lineItems.isEmpty()) {
                insert lineItems;
            }
        } else {
            System.debug('Invoice lines fetch failed: ' + res.getBody());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Line Item Error',
                Message__c = 'Failed to fetch invoice lines: ' + res.getBody(),
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceLineItemQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice_Line_Item__c',
                User_Email__c = UserInfo.getUserEmail()
            );
            insert logger;
        }
    }
}