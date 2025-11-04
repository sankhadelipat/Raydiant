@isTest
public class StripeCustomerQueueable_Test {
    
    // Mock for Stripe response
    private class StripeCustomerMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            //System.assertEquals('GET', req.getMethod());
            System.assert(req.getEndpoint().contains('https://api.stripe.com/v1/customers/'));
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Sample Stripe JSON response
            String body = '{'+
                '"id": "cus_test123",'+
                '"name": "John Doe",'+
                '"email": "johndoe@test.com",'+
                '"phone": "9999999999",'+
                '"currency": "usd",'+
                '"description": "Test Stripe Customer",'+
                '"address": {'+
                    '"line1": "123 Main St",'+
                    '"city": "Pune",'+
                    '"state": "MH",'+
                    '"postal_code": "411001",'+
                    '"country": "IN"'+
                '},'+
                '"shipping": {'+
                    '"address": {'+
                        '"line1": "456 Market Rd",'+
                        '"city": "Mumbai",'+
                        '"state": "MH",'+
                        '"postal_code": "400001",'+
                        '"country": "IN"'+
                    '}'+
                '}'+
            '}';
            res.setBody(body);
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        // Insert Stripe Details (Custom Setting)
        Stripe_Details__c details = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert details;
        
        // Insert a Stripe Org Account
        insert new stripeGC__Stripe_Account__c(Name = 'Test Stripe Org');
    }
    
    @isTest
    static void testQueueableSuccess() {
        Test.startTest();
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new StripeCustomerMock());
        
        // Enqueue the job
        System.enqueueJob(new StripeCustomerQueueable('cus_test123'));
        
        Test.stopTest();
        
        // Verify Account was created
        Account acc = [SELECT Id, Name, Stripe_Customer_ID__c, Phone, Dashboard_Email__c, BillingCity, ShippingCity 
                       FROM Account WHERE Stripe_Customer_ID__c = 'cus_test123' LIMIT 1];
        System.assertNotEquals(null, acc);
        System.assertEquals('John Doe', acc.Name);
        System.assertEquals('9999999999', acc.Phone);
        System.assertEquals('johndoe@test.com', acc.Dashboard_Email__c);
        System.assertEquals('Pune', acc.BillingCity);
        System.assertEquals('Mumbai', acc.ShippingCity);
        
        // Verify Contact was created
        Contact con = [SELECT Id, Email, AccountId FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        System.assertEquals('johndoe@test.com', con.Email);
    }
    
    // Negative test case - Stripe returns error
    private class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid Request"}');
            return res;
        }
    }
    
    @isTest
    static void testQueueableFailure() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        System.enqueueJob(new StripeCustomerQueueable('cus_invalid'));
        
        Test.stopTest();
        
        // Logger should be created due to error
        Logger__c log = [SELECT Id, Status__c, Apex_Class__c 
                         FROM Logger__c 
                         WHERE Apex_Class__c = 'StripeCustomerQueueable' 
                         LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }
}