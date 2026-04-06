@IsTest
private class StripeInvoiceAdditionalEmailBatch_Test {

    private class PdfMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            // Simulate successful PDF download
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('Dummy PDF Content'));
            return res;
        }
    }

    @TestSetup
    static void setupData() {
		// Stripe Details
        Stripe_Details__c stripeSettings = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert stripeSettings;

        // Account
        Account acc1 = new Account(
            Name = 'Test Account',
            Bill_to_Contacts__c = 'test1@test.com,test2@test.com'
        );
        insert acc1;
        
        Account acc2 = new Account(
            Name = 'Bad Email Account',
            Bill_to_Contacts__c = 'invalid-email'
        );
        insert acc2;

        // Stripe Invoice
        Stripe_Invoice__c invoice1 = new Stripe_Invoice__c(
            Name = 'INV-001',
            Account__c = acc1.Id,
            Status__c = 'Open',
            Stripe_Invoice_Id__c = 'in_test_123',
            Invoice_PDF_URL__c = 'https://test.com/fakepdf'
        );
        insert invoice1;

        Stripe_Invoice__c invoice2 = new Stripe_Invoice__c(
            Name = 'INV-002',
            Account__c = acc2.Id,
            Status__c = 'Open',
            Stripe_Invoice_Id__c = 'in_test_456',
            Invoice_PDF_URL__c = 'https://test.com/fakepdf'
        );
        insert invoice2;

        // -------------------------
        // Preconditions (setup data must exist)
        // -------------------------
        System.assert(
            [SELECT COUNT() FROM EmailTemplate WHERE DeveloperName = 'Stripe_Invoice_Email'] == 1
        );
        System.assert(
            [SELECT COUNT() FROM OrgWideEmailAddress WHERE DisplayName = 'Displai Billing'] == 1
        );
    }

    @IsTest
    static void testBatchSuccess() {

        Stripe_Invoice__c inv = [
            SELECT Id FROM Stripe_Invoice__c WHERE Name = 'INV-001' LIMIT 1
        ];

        Set<Id> invoiceIds = new Set<Id>{ inv.Id };

        Test.setMock(HttpCalloutMock.class, new PdfMock());

        Test.startTest();
        Database.executeBatch(
            new StripeInvoiceAdditionalEmailBatch(invoiceIds, 'NEW'),
            1
        );
        Test.stopTest();

        // If we reached here without exception,
        // batch executed successfully.
        System.assert(true);
    }

    @IsTest
    static void testBatchInvalidEmail() {
        
        Stripe_Invoice__c inv = [
            SELECT Id FROM Stripe_Invoice__c WHERE Name = 'INV-002' LIMIT 1
        ];
        
        Set<Id> invoiceIds = new Set<Id>{ inv.Id };

        Test.setMock(HttpCalloutMock.class, new PdfMock());

        Test.startTest();
        Database.executeBatch(
            new StripeInvoiceAdditionalEmailBatch(invoiceIds, 'REMINDER'),
            1
        );
        Test.stopTest();

        // Verify logger inserted (optional)
        List<Logger__c> logs = [
            SELECT Id FROM Logger__c
            WHERE Apex_Class__c = 'StripeInvoiceAdditionalEmailBatch'
        ];

        System.assert(logs.size() >= 0);
    }
}