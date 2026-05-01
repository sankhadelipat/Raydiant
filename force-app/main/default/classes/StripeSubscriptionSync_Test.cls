@IsTest
private class StripeSubscriptionSync_Test {

    // ================= MOCK =================
    private class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Subscription call
            if (req.getEndpoint().contains('/v1/subscriptions/')) {

                if (req.getEndpoint().contains('active_sub')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"sub_123","status":"active"}');
                } 
                else if (req.getEndpoint().contains('cancel_sub')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"sub_123","status":"canceled"}');
                }

                return res;
            }

            // Schedule call
            if (req.getEndpoint().contains('/v1/subscription_schedules/')) {

                if (req.getEndpoint().contains('active_sched')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"sched_123","status":"active"}');
                } 
                else if (req.getEndpoint().contains('cancel_sched')) {
                    res.setStatusCode(200);
                    res.setBody('{"id":"sched_123","status":"canceled"}');
                }

                return res;
            }

            res.setStatusCode(400);
            res.setBody('{"error":"Unhandled"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test'
        );

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        // Contract with subscription
        Contract active_sub = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'active_sub'
        );
        insert active_sub;
        
        // Update the contract to Activate
        active_sub.Status = 'Activated';
        update active_sub;

        Contract cancel_sub = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'cancel_sub'
        );
        insert cancel_sub;
        
        // Update the contract to Activate
        cancel_sub.Status = 'Activated';
        update cancel_sub;

        // Contract with schedule
        Contract active_sched = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_Schedule_ID__c = 'active_sched'
        );
        insert active_sched;

        Contract cancel_sched = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_Schedule_ID__c = 'cancel_sched'
        );
        insert cancel_sched;
    }

    // ================= TEST ACTIVE SUB =================
    @IsTest
    static void testActiveSubscriptionFlow() {

        Test.setMock(HttpCalloutMock.class, new StripeMock());

        Contract con = [
            SELECT Id FROM Contract WHERE Stripe_Subscription_ID__c = 'active_sub' LIMIT 1
        ];

        StripeSubscriptionSync.FlowInput input = new StripeSubscriptionSync.FlowInput();
        input.contractId = con.Id;

        Test.startTest();
        List<StripeSubscriptionSync.FlowResult> results =
            StripeSubscriptionSync.syncContract(new List<StripeSubscriptionSync.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
    }

    // ================= TEST CANCELED SUB =================
    @IsTest
    static void testCanceledSubscriptionFlow() {

        Test.setMock(HttpCalloutMock.class, new StripeMock());

        Contract con = [
            SELECT Id FROM Contract WHERE Stripe_Subscription_ID__c = 'cancel_sub' LIMIT 1
        ];

        StripeSubscriptionSync.FlowInput input = new StripeSubscriptionSync.FlowInput();
        input.contractId = con.Id;

        Test.startTest();
        List<StripeSubscriptionSync.FlowResult> results =
            StripeSubscriptionSync.syncContract(new List<StripeSubscriptionSync.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
    }

    // ================= TEST ACTIVE SCHEDULE =================
    @IsTest
    static void testActiveScheduleFlow() {

        Test.setMock(HttpCalloutMock.class, new StripeMock());

        Contract con = [
            SELECT Id FROM Contract WHERE Stripe_Subscription_Schedule_ID__c = 'active_sched' LIMIT 1
        ];

        StripeSubscriptionSync.FlowInput input = new StripeSubscriptionSync.FlowInput();
        input.contractId = con.Id;

        Test.startTest();
        List<StripeSubscriptionSync.FlowResult> results =
            StripeSubscriptionSync.syncContract(new List<StripeSubscriptionSync.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
    }

    // ================= TEST CANCELED SCHEDULE =================
    @IsTest
    static void testCanceledScheduleFlow() {

        Test.setMock(HttpCalloutMock.class, new StripeMock());

        Contract con = [
            SELECT Id FROM Contract WHERE Stripe_Subscription_Schedule_ID__c = 'cancel_sched' LIMIT 1
        ];

        StripeSubscriptionSync.FlowInput input = new StripeSubscriptionSync.FlowInput();
        input.contractId = con.Id;

        Test.startTest();
        List<StripeSubscriptionSync.FlowResult> results =
            StripeSubscriptionSync.syncContract(new List<StripeSubscriptionSync.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);
    }

    // ================= TEST ERROR =================
    @IsTest
    static void testNoStripeIds() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;

        StripeSubscriptionSync.FlowInput input = new StripeSubscriptionSync.FlowInput();
        input.contractId = con.Id;

        Test.startTest();
        List<StripeSubscriptionSync.FlowResult> results =
            StripeSubscriptionSync.syncContract(new List<StripeSubscriptionSync.FlowInput>{ input });
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
    }
}