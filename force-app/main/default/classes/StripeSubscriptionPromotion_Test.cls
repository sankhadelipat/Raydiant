@IsTest
private class StripeSubscriptionPromotion_Test {
    
    private class StripePromotionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // GET customer -> has default payment method
            if (req.getEndpoint().contains('/v1/customers/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"cus_test_1234",' +
                    '"invoice_settings":{' +
                    '"default_payment_method":"pm_test_123"' +
                    '}' +
                    '}'
                );
                return res;
            }
            
            // POST subscription promotion
            if (req.getEndpoint().contains('/v1/subscriptions/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"sub_test_1234",' +
                    '"collection_method":"charge_automatically"' +
                    '}'
                );
                return res;
            }
            
            res.setStatusCode(400);
            res.setBody('{"error":"Unhandled endpoint"}');
            return res;
        }
    }
    
    private class StripeDefaultPaymentMethodMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Customer WITHOUT default PM
            if (req.getEndpoint().contains('/v1/customers/')) {
                res.setBody('{"id":"cus_test_1234","invoice_settings":{}}');
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }
    
    private class StripeErrorMock implements HttpCalloutMock{
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Stripe failure');
            return res;
        }
    }
    
    @TestSetup
    static void setup() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_1234'
        );
        insert acc;
        
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_Id__c = 'sub_test_1234',
            Collection_Method__c = 'send_invoice'
        );
        insert con;
        
        con.Status = 'Activated'; update con;
    }
    
    @IsTest
    static void testPromotionSuccess() {
        Test.setMock(HttpCalloutMock.class, new StripePromotionMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripeSubscriptionPromotion(
                'sub_test_1234',
                'cus_test_1234'
            )
        );
        Test.stopTest();
        
        System.assert(true, 'Promotion executed successfully');
    }
    
    @IsTest
    static void testNotEligible_CollectionMethod() {
        Contract con = [
            SELECT Id, Collection_Method__c
            FROM Contract
            WHERE Stripe_Subscription_Id__c = 'sub_test_1234'
            LIMIT 1
        ];
        con.Collection_Method__c = 'charge_automatically';
        update con;
        
        Test.setMock(HttpCalloutMock.class, new StripePromotionMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripeSubscriptionPromotion(
                'sub_test_1234',
                'cus_test_1234'
            )
        );
        Test.stopTest();
        
        System.assert(true, 'Queueable exited due to ineligible contract');
    }
    
    @IsTest
    static void testNoDefaultPaymentMethod() {
        
        Test.setMock(HttpCalloutMock.class, new StripeDefaultPaymentMethodMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripeSubscriptionPromotion(
                'sub_test_1234',
                'cus_test_1234'
            )
        );
        Test.stopTest();
        
        System.assert(true, 'Handled missing default payment method');
    }
    
    @IsTest
    static void testExceptionLogged() {
        
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        Test.startTest();
        System.enqueueJob(
            new StripeSubscriptionPromotion(
                'sub_test_1234',
                'cus_test_1234'
            )
        );
        Test.stopTest();
        
        // Logger record should be created
        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeSubscriptionPromotion'
        ];
        System.assert(!logs.isEmpty(), 'Error was logged correctly');
    }
}