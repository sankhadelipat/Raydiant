public with sharing class StripeSubscriptionInvoiceProcess {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;
    
    @future(callout=true)
    public static void processInvoice(String invoiceId) {
        try {
            Http http = new Http();

            // 1. First update invoice metadata
            HttpRequest metadataReq = new HttpRequest();
            metadataReq.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId);
            metadataReq.setMethod('POST');
            metadataReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            metadataReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            metadataReq.setBody('metadata[initial_invoice]=true');

            HttpResponse metadataRes = http.send(metadataReq);

            if (metadataRes.getStatusCode() != 200) {
                throw new CalloutException('Failed to update metadata: ' + metadataRes.getBody());
            }

            // 2. Then pay the invoice
            HttpRequest payReq = new HttpRequest();
            payReq.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId + '/pay');
            payReq.setMethod('POST');
            payReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            payReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            payReq.setBody('paid_out_of_band=true');

            HttpResponse payRes = http.send(payReq);

            if (payRes.getStatusCode() != 200) {
                throw new CalloutException('Failed to pay invoice: ' + payRes.getBody());
            }

            System.debug('Successfully processed invoice: ' + invoiceId);
        } catch (Exception e) {
            System.debug('Error in markAndPayInvoice: ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
    }
}