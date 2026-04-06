@IsTest
public class StripeInvoiceLineItemQueueable_Test {
    public class StripeLineItemMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // Simulated Stripe response with line items
            res.setBody('{"data":[' +
                        '{"id":"il_1","description":"Product 1","amount":1500,"quantity":2},' + 
                        '{"id":"il_2","description":"Product 2","amount":2500,"quantity":1}' +
                        '],"object":"list"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Mock implementation for failed callout
    public class StripeLineItemErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Invalid API key"}');
            res.setStatusCode(401);
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        // Create the Stripe_Details__c config
        Stripe_Details__c sd = new Stripe_Details__c(Name = 'Stripe Details', Serect_Key__c = 'sk_test_key');
        insert sd;
        
        // Create any dummy related Account or Customer if required by the Stripe_Invoice__c object
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        
        Stripe_Invoice__c invoice = new Stripe_Invoice__c(       
            Account__c = acc.Id,
            Stripe_Invoice_ID__c = 'in_test_123'  
        );
        insert invoice;     
    }
    
    @isTest
    static void testQueueable_Success() {
        // Set the mock to simulate success response
        Test.setMock(HttpCalloutMock.class, new StripeLineItemMock());
        
        // Retrieve test data
        // Stripe_Details__c sd = [SELECT Id FROM Stripe_Details__c WHERE Name = 'Stripe Details' LIMIT 1];
        Stripe_Invoice__c invoice = [SELECT Id FROM Stripe_Invoice__c LIMIT 1];
        
        String fakeStripeId = 'in_test_123';
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceLineItemQueueable(fakeStripeId, invoice.Id));
        Test.stopTest();
        
        // Assert line items inserted
        List<Stripe_Invoice_Line_Item__c> items = [SELECT Id FROM Stripe_Invoice_Line_Item__c];
        System.assertEquals(2, items.size(), 'Should insert 2 line items');
    }
    
    @isTest
    static void testQueueable_Error() {
        // Set the mock to simulate error response
        Test.setMock(HttpCalloutMock.class, new StripeLineItemErrorMock());
        
        Stripe_Invoice__c invoice = [SELECT Id FROM Stripe_Invoice__c LIMIT 1];
        String fakeStripeId = 'in_error_123';
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceLineItemQueueable(fakeStripeId, invoice.Id));
        Test.stopTest();
        
        // Assert logger record inserted on error
        List<Logger__c> logs = [SELECT Id, Name, Status__c FROM Logger__c WHERE Name = 'Stripe Invoice Line Item Error'];
        System.assert(!logs.isEmpty(), 'Logger__c record should be inserted on error');
        System.assertEquals('Error', logs[0].Status__c);
    }
}