@IsTest
public class StripeInvoiceQueueable_Test {

    @TestSetup
    static void setupData() {
        // 1️⃣ Create Stripe Details hierarchy setting
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;

        // 2️⃣ Create test Account
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123456'
        );
        insert acc;

        // 3️⃣ Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            SBQQ__SubscriptionType__c = 'One-time',
            Stripe_Product_Id__c = 'prod_test_123'
        );
        insert prod;

        // 4️⃣ Create Quote
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id
        );
        insert quote;

        // 5️⃣ Create Quote Line
        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c = 100
        );
        insert ql;

         // 4️⃣ Create Contract linked to Quote
    Contract con = new Contract(
        AccountId = acc.Id,
        StartDate = Date.today(),
        Status = 'Draft',
        Stripe_Subscription_ID__c = 'sub_test_123',
        SBQQ__Quote__c = quote.Id
    );
    insert con;
        
    }

    // Mock the Stripe API callout
    class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String requestBody = '{\"id\":\"in_1S2pW2PuJCefzpgmpGy8biLr\",\"object\":\"invoice\",\"account_country\":\"US\",\"account_name\":\"Displai\",\"account_tax_ids\":null,\"amount_due\":28800,\"amount_overpaid\":0,\"amount_paid\":28800,\"amount_remaining\":0,\"amount_shipping\":0,\"application\":null,\"attempt_count\":0,\"attempted\":true,\"auto_advance\":false,\"automatic_tax\":{\"disabled_reason\":null,\"enabled\":false,\"liability\":null,\"provider\":null,\"status\":null},\"automatically_finalizes_at\":null,\"billing_reason\":\"subscription_create\",\"collection_method\":\"charge_automatically\",\"created\":1756801474,\"currency\":\"usd\",\"custom_fields\":null,\"customer\":\"cus_SweIjgQ67uYqLs\",\"customer_address\":null,\"customer_email\":\"johndoe08272025@test.test\",\"customer_name\":\"QuotetoCash08/27/2025\",\"customer_phone\":null,\"customer_shipping\":null,\"customer_tax_exempt\":\"none\",\"customer_tax_ids\":[],\"default_payment_method\":null,\"default_source\":null,\"default_tax_rates\":[],\"description\":null,\"discounts\":[],\"due_date\":null,\"effective_at\":1756801474,\"ending_balance\":0,\"footer\":null,\"from_invoice\":null,\"hosted_invoice_url\":\"https://invoice.stripe.com/i/acct_1R1YquPuJCefzpgm/test_YWNjdF8xUjFZcXVQdUpDZWZ6cGdtLF9TeW42UUtBQ2JnMGd6eHpqa0tneWg3YXV5Y2hsdXpnLDE0NzM1MTYwNg0200J535luVi?s=ap\",\"invoice_pdf\":\"https://pay.stripe.com/invoice/acct_1R1YquPuJCefzpgm/test_YWNjdF8xUjFZcXVQdUpDZWZ6cGdtLF9TeW42UUtBQ2JnMGd6eHpqa0tneWg3YXV5Y2hsdXpnLDE0NzM1MTYwNg0200J535luVi/pdf?s=ap\",\"issuer\":{\"type\":\"self\"},\"last_finalization_error\":null,\"latest_revision\":null,\"lines\":{\"object\":\"list\",\"data\":[{\"id\":\"il_1S2pW2PuJCefzpgm2xqNtEtE\",\"object\":\"line_item\",\"amount\":19900,\"currency\":\"usd\",\"description\":\"RaydiantScreenRayStandardN100\",\"discount_amounts\":[],\"discountable\":true,\"discounts\":[],\"invoice\":\"in_1S2pW2PuJCefzpgmpGy8biLr\",\"livemode\":false,\"metadata\":{},\"parent\":{\"invoice_item_details\":{\"invoice_item\":\"ii_1S2pW2PuJCefzpgmalwLeIuN\",\"proration\":false,\"proration_details\":{\"credited_items\":null},\"subscription\":\"sub_1S2pW3PuJCefzpgmjhIIz1nS\"},\"subscription_item_details\":null,\"type\":\"invoice_item_details\"},\"period\":{\"end\":1759393474,\"start\":1756801474},\"pretax_credit_amounts\":[],\"pricing\":{\"price_details\":{\"price\":\"price_1S2pV6PuJCefzpgmdsjFgoe8\",\"product\":\"prod_Squ82cbwNtiR6Q\"},\"type\":\"price_details\",\"unit_amount_decimal\":\"19900\"},\"quantity\":1,\"taxes\":[]}],\"has_more\":false,\"total_count\":3,\"url\":\"/v1/invoices/in_1S2pW2PuJCefzpgmpGy8biLr/lines\"},\"livemode\":false,\"metadata\":{},\"next_payment_attempt\":null,\"number\":\"FR0INIGA-0012\",\"on_behalf_of\":null,\"parent\":{\"quote_details\":null,\"subscription_details\":{\"metadata\":{},\"subscription\":\"sub_1S2pW3PuJCefzpgmjhIIz1nS\"},\"type\":\"subscription_details\"},\"payment_settings\":{\"default_mandate\":null,\"payment_method_options\":{\"acss_debit\":null,\"bancontact\":null,\"card\":{\"request_three_d_secure\":\"automatic\"},\"customer_balance\":null,\"konbini\":null,\"sepa_debit\":null,\"us_bank_account\":null},\"payment_method_types\":[\"card\"]},\"payments\":{\"object\":\"list\",\"data\":[{\"id\":\"inpay_1S2pW4PuJCefzpgm2gzoOR3P\",\"object\":\"invoice_payment\",\"amount_paid\":28800,\"amount_requested\":28800,\"created\":1756801474,\"currency\":\"usd\",\"invoice\":\"in_1S2pW2PuJCefzpgmpGy8biLr\",\"is_default\":true,\"livemode\":false,\"payment\":{\"payment_intent\":\"pi_3S2pW2PuJCefzpgm27pYjTZ1\",\"type\":\"payment_intent\"},\"status\":\"paid\",\"status_transitions\":{\"canceled_at\":null,\"paid_at\":1756801474}}],\"has_more\":false,\"url\":\"/v1/invoices/payments\"},\"period_end\":1756801474,\"period_start\":1756801474,\"post_payment_credit_notes_amount\":0,\"pre_payment_credit_notes_amount\":0,\"receipt_number\":null,\"rendering\":null,\"shipping_cost\":null,\"shipping_details\":null,\"starting_balance\":0,\"statement_descriptor\":null,\"status\":\"paid\",\"status_transitions\":{\"finalized_at\":1756801474,\"marked_uncollectible_at\":null,\"paid_at\":1756801474,\"voided_at\":null},\"subtotal\":28800,\"subtotal_excluding_tax\":28800,\"test_clock\":null,\"total\":28800,\"total_discount_amounts\":[],\"total_excluding_tax\":28800,\"total_pretax_credit_amounts\":[],\"total_taxes\":[],\"webhooks_delivered_at\":1756801474}';
            res.setBody(requestBody);
            return res;
        }
    }
    
    // Mock the Stripe API callout with Error
    class StripeMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            String requestBody = '{\"error\":{\"code\":\"card_declined\",\"decline_code\":\"do_not_honor\",\"doc_url\":\"https://stripe.com/docs/error-codes#card-declined\",\"message\":\"Yourcardwasdeclined.\",\"param\":\"card[number]\",\"type\":\"card_error\"}}';
            res.setBody(requestBody);
            return res;
        }
    }

    @IsTest
    static void testQueueableExecution_2ndInvoice() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Contract con = [SELECT Stripe_Subscription_ID__c FROM Contract LIMIT 1];

        Test.startTest();
        // Enqueue the queueable
        System.enqueueJob(
            new StripeInvoiceQueueable(
                'in_1S2pW2PuJCefzpgmpGy8biLr', 
                con.Stripe_Subscription_ID__c, 
                quote.Id, 
                true, 
                true
            )
        );
        Test.stopTest();

        // Assert Stripe Invoice created
        Stripe_Invoice__c inv = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Is_Payment_Done__c FROM Stripe_Invoice__c LIMIT 1];
        System.assertEquals('in_1S2pW2PuJCefzpgmpGy8biLr', inv.Stripe_Invoice_Id__c);
        System.assertEquals(false, inv.Is_Payment_Done__c);
        System.assertEquals(288, inv.Total_Amount__c);

        // Assert Stripe Invoice Line Item created
        Stripe_Invoice_Line_Item__c line = [SELECT Id, Stripe_Invoice_line_Item_Id__c, Quantity__c, Unit_Price__c FROM Stripe_Invoice_Line_Item__c LIMIT 1];
        System.assertEquals('il_1S2pW2PuJCefzpgm2xqNtEtE', line.Stripe_Invoice_line_Item_Id__c);
        System.assertEquals(1, line.Quantity__c);
        System.assertEquals(199, line.Unit_Price__c);
    }
    
    @IsTest
    static void testQueueableExecution_Q2IFirst() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        // Enqueue the queueable
        System.enqueueJob(
            new StripeInvoiceQueueable(
                'in_1S2pW2PuJCefzpgmpGy8biLr', 
                'sub_test_456', 
                quote.Id, 
                true, 
                true
            )
        );
        Test.stopTest();

        // Assert Stripe Invoice created
        Stripe_Invoice__c inv = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Is_Payment_Done__c FROM Stripe_Invoice__c LIMIT 1];
        System.assertEquals('in_1S2pW2PuJCefzpgmpGy8biLr', inv.Stripe_Invoice_Id__c);
        System.assertEquals(false, inv.Is_Payment_Done__c);
        System.assertEquals(288, inv.Total_Amount__c);

        // Assert Stripe Invoice Line Item created
        Stripe_Invoice_Line_Item__c line = [SELECT Id, Stripe_Invoice_line_Item_Id__c, Quantity__c, Unit_Price__c FROM Stripe_Invoice_Line_Item__c LIMIT 1];
        System.assertEquals('il_1S2pW2PuJCefzpgm2xqNtEtE', line.Stripe_Invoice_line_Item_Id__c);
        System.assertEquals(1, line.Quantity__c);
        System.assertEquals(199, line.Unit_Price__c);
    }
    
    @IsTest
    static void testQueueableExecution_Q2CFirst() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        // Enqueue the queueable
        System.enqueueJob(
            new StripeInvoiceQueueable(
                'in_1S2pW2PuJCefzpgmpGy8biLr', 
                'sub_test_456', 
                quote.Id, 
                true, 
                false
            )
        );
        Test.stopTest();

        // Assert Stripe Invoice created
        Stripe_Invoice__c inv = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Is_Payment_Done__c FROM Stripe_Invoice__c LIMIT 1];
        System.assertEquals('in_1S2pW2PuJCefzpgmpGy8biLr', inv.Stripe_Invoice_Id__c);
        System.assertEquals(false, inv.Is_Payment_Done__c);
        System.assertEquals(288, inv.Total_Amount__c);

        // Assert Stripe Invoice Line Item created
        Stripe_Invoice_Line_Item__c line = [SELECT Id, Stripe_Invoice_line_Item_Id__c, Quantity__c, Unit_Price__c FROM Stripe_Invoice_Line_Item__c LIMIT 1];
        System.assertEquals('il_1S2pW2PuJCefzpgm2xqNtEtE', line.Stripe_Invoice_line_Item_Id__c);
        System.assertEquals(1, line.Quantity__c);
        System.assertEquals(199, line.Unit_Price__c);
    }
    
    @IsTest
    static void testQueueableExecution_DMLException() {
        Test.setMock(HttpCalloutMock.class, new StripeMock());

        Test.startTest();
        // Enqueue the queueable
        System.enqueueJob(
            new StripeInvoiceQueueable(
                'invalid_invoiceId', 
                'invalid_subscriptionId', 
                'invalid_quoteId', 
                false, 
                false
            )
        );
        Test.stopTest();

        // Assert Stripe Invoice not created
        List<Stripe_Invoice__c> invs = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Is_Payment_Done__c FROM Stripe_Invoice__c];
		System.assertEquals(0, invs.size(), 'No invoices should be created');
        
        // Assert Logger created
        Integer loggerCount = [SELECT COUNT() FROM Logger__c];
        System.assertEquals(1, loggerCount, 'One logger should be created');
    }
    
    @IsTest
    static void testQueueableExecution_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new StripeMockError());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        Test.startTest();
        // Enqueue the queueable
        System.enqueueJob(
            new StripeInvoiceQueueable(
                'in_1S2pW2PuJCefzpgmpGy8biLr',
                'sub_test_456', 
                quote.Id, 
                true, 
                false
            )
        );
        Test.stopTest();

        // Assert Stripe Invoice not created
        List<Stripe_Invoice__c> invs = [SELECT Id, Stripe_Invoice_Id__c, Total_Amount__c, Is_Payment_Done__c FROM Stripe_Invoice__c];
		System.assertEquals(0, invs.size(), 'No invoices should be created');
        
        // Assert Logger created
        Integer loggerCount = [SELECT COUNT() FROM Logger__c];
        System.assertEquals(1, loggerCount, 'One logger should be created');
    }
}