@RestResource(urlMapping='/stripe/invoice/pdf')
global without sharing class StripeRedirectInvoicePdf {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    @HttpGet
    global static void redirectToPdf() {
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

                String invoicePdfUrl = (String) stripeInvoice.get('invoice_pdf');

                if (!String.isBlank(invoicePdfUrl)) {
                    // 302 redirect to hosted invoice URL
                    res.statusCode = 302;
                    res.addHeader('Location', invoicePdfUrl);
                    return;
                } else {
                    res.statusCode = 404;
                    res.responseBody = Blob.valueOf('Invoice PDF not available');
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