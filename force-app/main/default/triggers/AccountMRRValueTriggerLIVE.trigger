/**
 * AccountMRRValueTriggerLIVE
 *
 * Keeps Account_Value__c dead accurate in real time.
 * Fires on every SBQQ__Subscription__c DML operation and recalculates
 * the SUM of Monthly_Value__c (F52_Active__c = true) for all affected accounts.
 *
 * Replaces: [UPDATED] Total MRR (Account Value) Calculation V2.0 (Flow)
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-04-03
 */
trigger AccountMRRValueTriggerLIVE on SBQQ__Subscription__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (StripeTriggerHandler.isBypassEnabled('SBQQ__Subscription__c')) {
        return;
    }

    AccountMRRValueHandler.handleTrigger(
        Trigger.new,
        Trigger.old,
        Trigger.isInsert,
        Trigger.isUpdate,
        Trigger.isDelete,
        Trigger.isUndelete
    );
}