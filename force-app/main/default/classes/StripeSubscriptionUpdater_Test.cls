@IsTest
private class StripeSubscriptionUpdater_Test {
    
    // --- Fake HTTP mock for Stripe ---
    private class StripeHttpMock implements System.HttpCalloutMock {
        private Integer status;
        private String body;
        public StripeHttpMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public System.HttpResponse respond(System.HttpRequest req) {
            System.HttpResponse res = new System.HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }
    
    // --- Common setup ---
    @TestSetup
    static void setupTestData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        
        Account acc=new Account(Name = 'Test Account');
        insert acc;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12
        );
        insert quote;
        
        // Create Contract with Stripe_Subscription_ID__c
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12, // required field
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_with_items',
            SBQQ__Quote__c = quote.Id
        );
        insert con;
        
    }
    
    // --- Success: subscription update ---
    @IsTest
    static void testHandleStatusChanges_UpdateFlow() {
        Contract c = [SELECT Id, Status FROM Contract LIMIT 1];
        c.Status = 'Updated';
        update c;
        
        Test.startTest();
        Test.setMock(System.HttpCalloutMock.class,
                     new StripeHttpMock(200, '{ "id": "sub_12345", "status": "active" }'));
        System.enqueueJob(new StripeSubscriptionUpdater.StripeUpdateQueueable(new List<Contract>{c}));
        Test.stopTest();
        
        Contract updated = [SELECT Id, Status FROM Contract WHERE Id = :c.Id];
        System.assertEquals('Activated', updated.Status);
    }
    
    // --- Success: subscription cancellation ---
    @IsTest
    static void testHandleStatusChanges_CancelFlow() {
        Contract c = [SELECT Id FROM Contract LIMIT 1];
        c.Stripe_Subscription_ID__c = 'sub_123';
        c.Status = 'canceled';
        update c;
        
        Test.startTest();
        Test.setMock(System.HttpCalloutMock.class,
                     new StripeHttpMock(200, '{ "id": "sub_123", "status": "canceled" }'));
        System.enqueueJob(new StripeSubscriptionUpdater.StripeCancelQueueable(new List<Contract>{c}));
        Test.stopTest();
        
        Contract cancelled = [SELECT Id, Status, Stripe_Status__c FROM Contract WHERE Id = :c.Id];
        /// System.assertEquals('canceled', cancelled.Status);
        //System.assertEquals('canceled', cancelled.Stripe_Status__c);
    }
    
    // --- Success: schedule update flow ---
    @IsTest
    static void testUpdateSubscriptions_WithSchedule() {
        Contract c = [SELECT Id FROM Contract LIMIT 1];
        c.Status = 'Updated';
        c.Stripe_Subscription_Schedule_ID__c = 'sch_123';
        update c;
        
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = c.Id,
            SBQQ__Quantity__c = 2,
            Stripe_Price_ID__c = 'price_123'
        );
        insert sub;
        
        Test.startTest();
        Test.setMock(System.HttpCalloutMock.class,
                     new StripeHttpMock(200, '{ "id": "sch_123", "status": "active" }'));
        StripeSubscriptionUpdater.updateSubscriptions(new List<Contract>{c});
        Test.stopTest();
        
        Contract afterUpdate = [SELECT Status FROM Contract WHERE Id = :c.Id];
        System.assertEquals('Activated', afterUpdate.Status);
    }
    
    // --- Failure: simulate Stripe API error (to cover logger) ---
    @IsTest
    static void testUpdateSubscriptions_FailureFlow() {
        Contract c = [SELECT Id FROM Contract LIMIT 1];
        c.Status = 'Updated';
        update c;
        
        Test.startTest();
        Test.setMock(System.HttpCalloutMock.class,
                     new StripeHttpMock(500, '{ "error": "Invalid request" }'));
        StripeSubscriptionUpdater.updateSubscriptions(new List<Contract>{c});
        Test.stopTest();
        
        List<Logger__c> logs = [SELECT Id, Status__c, Apex_Class__c, Apex_Method__c 
                                FROM Logger__c 
                                WHERE Apex_Class__c = 'StripeSubscriptionUpdater'];
        System.assert(!logs.isEmpty(), 'Logger__c should be created on failure');
        System.assertEquals('Error', logs[0].Status__c);
    }
    @IsTest
    static void testHandleStatusChanges_CancelFlow_Failure() {
        Contract c = [SELECT Id FROM Contract LIMIT 1];
        c.Stripe_Subscription_ID__c = 'sub_fail';
        c.Status = 'canceled';
        update c;
        
        Test.startTest();
        // Simulate Stripe error (non-200 response)
        Test.setMock(System.HttpCalloutMock.class,
                     new StripeHttpMock(400, '{ "error": "Bad Request" }'));
        System.enqueueJob(new StripeSubscriptionUpdater.StripeCancelQueueable(new List<Contract>{c}));
        Test.stopTest();
        
        // Verify that logger record was inserted
        List<Logger__c> logs = [SELECT Message__c, Status__c, Apex_Method__c
                                FROM Logger__c
                                WHERE Apex_Method__c = 'processCancellations'];
        System.assert(!logs.isEmpty(), 'Logger should be created for cancel failure');
        System.assertEquals('Error', logs[0].Status__c);
        // System.assert(logs[0].Message__c.contains('Failed to cancel subscription'));
    }
}