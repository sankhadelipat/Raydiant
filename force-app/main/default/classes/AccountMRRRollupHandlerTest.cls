/**
 * AccountMRRRollupHandlerTest
 * Tests single-level and deep multi-level Parent_MRR__c rollup.
 * Author : Stargate / Blake Reeves
 * Updated: 2026-04-07 � added deep 3-level rollup test (Texas Roadhouse scenario)
 */
@isTest
private class AccountMRRRollupHandlerTest {

    private static void bypassStripe() { StripeTriggerHandler.enableBypass('Account'); }

    private static Account createParent(String name, Decimal ownMRR) {
        bypassStripe();
        Account a = new Account(Name = name, Account_Value__c = ownMRR);
        insert a; return a;
    }

    private static Account createChild(String name, Id parentId, Decimal mrr) {
        bypassStripe();
        Account a = new Account(Name = name, ParentId = parentId, Account_Value__c = mrr);
        insert a; return a;
    }

    @isTest static void testParentMRRIsChildrenOnly() {
        bypassStripe();
        Account parent = createParent('Test Parent', 100);
        Test.startTest(); createChild('Loc 1', parent.Id, 200); createChild('Loc 2', parent.Id, 300); Test.stopTest();
        System.assertEquals(500, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c,
            'Parent_MRR__c = 200+300 = 500. Own (100) excluded.');
    }

    @isTest static void testParentWithNoOwnMRR() {
        bypassStripe();
        Account parent = createParent('No Own MRR Parent', null);
        Test.startTest(); createChild('Loc 1', parent.Id, 150); createChild('Loc 2', parent.Id, 150); Test.stopTest();
        System.assertEquals(300, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c,
            'Null own MRR: children only = 300');
    }

    @isTest static void testUpdateChildMRRUpdatesParent() {
        bypassStripe();
        Account parent = createParent('Test Parent', 50);
        Account child  = createChild('Loc 1', parent.Id, 100);
                         createChild('Loc 2', parent.Id, 100);
        Test.startTest(); bypassStripe(); child.Account_Value__c = 300; update child; Test.stopTest();
        System.assertEquals(400, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c,
            '300+100 = 400. Own (50) excluded.');
    }

    @isTest static void testDeleteChildReducesParentMRR() {
        bypassStripe();
        Account parent = createParent('Test Parent', 0);
        Account child1 = createChild('Loc 1', parent.Id, 200);
                         createChild('Loc 2', parent.Id, 100);
        Test.startTest(); delete child1; Test.stopTest();
        System.assertEquals(100, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c,
            'After delete: remaining child = 100');
    }

    @isTest static void testReparentUpdatesBothParents() {
        bypassStripe();
        Account parentA = createParent('Parent A', 0); Account parentB = createParent('Parent B', 0);
        Account child   = createChild('Loc 1', parentA.Id, 250);
                          createChild('Loc 2', parentA.Id, 100);
        Test.startTest(); bypassStripe(); child.ParentId = parentB.Id; update child; Test.stopTest();
        System.assertEquals(100, [SELECT Parent_MRR__c FROM Account WHERE Id = :parentA.Id].Parent_MRR__c, 'Parent A = 100');
        System.assertEquals(250, [SELECT Parent_MRR__c FROM Account WHERE Id = :parentB.Id].Parent_MRR__c, 'Parent B = 250');
    }

    @isTest static void testBulkInsert() {
        bypassStripe();
        Account parent = createParent('Bulk Parent', 0);
        List<Account> children = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            children.add(new Account(Name = 'Loc ' + i, ParentId = parent.Id, Account_Value__c = 100));
        }
        Test.startTest(); bypassStripe(); insert children; Test.stopTest();
        System.assertEquals(5000, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c, '50x100=5000');
    }

    /**
     * 3-level deep rollup test � the Texas Roadhouse scenario.
     * ##Parent ($0) -> Markets ($0 each) -> Locations ($25 each)
     * Without deep rollup, ##Parent.Parent_MRR__c = 0 (markets have $0 Account_Value__c).
     * With deep rollup, ##Parent.Parent_MRR__c = $100 (carries up through markets).
     */
    @isTest static void testDeepThreeLevelRollup() {
        bypassStripe();
        Account topParent = createParent('TX Roadhouse ##Parent', 0);
        Account market1   = createChild('Alan Hansen Market', topParent.Id, 0);
        Account market2   = createChild('Southwest Market',   topParent.Id, 0);

        Test.startTest();
        bypassStripe();
        insert new List<Account>{
            new Account(Name = 'Location 1', ParentId = market1.Id, Account_Value__c = 25),
            new Account(Name = 'Location 2', ParentId = market1.Id, Account_Value__c = 25),
            new Account(Name = 'Location 3', ParentId = market2.Id, Account_Value__c = 25),
            new Account(Name = 'Location 4', ParentId = market2.Id, Account_Value__c = 25)
        };
        Test.stopTest();

        System.assertEquals(50,  [SELECT Parent_MRR__c FROM Account WHERE Id = :market1.Id].Parent_MRR__c,   'Market1: 25+25=50');
        System.assertEquals(50,  [SELECT Parent_MRR__c FROM Account WHERE Id = :market2.Id].Parent_MRR__c,   'Market2: 25+25=50');
        System.assertEquals(100, [SELECT Parent_MRR__c FROM Account WHERE Id = :topParent.Id].Parent_MRR__c, '##Parent deep: (0+50)+(0+50)=100');
    }

    @isTest static void testRollupParentMRRDirect() {
        bypassStripe();
        Account parent = createParent('Direct Test Parent', 0);
        createChild('Child A', parent.Id, 300); createChild('Child B', parent.Id, 200);
        Test.startTest(); AccountMRRRollupHandler.rollupParentMRR(new Set<Id>{ parent.Id }); Test.stopTest();
        System.assertEquals(500, [SELECT Parent_MRR__c FROM Account WHERE Id = :parent.Id].Parent_MRR__c, 'Direct: 300+200=500');
    }
}