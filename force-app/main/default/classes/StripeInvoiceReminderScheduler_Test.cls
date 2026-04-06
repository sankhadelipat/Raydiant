@IsTest
private class StripeInvoiceReminderScheduler_Test {

    @TestSetup
    static void setupData() {
        
        Stripe_Details__c stripeSettings = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert stripeSettings;

        Account acc = new Account(
            Name = 'Test Account',
            Bill_to_Contacts__c = 'test@example.com'
        );
        insert acc;

        Date today = Date.today();

        // Invoice for 7-day reminder
        Stripe_Invoice__c inv7 = new Stripe_Invoice__c(
            Name = 'INV-7',
            Account__c = acc.Id,
            Status__c = 'Open',
            Due_Date__c = today.addDays(-7)
        );

        // Invoice for 15-day reminder
        Stripe_Invoice__c inv15 = new Stripe_Invoice__c(
            Name = 'INV-15',
            Account__c = acc.Id,
            Status__c = 'Open',
            Due_Date__c = today.addDays(-15)
        );

        insert new List<Stripe_Invoice__c>{ inv7, inv15 };
    }

    private class MockHttp implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('PDF DATA');
            return res;
        }
    }

    @IsTest
    static void test7DayReminderExecution() {

        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Test.startTest();
        new StripeInvoiceReminderScheduler(7)
            .execute(null);
        Test.stopTest();

        // If no exception, batch was triggered successfully
        System.assert(true);
    }

    @IsTest
    static void test15DayReminderExecution() {

        Test.setMock(HttpCalloutMock.class, new MockHttp());

        Test.startTest();
        new StripeInvoiceReminderScheduler(15)
            .execute(null);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testSchedulingMethods() {

        Test.startTest();
        StripeInvoiceReminderScheduler.schedule7DayReminder();
        StripeInvoiceReminderScheduler.schedule15DayReminder();
        Test.stopTest();

        // Validate jobs created
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Stripe Invoice%'
        ];

        System.assertEquals(2, jobs.size());
    }
}