@IsTest
public class StripePaymentMethodQueueable_Test {
    
    // Mock response for a successful Stripe Payment Method GET call
    private class StripeHttpMock1 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Mocked JSON response
            res.setBody('{' +
                        '"id":"pm_12345",' +
                        '"type":"card",' +
                        '"created":1693363200,' +
                        '"customer":"cus_12345",' +
                        '"billing_details":{"name":"John Doe","email":"john@example.com","phone":"1234567890","address":{"line1":"123 Main St","city":"Cityville","postal_code":"12345","country":"US"}},' +
                        '"card":{"brand":"visa","country":"US","exp_month":12,"exp_year":2030,"funding":"credit","last4":"4242"}' +
                        '}');
            return res;
        }
    }
    
    // Mock response for a successful Stripe Payment Method GET call
    private class StripeHttpMock2 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Mocked JSON response
            res.setBody('{' +
                        '"id":"pm_123456",' +
                        '"type":"us_bank_account",' +
                        '"created":1693363200,' +
                        '"customer":"cus_12345",' +
                        '"billing_details":{"name":"John Doe","email":"john@example.com","phone":"1234567890","address":{"line1":"123 Main St","city":"Cityville","postal_code":"12345","country":"US"}},' +
                        '"us_bank_account":{"account_type":"checking","account_holder_type":"individual","bank_name":"TRUIST BANK","fingerprint":"truist_78hmnnjknjs234a","last4":"4444"}' +
                        '}');
            return res;
        }
    }
    
    // Test scenario when callout fails and error is logged
    private class StripeHttpMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        // Create Stripe Details record for tests
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        insert sd;
        
        Account acc = new Account(
            Name='Test Account',
            Stripe_Customer_ID__c = 'cus_12345'
        );
        insert acc;
    }
    
    @IsTest
    static void testCreatePaymentMethod_Success1() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock1());
        
        // Call the future method
        System.enqueueJob(new StripePaymentMethodQueueable('pm_12345'));
        
        // Execute future methods
        Test.stopTest();
        
        // Validate the Stripe_Payment_Method__c record
        Stripe_Payment_Method__c pm = [SELECT Name, Payment_Method_Type__c, Payer_Name__c, Payer_Email__c,
                                       Card_Brand__c, Card_Expiry_Month__c, Card_Expiry_Year__c, Card_Last_4__c
                                       FROM Stripe_Payment_Method__c WHERE Stripe_Payment_Method_ID__c='pm_12345' LIMIT 1];
        
        System.assertEquals('visa - 4242', pm.Name);
        System.assertEquals('card', pm.Payment_Method_Type__c);
        System.assertEquals('John Doe', pm.Payer_Name__c);
        System.assertEquals('john@example.com', pm.Payer_Email__c);
        System.assertEquals('visa', pm.Card_Brand__c);
        System.assertEquals('12', pm.Card_Expiry_Month__c);
        System.assertEquals('2030', pm.Card_Expiry_Year__c);
    }
    @IsTest
    static void testCreatePaymentMethod_Success2() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock2());
        
        // Call the future method
        System.enqueueJob(new StripePaymentMethodQueueable('pm_123456'));
        
        // Execute future methods
        Test.stopTest();
        
        // Validate the Stripe_Payment_Method__c record
        Stripe_Payment_Method__c pm = [SELECT Name, Payment_Method_Type__c, Payer_Name__c, Payer_Email__c,
                                       Bank_Account_Type__c, Bank_Name__c, Bank_Account_Holder_Type__c, Bank_Last_4__c
                                       FROM Stripe_Payment_Method__c WHERE Stripe_Payment_Method_ID__c='pm_123456' LIMIT 1];
        
        System.assertEquals('TRUIST BANK - 4444', pm.Name);
        System.assertEquals('us_bank_account', pm.Payment_Method_Type__c);
        System.assertEquals('John Doe', pm.Payer_Name__c);
        System.assertEquals('john@example.com', pm.Payer_Email__c);
        System.assertEquals('checking', pm.Bank_Account_Type__c);
        System.assertEquals('TRUIST BANK', pm.Bank_Name__c);
        System.assertEquals('individual', pm.Bank_Account_Holder_Type__c);
    }
    
    @IsTest
    static void testCreatePaymentMethod_Failure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());
        
        // Call the future method which will fail
        System.enqueueJob(new StripePaymentMethodQueueable('pm_fail'));
        Test.stopTest();
        
        // Validate that a Logger__c record is inserted
        Logger__c log = [SELECT Name, Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripePaymentMethodQueueable' LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Message__c.contains('Failed to retrieve payment method'));
    }
}