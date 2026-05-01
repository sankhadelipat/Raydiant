public class CaseTriggerHandler {

    // AR Case record type — used to filter Open_AR_Case_Count__c rollup
    private static final Id AR_RECORD_TYPE_ID = '0128W000001QAtl';

    public static void handleTrigger(
        List<Case> newList,
        List<Case> oldList,
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isDelete,
        Boolean isUndelete
    ) {
        Set<Id> accountIds = new Set<Id>();

        if (isDelete) {
            // Trigger.new is null on delete — use old list
            for (Case c : oldList) {
                if (c.AccountId != null) accountIds.add(c.AccountId);
            }
        } else if (isUpdate) {
            // Capture both new AND old values — handles re-parenting
            for (Case c : newList) {
                if (c.AccountId != null) accountIds.add(c.AccountId);
            }
            for (Case c : oldList) {
                if (c.AccountId != null) accountIds.add(c.AccountId);
            }
        } else {
            // insert or undelete
            for (Case c : newList) {
                if (c.AccountId != null) accountIds.add(c.AccountId);
            }
        }

        if (!accountIds.isEmpty()) updateAccountRollups(accountIds);
    }

    // ── Account rollups ─────────────────────────────────────────────
    // Calculates both fields in two SOQLs but ONE Account DML update:
    //   Number_of_Open_Cases__c  — all open cases (any record type)
    //   Open_AR_Case_Count__c    — open AR-record-type cases only
    @TestVisible
    private static void updateAccountRollups(Set<Id> accountIds) {
        // 1. All open cases per Account
        Map<Id, Integer> openCaseMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
              AND IsClosed = false
            GROUP BY AccountId
        ]) {
            openCaseMap.put((Id) ar.get('AccountId'), (Integer) ar.get('cnt'));
        }

        // 2. Open AR cases per Account (specific record type)
        Map<Id, Integer> openARMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
              AND IsClosed = false
              AND RecordTypeId = :AR_RECORD_TYPE_ID
            GROUP BY AccountId
        ]) {
            openARMap.put((Id) ar.get('AccountId'), (Integer) ar.get('cnt'));
        }

        // Single DML — both fields in one update
        List<Account> toUpdate = new List<Account>();
        for (Id accId : accountIds) {
            toUpdate.add(new Account(
                Id                      = accId,
                Number_of_Open_Cases__c = openCaseMap.containsKey(accId) ? openCaseMap.get(accId) : 0,
                Open_AR_Case_Count__c   = openARMap.containsKey(accId)   ? openARMap.get(accId)   : 0
            ));
        }
        update toUpdate;
    }

    // Kept for backward compatibility with existing test class
    @TestVisible
    private static void updateOpenCaseCount(Set<Id> accountIds) {
        updateAccountRollups(accountIds);
    }

    // ── Payment Method rollup ────────────────────────────────────────
    // TODO: Open_AR_Case_Count__c on blng__PaymentMethod__c
    // Replacing DLRS "PM Open Case Count" — requires test data in sandbox.
    // Will be added in a follow-up change set.
}