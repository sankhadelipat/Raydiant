@IsTest
private class StripeSendAdditionalEmailService_Test {

    private class StripeCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setStatusCode(200);
                res.setBody('{"invoice_pdf":"https://mock.stripe/pdf"}');
            } else if (req.getEndpoint().contains('mock.stripe/pdf')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('PDFDATA'));
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }
    
    private class StripeCalloutErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            return res;
        }
    }
    
    @testSetup
    static void setupTestData() {
        // -------------------------
        // Custom Settings setup
        // -------------------------
        Stripe_Details__c stripeSettings = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert stripeSettings;

        // -------------------------
        // Account
        // -------------------------
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // -------------------------
        // Bill To Contact (formula source)
        // -------------------------
        Contact billTo = new Contact(
            LastName = 'Billing',
            Email = 'primary@test.com',
            AccountId = acc.Id
        );
        insert billTo;

        // IMPORTANT: set the lookup used by the formula
        acc.blng__BillToContact__c = billTo.Id; // <-- or your actual field
        acc.Bill_to_Contacts__c = 'cc1@test.com,cc2@test.com';
        update acc;

        // -------------------------
        // Invoice
        // -------------------------
        Stripe_Invoice__c inv = new Stripe_Invoice__c(
            Name = 'INV-001',
            Account__c = acc.Id,
            Stripe_Invoice_Id__c = 'in_test_123'
        );
        insert inv;

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
    static void testSendInvoiceEmails_success() {
        Test.setMock(HttpCalloutMock.class, new StripeCalloutMock());

        // -------------------------
        // Flow invocation
        // -------------------------
        Stripe_Invoice__c inv = [SELECT Id FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'in_test_123'];
        
        StripeSendAdditionalEmailService.FlowInput input =
            new StripeSendAdditionalEmailService.FlowInput();
        input.invoices = new List<Stripe_Invoice__c>{ inv };

        Test.startTest();
        List<StripeSendAdditionalEmailService.FlowResult> res =
            StripeSendAdditionalEmailService.sendInvoiceEmails(
                new List<StripeSendAdditionalEmailService.FlowInput>{ input }
            );
        Test.stopTest();

        // -------------------------
        // Assert
        // -------------------------
        System.assertEquals(true, res[0].isSuccess);
        System.assertEquals('Emails sent successfully', res[0].message);
    }
    
    @IsTest
    static void testSendInvoiceEmails_error() {
        Test.setMock(HttpCalloutMock.class, new StripeCalloutErrorMock());

        // -------------------------
        // Flow invocation
        // -------------------------
        Stripe_Invoice__c inv = [SELECT Id FROM Stripe_Invoice__c WHERE Stripe_Invoice_Id__c = 'in_test_123'];
        
        StripeSendAdditionalEmailService.FlowInput input =
            new StripeSendAdditionalEmailService.FlowInput();
        input.invoices = new List<Stripe_Invoice__c>{ inv };

        Test.startTest();
        List<StripeSendAdditionalEmailService.FlowResult> res =
            StripeSendAdditionalEmailService.sendInvoiceEmails(
                new List<StripeSendAdditionalEmailService.FlowInput>{ input }
            );
        Test.stopTest();

        // -------------------------
        // Assert
        // -------------------------
        System.assertEquals(false, res[0].isSuccess);
    }
}