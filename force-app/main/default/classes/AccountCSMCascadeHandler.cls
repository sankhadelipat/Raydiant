/**
 * AccountCSMCascadeHandler
 * ─────────────────────────────────────────────────────────────────────────────
 * Called by AccountCSMCascadeTrigger (after update on Account).
 *
 * WHEN IT FIRES:
 *   Account_Team_CSM__c changed to a non-null value on any Account.
 *
 * WHAT IT DOES:
 *   1. Updates OwnerId on all related non-canceled Contracts to the new CSM.
 *   2. BFS outward from every changed account, collecting ALL downstream
 *      accounts no matter how deep, then sets Account_Team_CSM__c on all of
 *      them to the same CSM in a single Database.update call.
 *
 * GUARDS:
 *   1. System.isBatch()  - skips entirely when CSMAssignmentBatch is running.
 *      The batch manages its own assignments; we must not interfere.
 *   2. isCascading flag  - prevents re-entry when the cascade DML itself
 *      fires this trigger on the child records.
 *
 * @author  Blake Reeves / StargateCRM
 * @org     Displai.ai
 */
public class AccountCSMCascadeHandler {

    /** Set to true before cascade DML to block re-entry. */
    public static Boolean isCascading = false;

    public static void handleCSMChange(
            List<Account> newList, Map<Id, Account> oldMap) {

        // Guard 1: never run inside a batch execution context
        if (System.isBatch()) return;

        // Guard 2: never re-enter during our own cascade DML
        if (isCascading) return;

        // ── Collect accounts whose CSM changed to a non-null value ─────────
        Map<Id, Id> changedRoots = new Map<Id, Id>();
        for (Account acct : newList) {
            Id oldCSM = oldMap.get(acct.Id).Account_Team_CSM__c;
            if (acct.Account_Team_CSM__c != null
                    && acct.Account_Team_CSM__c != oldCSM) {
                changedRoots.put(acct.Id, acct.Account_Team_CSM__c);
            }
        }
        if (changedRoots.isEmpty()) return;

        // ── Update Contracts on changed accounts ────────────────────────────
        // Sets OwnerId = new CSM on all non-canceled Contracts
        // related to any account whose CSM just changed.
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Contract c : [
            SELECT Id, AccountId
            FROM   Contract
            WHERE  AccountId IN :changedRoots.keySet()
            AND    Status != 'canceled'
        ]) {
            c.OwnerId = changedRoots.get(c.AccountId);
            contractsToUpdate.add(c);
        }
        if (!contractsToUpdate.isEmpty()) {
            Database.update(contractsToUpdate, false);
        }

        // ── BFS: walk down the hierarchy level by level ─────────────────────
        // parentNewCSM maps every already-visited account to the CSM its
        // children should inherit.  Starts with the changed root accounts.
        Map<Id, Id> parentNewCSM   = new Map<Id, Id>(changedRoots);
        Map<Id, Id> allDescendants = new Map<Id, Id>();
        Set<Id>     frontier       = new Set<Id>(changedRoots.keySet());

        Integer depth = 0;
        while (!frontier.isEmpty() && depth < 15) {
            depth++;
            List<Account> children = [
                SELECT Id, ParentId
                FROM   Account
                WHERE  ParentId IN :frontier
            ];
            if (children.isEmpty()) break;
            Set<Id> nextFrontier = new Set<Id>();
            for (Account child : children) {
                Id inheritCSM = parentNewCSM.get(child.ParentId);
                if (inheritCSM != null) {
                    allDescendants.put(child.Id, inheritCSM);
                    parentNewCSM.put(child.Id, inheritCSM);
                    nextFrontier.add(child.Id);
                }
            }
            frontier = nextFrontier;
        }

        if (allDescendants.isEmpty()) return;

        // ── Build update list and fire single DML ────────────────────────────
        List<Account> toUpdate = new List<Account>();
        for (Id descId : allDescendants.keySet()) {
            toUpdate.add(new Account(
                Id                  = descId,
                Account_Team_CSM__c = allDescendants.get(descId)
            ));
        }

        isCascading = true;
        try {
            Database.update(toUpdate, false);
        } finally {
            isCascading = false;
        }
    }
}