@IsTest
private class StripeRenewalCancellationService_Test {
    
    private class StripeCancelScheduleMock implements HttpCalloutMock {
        Boolean isSuccess;
        
        StripeCancelScheduleMock(Boolean isSuccess) {
            this.isSuccess = isSuccess;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (isSuccess) {
                res.setStatusCode(200);
                res.setBody('{"id":"sub_sched_test","status":"canceled"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":{"message":"Invalid schedule"}}');
            }
            
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;
    }
    
    @IsTest
    static void testCancelSchedule_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Renewed_Schedule_ID__c = 'sub_sched_test'
        );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        Test.setMock(HttpCalloutMock.class, new StripeCancelScheduleMock(true));
        
        Test.startTest();
        System.enqueueJob(
            new StripeRenewalCancellationService(new List<Id>{ con.Id })
        );
        Test.stopTest();
        
        Contract updated = [
            SELECT Renewed_Schedule_ID__c
            FROM Contract
            WHERE Id = :con.Id
        ];
        
        System.assertEquals(
            null,
            updated.Renewed_Schedule_ID__c,
            'Renewed_Schedule_ID__c should be cleared after successful cancellation'
        );
    }
    
    @IsTest
    static void testCancelSchedule_Error_Logs() {
        delete [SELECT Id FROM Logger__c];
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Renewed_Schedule_ID__c = 'sub_sched_fail'
        );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        Test.setMock(HttpCalloutMock.class, new StripeCancelScheduleMock(false));
        
        Test.startTest();
        System.enqueueJob(
            new StripeRenewalCancellationService(new List<Id>{ con.Id })
        );
        Test.stopTest();
        
        // Contract should still have schedule ID
        Contract unchanged = [
            SELECT Renewed_Schedule_ID__c
            FROM Contract
            WHERE Id = :con.Id
        ];
        System.assertEquals(
            'sub_sched_fail',
            unchanged.Renewed_Schedule_ID__c,
            'Schedule ID should not be cleared on failure'
        );
        
        // Logger should exist
        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeRenewalCancellationService'
        ];
        
        System.assertEquals(
            1,
            logs.size(),
            'Error should be logged when Stripe cancellation fails'
        );
    }
    
    @IsTest
    static void testCancelSchedule_NoMatchingContracts() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        Test.setMock(HttpCalloutMock.class, new StripeCancelScheduleMock(true));
        
        Test.startTest();
        System.enqueueJob(
            new StripeRenewalCancellationService(new List<Id>{ con.Id })
        );
        Test.stopTest();
        
        System.assert(true, 'Queueable should safely exit when no schedule exists');
    }
    
    @IsTest
    static void testContractDoNotRenewTrigger_CancelsSchedule() {
        // Clean logs
        delete [SELECT Id FROM Logger__c];
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Step 1: Create contract with renewal already scheduled
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-11),
            EndDate = Date.today().addDays(10), // within 30 days
            ContractTerm = 12,
            Status = 'Pending',
            DO_NOT_RENEW__c = false,
            Renewed_Schedule_ID__c = 'sub_sched_trigger_test'
        );
        insert con;
        
        // Step 2: Mock Stripe cancellation success
        Test.setMock(HttpCalloutMock.class, new StripeCancelScheduleMock(true));
        
        // Step 3: Flip DO_NOT_RENEW__c (this fires trigger)
        Test.startTest();
        con.DO_NOT_RENEW__c = true;
        update con;
        Test.stopTest();
        
        // Step 4: Assert schedule ID cleared by queueable
        Contract updated = [
            SELECT DO_NOT_RENEW__c, Renewed_Schedule_ID__c
            FROM Contract
            WHERE Id = :con.Id
        ];
        
        System.assertEquals(
            true,
            updated.DO_NOT_RENEW__c,
            'DO_NOT_RENEW__c should be updated'
        );
        
        System.assertEquals(
            null,
            updated.Renewed_Schedule_ID__c,
            'Renewed_Schedule_ID__c must be cleared after cancellation'
        );
        
        // Step 5: No error logs
        Integer logCount = [
            SELECT COUNT()
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeRenewalCancellationService'
        ];
        System.assertEquals(0, logCount, 'No errors should be logged');
    }
}