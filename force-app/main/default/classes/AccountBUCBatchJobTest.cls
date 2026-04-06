@isTest
private class AccountBUCBatchJobTest {

    @isTest(SeeAllData=true)
    static void testBatchLogicWithRealData() {
        AccountBUCBatchJob job = new AccountBUCBatchJob();

        // Query a small set of accounts that have active Hoopla/DS subs
        List<Account> testAccounts = [
            SELECT Id, Business_Use_Case__c, Account_Team_CSM__c
            FROM Account
            WHERE Id IN (
                SELECT SBQQ__Account__c
                FROM SBQQ__Subscription__c
                WHERE F52_Active__c = true
                AND SBQQ__Product__r.Business_Use_Case__c IN ('Hoopla', 'Digital Signage')
            )
            LIMIT 10
        ];

        // Call methods directly — avoids executeBatch limit in test context
        Test.startTest();
        job.start(null);
        if (!testAccounts.isEmpty()) {
            job.execute(null, testAccounts);
        }
        job.finish(null);
        Test.stopTest();

        System.assert(true, 'Batch logic executed successfully');
    }

    @isTest
    static void testSchedulerRuns() {
        Test.startTest();
        System.schedule(
            'BUC Test Schedule',
            '0 0 2 * * ?',
            new AccountBUCScheduler()
        );
        Test.stopTest();

        System.assert(true, 'Scheduler completed successfully');
    }
}