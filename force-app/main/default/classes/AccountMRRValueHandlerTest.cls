/**
 * AccountMRRValueHandlerTest
 *
 * Monthly_Value__c and F52_Active__c are formula/managed fields —
 * cannot be set directly in Apex tests. Tests validate handler logic,
 * trigger wiring, and governor limit safety via recalculate() and
 * real DML on SBQQ__Subscription__c.
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-04-03
 */
@isTest
private class AccountMRRValueHandlerTest {

    private static Account createAccount(String name) {
        StripeTriggerHandler.enableBypass('Account');
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static SBQQ__Subscription__c createSub(Id accountId) {
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Account__c  = accountId,
            SBQQ__Quantity__c = 1
        );
        insert sub;
        return sub;
    }

    // ── recalculate() with no active subs → Account_Value__c = 0 ─────────────

    @isTest
    static void testRecalculateNoSubs() {
        Account acc = createAccount('No Subs Test');

        Test.startTest();
        AccountMRRValueHandler.recalculate(new Set<Id>{ acc.Id });
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(0, result.Account_Value__c,
            'No active subs — Account_Value__c should be 0');
    }

    // ── recalculate() with empty set — should not error ───────────────────────

    @isTest
    static void testRecalculateEmptySet() {
        Test.startTest();
        AccountMRRValueHandler.recalculate(new Set<Id>());
        Test.stopTest();
    }

    // ── recalculate() with multiple accounts ──────────────────────────────────

    @isTest
    static void testRecalculateMultipleAccounts() {
        Account acc1 = createAccount('Multi Test 1');
        Account acc2 = createAccount('Multi Test 2');

        Test.startTest();
        AccountMRRValueHandler.recalculate(new Set<Id>{ acc1.Id, acc2.Id });
        Test.stopTest();

        List<Account> results = [
            SELECT Account_Value__c FROM Account WHERE Id IN (:acc1.Id, :acc2.Id)
        ];
        for (Account a : results) {
            System.assertNotEquals(null, a.Account_Value__c,
                'Account_Value__c should be set after recalculate');
        }
    }

    // ── Trigger fires on insert ───────────────────────────────────────────────

    @isTest
    static void testTriggerFiresOnInsert() {
        Account acc = createAccount('Trigger Insert Test');

        Test.startTest();
        createSub(acc.Id);
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, result.Account_Value__c,
            'Trigger should fire and set Account_Value__c on insert');
    }

    // ── Trigger fires on update ───────────────────────────────────────────────

    @isTest
    static void testTriggerFiresOnUpdate() {
        Account acc = createAccount('Trigger Update Test');
        SBQQ__Subscription__c sub = createSub(acc.Id);

        Test.startTest();
        sub.SBQQ__TerminatedDate__c = Date.today().addDays(30);
        update sub;
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, result.Account_Value__c,
            'Trigger should fire and set Account_Value__c on update');
    }

    // ── Trigger fires on delete ───────────────────────────────────────────────

    @isTest
    static void testTriggerFiresOnDelete() {
        Account acc = createAccount('Trigger Delete Test');
        SBQQ__Subscription__c sub = createSub(acc.Id);

        Test.startTest();
        delete sub;
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(0, result.Account_Value__c,
            'Account_Value__c should be 0 after last sub deleted');
    }

    // ── Trigger fires on undelete ─────────────────────────────────────────────

    @isTest
    static void testTriggerFiresOnUndelete() {
        Account acc = createAccount('Trigger Undelete Test');
        SBQQ__Subscription__c sub = createSub(acc.Id);
        delete sub;

        Test.startTest();
        undelete sub;
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, result.Account_Value__c,
            'Trigger should fire and set Account_Value__c on undelete');
    }

    // ── Bulk — 200 subs, no governor limit errors ─────────────────────────────

    @isTest
    static void testBulkInsert() {
        Account acc = createAccount('Bulk Test');

        List<SBQQ__Subscription__c> subs = new List<SBQQ__Subscription__c>();
        for (Integer i = 0; i < 200; i++) {
            subs.add(new SBQQ__Subscription__c(
                SBQQ__Account__c  = acc.Id,
                SBQQ__Quantity__c = 1
            ));
        }

        Test.startTest();
        insert subs;
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, result.Account_Value__c,
            'Bulk insert should complete without governor errors');
    }
}