@IsTest
public class StripeInvoiceMigration_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create custom setting for Stripe Details
        Stripe_Details__c stripeDetails = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_1234567890'
        );
        insert stripeDetails;
        
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Update Account with Bill To Contact
        testAccount.blng__BillToContact__c = testContact.Id;
        update testAccount;
        
        // Create test Quote
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = testAccount.Id,
            SBQQ__Primary__c = true
        );
        insert testQuote;
    }
    
    @IsTest
    static void testBatchSuccess() {
        // Setup mock response
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());
        
        Test.startTest();
        StripeInvoiceMigration batch = new StripeInvoiceMigration();
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchWithStripeError() {
        // Setup error mock response
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        List<Logger__c> allLoggers = [SELECT Id FROM Logger__c];
        delete allLoggers;
        
        List<String> invoiceIds = new List<String>{'in_test1'};
        
        Test.startTest();
        StripeInvoiceMigration batch = new StripeInvoiceMigration();
        Database.executeBatch(batch, 1);
        Test.stopTest();
        
        // Verify error was recorded
        List<Logger__c> loggers = [SELECT Id FROM Logger__c];
        System.AssertEquals(1, loggers.size(), 'One Logger should be created.');
    }
    
    // Mock class for successful Stripe invoice responses
    public class StripeInvoiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/invoices?limit=100')) {
                // Mock for invoice list
                res.setBody('{' +
                    '"object": "list",' +
                    '"data": [' +
                    '  {"id": "in_test1"}' +
                    '],' +
                    '"has_more": false' +
                '}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/invoices/')) {
                // Mock for individual invoice
                res.setBody('{' +
                    '"id": "in_test1",' +
                    '"object": "invoice",' +
                    '"number": "INV-001",' +
                    '"currency": "usd",' +
                    '"total": 10000,' +
                    '"total_excluding_tax": 9000,' +
                    '"subtotal": 9000,' +
                    '"amount_paid": 10000,' +
                    '"amount_due": 0,' +
                    '"amount_remaining": 0,' +
                    '"tax": 1000,' +
                    '"due_date": 1635724800,' +
                    '"automatically_finalizes_at": 1635724800,' +
                    '"billing_reason": "subscription_create",' +
                    '"paid": true,' +
                    '"effective_at": 1635724800,' +
                    '"period_start": 1635724800,' +
                    '"period_end": 1638403200,' +
                    '"webhooks_delivered_at": 1635724800,' +
                    '"status": "paid",' +
                    '"invoice_pdf": "https://example.com/invoice.pdf",' +
                    '"hosted_invoice_url": "https://example.com/invoice",' +
                    '"metadata": {' +
                    '  "salesforce_quote_id": "' + [SELECT Id FROM SBQQ__Quote__c LIMIT 1].Id + '"' +
                    '},' +
                    '"lines": {' +
                    '  "object": "list",' +
                    '  "data": [' +
                    '    {' +
                    '      "id": "ii_test1",' +
                    '      "amount": 5000,' +
                    '      "quantity": 1,' +
                    '      "description": "Test Product",' +
                    '      "period": {' +
                    '        "start": 1635724800,' +
                    '        "end": 1638403200' +
                    '      },' +
                    '      "price": {' +
                    '        "unit_amount_decimal": "5000",' +
                    '        "type": "recurring"' +
                    '      },' +
                    '      "unit_amount_excluding_tax": "4500"' +
                    '    }' +
                    '  ]' +
                    '}' +
                '}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            
            return res;
        }
    }
    
    // Mock class for Stripe errors
    public class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request", "type": "invalid_request_error"}}');
            return res;
        }
    }
}