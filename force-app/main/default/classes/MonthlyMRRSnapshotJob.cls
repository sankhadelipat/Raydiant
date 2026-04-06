global class MonthlyMRRSnapshotJob implements Schedulable, Database.Batchable<sObject> {

    // ---------------------------------------------------------------
    // Schedulable — kicks off the batch
    // ---------------------------------------------------------------
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MonthlyMRRSnapshotJob(), 200);
    }

    // ---------------------------------------------------------------
    // Convenience method for Execute Anonymous
    // ---------------------------------------------------------------
    public static void runSnapshot() {
        Database.executeBatch(new MonthlyMRRSnapshotJob(), 200);
    }

    // ---------------------------------------------------------------
    // Batchable — start / execute / finish
    // ---------------------------------------------------------------
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Account_Value__c, Total_ARR__c,
                   Active_Subscriptions_Rollup__c,
                   Lifetime_Value_SFBilling_and_stripe__c,
                   Outstanding_AR__c
            FROM Account
            WHERE Account_Value__c > 0
        ]);
    }

    global void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<Account> accounts = (List<Account>) scope;
        System.debug('Processing batch of ' + accounts.size() + ' accounts');

        List<MRR_Snapshot__c> snapshots = buildSnapshots(accounts, Date.today());
        insertSnapshots(snapshots);
        updateAccountMRR(accounts);
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('MonthlyMRRSnapshotJob batch complete');
    }

    // ---------------------------------------------------------------
    // Helper methods (unchanged)
    // ---------------------------------------------------------------

    @TestVisible
    private static List<MRR_Snapshot__c> buildSnapshots(
        List<Account> accounts, Date snapshotDate
    ) {
        List<MRR_Snapshot__c> snapshots = new List<MRR_Snapshot__c>();
        if (accounts == null || accounts.isEmpty()) {
            return snapshots;
        }
        for (Account acct : accounts) {
            MRR_Snapshot__c snap = buildSnapshot(acct, snapshotDate);
            if (snap != null) {
                snapshots.add(snap);
            }
        }
        return snapshots;
    }

    @TestVisible
    private static MRR_Snapshot__c buildSnapshot(Account acct, Date snapshotDate) {
        if (acct == null) {
            return null;
        }

        Decimal mrr           = acct.Account_Value__c != null ? acct.Account_Value__c : 0;
        Decimal activeSubs    = acct.Active_Subscriptions_Rollup__c != null ? acct.Active_Subscriptions_Rollup__c : 0;
        Decimal ltv           = acct.Lifetime_Value_SFBilling_and_stripe__c != null ? acct.Lifetime_Value_SFBilling_and_stripe__c : 0;
        Decimal outstandingAR = acct.Outstanding_AR__c != null ? acct.Outstanding_AR__c : 0;

        String label = String.isNotBlank(acct.Name)
            ? acct.Name + ' - ' + snapshotDate.format()
            : acct.Id + ' - ' + snapshotDate.format();

        if (label.length() > 80) {
            label = label.substring(0, 80);
        }

        MRR_Snapshot__c snap = new MRR_Snapshot__c(
            Name                         = label,
            Snapshot_Date__c             = snapshotDate,
            Account18__c                 = String.valueOf(acct.Id),
            Account__c                   = acct.Id,
            MRR__c                       = mrr,
            Active_Subscription_Count__c = activeSubs,
            Lifetime_Value__c            = ltv,
            Outstanding_AR__c            = outstandingAR
        );

        return snap;
    }

    @TestVisible
    private static void insertSnapshots(List<MRR_Snapshot__c> snapshots) {
        if (snapshots == null || snapshots.isEmpty()) {
            return;
        }

        Integer batchSize = 200;
        for (Integer i = 0; i < snapshots.size(); i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, snapshots.size());
            List<MRR_Snapshot__c> batch = new List<MRR_Snapshot__c>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(snapshots[j]);
            }
            Database.insert(batch, false);
        }
    }

    @TestVisible
    private static void updateAccountMRR(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        List<Account> toUpdate = new List<Account>();
        for (Account acct : accounts) {
            if (acct.Id != null && acct.Account_Value__c != null) {
                toUpdate.add(new Account(
                    Id = acct.Id,
                    Latest_MRR__c = acct.Account_Value__c
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }
}