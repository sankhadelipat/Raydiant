/**
 * AccountMRRRollupHandler - Deep multi-level rollup of Parent_MRR__c (up to 5 levels).
 *
 * Parent_MRR__c = SUM(child.Account_Value__c + child.Parent_MRR__c) at each level.
 * Never touches Account_Value__c or Account_Team_CSM__c.
 *
 * Author : Stargate / Blake Reeves
 * Updated: 2026-04-07 � deep multi-level rollup (was single-level only)
 */
public class AccountMRRRollupHandler {

    public static void handleTrigger(
        List<Account> newList, List<Account> oldList,
        Map<Id, Account> newMap, Map<Id, Account> oldMap,
        Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete
    ) {
        Set<Id> parentIds = new Set<Id>();

        if (isDelete) {
            for (Account acc : oldList) { if (acc.ParentId != null) parentIds.add(acc.ParentId); }
        } else if (isUpdate) {
            for (Account acc : newList) {
                Account oldAcc = oldMap.get(acc.Id);
                Boolean mrrChanged    = (acc.Account_Value__c != oldAcc.Account_Value__c);
                Boolean parentChanged = (acc.ParentId         != oldAcc.ParentId);
                if (acc.ParentId != null && (mrrChanged || parentChanged)) parentIds.add(acc.ParentId);
                if (parentChanged && oldAcc.ParentId != null) parentIds.add(oldAcc.ParentId);
            }
        } else {
            for (Account acc : newList) { if (acc.ParentId != null) parentIds.add(acc.ParentId); }
        }

        if (parentIds.isEmpty()) return;
        rollupParentMRR(parentIds);
    }

    /**
     * Deep multi-level rollup.
     * 1. Walk UP from triggered parents collecting all ancestor levels.
     * 2. Process BOTTOM-UP: levels[0] first, carrying fresh values upward.
     * 3. Single DML update for all ancestors.
     */
    @TestVisible
    public static void rollupParentMRR(Set<Id> parentIds) {

        // Step 1: collect ancestor levels
        List<Set<Id>> levels = new List<Set<Id>>();
        Set<Id> currentLevel = new Set<Id>(parentIds);
        levels.add(currentLevel);

        for (Integer i = 0; i < 5; i++) {
            Set<Id> nextLevel = new Set<Id>();
            for (Account a : [SELECT Id, ParentId FROM Account WHERE Id IN :currentLevel AND ParentId != null]) {
                nextLevel.add(a.ParentId);
            }
            if (nextLevel.isEmpty()) break;
            levels.add(nextLevel);
            currentLevel = nextLevel;
        }

        // Step 2: process bottom-up with in-memory carry
        Map<Id, Decimal> freshParentMRR = new Map<Id, Decimal>();

        for (Integer i = 0; i < levels.size(); i++) {
            Set<Id> levelIds = levels[i];
            Map<Id, Decimal> childSumByParent = new Map<Id, Decimal>();
            for (Id pid : levelIds) childSumByParent.put(pid, 0);

            for (Account child : [
                SELECT Id, ParentId, Account_Value__c, Parent_MRR__c
                FROM   Account WHERE ParentId IN :levelIds
            ]) {
                Decimal ownMRR      = child.Account_Value__c != null ? child.Account_Value__c : 0;
                Decimal childRollup = freshParentMRR.containsKey(child.Id)
                    ? freshParentMRR.get(child.Id)
                    : (child.Parent_MRR__c != null ? child.Parent_MRR__c : 0);
                Decimal running = childSumByParent.get(child.ParentId);
                childSumByParent.put(child.ParentId, (running != null ? running : 0) + ownMRR + childRollup);
            }

            for (Id pid : levelIds) {
                freshParentMRR.put(pid, childSumByParent.containsKey(pid) ? childSumByParent.get(pid) : 0);
            }
        }

        // Step 3: single DML
        List<Account> toUpdate = new List<Account>();
        for (Id pid : freshParentMRR.keySet()) {
            toUpdate.add(new Account(Id = pid, Parent_MRR__c = freshParentMRR.get(pid)));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}