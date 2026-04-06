@IsTest
private class StripePaymentIntentBatch_Test {

    private class StripeInvoicePaymentMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Invoice WITH payment intent
            if (req.getEndpoint().contains('/v1/invoices/in_paid_001')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_paid_001",' +
                        '"payments":{' +
                            '"object":"list",' +
                            '"data":[' +
                                '{' +
                                    '"payment":{' +
                                        '"payment_intent":"pi_paid_001"' +
                                    '}' +
                                '}' +
                            ']' +
                        '}' +
                    '}'
                );
                return res;
            }

            // Invoice WITHOUT payment intent
            if (req.getEndpoint().contains('/v1/invoices/in_unpaid_001')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_unpaid_001",' +
                        '"payments":{' +
                            '"object":"list",' +
                            '"data":[]' +
                        '}' +
                    '}'
                );
                return res;
            }

            res.setStatusCode(404);
            res.setBody('{"error":"Invoice not found"}');
            return res;
        }
    }
    
    private class StripeErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(404);
            res.setBody('{"error":"Invoice not found"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123',
            Publishable_Key__c = 'pk_test_123'
        );

        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_001'
        );
        insert acc;

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;

        con.Status = 'Activated';
        update con;

        // Invoice that SHOULD link to transaction
        insert new Stripe_Invoice__c(
            Name = 'INV-001',
            Stripe_Invoice_ID__c = 'in_paid_001',
            Account__c = acc.Id,
            Contract__c = con.Id
        );

        // Invoice with NO payment
        insert new Stripe_Invoice__c(
            Name = 'INV-002',
            Stripe_Invoice_ID__c = 'in_unpaid_001',
            Account__c = acc.Id,
            Contract__c = con.Id
        );
    }

    @IsTest
    static void testPaymentIntentLinking() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoicePaymentMock());

        Test.startTest();
        Database.executeBatch(
            new StripePaymentIntentBatch(),
            2
        );
        Test.stopTest();

        // Only ONE transaction should be created/updated
        List<Stripe_Payment_Transaction__c> txns = [
            SELECT
                Stripe_PaymentIntent_ID__c,
                Stripe_Invoice__c,
                Contract__c
            FROM Stripe_Payment_Transaction__c
        ];

        System.assertEquals(
            1,
            txns.size(),
            'Only invoices with payment intents should create/update transactions'
        );

        Stripe_Payment_Transaction__c txn = txns[0];

        System.assertEquals(
            'pi_paid_001',
            txn.Stripe_PaymentIntent_ID__c,
            'PaymentIntent ID must be populated'
        );

        System.assertNotEquals(
            null,
            txn.Stripe_Invoice__c,
            'Transaction must be linked to Invoice'
        );

        System.assertNotEquals(
            null,
            txn.Contract__c,
            'Transaction must be linked to Contract'
        );
    }

    @IsTest
    static void testFinishLoggerCreated() {

        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());

        Test.startTest();
        Database.executeBatch(
            new StripePaymentIntentBatch(),
            2
        );
        Test.stopTest();

        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE Apex_Class__c = 'StripePaymentIntentBatch'
        ];

        System.assert(
            !logs.isEmpty(),
            'Finish method must create a Logger record'
        );
    }
}