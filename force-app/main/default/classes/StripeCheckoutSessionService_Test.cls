@IsTest
public class StripeCheckoutSessionService_Test {
    
    // Helper method to create mock session response
    private static String getMockSessionResponse() {
        return '{' +
            '"id": "cs_test_b1FKRhMU3tDzFmG1AR9Oerpy0HckFy9P6Z5RbOPUaLaEJlWcdOn3Auaaz5",' +
            '"object": "checkout.session",' +
            '"customer": "cus_test123",' +
            '"customer_details": {' +
            '  "address": {' +
            '    "line1": "123 Main St",' +
            '    "line2": "Apt 4B",' +
            '    "city": "New York",' +
            '    "state": "NY",' +
            '    "postal_code": "10001",' +
            '    "country": "US"' +
            '  }' +
            '},' +
            '"collected_information": {' +
            '  "shipping_details": {' +
            '    "address": {' +
            '    "line1": "456 Shipping Ave",' +
            '    "line2": "Suite 100",' +
            '    "city": "Los Angeles",' +
            '    "state": "CA",' +
            '    "postal_code": "90210",' +
            '    "country": "US"' +
            '    }' +
            '  }' +
            '},' +
            '"consent": {' +
            '  "terms_of_service": "accepted"' +
            '},' +
            '"custom_fields": [' +
            '  {' +
            '    "key": "signature",' +
            '    "text": {' +
            '      "value": "John Doe"' +
            '    }' +
            '  }' +
            ']' +
        '}';
    }
    
    // Mock HTTP response class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        private Boolean throwException;
        
        public MockHttpResponseGenerator(Integer statusCode, String responseBody, Boolean throwException) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.throwException = throwException;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            if (throwException) {
                CalloutException e = new CalloutException();
                e.setMessage('Mock callout exception');
                throw e;
            }
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Create custom setting data
        Stripe_Details__c stripeDetails = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456789',
            Publishable_Key__c = 'pk_test_123456789'
        );
        insert stripeDetails;
        
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Customer',
            Stripe_Customer_ID__c = 'cus_test123',
            BillingStreet = 'Old Billing Street',
            BillingCity = 'Old Billing City',
            ShippingStreet = 'Old Shipping Street',
            ShippingCity = 'Old Shipping City'
        );
        insert testAccount;
    }
    
    // Test successful session retrieval and account update
    @IsTest
    static void testGetCheckoutSession_Success() {
        // Setup mock response with complete session data
        String mockResponseBody = getMockSessionResponse();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockResponseBody, false));
        
        // Get the test account
        Account testAccount = [SELECT Id, Stripe_Customer_ID__c FROM Account WHERE Stripe_Customer_ID__c = 'cus_test123'];
        
        Test.startTest();
        // Call the future method
        StripeCheckoutSessionService.getCheckoutSession('cs_test_b1FKRhMU3tDzFmG1AR9Oerpy0HckFy9P6Z5RbOPUaLaEJlWcdOn3Auaaz5');
        Test.stopTest();
        
        // Verify the account was updated
        Account updatedAccount = [SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                                         ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                                         Stripe_Consent_Accepted__c, Stripe_Signature__c
                                  FROM Account 
                                  WHERE Stripe_Customer_ID__c = 'cus_test123'];
        
        // Assert billing address updates
        System.assertEquals('123 Main St', updatedAccount.BillingStreet, 'Billing street should be updated');
        System.assertEquals('New York', updatedAccount.BillingCity, 'Billing city should be updated');
        System.assertEquals('NY', updatedAccount.BillingState, 'Billing state should be updated');
        //System.assertEquals('10001', updatedAccount.BillingPostalCode, 'Billing postal code should be updated');
        //System.assertEquals('US', updatedAccount.BillingCountry, 'Billing country should be updated');
        
        // Assert shipping address updates
        System.assertEquals('456 Shipping Ave', updatedAccount.ShippingStreet, 'Shipping street should be updated');
        System.assertEquals('Los Angeles', updatedAccount.ShippingCity, 'Shipping city should be updated');
        System.assertEquals('CA', updatedAccount.ShippingState, 'Shipping state should be updated');
        //System.assertEquals('90210', updatedAccount.ShippingPostalCode, 'Shipping postal code should be updated');
        //System.assertEquals('US', updatedAccount.ShippingCountry, 'Shipping country should be updated');
        
        // Assert consent and signature
        System.assertEquals('accepted', updatedAccount.Stripe_Consent_Accepted__c, 'Consent should be accepted');
        System.assertEquals('John Doe', updatedAccount.Stripe_Signature__c, 'Signature should be updated');
    }
}