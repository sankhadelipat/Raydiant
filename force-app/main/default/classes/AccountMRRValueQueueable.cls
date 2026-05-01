/**
 * AccountMRRValueQueueable
 *
 * Queueable wrapper for AccountMRRValueHandler.recalculate().
 * Introduced to add a 5-minute delay between the subscription DML event
 * and the Account_Value__c rollup — prevents mid-transaction race conditions
 * when CPQ commits multiple subscription records in rapid succession.
 *
 * Called from : AccountMRRValueHandler.handleTrigger()
 * Delay       : 5 minutes (System.enqueueJob delay parameter)
 *
 * Author : Stargate / Blake Reeves
 * Updated: 2026-04-06
 */
public class AccountMRRValueQueueable implements Queueable {

    private Set<Id> accountIds;

    public AccountMRRValueQueueable(Set<Id> accountIds) {
        this.accountIds = accountIds;
    }

    public void execute(QueueableContext context) {
        if (accountIds == null || accountIds.isEmpty()) return;
        AccountMRRValueHandler.recalculate(accountIds);
    }
}