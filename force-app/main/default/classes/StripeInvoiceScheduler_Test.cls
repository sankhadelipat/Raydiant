@IsTest
public class StripeInvoiceScheduler_Test {
    
    // Mock class for Stripe Invoice callout
    private class StripeInvoiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Minimal valid response JSON
            res.setBody('{"id":"in_test123","object":"invoice","total":102300,"total_excluding_tax":102300,"subtotal":102300,"amount_paid":102300,"amount_due":0,"amount_remaining":0,"tax":0,"due_date":1752575141,"automatically_finalizes_at":1752575141,"billing_reason":"manual","currency":"usd","paid":true,"effective_at":1752575141,"period_start":1752575141,"period_end":1752575141,"webhooks_delivered_at":1752575141,"invoice_pdf":"https://test.com/invoice.pdf","hosted_invoice_url":"https://test.com/invoice","number":"INV-001","status":"paid","lines":{"data":[{"id":"il_test1","quantity":1,"description":"Test Product","period":{"start":1752575141,"end":1752575141},"price":{"unit_amount_decimal":"10000"},"unit_amount_excluding_tax":"10000"}]}}');
            return res;
        }
    }
    
    // Mock class for failure response
    private class StripeInvoiceMock_Failure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Insert Stripe Details Custom Setting
        Stripe_Details__c stripeDetails = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_12345'
        );
        insert stripeDetails;
    }
    
    private static SBQQ__Quote__c createQuote() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact c = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert c;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            //Name = 'Test Quote',
            SBQQ__Account__c = acc.Id,
            Bill_To_Contact__c = c.Id
        );
        insert quote;
        return quote;
    }
    
    @IsTest
    static void testInvoiceScheduler_Success() {
        SBQQ__Quote__c quote = createQuote();
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceScheduler('in_test123', 'sub_test123', quote.Id, true));
        Test.stopTest();
        
        // Assert invoice created
        Stripe_Invoice__c inv = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Payment_Status__c 
                                 FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'in_test123' LIMIT 1];
        System.assertEquals('in_test123', inv.Stripe_Invoice_Id__c);
        System.assertEquals(1023, inv.Total_Amount__c); // 102300 / 100
        System.assertEquals('paid', inv.Payment_Status__c);
        
        // Assert line item
        Stripe_Invoice_Line_Item__c line = [SELECT Id, Stripe_Invoice_line_Item_Id__c, Product_Name__c, Quantity__c 
                                            FROM Stripe_Invoice_Line_Item__c 
                                            WHERE Stripe_Invoice_line_Item_Id__c = 'il_test1' LIMIT 1];
        System.assertEquals('il_test1', line.Stripe_Invoice_line_Item_Id__c);
        System.assertEquals('Test Product', line.Product_Name__c);
        System.assertEquals(1, line.Quantity__c);
    }
    
    @IsTest
    static void testInvoiceScheduler_WithoutQuote() {
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceScheduler('in_test123', 'sub_test123', null, true));
        Test.stopTest();
        
        // Assert invoice created
        Stripe_Invoice__c inv = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Payment_Status__c 
                                 FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'in_test123' LIMIT 1];
        System.assertEquals('in_test123', inv.Stripe_Invoice_Id__c);
        System.assertEquals(1023, inv.Total_Amount__c); // 102300 / 100
        System.assertEquals('paid', inv.Payment_Status__c);
        
        // Assert line item
        Stripe_Invoice_Line_Item__c line = [SELECT Id, Stripe_Invoice_line_Item_Id__c, Product_Name__c, Quantity__c 
                                            FROM Stripe_Invoice_Line_Item__c 
                                            WHERE Stripe_Invoice_line_Item_Id__c = 'il_test1' LIMIT 1];
        System.assertEquals('il_test1', line.Stripe_Invoice_line_Item_Id__c);
        System.assertEquals('Test Product', line.Product_Name__c);
        System.assertEquals(1, line.Quantity__c);
    }
    
    @IsTest
    static void testInvoiceScheduler_FailureResponse() {
        SBQQ__Quote__c quote = createQuote();
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock_Failure());
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceScheduler('in_invalid', 'sub_invalid', quote.Id, false));
        Test.stopTest();
        
        // Verify logger record inserted
        Logger__c log = [SELECT Message__c, Status__c FROM Logger__c LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Message__c.contains('Failed to fetch invoice'));
    }
    
    @IsTest
    static void testInvoiceScheduler_Exception() {
        SBQQ__Quote__c quote = createQuote();
        
        // Delete Stripe Details so secret key is missing → causes exception
        delete [SELECT Id FROM Stripe_Details__c WHERE Name = 'Stripe Details' LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());
        
        Test.startTest();
        System.enqueueJob(new StripeInvoiceScheduler('in_test_exception', 'sub_test123', quote.Id, true));
        Test.stopTest();
        
        // Verify exception logged
        Logger__c log = [SELECT Message__c, Status__c FROM Logger__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Message__c.contains('Failed to fetch invoice from Stripe'));
    }
}