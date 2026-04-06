/**
 * AccountMRRBackfillBatch
 *
 * One-time backfill batch — recalculates Account_Value__c on all accounts
 * that have CPQ subscriptions. Each batch chunk runs in its own transaction
 * with fresh governor limits.
 *
 * Run from Developer Console:
 *   Database.executeBatch(new AccountMRRBackfillBatch(), 25);
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-04-03
 */
global class AccountMRRBackfillBatch implements Database.Batchable<sObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Account
            WHERE Id IN (
                SELECT SBQQ__Account__c
                FROM SBQQ__Subscription__c
                WHERE SBQQ__Account__c != null
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> accountIds = new Map<Id, Account>(scope).keySet();
        AccountMRRValueHandler.recalculate(accountIds);
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('AccountMRRBackfillBatch complete.');
    }
}