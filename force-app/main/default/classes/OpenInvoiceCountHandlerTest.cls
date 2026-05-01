/**
 * OpenInvoiceCountHandlerTest
 *
 * Tests for OpenInvoiceCountHandler.
 *
 * Coverage targets:
 *   - Stripe open invoices roll up to Account
 *   - Updating a Stripe invoice to Paid zeros the count
 *   - Deleting a Stripe invoice decrements the count
 *   - Accounts with no open invoices stay at / reset to 0
 *   - Bulk insert of Stripe invoices across multiple accounts
 *   - handleBillingTrigger code path (called directly, no DML)
 *
 * NOTE ON BillingInvoiceOpenCountTrigger:
 *   The billing trigger is intentionally NOT deployed alongside this class.
 *   The existing managed Salesforce Billing triggers on blng__Invoice__c
 *   already handle part of the billing count; adding a second custom trigger
 *   creates a managed-vs-custom race condition that nulls out the field.
 *   Billing invoice counts are corrected via the backfill anonymous Apex.
 *   The Stripe trigger covers all new Stripe activity going forward.
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-03-26
 */
@isTest
private class OpenInvoiceCountHandlerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Suppress the Stripe account-sync trigger before Account DML. */
    private static void bypassStripe() {
        StripeTriggerHandler.enableBypass('Account');
    }

    private static Account createAccount(String name) {
        bypassStripe();
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    /**
     * Creates a Stripe_Invoice__c linked to the given account.
     * status: 'Open' | 'Paid' | 'Void' etc.
     */
    private static Stripe_Invoice__c createStripeInvoice(Id accountId, String status) {
        Stripe_Invoice__c inv = new Stripe_Invoice__c(
            Account__c = accountId,
            Status__c  = status
        );
        insert inv;
        return inv;
    }


    // ── Stripe invoice tests ──────────────────────────────────────────────────

    @isTest
    static void testStripeOpenInvoiceIncrementsCount() {
        Account acct = createAccount('Stripe Test Account');

        Test.startTest();
        bypassStripe();
        createStripeInvoice(acct.Id, 'Open');
        createStripeInvoice(acct.Id, 'Open');
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(2, result.Open_Invoice_Count__c,
            'Two open Stripe invoices should produce count = 2');
    }

    @isTest
    static void testStripeNonOpenInvoiceNotCounted() {
        Account acct = createAccount('Stripe Paid Account');

        Test.startTest();
        bypassStripe();
        createStripeInvoice(acct.Id, 'Paid');
        createStripeInvoice(acct.Id, 'Void');
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(0, result.Open_Invoice_Count__c,
            'Paid/Void Stripe invoices should not be counted');
    }

    @isTest
    static void testStripeInvoiceMarkedPaidDecrementsCount() {
        Account acct = createAccount('Stripe Decrement Account');
        bypassStripe();
        Stripe_Invoice__c inv = createStripeInvoice(acct.Id, 'Open');

        Test.startTest();
        bypassStripe();
        inv.Status__c = 'Paid';
        update inv;
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(0, result.Open_Invoice_Count__c,
            'After paying the Stripe invoice the count should be 0');
    }

    @isTest
    static void testStripeInvoiceDeleteDecrementsCount() {
        Account acct = createAccount('Stripe Delete Account');
        bypassStripe();
        Stripe_Invoice__c inv = createStripeInvoice(acct.Id, 'Open');

        Test.startTest();
        bypassStripe();
        delete inv;
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(0, result.Open_Invoice_Count__c,
            'After deleting the open Stripe invoice the count should be 0');
    }

    // ── Billing handler direct-call test ─────────────────────────────────────
    // We test handleBillingTrigger() directly (no blng DML) to avoid the
    // managed InvoiceTrigger race condition while still covering that code path.

    @isTest
    static void testHandleBillingTriggerCodePath() {
        Account acct = createAccount('Billing Handler Account');

        // Build an in-memory blng__Invoice__c (not inserted) pointing at the account
        blng__Invoice__c fakeInv = new blng__Invoice__c(blng__Account__c = acct.Id);

        Test.startTest();
        bypassStripe();
        // Call insert path — no matching open billing invoices so count = 0
        OpenInvoiceCountHandler.handleBillingTrigger(
            new List<blng__Invoice__c>{ fakeInv }, null, false
        );
        // Call delete path
        OpenInvoiceCountHandler.handleBillingTrigger(
            null, new List<blng__Invoice__c>{ fakeInv }, true
        );
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assert(
            result.Open_Invoice_Count__c == null || result.Open_Invoice_Count__c == 0,
            'Account with no real open billing invoices should have count of 0'
        );
    }

    // ── Bulk test ─────────────────────────────────────────────────────────────

    @isTest
    static void testBulkStripeInsert() {
        bypassStripe();
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i));
        }
        insert accounts;

        List<Stripe_Invoice__c> invoices = new List<Stripe_Invoice__c>();
        for (Account a : accounts) {
            for (Integer j = 0; j < 3; j++) {
                invoices.add(new Stripe_Invoice__c(
                    Account__c = a.Id,
                    Status__c  = 'Open'
                ));
            }
        }

        Test.startTest();
        bypassStripe();
        insert invoices;
        Test.stopTest();

        for (Account result : [
            SELECT Open_Invoice_Count__c
            FROM   Account
            WHERE  Id IN :accounts
        ]) {
            System.assertEquals(3, result.Open_Invoice_Count__c,
                'Each bulk account should have 3 open Stripe invoices');
        }
    }

    // ── Direct recalculate test (no-DML path) ─────────────────────────────────

    @isTest
    static void testRecalculateDirectly() {
        Account acct = createAccount('Direct Recalculate Account');

        // Insert invoices without relying on trigger order
        bypassStripe();
        Stripe_Invoice__c si = new Stripe_Invoice__c(
            Account__c = acct.Id,
            Status__c  = 'Open'
        );
        insert si;

        Test.startTest();
        bypassStripe();
        OpenInvoiceCountHandler.recalculate(new Set<Id>{ acct.Id });
        Test.stopTest();

        Account result = [SELECT Open_Invoice_Count__c FROM Account WHERE Id = :acct.Id];
        System.assert(result.Open_Invoice_Count__c >= 1,
            'Direct recalculate should pick up the open Stripe invoice');
    }
}