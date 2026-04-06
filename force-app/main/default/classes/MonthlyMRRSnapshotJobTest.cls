@isTest
private class MonthlyMRRSnapshotJobTest {

    // ---------------------------------------------------------------
    // Schedulable / entry point tests
    // ---------------------------------------------------------------

    @isTest
    static void testSchedule() {
        Test.startTest();
        String jobId = System.schedule(
            'Test MRR Snapshot',
            '0 0 2 1 * ?',
            new MonthlyMRRSnapshotJob()
        );
        System.assertNotEquals(null, jobId);
        Test.stopTest();
    }

    @isTest
    static void testRunSnapshot() {
        Test.startTest();
        MonthlyMRRSnapshotJob.runSnapshot();
        Test.stopTest();
    }

    // ---------------------------------------------------------------
    // Batchable interface tests
    // ---------------------------------------------------------------

    @isTest
    static void testBatchStart() {
        MonthlyMRRSnapshotJob job = new MonthlyMRRSnapshotJob();
        Test.startTest();
        Database.QueryLocator ql = job.start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql);
    }

    @isTest
    static void testBatchExecute() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Id = '001000000000001AAA',
            Name = 'Batch Test Acct',
            Account_Value__c = 500,
            Active_Subscriptions_Rollup__c = 2,
            Lifetime_Value_SFBilling_and_stripe__c = 10000,
            Outstanding_AR__c = 50
        ));

        MonthlyMRRSnapshotJob job = new MonthlyMRRSnapshotJob();
        Test.startTest();
        job.execute((Database.BatchableContext) null, accounts);
        Test.stopTest();
    }

    @isTest
    static void testBatchFinish() {
        MonthlyMRRSnapshotJob job = new MonthlyMRRSnapshotJob();
        Test.startTest();
        job.finish(null);
        Test.stopTest();
    }

    // ---------------------------------------------------------------
    // buildSnapshots tests
    // ---------------------------------------------------------------

    @isTest
    static void testBuildSnapshotsNull() {
        List<MRR_Snapshot__c> result = MonthlyMRRSnapshotJob.buildSnapshots(null, Date.today());
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testBuildSnapshotsEmpty() {
        List<Account> accounts = new List<Account>();
        List<MRR_Snapshot__c> result = MonthlyMRRSnapshotJob.buildSnapshots(accounts, Date.today());
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testBuildSnapshotsValidAccounts() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Id = '001000000000001AAA',
            Name = 'Acme Corp',
            Account_Value__c = 1234.56,
            Active_Subscriptions_Rollup__c = 3,
            Lifetime_Value_SFBilling_and_stripe__c = 50000,
            Outstanding_AR__c = 200
        ));
        accounts.add(new Account(
            Id = '001000000000002AAA',
            Name = 'Beta Inc',
            Account_Value__c = 500,
            Active_Subscriptions_Rollup__c = 1,
            Lifetime_Value_SFBilling_and_stripe__c = 10000,
            Outstanding_AR__c = 0
        ));

        Test.startTest();
        List<MRR_Snapshot__c> result = MonthlyMRRSnapshotJob.buildSnapshots(accounts, Date.today());
        Test.stopTest();

        System.assertEquals(2, result.size());
        System.assert(result[0].Name.contains('Acme Corp'));
        System.assertEquals(1234.56, result[0].MRR__c);
        System.assertEquals(3, result[0].Active_Subscription_Count__c);
        System.assertEquals(50000, result[0].Lifetime_Value__c);
        System.assertEquals(200, result[0].Outstanding_AR__c);
        System.assertNotEquals(null, result[0].Account__c);
    }

    // ---------------------------------------------------------------
    // buildSnapshot tests
    // ---------------------------------------------------------------

    @isTest
    static void testBuildSnapshotNull() {
        MRR_Snapshot__c result = MonthlyMRRSnapshotJob.buildSnapshot(null, Date.today());
        System.assertEquals(null, result);
    }

    @isTest
    static void testBuildSnapshotWithAllFields() {
        Account acct = new Account(
            Id = '001000000000001AAA',
            Name = 'Test Account',
            Account_Value__c = 999.99,
            Active_Subscriptions_Rollup__c = 2,
            Lifetime_Value_SFBilling_and_stripe__c = 25000,
            Outstanding_AR__c = 150
        );
        Date d = Date.newInstance(2025, 6, 1);
        MRR_Snapshot__c result = MonthlyMRRSnapshotJob.buildSnapshot(acct, d);

        System.assertNotEquals(null, result);
        System.assert(result.Name.contains('Test Account'));
        System.assertEquals(d, result.Snapshot_Date__c);
        System.assertEquals(999.99, result.MRR__c);
        System.assertEquals(2, result.Active_Subscription_Count__c);
        System.assertEquals(25000, result.Lifetime_Value__c);
        System.assertEquals(150, result.Outstanding_AR__c);
        System.assertNotEquals(null, result.Account__c);
        System.assertEquals(String.valueOf(acct.Id), result.Account18__c);
    }

    @isTest
    static void testBuildSnapshotNullFields() {
        Account acct = new Account(
            Id = '001000000000001AAA',
            Name = 'Null Fields Test'
        );
        MRR_Snapshot__c result = MonthlyMRRSnapshotJob.buildSnapshot(acct, Date.today());

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.MRR__c);
        System.assertEquals(0, result.Active_Subscription_Count__c);
        System.assertEquals(0, result.Lifetime_Value__c);
        System.assertEquals(0, result.Outstanding_AR__c);
    }

    @isTest
    static void testBuildSnapshotLongName() {
        String longName = '';
        for (Integer i = 0; i < 101; i++) {
            longName += 'A';
        }
        Account acct = new Account(
            Id = '001000000000001AAA',
            Name = longName,
            Account_Value__c = 100
        );
        MRR_Snapshot__c result = MonthlyMRRSnapshotJob.buildSnapshot(acct, Date.today());

        System.assertNotEquals(null, result);
        System.assert(result.Name.length() <= 80);
    }

    @isTest
    static void testBuildSnapshotNoName() {
        Account acct = new Account(
            Id = '001000000000001AAA',
            Account_Value__c = 100
        );
        MRR_Snapshot__c result = MonthlyMRRSnapshotJob.buildSnapshot(acct, Date.today());

        System.assertNotEquals(null, result);
        System.assert(result.Name.contains('001000000000001AAA'));
    }

    // ---------------------------------------------------------------
    // insertSnapshots tests (no DML — covers code paths only)
    // ---------------------------------------------------------------

    @isTest
    static void testInsertSnapshotsNull() {
        MonthlyMRRSnapshotJob.insertSnapshots(null);
    }

    @isTest
    static void testInsertSnapshotsEmpty() {
        MonthlyMRRSnapshotJob.insertSnapshots(new List<MRR_Snapshot__c>());
    }

    @isTest
    static void testInsertSnapshotsCoversLoop() {
        List<MRR_Snapshot__c> snapshots = new List<MRR_Snapshot__c>();
        for (Integer i = 0; i < 250; i++) {
            snapshots.add(new MRR_Snapshot__c(
                Name = 'Coverage Test ' + i,
                Snapshot_Date__c = Date.today(),
                MRR__c = i * 10
            ));
        }
        Test.startTest();
        MonthlyMRRSnapshotJob.insertSnapshots(snapshots);
        Test.stopTest();
    }

    // ---------------------------------------------------------------
    // updateAccountMRR tests
    // ---------------------------------------------------------------

    @isTest
    static void testUpdateAccountMRRNull() {
        MonthlyMRRSnapshotJob.updateAccountMRR(null);
    }

    @isTest
    static void testUpdateAccountMRREmpty() {
        MonthlyMRRSnapshotJob.updateAccountMRR(new List<Account>());
    }

    @isTest
    static void testUpdateAccountMRRNoValue() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Id = '001000000000001AAA',
            Name = 'No MRR Test'
        ));
        MonthlyMRRSnapshotJob.updateAccountMRR(accounts);
    }

    @isTest
    static void testUpdateAccountMRRValid() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Id = '001000000000001AAA',
            Name = 'MRR Update Test',
            Account_Value__c = 1234.56
        ));

        Test.startTest();
        MonthlyMRRSnapshotJob.updateAccountMRR(accounts);
        Test.stopTest();
    }

    // ---------------------------------------------------------------
    // End-to-end: build only (no insert)
    // ---------------------------------------------------------------

    @isTest
    static void testEndToEndBuild() {
        List<Account> accounts = new List<Account>();
        accounts.add(new Account(
            Id = '001000000000001AAA',
            Name = 'E2E Test',
            Account_Value__c = 750,
            Active_Subscriptions_Rollup__c = 2,
            Lifetime_Value_SFBilling_and_stripe__c = 30000,
            Outstanding_AR__c = 0
        ));

        Test.startTest();
        List<MRR_Snapshot__c> snapshots = MonthlyMRRSnapshotJob.buildSnapshots(
            accounts, Date.today()
        );
        Test.stopTest();

        System.assertEquals(1, snapshots.size());
        System.assert(snapshots[0].Name.contains('E2E Test'));
        System.assertEquals(750, snapshots[0].MRR__c);
        System.assertEquals(2, snapshots[0].Active_Subscription_Count__c);
        System.assertEquals(30000, snapshots[0].Lifetime_Value__c);
        System.assertEquals(0, snapshots[0].Outstanding_AR__c);
        System.assertEquals(Date.today(), snapshots[0].Snapshot_Date__c);
    }
}