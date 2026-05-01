@IsTest
private class StripePaymentIntentQueueable_Test {
    
    private class StripeInvoiceWithPaymentMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Match invoice retrieve call
            if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"in_test_123",' +
                    '"payments":{' +
                    '"data":[' +
                    '{' +
                    '"payment":{' +
                    '"payment_intent":"pi_test_123"' +
                    '}' +
                    '}' +
                    ']' +
                    '}' +
                    '}'
                );
                return res;
            }
            
            res.setStatusCode(400);
            res.setBody('{"error":"Unhandled endpoint"}');
            return res;
        }
    }
    
    private class StripeInvoiceWithPaymentRecordMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Invoice call
            if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"in_test_123",' +
                    '"payments":{' +
                    '"data":[' +
                    '{' +
                    '"payment":{' +
                    '"payment_record":"pr_test_123",' +
                    '"type":"out_of_band_payment"' +
                    '}' +
                    '}' +
                    ']' +
                    '}' +
                    '}'
                );
                return res;
            }
            
            // Payment record call (from StripeOutOfBandQueueable)
            if (req.getEndpoint().contains('/v1/payment_records/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"pr_test_123",' +
                    '"created":1774917319,' +
                    '"description":"Test OOB payment",' +
                    '"amount":{"currency":"usd","value":2500},' +
                    '"amount_authorized":{"currency":"usd","value":2500}' +
                    '}'
                );
                return res;
            }
            
            res.setStatusCode(400);
            res.setBody('{"error":"Unhandled endpoint"}');
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        
        // Stripe config
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;
        
        // Contract MUST be Draft first
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        // Stripe Invoice record
        Stripe_Invoice__c inv = new Stripe_Invoice__c(
            Stripe_Invoice_ID__c = 'in_test_123',
            Contract__c = con.Id,
            Quote_CPQ__c = null
        );
        insert inv;
    }
    
    @IsTest
    static void testPaymentIntentLinkedToInvoice() {
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceWithPaymentMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripePaymentIntentQueueable('in_test_123')
        );
        Test.stopTest();
        
        // Verify Payment Transaction was created / updated
        Stripe_Payment_Transaction__c pt = [
            SELECT Id,
            Stripe_PaymentIntent_ID__c,
            Stripe_Invoice__c,
            Contract__c
            FROM Stripe_Payment_Transaction__c
            WHERE Stripe_PaymentIntent_ID__c = 'pi_test_123'
            LIMIT 1
        ];
        
        System.assertEquals(
            'pi_test_123',
            pt.Stripe_PaymentIntent_ID__c,
            'PaymentIntent ID should match'
        );
        
        System.assertNotEquals(
            null,
            pt.Stripe_Invoice__c,
            'Invoice should be linked'
        );
        
        System.assertNotEquals(
            null,
            pt.Contract__c,
            'Contract should be linked'
        );
    }
    
    @IsTest
    static void testInvoiceNotFound_HandledGracefully() {
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceWithPaymentMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripePaymentIntentQueueable('in_does_not_exist')
        );
        Test.stopTest();
        
        // Logger should be created
        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE Apex_Class__c = 'StripePaymentIntentQueueable'
        ];
        
        System.assert(
            !logs.isEmpty(),
            'Error should be logged when invoice is missing'
        );
    }
    
    // Payment Record
    @IsTest
    static void testPaymentRecordFlow() {
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceWithPaymentRecordMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripePaymentIntentQueueable('in_test_123')
        );
        Test.stopTest();
    }
}