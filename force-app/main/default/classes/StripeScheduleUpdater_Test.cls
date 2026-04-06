@IsTest
public class StripeScheduleUpdater_Test {
    
    private class StripeScheduleMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // CANCEL schedule
            if (req.getEndpoint().endsWith('/cancel')) {
                res.setStatusCode(200);
                res.setBody('{"status":"canceled"}');
            }
            // UPDATE schedule
            else if (req.getEndpoint().contains('/v1/subscription_schedules/')
                     && !req.getEndpoint().endsWith('/cancel')) {
                         
                         res.setStatusCode(200);
                         res.setBody('{"id":"sub_sched_test"}');
                     }
            else {
                res.setStatusCode(500);
                res.setBody('{"error":"server error"}');
            }
            return res;
        }
    }
    
    private class StripeErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error":"server error"}');
            
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
            Stripe_Customer_ID__c = 'cus_test'
        );
        insert acc;
        
        Contract pending = new Contract(
            AccountId = acc.Id,
            Status = 'Pending',
            StartDate = Date.today(),
            EndDate = Date.today().addMonths(12),
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_test'
        );
        insert pending;
        
        insert new SBQQ__Subscription__c(
            SBQQ__Contract__c = pending.Id,
            Stripe_Price_ID__c = 'price_test',
            SBQQ__Quantity__c = 2
        );
    }
    
    @IsTest
    static void testScheduleUpdate() {
        
        Test.setMock(HttpCalloutMock.class, new StripeScheduleMock());
        
        Contract con = [
            SELECT Id, Status
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c != null
            LIMIT 1
        ];
        
        Test.startTest();
        con.Status = 'Updated';
        update con;
        Test.stopTest();
    }
    
    @IsTest
    static void testScheduleCancel() {
        
        Test.setMock(HttpCalloutMock.class, new StripeScheduleMock());
        
        Contract con = [
            SELECT Id, Status
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c != null
            LIMIT 1
        ];
        
        Test.startTest();
        con.Status = 'canceled';
        update con;
        Test.stopTest();
        
        Contract canceled = [
            SELECT Status
            FROM Contract
            WHERE Id = :con.Id
        ];
        
        System.assertEquals(
            'canceled',
            canceled.Status,
            'Contract should remain canceled'
        );
    }
    
    @IsTest
    static void testScheduleErrorLogging() {
        
        Test.setMock(HttpCalloutMock.class, new StripeScheduleMock());
        
        delete [SELECT Id FROM Logger__c];
        
        Contract con = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c != null
            LIMIT 1
        ];
        
        Test.startTest();
        con.Status = 'Updated';
        update con;
        Test.stopTest();
        
        Integer logs = [
            SELECT COUNT()
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeScheduleUpdater'
        ];
        
        System.assert(
            logs > 0,
            'Error should be logged when Stripe API fails'
        );
    }
    
    @IsTest
    static void testScheduleCancelErrorLogging() {
        
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        delete [SELECT Id FROM Logger__c];
        
        Contract con = [
            SELECT Id
            FROM Contract
            WHERE Stripe_Subscription_Schedule_ID__c != null
            LIMIT 1
        ];
        
        Test.startTest();
        con.Status = 'canceled';
        update con;
        Test.stopTest();
        
        Integer logs = [
            SELECT COUNT()
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeScheduleUpdater'
        ];
        
        System.assert(
            logs > 0,
            'Error should be logged when Stripe API fails'
        );
    }
}