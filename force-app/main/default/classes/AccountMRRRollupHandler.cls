/**
 * AccountMRRRollupHandler
 *
 * Rolls up MRR from child Accounts to their parent, then assigns the
 * correct Account CSM based on the Displai CSM matrix.
 *
 * FIELD RULES (never violate):
 *   Account_Value__c — live real-time MRR on every account (sum of active subs).
 *                      Written by AccountMRRValueTriggerLIVE. NEVER touched here.
 *   Parent_MRR__c  — calculated total written by this class:
 *                      = SUM(children's Account_Value__c) ONLY.
 *                      The parent's own Account_Value__c is intentionally excluded —
 *                      Parent_MRR__c represents the child rollup only.
 *
 * CSM ASSIGNMENT MATRIX (evaluated against total family MRR = own + children):
 *   EX product (Hoopla) at any level        →  Annette Broussard  [TRUMP CARD]
 *   Total family MRR >= $500                →  Vilen Gabrielyan
 *   Total family MRR >= $101                →  Ali Aziz
 *   Total family MRR  < $101 (or null)      →  Francisco Fiedler
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-03-26
 * Updated: 2026-04-03 — swapped Latest_MRR__c → Account_Value__c (live MRR)
 */
public class AccountMRRRollupHandler {

    // ── CSM User IDs ─────────────────────────────────────────────────────────
    private static final Id CSM_ANNETTE   = '0051I000007llZLQAY'; // Annette Broussard
    private static final Id CSM_VILEN     = '0058W000009o8jpQAA'; // Vilen Gabrielyan
    private static final Id CSM_ALI       = '0051I000007n36jQAA'; // Ali Aziz
    private static final Id CSM_FRANCISCO = '0058W00000FtNrxQAF'; // Francisco Fiedler

    // ── MRR Tier Thresholds ──────────────────────────────────────────────────
    private static final Decimal TIER_VILEN = 500;
    private static final Decimal TIER_ALI   = 101;  // corrected from 200

    // ────────────────────────────────────────────────────────────────────────

    public static void handleTrigger(
        List<Account> newList,
        List<Account> oldList,
        Map<Id, Account> newMap,
        Map<Id, Account> oldMap,
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isDelete,
        Boolean isUndelete
    ) {
        Set<Id> parentIds = new Set<Id>();

        if (isDelete) {
            for (Account acc : oldList) {
                if (acc.ParentId != null) parentIds.add(acc.ParentId);
            }

        } else if (isUpdate) {
            for (Account acc : newList) {
                Account oldAcc = oldMap.get(acc.Id);
                Boolean mrrChanged    = (acc.Account_Value__c != oldAcc.Account_Value__c);
                Boolean parentChanged = (acc.ParentId      != oldAcc.ParentId);

                if (acc.ParentId != null && (mrrChanged || parentChanged)) {
                    parentIds.add(acc.ParentId);
                }
                // Old parent also needs recalculating if child was reparented
                if (parentChanged && oldAcc.ParentId != null) {
                    parentIds.add(oldAcc.ParentId);
                }
            }

        } else {
            // Insert or undelete
            for (Account acc : newList) {
                if (acc.ParentId != null) parentIds.add(acc.ParentId);
            }
        }

        if (parentIds.isEmpty()) return;

        rollupAndAssignCSM(parentIds);
    }

    /**
     * For each parent:
     *   1. Sums children's Account_Value__c  →  writes to Parent_MRR__c
     *   2. Assigns Account_Team_CSM__c based on Hoopla trump card + MRR matrix
     */
    @TestVisible
    public static void rollupAndAssignCSM(Set<Id> parentIds) {

        // ── Step 1: Get parent account details ───────────────────────────────
        Map<Id, Account> parentMap = new Map<Id, Account>([
            SELECT Id, Account_Value__c, EX_Product_Formula__c
            FROM   Account
            WHERE  Id IN :parentIds
        ]);

        // ── Step 2: Aggregate children's MRR ────────────────────────────────
        Map<Id, Decimal> childSumMap = new Map<Id, Decimal>();
        for (Id pid : parentIds) {
            childSumMap.put(pid, 0);
        }
        for (AggregateResult ar : [
            SELECT ParentId, SUM(Account_Value__c) totalMRR
            FROM   Account
            WHERE  ParentId IN :parentIds
            GROUP BY ParentId
        ]) {
            Id      pid   = (Id)      ar.get('ParentId');
            Decimal total = (Decimal) ar.get('totalMRR');
            childSumMap.put(pid, total != null ? total : 0);
        }

        // ── Step 3: Build update list ────────────────────────────────────────
        List<Account> toUpdate = new List<Account>();

        for (Id pid : parentIds) {
            Account parent = parentMap.get(pid);
            if (parent == null) continue;

            // Parent_MRR__c = children's MRR only (parent's own Account_Value__c excluded)
            Decimal ownMRR    = parent.Account_Value__c != null ? parent.Account_Value__c : 0;
            Decimal childSum  = childSumMap.containsKey(pid) ? childSumMap.get(pid) : 0;
            Decimal parentMRR = childSum; // stored value — children only

            // CSM thresholds evaluate total family MRR (own + children)
            Decimal totalFamilyMRR = ownMRR + childSum;

            // CSM assignment — Hoopla is the trump card
            Id assignedCSM;
            String exFormula = parent.EX_Product_Formula__c;
            if (String.isNotBlank(exFormula) && exFormula.contains('EX')) {
                assignedCSM = CSM_ANNETTE;
            } else if (totalFamilyMRR >= TIER_VILEN) {
                assignedCSM = CSM_VILEN;
            } else if (totalFamilyMRR >= TIER_ALI) {
                assignedCSM = CSM_ALI;
            } else {
                assignedCSM = CSM_FRANCISCO;
            }

            toUpdate.add(new Account(
                Id                  = pid,
                Parent_MRR__c     = parentMRR,
                Account_Team_CSM__c = assignedCSM
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}