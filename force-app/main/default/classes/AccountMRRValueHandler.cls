/**
 * AccountMRRValueHandler
 *
 * Recalculates Account_Value__c in real time whenever subscriptions change.
 *
 * LOGIC:
 *   Account_Value__c = SUM(Monthly_Value__c)
 *   FROM SBQQ__Subscription__c
 *   WHERE SBQQ__Account__c = Account.Id
 *     AND F52_Active__c = true
 *
 * Handles all DML contexts including delete — if no active subs remain,
 * Account_Value__c is set to 0.
 *
 * For updates where SBQQ__Account__c changes, both the old and new
 * account are recalculated.
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-04-03
 */
public class AccountMRRValueHandler {

    public static void handleTrigger(
        List<SBQQ__Subscription__c> newList,
        List<SBQQ__Subscription__c> oldList,
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isDelete,
        Boolean isUndelete
    ) {
        Set<Id> accountIds = new Set<Id>();

        if (isDelete) {
            for (SBQQ__Subscription__c sub : oldList) {
                if (sub.SBQQ__Account__c != null) {
                    accountIds.add(sub.SBQQ__Account__c);
                }
            }
        } else if (isUpdate) {
            for (Integer i = 0; i < newList.size(); i++) {
                SBQQ__Subscription__c newSub = newList[i];
                SBQQ__Subscription__c oldSub = oldList[i];

                // Collect new account
                if (newSub.SBQQ__Account__c != null) {
                    accountIds.add(newSub.SBQQ__Account__c);
                }
                // If account changed, recalculate the old account too
                if (oldSub.SBQQ__Account__c != null &&
                    oldSub.SBQQ__Account__c != newSub.SBQQ__Account__c) {
                    accountIds.add(oldSub.SBQQ__Account__c);
                }
            }
        } else {
            // Insert or undelete
            for (SBQQ__Subscription__c sub : newList) {
                if (sub.SBQQ__Account__c != null) {
                    accountIds.add(sub.SBQQ__Account__c);
                }
            }
        }

        if (accountIds.isEmpty()) return;

        recalculate(accountIds);
    }

    @TestVisible
    public static void recalculate(Set<Id> accountIds) {

        // SUM active subscription MRR per account
        Map<Id, Decimal> mrrByAccount = new Map<Id, Decimal>();
        for (Id accId : accountIds) {
            mrrByAccount.put(accId, 0);
        }

        for (AggregateResult ar : [
            SELECT SBQQ__Account__c accId, SUM(Monthly_Value__c) totalMRR
            FROM   SBQQ__Subscription__c
            WHERE  SBQQ__Account__c IN :accountIds
              AND  F52_Active__c = true
            GROUP BY SBQQ__Account__c
        ]) {
            Id      accId = (Id)      ar.get('accId');
            Decimal total = (Decimal) ar.get('totalMRR');
            mrrByAccount.put(accId, total != null ? total : 0);
        }

        // Update all affected accounts — zero out if no active subs remain
        List<Account> toUpdate = new List<Account>();
        for (Id accId : accountIds) {
            toUpdate.add(new Account(
                Id              = accId,
                Account_Value__c = mrrByAccount.get(accId)
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}