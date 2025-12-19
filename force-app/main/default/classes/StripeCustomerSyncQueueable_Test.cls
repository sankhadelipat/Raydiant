@isTest
public class StripeCustomerSyncQueueable_Test {

    // ------------------------------
    // MOCK FOR SUCCESS (200)
    // ------------------------------
    private class StripeSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            // Stripe returns an ID on create or update
            String jsonBody = '{ "id": "cus_test_sync_123" }';

            res.setBody(jsonBody);
            return res;
        }
    }

    // ------------------------------
    // MOCK FOR ERROR (400)
    // ------------------------------
    private class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{ "error": "Invalid Request" }');
            return res;
        }
    }

    // ------------------------------
    // COMMON TEST DATA
    // ------------------------------
    @testSetup
    static void setupData() {

        // Required Custom Setting
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );

        // Required Stripe Org Account
        insert new stripeGC__Stripe_Account__c(
            Name = 'Test Stripe Org'
        );
    }

    // --------------------------------------------------------
    // TEST 1: CREATE STRIPE CUSTOMER WHEN ACCOUNT HAS NO ID
    // --------------------------------------------------------
    @isTest
    static void testCreateStripeCustomer() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeSuccessMock());

        // Account without Stripe ID → triggers CREATE branch
        Account acc = new Account(
            Name = 'Test Create ACC',
            BillingStreet = 'ABC Street',
            BillingCity = 'Brooklyn',
            BillingState = 'New York',
            BillingPostalCode = '13433',
            BillingCountry = 'US',
            ShippingStreet = 'ABC Street',
            ShippingCity = 'Brooklyn',
            ShippingState = 'New York',
            ShippingPostalCode = '13433',
            ShippingCountry = 'US'
        );
        insert acc;

        Test.stopTest();

        // Fetch updated account
        Account updatedAcc = [
            SELECT Stripe_Customer_ID__c, Stripe_Customer_URL__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertNotEquals(null, updatedAcc.Stripe_Customer_ID__c, 'Stripe ID must be populated');
        System.assert(updatedAcc.Stripe_Customer_URL__c.contains(updatedAcc.Stripe_Customer_ID__c));
    }


    // --------------------------------------------------------
    // TEST 2: UPDATE STRIPE CUSTOMER WHEN ACCOUNT HAS ID
    // --------------------------------------------------------
    @isTest
    static void testUpdateStripeCustomer() {
		Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeSuccessMock());

        // Account with existing Stripe ID → triggers UPDATE branch
        Account acc = new Account(
            Name = 'Test Update ACC',
            Stripe_Customer_ID__c = 'cus_test_sync_123',
            Raydiant_Signup_Type__c = 'salesforce'
        );
        insert acc;
        
        Account updatedAcc = new Account(
            Id = acc.Id,
            BillingStreet = 'ABC Street',
            BillingCity = 'Brooklyn',
            BillingState = 'New York',
            BillingPostalCode = '13433',
            BillingCountry = 'US',
            ShippingStreet = 'ABC Street',
            ShippingCity = 'Brooklyn',
            ShippingState = 'New York',
            ShippingPostalCode = '13433',
            ShippingCountry = 'US'
        );
        update updatedAcc;

        Test.stopTest();

        // Verify no exception and account still exists
        updatedAcc = [
            SELECT Id, Stripe_Customer_ID__c 
            FROM Account 
            WHERE Id = :acc.Id
        ];

        System.assertEquals('cus_test_sync_123', updatedAcc.Stripe_Customer_ID__c);
    }


    // --------------------------------------------------------
    // TEST 3: FAILURE PATH → Stripe returns an error
    // --------------------------------------------------------
    @isTest
    static void testStripeCalloutFailure() {

        // Fails because Stripe API returns 400
        Account acc = new Account(
            Name = 'Fail ACC'
        );
        insert acc;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());

        System.enqueueJob(new StripeCustomerSyncQueueable('CREATE', new Set<Id>{ acc.Id }));

        Test.stopTest();

        // Verify a Logger__c entry was created
        Logger__c log = [
            SELECT Id, Status__c, Apex_Class__c
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeCustomerSyncQueueable'
            LIMIT 1
        ];

        System.assertEquals('Error', log.Status__c);
    }
}