@IsTest
public class StripeSendPaymentLinkEmailService_Test {

    @TestSetup
    static void setupData() {
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

        // Create Quote
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id
        );
        insert quote;
        
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
    static void testSendPaymentLinkEmail_Success() {
        SBQQ__Quote__c quote = [
            SELECT Id FROM SBQQ__Quote__c LIMIT 1
        ];

        Test.startTest();
        List<StripeSendPaymentLinkEmailService.FlowResult> results =
            StripeSendPaymentLinkEmailService.sendPaymentLinkEmails(
                new List<String>{ quote.Id }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(
            'Payment link email sent successfully',
            results[0].message
        );
    }

    @IsTest
    static void testSendPaymentLinkEmail_NoQuote() {
        Test.startTest();
        List<StripeSendPaymentLinkEmailService.FlowResult> results =
            StripeSendPaymentLinkEmailService.sendPaymentLinkEmails(null);
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assertEquals('No Quote ID provided', results[0].message);
    }

    // -------------------------------------------------
    // INVALID ADDITIONAL EMAILS
    // -------------------------------------------------
    @IsTest
    static void testSendPaymentLinkEmail_InvalidAdditionalEmails() {
        Account acc = [
            SELECT Id FROM Account LIMIT 1
        ];

        acc.Bill_to_Contacts__c = 'good@test.com,bad-email';
        update acc;
        
        SBQQ__Quote__c quote = [
            SELECT Id FROM SBQQ__Quote__c LIMIT 1
        ];

        Test.startTest();
        List<StripeSendPaymentLinkEmailService.FlowResult> results =
            StripeSendPaymentLinkEmailService.sendPaymentLinkEmails(
                new List<String>{ quote.Id }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].message.contains('Invalid additional emails'));
    }
}