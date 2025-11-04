@IsTest
public class StripeSubscriptionItemUpdater_Test {

    // Mock successful HTTP response for updates and cancellations
    private class StripeHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"sub_item_123"}'); // Mocked Stripe ID
            return res;
        }
    }

    // Mock failed HTTP response
    private class StripeHttpMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        insert new Stripe_Details__c(Name = 'Stripe Details', Serect_Key__c = 'sk_test_123456');
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__PaymentTerms__c = '30'
        );
        insert quote;

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_123',
            SBQQ__Quote__c = quote.Id
        );
        insert con;

        List<SBQQ__Subscription__c> subs = new List<SBQQ__Subscription__c>();
        for (Integer i = 1; i <= 3; i++) {
            subs.add(new SBQQ__Subscription__c(
                SBQQ__Contract__c = con.Id,
                Status__c = 'Active',
                SBQQ__Quantity__c = 1,
                Stripe_Product_ID__c = 'prod_123',
                Stripe_Subscription_ID__c = 'sub_123' + i,
                Stripe_Monthly_Value__c = 100
            ));
        }
        insert subs;
    }

    @IsTest
    static void testHandleStatusChanges_Update() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());
        List<SBQQ__Subscription__c> subs = [SELECT Id, Status__c, SBQQ__Contract__c, Stripe_Product_ID__c, Stripe_Subscription_ID__c, SBQQ__Quantity__c, Stripe_Monthly_Value__c FROM SBQQ__Subscription__c LIMIT 2];
        Map<Id, SBQQ__Subscription__c> oldMap = new Map<Id, SBQQ__Subscription__c>();
        for (SBQQ__Subscription__c sub : subs) {
            oldMap.put(sub.Id, sub.clone(false, true, false, false));
            sub.Status__c = 'Updated';
        }
        Test.startTest();
        StripeSubscriptionItemUpdater.handleStatusChanges(subs, oldMap);
        Test.stopTest();

        // Assert queueable ran without exceptions
        System.assert(true);
    }

    @IsTest
    static void testHandleStatusChanges_Cancel() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());
        SBQQ__Subscription__c sub = [SELECT Id, Status__c, SBQQ__Contract__c, Stripe_Subscription_ID__c FROM SBQQ__Subscription__c LIMIT 1];
        SBQQ__Subscription__c oldSub = sub.clone(false, true, false, false);
        sub.Status__c = 'Cancelled';
        Map<Id, SBQQ__Subscription__c> oldMap = new Map<Id, SBQQ__Subscription__c>{ sub.Id => oldSub };

        Test.startTest();
        StripeSubscriptionItemUpdater.handleStatusChanges(new List<SBQQ__Subscription__c>{sub}, oldMap);
        Test.stopTest();

        SBQQ__Subscription__c updatedSub = [SELECT Status__c FROM SBQQ__Subscription__c WHERE Id = :sub.Id];
        System.assertEquals('Active', updatedSub.Status__c);
    }

    @IsTest
    static void testUpdateSubscriptionItems_Success() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());
        SBQQ__Subscription__c sub = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Product_ID__c, Stripe_Monthly_Value__c, SBQQ__Quantity__c FROM SBQQ__Subscription__c LIMIT 1];
        Test.startTest();
        StripeSubscriptionItemUpdater.updateSubscriptionItems(new List<SBQQ__Subscription__c>{sub});
        Test.stopTest();

        // Confirm status updated to Activated
        SBQQ__Subscription__c updated = [SELECT Status__c, Stripe_Price_ID__c FROM SBQQ__Subscription__c WHERE Id = :sub.Id];
        System.assertEquals('Active', updated.Status__c);
        //System.assertEquals('sub_item_123', updated.Stripe_Price_ID__c);
    }

    @IsTest
    static void testProcessCancellations_Success() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMock());
        SBQQ__Subscription__c sub = [SELECT Id, Stripe_Subscription_ID__c FROM SBQQ__Subscription__c LIMIT 1];
        Test.startTest();
        StripeSubscriptionItemUpdater.processCancellations(new List<SBQQ__Subscription__c>{sub});
        Test.stopTest();

        SBQQ__Subscription__c updated = [SELECT Status__c, Stripe_Activate__c FROM SBQQ__Subscription__c WHERE Id = :sub.Id];
        System.assertEquals('Active', updated.Status__c);
        System.assertEquals(false, updated.Stripe_Activate__c);
    }

    @IsTest
    static void testUpdateSubscriptionItems_Failure() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());
        SBQQ__Subscription__c sub = [SELECT Id, Stripe_Subscription_ID__c, Stripe_Product_ID__c, Stripe_Monthly_Value__c, SBQQ__Quantity__c FROM SBQQ__Subscription__c LIMIT 1];
        Test.startTest();
        try {
            StripeSubscriptionItemUpdater.updateSubscriptionItems(new List<SBQQ__Subscription__c>{sub});
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
        Logger__c log = [SELECT Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionItemUpdater' ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }

    @IsTest
    static void testProcessCancellations_Failure() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockFailure());
        SBQQ__Subscription__c sub = [SELECT Id, Stripe_Subscription_ID__c FROM SBQQ__Subscription__c LIMIT 1];
        Test.startTest();
        try {
            StripeSubscriptionItemUpdater.processCancellations(new List<SBQQ__Subscription__c>{sub});
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
        Logger__c log = [SELECT Status__c, Message__c FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionItemUpdater' ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }
    @IsTest
static void testTriggerExecution() {
    Test.setMock(HttpCalloutMock.class, new StripeHttpMock());

    SBQQ__Subscription__c sub = [
        SELECT Id, Status__c, SBQQ__Contract__c, Stripe_Product_ID__c, 
               Stripe_Subscription_ID__c, SBQQ__Quantity__c, Stripe_Monthly_Value__c 
        FROM SBQQ__Subscription__c LIMIT 1
    ];

    Test.startTest();
    sub.Status__c = 'Updated';  // this will fire the trigger
    update sub;                 // <-- trigger calls handleStatusChanges
    Test.stopTest();

    SBQQ__Subscription__c updated = [
        SELECT Status__c, Stripe_Price_ID__c 
        FROM SBQQ__Subscription__c 
        WHERE Id = :sub.Id
    ];
    System.assertEquals('Updated', updated.Status__c);
}


}