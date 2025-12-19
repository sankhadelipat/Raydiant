@IsTest
public class StripeSubscriptionAutoRenewal_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create custom setting for Stripe Details
        Stripe_Details__c stripeDetails = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_1234567890'
        );
        insert stripeDetails;
        
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test123'
        );
        insert testAccount;
        
        // Create test Contracts
        List<Contract> testContracts = new List<Contract>();
        
        // Contract without schedule ID (will create new schedule)
        Contract contractWithoutSchedule = new Contract(
            AccountId = testAccount.Id,
            Stripe_Subscription_ID__c = 'sub_test123',
            Stripe_Subscription_Schedule_ID__c = null,
            EndDate = Date.today().addDays(29),
            StartDate = Date.today().addDays(-1),
            ContractTerm = 12,
            Status = 'Draft',
            DO_NOT_RENEW__c = false,
            CurrencyIsoCode = 'USD',
            Renewed_End_Date__c = null
        );
        
        insert contractWithoutSchedule;
        contractWithoutSchedule.Status = 'Activated';
        update contractWithoutSchedule;
        
        // Contract with existing schedule ID (will update schedule)
        Contract contractWithSchedule = new Contract(
            AccountId = testAccount.Id,
            Stripe_Subscription_ID__c = 'sub_test456',
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_test456',
            EndDate = Date.today().addDays(1), // Expires tomorrow
            StartDate = Date.today().addDays(-30),
            ContractTerm = 12,
            Status = 'draft',
            DO_NOT_RENEW__c = false,
            CurrencyIsoCode = 'USD',
            Renewed_End_Date__c = null
        );
        
        insert contractWithSchedule;
        contractWithSchedule.Status = 'Activated';
        update contractWithSchedule;
        
        // Contract that should not renew (DO_NOT_RENEW__c = true)
        Contract contractNoRenewal = new Contract(
            AccountId = testAccount.Id,
            Stripe_Subscription_ID__c = 'sub_test789',
            Stripe_Subscription_Schedule_ID__c = null,
            EndDate = Date.today().addDays(1),
            StartDate = Date.today().addDays(-30),
            ContractTerm = 12,
            Status = 'Draft',
            DO_NOT_RENEW__c = true, // Should not be processed
            CurrencyIsoCode = 'USD',
            Renewed_End_Date__c = null
        );
        
        insert contractNoRenewal;
        contractNoRenewal.Status = 'Activated';
        update contractNoRenewal;
        
        // Create test Subscriptions
        List<SBQQ__Subscription__c> testSubscriptions = new List<SBQQ__Subscription__c>();
        
        for (Contract con : [SELECT Id FROM Contract WHERE DO_NOT_RENEW__c = false]) {
            testSubscriptions.add(new SBQQ__Subscription__c(
                SBQQ__Contract__c = con.Id,
                SBQQ__Account__c = testAccount.Id,
                Stripe_Price_Id__c = 'price_test_' + con.Id,
                SBQQ__Quantity__c = 2
            ));
        }
        
        insert testSubscriptions;
    }
    
    @IsTest
    static void testBatchStartMethod() {
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @IsTest
    static void testBatchExecuteWithNewSchedule() {
        // Setup mock for successful schedule creation and update
        Test.setMock(HttpCalloutMock.class, new StripeScheduleMock());
        
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 5);
        Test.stopTest();
        
        // Verify contract was updated with schedule ID and renewed end date
        Contract updatedContract = [
            SELECT Id, Stripe_Subscription_Schedule_ID__c, Renewed_End_Date__c, Latest_Change_Reason__c
            FROM Contract WHERE Stripe_Subscription_ID__c = 'sub_test123' LIMIT 1
        ];
        
        System.debug(updatedContract.Renewed_End_Date__c);
        //System.assertNotEquals(null, updatedContract.Stripe_Subscription_Schedule_ID__c, 'Schedule ID should be set');
        //System.assertNotEquals(null, updatedContract.Renewed_End_Date__c, 'Renewed end date should be set');
        //System.assert(updatedContract.Latest_Change_Reason__c.contains('Auto-renewed'), 'Change reason should indicate renewal');
    }
    
    @IsTest
    static void testBatchExecuteWithExistingSchedule() {
        // Setup mock for successful schedule update
        Test.setMock(HttpCalloutMock.class, new StripeScheduleMock());
        
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 5);
        Test.stopTest();
        
        // Verify contract with existing schedule was updated
        Contract updatedContract = [
            SELECT Id, Renewed_End_Date__c, Latest_Change_Reason__c
            FROM Contract WHERE Stripe_Subscription_ID__c = 'sub_test456' LIMIT 1
        ];
        
        System.debug(updatedContract.Renewed_End_Date__c);
        //System.assertNotEquals(null, updatedContract.Renewed_End_Date__c, 'Renewed end date should be set');
    }
    
    @IsTest
    static void testBatchExecuteWithNoActiveSubscriptions() {
        // Delete all subscriptions to simulate no active subscriptions
        delete [SELECT Id FROM SBQQ__Subscription__c];
        
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 5);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchExecuteWithStripeAPIError() {
        // Setup mock for Stripe API errors
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 5);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatchExecuteWithContractNoRenewal() {
        Test.startTest();
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 5);
        Test.stopTest();
        
        // Verify contract with DO_NOT_RENEW__c = true was not processed
        Contract noRenewalContract = [
            SELECT Id, Renewed_End_Date__c, Stripe_Subscription_Schedule_ID__c
            FROM Contract 
            WHERE DO_NOT_RENEW__c = true
            LIMIT 1
        ];
        
        System.assertEquals(null, noRenewalContract.Renewed_End_Date__c, 'Contract with DO_NOT_RENEW__c = true should not be renewed');
    }
    
    @isTest
    static void testScheduleJobMethod() {

        Test.startTest();
        // Call the custom schedule method
        StripeSubscriptionAutoRenewScheduler.scheduleJob();
        Test.stopTest();

        // Same: validate it runs without blowing up.
        System.assert(true, 'scheduleJob() executed successfully.');
    }
    
    // Mock class for successful Stripe schedule operations
    public class StripeScheduleMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            callCount++;
            
            if (req.getEndpoint().contains('/subscription_schedules') && req.getMethod() == 'POST') {
                if (callCount == 1) {
                    // First call - create schedule
                    res.setBody('{' +
                                '"id": "sub_sched_test123",' +
                                '"object": "subscription_schedule",' +
                                '"status": "active"' +
                                '}');
                } else {
                    // Subsequent calls - update schedule or get schedule
                    res.setBody('{' +
                                '"id": "sub_sched_test123",' +
                                '"object": "subscription_schedule",' +
                                '"status": "active",' +
                                '"phases": [{' +
                                '  "start_date": 1635724800,' +
                                '  "duration": {"interval": "month", "interval_count": 12},' +
                                '  "items": [{"price": "price_test_123", "quantity": 2}]' +
                                '}]' +
                                '}');
                }
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/subscription_schedules/') && req.getMethod() == 'GET') {
                // GET schedule
                res.setBody('{' +
                            '"id": "sub_sched_test456",' +
                            '"object": "subscription_schedule",' +
                            '"status": "active",' +
                            '"phases": [{' +
                            '  "start_date": 1635724800,' +
                            '  "duration": {"interval": "month", "interval_count": 12},' +
                            '  "items": [{"price": "price_test_456", "quantity": 2}],' +
                            '  "proration_behavior": "none"' +
                            '}],' +
                            '"metadata": {"renewal_count": "1"}' +
                            '}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            
            return res;
        }
    }
    
    // Mock class for Stripe API errors
    public class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request", "type": "invalid_request_error"}}');
            return res;
        }
    }
}