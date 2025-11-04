@IsTest
public class StripePaymentMethodCreator_Test {

    // Mock response for a successful Stripe Payment Method GET call
    private class StripeHttpMock implements HttpCalloutMock {
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
                '"card":{"brand":"visa","country":"US","exp_month":12,"exp_year":2030,"funding":"credit"}' +
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
                '"id":"pm_12345",' +
                '"type":"us_bank_account",' +
                '"created":1693363200,' +
                '"customer":"cus_12345",' +
                '"billing_details":{"name":"John Doe","email":"john@example.com","phone":"1234567890","address":{"line1":"123 Main St","city":"Cityville","postal_code":"12345","country":"US"}},' +
                '"us_bank_account":{"brand":"visa","country":"US","exp_month":12,"exp_year":2030,"funding":"credit"}' +
            '}');
            return res;
        }
    }
    
     // Mock response for a successful Stripe Payment Method GET call
    private class StripeHttpMock3 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Mocked JSON response
             // Mocked JSON response
            res.setBody('{' +
                '"id":"pm_12345",' +
                '"type":"klarna",' +
                '"created":1693363200,' +
                '"customer":"cus_12345",' +
                '"billing_details":{"name":"John Doe","email":"john@example.com","phone":"1234567890","address":{"line1":"123 Main St","city":"Cityville","postal_code":"12345","country":"US"}},' +
                '"klarna":{"brand":"visa","country":"US","exp_month":12,"exp_year":2030,"funding":"credit"}' +
            '}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name='Test Account');
        insert acc;

           SBQQ__Quote__c quote = new SBQQ__Quote__c(
            //Name = 'Test Quote',
            SBQQ__Account__c = acc.Id
        );
        insert quote;
    
        // Create Stripe Details record for tests
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456'
        );
        insert sd;
    }

    @IsTest
    static void testCreatePaymentMethod_Success() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        // Call the future method
        StripePaymentMethodCreator.createPaymentMethod('pm_12345', null, quote.Id, null);

        // Execute future methods
        Test.stopTest();

        // Validate the Stripe_Payment_Method__c record
        Stripe_Payment_Method__c pm = [SELECT Name, Payment_Method_Type__c, Payer_Name__c, Payer_Email__c,
                                       Card_Brand__c, Card_Expiry_Month__c, Card_Expiry_Year__c
                                       FROM Stripe_Payment_Method__c WHERE Stripe_Payment_Method_ID__c='pm_12345' LIMIT 1];

        System.assertEquals('PMR - pm_12345', pm.Name);
        System.assertEquals('card', pm.Payment_Method_Type__c);
        System.assertEquals('John Doe', pm.Payer_Name__c);
        System.assertEquals('john@example.com', pm.Payer_Email__c);
        System.assertEquals('visa', pm.Card_Brand__c);
        System.assertEquals('12', pm.Card_Expiry_Month__c);
        System.assertEquals('2030', pm.Card_Expiry_Year__c);
    }
     @IsTest
    static void testCreatePaymentMethod_Success1() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock2());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        // Call the future method
        StripePaymentMethodCreator.createPaymentMethod('pm_12345', null, quote.Id, null);

        // Execute future methods
        Test.stopTest();

        // Validate the Stripe_Payment_Method__c record
        Stripe_Payment_Method__c pm = [SELECT Name, Payment_Method_Type__c, Payer_Name__c, Payer_Email__c,
                                       Card_Brand__c, Card_Expiry_Month__c, Card_Expiry_Year__c
                                       FROM Stripe_Payment_Method__c WHERE Stripe_Payment_Method_ID__c='pm_12345' LIMIT 1];

        System.assertEquals('PMR - pm_12345', pm.Name);
        System.assertEquals('us_bank_account', pm.Payment_Method_Type__c);
        System.assertEquals('John Doe', pm.Payer_Name__c);
        System.assertEquals('john@example.com', pm.Payer_Email__c);
       // System.assertEquals('visa', pm.Card_Brand__c);
       // System.assertEquals('12', pm.Card_Expiry_Month__c);
        //System.assertEquals('2030', pm.Card_Expiry_Year__c);
    }
    
     @IsTest
    static void testCreatePaymentMethod_Success2() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock3());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        // Call the future method
        StripePaymentMethodCreator.createPaymentMethod('pm_12345', null, quote.Id, null);

        // Execute future methods
        Test.stopTest();

        // Validate the Stripe_Payment_Method__c record
        Stripe_Payment_Method__c pm = [SELECT Name, Payment_Method_Type__c, Payer_Name__c, Payer_Email__c,
                                       Card_Brand__c, Card_Expiry_Month__c, Card_Expiry_Year__c, Klarna_DOB__c
                                       FROM Stripe_Payment_Method__c WHERE Stripe_Payment_Method_ID__c='pm_12345' LIMIT 1];

        System.assertEquals('PMR - pm_12345', pm.Name);
        System.assertEquals('klarna', pm.Payment_Method_Type__c);
        System.assertEquals('John Doe', pm.Payer_Name__c);
        System.assertEquals('john@example.com', pm.Payer_Email__c);
        System.assertEquals('visa', pm.Card_Brand__c);
        System.assertEquals('12', pm.Card_Expiry_Month__c);
        System.assertEquals('2030', pm.Card_Expiry_Year__c);
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

    @IsTest
    static void testCreatePaymentMethod_Failure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

        // Call the future method which will fail
        StripePaymentMethodCreator.createPaymentMethod('pm_fail', null, quote.Id, null);
        Test.stopTest();

        // Validate that a Logger__c record is inserted
        Logger__c log = [SELECT Name, Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripePaymentMethodCreator' LIMIT 1];
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Message__c.contains('Failed to retrieve payment method'));
    }
}