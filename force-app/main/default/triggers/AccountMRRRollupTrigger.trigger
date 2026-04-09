/**
 * AccountMRRRollupTrigger
 *
 * Rolls up Account_Value__c from child Accounts to their parent Account's Parent_MRR__c.
 * Fires whenever a child account's MRR or parent relationship changes.
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-03-26
 */
trigger AccountMRRRollupTrigger on Account (
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (StripeTriggerHandler.isBypassEnabled('Account')) {
        return;
    }
    
    AccountMRRRollupHandler.handleTrigger(
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate,
        Trigger.isDelete,
        Trigger.isUndelete
    );
}