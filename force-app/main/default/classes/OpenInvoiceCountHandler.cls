/**
 * OpenInvoiceCountHandler
 *
 * Maintains Open_Invoice_Count__c on Account as the combined total of:
 *   - blng__Invoice__c  where Status = 'Posted'  AND Balance > 0
 *   - Stripe_Invoice__c where Status__c = 'Open'
 *
 * Called by two thin triggers:
 *   BillingInvoiceOpenCountTrigger  (blng__Invoice__c)
 *   StripeInvoiceOpenCountTrigger   (Stripe_Invoice__c)
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-03-26
 */
public class OpenInvoiceCountHandler {

    // ── Entry points from triggers ──────────────────────────────────────────

    /**
     * Called from BillingInvoiceOpenCountTrigger (blng__Invoice__c).
     */
    public static void handleBillingTrigger(
        List<blng__Invoice__c> newList,
        List<blng__Invoice__c> oldList,
        Boolean isDelete
    ) {
        Set<Id> accountIds = new Set<Id>();

        // Collect account IDs from the changed invoices
        List<blng__Invoice__c> primary = isDelete ? oldList : newList;
        for (blng__Invoice__c inv : primary) {
            if (inv.blng__Account__c != null) {
                accountIds.add(inv.blng__Account__c);
            }
        }

        // On update, also capture the old account ID to handle reparenting
        if (!isDelete && oldList != null) {
            for (blng__Invoice__c inv : oldList) {
                if (inv.blng__Account__c != null) {
                    accountIds.add(inv.blng__Account__c);
                }
            }
        }

        if (!accountIds.isEmpty()) {
            recalculate(accountIds);
        }
    }

    /**
     * Called from StripeInvoiceOpenCountTrigger (Stripe_Invoice__c).
     */
    public static void handleStripeTrigger(
        List<Stripe_Invoice__c> newList,
        List<Stripe_Invoice__c> oldList,
        Boolean isDelete
    ) {
        Set<Id> accountIds = new Set<Id>();

        List<Stripe_Invoice__c> primary = isDelete ? oldList : newList;
        for (Stripe_Invoice__c inv : primary) {
            if (inv.Account__c != null) {
                accountIds.add(inv.Account__c);
            }
        }

        // On update, also capture old account ID to handle reparenting
        if (!isDelete && oldList != null) {
            for (Stripe_Invoice__c inv : oldList) {
                if (inv.Account__c != null) {
                    accountIds.add(inv.Account__c);
                }
            }
        }

        if (!accountIds.isEmpty()) {
            recalculate(accountIds);
        }
    }

    // ── Core recalculation ──────────────────────────────────────────────────

    /**
     * Queries both invoice sources for the given account IDs and writes
     * the combined open-invoice total to Open_Invoice_Count__c.
     *
     * Seeding every ID at 0 ensures accounts that drop to zero get
     * written correctly (not left with a stale positive count).
     */
    @TestVisible
    public static void recalculate(Set<Id> accountIds) {

        // Seed every account at zero
        Map<Id, Integer> openCounts = new Map<Id, Integer>();
        for (Id acctId : accountIds) {
            openCounts.put(acctId, 0);
        }

        // ── Salesforce Billing invoices ──────────────────────────────────────
        // Open = Status 'Posted' with a remaining balance
        for (AggregateResult ar : [
            SELECT blng__Account__c acctId, COUNT(Id) cnt
            FROM   blng__Invoice__c
            WHERE  blng__Account__c IN :accountIds
              AND  blng__InvoiceStatus__c = 'Posted'
              AND  blng__Balance__c > 0
            GROUP BY blng__Account__c
        ]) {
            Id  acctId = (Id)  ar.get('acctId');
            Integer cnt = Integer.valueOf(ar.get('cnt'));
            openCounts.put(acctId, openCounts.get(acctId) + cnt);
        }

        // ── Stripe invoices ──────────────────────────────────────────────────
        // Open = Status__c = 'Open'
        for (AggregateResult ar : [
            SELECT Account__c acctId, COUNT(Id) cnt
            FROM   Stripe_Invoice__c
            WHERE  Account__c IN :accountIds
              AND  Status__c = 'Open'
            GROUP BY Account__c
        ]) {
            Id  acctId = (Id)  ar.get('acctId');
            Integer cnt = Integer.valueOf(ar.get('cnt'));
            openCounts.put(acctId, openCounts.get(acctId) + cnt);
        }

        // ── Write results ────────────────────────────────────────────────────
        List<Account> toUpdate = new List<Account>();
        for (Id acctId : openCounts.keySet()) {
            toUpdate.add(new Account(
                Id = acctId,
                Open_Invoice_Count__c = openCounts.get(acctId)
            ));
        }

        if (!toUpdate.isEmpty()) {
            // Bypass the Stripe account-sync trigger to prevent NPE in async queue
            StripeTriggerHandler.enableBypass('Account');
            update toUpdate;
        }
    }
}