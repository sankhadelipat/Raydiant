/**
 * AccountMRRRollupHandlerTest
 *
 * Tests Parent_MRR__c rollup only.
 * CSM assignment tests are handled separately once user IDs are confirmed in each org.
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-03-26
 * Updated: 2026-04-03 — swapped Latest_MRR__c → Account_Value__c, stripped CSM assertions
 */
@isTest
private class AccountMRRRollupHandlerTest {

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static void bypassStripe() {
        StripeTriggerHandler.enableBypass('Account');
    }

    private static Account createParent(String name, Decimal ownMRR) {
        bypassStripe();
        Account a = new Account(Name = name, Account_Value__c = ownMRR);
        insert a;
        return a;
    }

    private static Account createChild(String name, Id parentId, Decimal mrr) {
        bypassStripe();
        Account a = new Account(Name = name, ParentId = parentId, Account_Value__c = mrr);
        insert a;
        return a;
    }

    // ── MRR Rollup Tests ─────────────────────────────────────────────────────

    @isTest
    static void testParentMRRIsChildrenOnly() {
        bypassStripe();
        Account parent = createParent('Test Parent', 100); // own MRR = 100, excluded from Parent_MRR__c

        Test.startTest();
        createChild('Loc 1', parent.Id, 200);
        createChild('Loc 2', parent.Id, 300);
        Test.stopTest();

        Account result = [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(500, result.Parent_MRR__c,
            'Parent_MRR__c = children only (200+300) = 500. Own MRR excluded.');
    }

    @isTest
    static void testParentWithNoOwnMRR() {
        bypassStripe();
        Account parent = createParent('No Own MRR Parent', null);

        Test.startTest();
        createChild('Loc 1', parent.Id, 150);
        createChild('Loc 2', parent.Id, 150);
        Test.stopTest();

        Account result = [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(300, result.Parent_MRR__c,
            'Parent with null own MRR should roll up children only = 300');
    }

    @isTest
    static void testUpdateChildMRRUpdatesParent() {
        bypassStripe();
        Account parent = createParent('Test Parent', 50);
        Account child  = createChild('Loc 1', parent.Id, 100);
                         createChild('Loc 2', parent.Id, 100);

        Test.startTest();
        bypassStripe();
        child.Account_Value__c = 300;
        update child;
        Test.stopTest();

        Account result = [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(400, result.Parent_MRR__c,
            'Parent_MRR__c = children only (300 + 100) = 400. Own (50) excluded.');
    }

    @isTest
    static void testDeleteChildReducesParentMRR() {
        bypassStripe();
        Account parent = createParent('Test Parent', 0);
        Account child1 = createChild('Loc 1', parent.Id, 200);
                         createChild('Loc 2', parent.Id, 100);

        Test.startTest();
        delete child1;
        Test.stopTest();

        Account result = [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(100, result.Parent_MRR__c,
            'After delete: remaining child (100) = 100');
    }

    @isTest
    static void testReparentUpdatesBothParents() {
        bypassStripe();
        Account parentA = createParent('Parent A', 0);
        Account parentB = createParent('Parent B', 0);
        Account child   = createChild('Loc 1', parentA.Id, 250);
                          createChild('Loc 2', parentA.Id, 100);

        Test.startTest();
        bypassStripe();
        child.ParentId = parentB.Id;
        update child;
        Test.stopTest();

        Account resA = [SELECT Parent_MRR__c FROM Account WHERE Id = :parentA.Id];
        Account resB = [SELECT Parent_MRR__c FROM Account WHERE Id = :parentB.Id];
        System.assertEquals(100, resA.Parent_MRR__c, 'Parent A should = 100 after reparent');
        System.assertEquals(250, resB.Parent_MRR__c, 'Parent B should = 250 after reparent');
    }

    @isTest
    static void testBulkInsert() {
        bypassStripe();
        Account parent = createParent('Bulk Parent', 0);

        List<Account> children = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            children.add(new Account(
                Name             = 'Loc ' + i,
                ParentId         = parent.Id,
                Account_Value__c = 100
            ));
        }

        Test.startTest();
        bypassStripe();
        insert children;
        Test.stopTest();

        Account result = [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id];
        System.assertEquals(5000, result.Parent_MRR__c, '50 x $100 = $5000');
    }
}