@isTest
private class StripeOutOfBandQueueable_Test {

    // ================= MOCK RESPONSE =================
    class PaymentRecordMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Extract ID from endpoint for dynamic response
            String endpoint = req.getEndpoint();
            String prId = endpoint.substringAfterLast('/');

            String body = '{' +
                '"id": "' + prId + '",' +
                '"object": "payment_record",' +
                '"created": 1774917319,' +
                '"description": "Test payment for ' + prId + '",' +
                '"amount": {"currency": "usd", "value": 2500},' +
                '"amount_authorized": {"currency": "usd", "value": 2500}' +
            '}';

            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }
    
    // ================= MOCK ERROR RESPONSE =================
    class PaymentRecordErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;
        
        // Create quote
        SBQQ__Quote__c qt = new SBQQ__Quote__c(
            SBQQ__StartDate__c = Date.today().addMonths(-1),
            SBQQ__EndDate__c = Date.today().addMonths(11),
            SBQQ__Account__c = acc.Id,
            SBQQ__Primary__c = true,
            Billing_Frequency_Override__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            CurrencyIsoCode = 'USD',
            SBQQ__PaymentTerms__c = 'Due on Recipt'
        );
        insert qt;
        
        // Create Contract
        Contract con = new Contract(
            AccountId = acc.Id,
            SBQQ__Quote__c = qt.Id,
            Stripe_Subscription_ID__c = 'sub_test_123',
            Status = 'Draft',
            StartDate = Date.today().addMonths(-1),
            EndDate = Date.today().addMonths(11),
            ContractTerm = 12
        );
        insert con;
        
        // Create Invoice
        Stripe_Invoice__c invoice = new Stripe_Invoice__c(
            Name = 'Test Invoice',
            Stripe_Invoice_Id__c = 'in_test_123',
            Account__c = acc.Id,
            Contract__c = con.Id,
            Quote_CPQ__c = qt.Id
        );
        insert invoice;
    }

    // ================= TEST METHOD =================
    @isTest
    static void testOutOfBandQueueable() {

        // Set mock
        Test.setMock(HttpCalloutMock.class, new PaymentRecordMock());

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Stripe_Invoice__c invoice = [SELECT Id, Stripe_Invoice_Id__c, Account__c, Quote_CPQ__c, Contract__c FROM Stripe_Invoice__c LIMIT 1];

        // Payment Record IDs
        List<String> paymentRecordIds = new List<String>{
            'pr_test_1',
            'pr_test_2'
        };

        Test.startTest();

        System.enqueueJob(
            new StripeOutOfBandQueueable(paymentRecordIds, invoice)
        );

        Test.stopTest();

        // ================= ASSERTIONS =================
        List<Stripe_Payment_Transaction__c> records = [
            SELECT Id,
                   Stripe_PaymentIntent_ID__c,
                   Amount__c,
                   Amount_Paid__c,
                   Description__c,
                   Payment_Type__c,
                   Status__c,
                   Stripe_Transaction_Status__c,
                   Account__c
            FROM Stripe_Payment_Transaction__c
        ];

        System.assertEquals(2, records.size(), 'Should create 2 transactions');

        for (Stripe_Payment_Transaction__c rec : records) {
            System.assertNotEquals(null, rec.Stripe_PaymentIntent_ID__c);
            System.assertEquals(25, rec.Amount__c);
            System.assertEquals(25, rec.Amount_Paid__c);
            System.assertEquals('out_of_band_payment', rec.Payment_Type__c);
            System.assertEquals('Succeeded', rec.Status__c);
            System.assertEquals('succeeded', rec.Stripe_Transaction_Status__c);
            System.assertEquals(acc.Id, rec.Account__c);
        }
    }

    // ================= IDEMPOTENCY TEST =================
    @isTest
    static void testUpsertIdempotency() {

        Test.setMock(HttpCalloutMock.class, new PaymentRecordMock());

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Stripe_Invoice__c invoice = [SELECT Id, Stripe_Invoice_Id__c, Account__c, Quote_CPQ__c, Contract__c FROM Stripe_Invoice__c LIMIT 1];

        List<String> paymentRecordIds = new List<String>{ 'pr_test_same' };

        Test.startTest();

        // Run twice → should NOT duplicate
        System.enqueueJob(new StripeOutOfBandQueueable(paymentRecordIds, invoice));
        System.enqueueJob(new StripeOutOfBandQueueable(paymentRecordIds, invoice));

        Test.stopTest();

        List<Stripe_Payment_Transaction__c> records = [
            SELECT Id FROM Stripe_Payment_Transaction__c
            WHERE Stripe_PaymentIntent_ID__c = 'pr_test_same'
        ];

        System.assertEquals(1, records.size(), 'Upsert should prevent duplicates');
    }
    
    // ================= ERROR TEST =================
    @isTest
    static void testException() {

        Test.setMock(HttpCalloutMock.class, new PaymentRecordErrorMock());

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Stripe_Invoice__c invoice = [SELECT Id, Stripe_Invoice_Id__c, Account__c, Quote_CPQ__c, Contract__c FROM Stripe_Invoice__c LIMIT 1];

        List<String> paymentRecordIds = new List<String>{ 'pr_test_same' };

        Test.startTest();
        System.enqueueJob(new StripeOutOfBandQueueable(paymentRecordIds, invoice));
        Test.stopTest();

        List<Logger__c> logs = [SELECT Id FROM Logger__c];

        System.assert(logs.size() > 0, 'Loggers should be created');
    }
}