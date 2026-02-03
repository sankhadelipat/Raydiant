@RestResource(urlMapping='/stripe/invoice/pay')
global without sharing class StripeRedirectInvoicePay {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    @HttpGet
    global static void redirectToPayment() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String invoiceId = req.params.get('iid');

        if (String.isBlank(invoiceId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing invoice id');
            return;
        }

        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId);
            httpReq.setMethod('GET');
            httpReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);

            if (httpRes.getStatusCode() == 200) {
                Map<String, Object> stripeInvoice = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());

                String status = (String) stripeInvoice.get('status');
                String hostedInvoiceUrl = (String) stripeInvoice.get('hosted_invoice_url');

                if (status == 'void' || status == 'uncollectible') {
                    res.statusCode = 403;
                    res.responseBody = Blob.valueOf('This invoice cannot be paid (' + status + ')');
                    return;
                }

                if (!String.isBlank(hostedInvoiceUrl)) {
                    // 302 redirect to hosted invoice URL
                    res.statusCode = 302;
                    res.addHeader('Location', hostedInvoiceUrl);
                    return;
                } else {
                    res.statusCode = 404;
                    res.responseBody = Blob.valueOf('No payment link available');
                    return;
                }
            } else {
                res.statusCode = httpRes.getStatusCode();
                res.responseBody = Blob.valueOf('Error retrieving invoice from Stripe: ' + httpRes.getBody());
                return;
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Exception occurred: ' + e.getMessage());
            return;
        }
    }
}