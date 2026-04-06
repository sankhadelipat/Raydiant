@IsTest
private class StripeRedirectInvoice_Test {

    private class StripeInvoiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // ---- PAYABLE INVOICE ----
            if (req.getEndpoint().contains('/v1/invoices/in_payable')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_payable",' +
                        '"status":"open",' +
                        '"hosted_invoice_url":"https://invoice.stripe.com/pay/in_payable",' +
                        '"invoice_pdf":"https://invoice.stripe.com/pdf/in_payable"' +
                    '}'
                );
                return res;
            }

            // ---- VOID INVOICE ----
            if (req.getEndpoint().contains('/v1/invoices/in_void')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_void",' +
                        '"status":"void",' +
                        '"hosted_invoice_url":"https://invoice.stripe.com/pay/in_void"' +
                    '}'
                );
                return res;
            }

            // ---- PDF ONLY ----
            if (req.getEndpoint().contains('/v1/invoices/in_pdf_only')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_pdf_only",' +
                        '"status":"paid",' +
                        '"invoice_pdf":"https://invoice.stripe.com/pdf/in_pdf_only"' +
                    '}'
                );
                return res;
            }

            // ---- NOT FOUND ----
            res.setStatusCode(404);
            res.setBody('{"error":"Invoice not found"}');
            return res;
        }
    }
    
    private class StripeInvoiceErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // ---- PAYABLE INVOICE ----
            if (req.getEndpoint().contains('/v1/invoices/in_payable')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_payable",' +
                        '"status":"open"' + 
                    '}'
                );
                return res;
            }

            // ---- NOT FOUND ----
            res.setStatusCode(404);
            res.setBody('{"error":"Invoice not found"}');
            return res;
        }
    }

    @TestSetup
    static void setupStripeConfig() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123',
            Publishable_Key__c = 'pk_test_123'
        );
    }

    @IsTest
    static void testPayRedirectSuccess() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_payable');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePay.redirectToPayment();
        Test.stopTest();

        System.assertEquals(302, RestContext.response.statusCode);
        System.assertEquals(
            'https://invoice.stripe.com/pay/in_payable',
            RestContext.response.headers.get('Location')
        );
    }
    
    @IsTest
    static void testPayRedirectFailure() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceErrorMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_invalid');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePay.redirectToPayment();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void testPayRedirectVoidInvoice() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_void');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePay.redirectToPayment();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
    }

    @IsTest
    static void testPayRedirectMissingParam() {

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePay.redirectToPayment();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
    
    @IsTest
    static void testPayRedirectMissingLink() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceErrorMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_payable'); // no Link in mock

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePay.redirectToPayment();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void testPdfRedirectSuccess() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pdf';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_pdf_only');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePdf.redirectToPdf();
        Test.stopTest();

        System.assertEquals(302, RestContext.response.statusCode);
        System.assertEquals(
            'https://invoice.stripe.com/pdf/in_pdf_only',
            RestContext.response.headers.get('Location')
        );
    }
    
    @IsTest
    static void testPdfRedirectMissingParam() {

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pdf';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePdf.redirectToPdf();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
    
    @IsTest
    static void testPdfRedirectFailure() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceErrorMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pay';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_invalid');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePdf.redirectToPdf();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void testPdfRedirectMissingPdf() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceErrorMock());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/stripe/invoice/pdf';
        req.httpMethod = 'GET';
        req.addParameter('iid', 'in_payable'); // no PDF in mock

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        StripeRedirectInvoicePdf.redirectToPdf();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }
}