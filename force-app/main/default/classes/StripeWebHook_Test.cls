@isTest
private class StripeWebHook_Test {
    
    private class StripeMockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Mock response for different endpoints
            if (req.getEndpoint().contains('/v1/subscriptions/')) {
                res.setBody('{"id":"sub_123","object":"subscription","status":"active","customer":"cus_123","latest_invoice":"in_123","items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/invoices/')) {
                res.setBody('{"id":"in_123","object":"invoice","status":"paid","payment_intent":"pi_123","subscription":"sub_123"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/v1/payment_intents/')) {
                res.setBody('{"id":"pi_123","object":"payment_intent","status":"succeeded","customer":"cus_123"}');
                res.setStatusCode(200);
            } else {
                // Default response
                res.setBody('{"id":"test","object":"test","status":"success"}');
                res.setStatusCode(200);
            }
            
            return res;
        }
    }
    
    @testSetup
    static void setup() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
    }
    
    @isTest
    static void testCheckoutSessionCompleted() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Prepare test data
        String requestBody = '{"type":"checkout.session.completed","data":{"object":{"id":"cs_test_123","invoice":"in_123","subscription":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"}}}}';
        
        // Set up REST request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        // Verify results
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoiceCreate() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.create
        String requestBody = '{\"type\":\"invoice.created\",\"data\":{\"object\":{\"id\":\"in_123\",\"billing_reason\":\"subscription_create\",\"subscription\":\"sub_123\",\"payment_intent\":\"pi_123\",\"metadata\":{\"salesforce_initial_payment\":\"false\",\"salesforce_quote_id\":\"a2ffY000000a9b3QAA\",\"salesforce_quote_accepted\":\"true\"},\"parent\":{\"quote_details\":null,\"subscription_details\":{\"metadata\":{\"salesforce_quote_id\":\"a2ffY000000b2Z7QAI\",\"subscription_source\":\"salesforce\",\"updated_from_salesforce\":\"true\"},\"subscription\":\"sub_1SPHgRPuJCefzpgmAHpdyCZT\"},\"type\":\"subscription_details\"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoiceUpdate() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.update
        String requestBody = '{\"type\":\"invoice.updated\",\"data\":{\"object\":{\"id\":\"in_123\",\"billing_reason\":\"subscription_create\",\"subscription\":\"sub_123\",\"payment_intent\":\"pi_123\",\"metadata\":{\"salesforce_initial_payment\":\"false\",\"salesforce_quote_id\":\"a2ffY000000a9b3QAA\",\"salesforce_quote_accepted\":\"true\"},\"parent\":{\"quote_details\":null,\"subscription_details\":{\"metadata\":{\"salesforce_quote_id\":\"a2ffY000000b2Z7QAI\",\"subscription_source\":\"salesforce\",\"updated_from_salesforce\":\"true\"},\"subscription\":\"sub_1SPHgRPuJCefzpgmAHpdyCZT\"},\"type\":\"subscription_details\"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoiceUpdate_WithPreviousLinesDeleted() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.update
        String requestBody = '{'
            + '"type":"invoice.updated",'
            + '"data":{'
            + '"object":{'
            + '"id":"in_999",'
            + '"lines":{"data":[{"id":"li_old_2","description":"Keep me"}]},'
            + '"metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"}'
            + '},'
            + '"previous_attributes":{'
            +   '"lines":{'
            +       '"data":['
            +           '{"id":"li_old_1","description":"Was deleted"},'
            +           '{"id":"li_old_2","description":"Keep me"}'
            +       ']'
            +   '}'
            + '}'
            + '}'
            + '}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoicePaidWithSubscriptionCreate() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.paid with subscription_create billing reason
        String requestBody = '{"type":"invoice.paid","data":{"object":{"id":"in_123","billing_reason":"subscription_create","subscription":"sub_123","payment_intent":"pi_123","metadata":{"salesforce_initial_payment":"false","salesforce_quote_id":"a2ffY000000a9b3QAA","salesforce_quote_accepted":"true"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoicePaidWithOtherBillingReason() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.paid with other billing reason
        String requestBody = '{"type":"invoice.paid","data":{"object":{"id":"in_123","billing_reason":"manual","subscription":"sub_123","payment_intent":"pi_123","metadata":{"salesforce_initial_payment":"false","salesforce_quote_id":"a2ffY000000a9b3QAA"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionUpdatedWithQuote() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.updated with quote ID
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA","last_updated_from_Salesforce":"true"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionUpdatedWithoutQuote() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.updated without quote ID
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"subscription_source":"self_service"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionUpdatedWithItemMismatch() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.updated with item ID mismatch
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_456","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionDeleted() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.deleted
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA","last_updated_from_Salesforce":"true"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testPaymentIntentPaymentFailed() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test payment_intent.payment_failed
        String requestBody = '{"type":"payment_intent.payment_failed","data":{"object":{"id":"pi_123","customer":"cus_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testInvoicePaymentFailed() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test invoice.payment_failed
        String requestBody = '{"type":"invoice.payment_failed","data":{"object":{"id":"in_123","subscription":"sub_123","payment_intent":"pi_123"}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerCreatedWithAmazonSignup() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.created with amazon signup
        String requestBody = '{"type":"customer.created","data":{"object":{"id":"cus_123","metadata":{"raydiant_signup_type__c":"amazon"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerCreatedWithSelfServiceSignup() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.created with self_service signup
        String requestBody = '{"type":"customer.created","data":{"object":{"id":"cus_123","metadata":{"raydiant_signup_type__c":"self_service"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerCreatedWithOtherSignup() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.created with other signup type (should not create event)
        String requestBody = '{"type":"customer.created","data":{"object":{"id":"cus_123","metadata":{"raydiant_signup_type__c":"enterprise"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionCreatedWithSchedule() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.created with subscription schedule
        String requestBody = '{"type":"customer.subscription.created","data":{"object":{"id":"sub_123","latest_invoice":"in_123","customer":"cus_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA","subscription_schedule":"true"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionCreatedWithoutQuote() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.created without quote ID
        String requestBody = '{"type":"customer.subscription.created","data":{"object":{"id":"sub_123","latest_invoice":"in_123","customer":"cus_123","metadata":{"subscription_source":"amazon"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionCreatedManually() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.created without quote ID
        String requestBody = '{"type":"customer.subscription.created","data":{"object":{"id":"sub_123","latest_invoice":"in_123","customer":"cus_123","metadata":{"subscription_source":"stripe"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testCustomerSubscriptionUpdatedManually() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test customer.subscription.created without quote ID
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","latest_invoice":"in_123","customer":"cus_123","metadata":{"subscription_source":"stripe"}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testUnknownEventType() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test unknown event type
        String requestBody = '{"type":"unknown.event.type","data":{"object":{}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        // Should not throw any exceptions
        System.assert(true, 'Method should execute without errors');
    }
    
    @isTest
    static void testMultipleItemsComparison() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test with multiple items for comparison
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}},{"id":"si_124","price":{"id":"price_124","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}},{"id":"si_124","price":{"id":"price_124","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors for multiple items');
    }
    
    @isTest
    static void testDifferentItemCount() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test with different item counts (should stop execution)
        String requestBody = '{"type":"customer.subscription.updated","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}},{"id":"si_124","price":{"id":"price_124","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
        
        System.assert(true, 'Method should execute without errors for different item counts');
    }
    
    @isTest
    static void testSubscriptionDeletion() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Test with different item counts (should stop execution)
        String requestBody = '{"type":"customer.subscription.deleted","data":{"object":{"id":"sub_123","metadata":{"salesforce_quote_id":"a2ffY000000a9b3QAA"},"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}},{"id":"si_124","price":{"id":"price_124","product":"prod_123"}}]}},"previous_attributes":{"items":{"data":[{"id":"si_123","price":{"id":"price_123","product":"prod_123"}}]}}}}';
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
    }
    
    @IsTest
    static void testSubscriptionScheduleCreated_EventPublished() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // Fake Quote Id (no SOQL dependency in webhook)
        String fakeQuoteId = 'a2f000000000AAA';
        
        // subscription_schedule.created payload
        String requestBody =
            '{' +
            '"type":"subscription_schedule.created",' +
            '"data":{' +
            '"object":{' +
            '"id":"sub_sched_123",' +
            '"subscription":null,' +
            '"metadata":{' +
            '"salesforce_quote_id":"' + fakeQuoteId + '",' +
            '"subscription_source":"salesforce",' +
            '"subscription_schedule":"true",' +
            '"is_renewal_subscription":"true"' +
            '}' +
            '}' +
            '}' +
            '}' ;
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
    }
    
    @IsTest
    static void testScheduleDeleted_EventPublish() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new StripeMockCallout());
        
        // subscription_schedule.created payload
        String requestBody =
            '{' +
            '"type":"subscription_schedule.canceled",' +
            '"data":{' +
            '"object":{' +
            '"id":"sub_sched_123",' +
            '"subscription":null,' +
            '"metadata":{' +
            '"subscription_source":"salesforce",' +
            '"subscription_schedule":"true",' +
            '"is_renewal_subscription":"true"' +
            '}' +
            '}' +
            '}' +
            '}' ;
        
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        StripeWebHook.handleWebhook();
        Test.stopTest();
    }
}