@isTest
private class CaseTriggerHandlerTest {

    // ─── helpers ───────────────────────────────────────────────────────────────

    private static Account makeAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Case makeCase(Id accountId, String status) {
        Case c = new Case(AccountId = accountId, Status = status);
        insert c;
        return c;
    }

    private static Integer getCount(Id accountId) {
        return [SELECT Number_of_Open_Cases__c FROM Account WHERE Id = :accountId].Number_of_Open_Cases__c.intValue();
    }

    private static Integer getARCount(Id accountId) {
        Decimal val = [SELECT Open_AR_Case_Count__c FROM Account WHERE Id = :accountId].Open_AR_Case_Count__c;
        return val == null ? 0 : val.intValue();
    }

    // ─── tests ─────────────────────────────────────────────────────────────────

    @isTest
    static void testInsertOpenCase() {
        Account a = makeAccount('Test Account');
        Test.startTest();
        makeCase(a.Id, 'New');
        Test.stopTest();
        System.assertEquals(1, getCount(a.Id), 'Should have 1 open case after insert');
    }

    @isTest
    static void testInsertMultipleOpenCases() {
        Account a = makeAccount('Test Account');
        Test.startTest();
        makeCase(a.Id, 'New');
        makeCase(a.Id, 'Working');
        makeCase(a.Id, 'Escalated');
        Test.stopTest();
        System.assertEquals(3, getCount(a.Id), 'Should have 3 open cases');
    }

    @isTest
    static void testCloseCase_decrementsCount() {
        Account a = makeAccount('Test Account');
        Case c = makeCase(a.Id, 'New');
        makeCase(a.Id, 'New');

        Test.startTest();
        c.Status = 'Closed';
        update c;
        Test.stopTest();

        System.assertEquals(1, getCount(a.Id), 'Closing a case should decrement count to 1');
    }

    @isTest
    static void testDeleteCase_decrementsCount() {
        Account a = makeAccount('Test Account');
        Case c = makeCase(a.Id, 'New');
        makeCase(a.Id, 'New');

        Test.startTest();
        delete c;
        Test.stopTest();

        System.assertEquals(1, getCount(a.Id), 'Deleting a case should decrement count to 1');
    }

    @isTest
    static void testUndeleteCase_incrementsCount() {
        Account a = makeAccount('Test Account');
        Case c = makeCase(a.Id, 'New');
        delete c;

        Test.startTest();
        undelete c;
        Test.stopTest();

        System.assertEquals(1, getCount(a.Id), 'Undeleting an open case should increment count');
    }

    @isTest
    static void testAllCasesClosed_setsZero() {
        Account a = makeAccount('Test Account');
        Case c = makeCase(a.Id, 'New');

        Test.startTest();
        c.Status = 'Closed';
        update c;
        Test.stopTest();

        System.assertEquals(0, getCount(a.Id), 'All cases closed should set count to 0');
    }

    @isTest
    static void testCaseWithNoAccount_noError() {
        Test.startTest();
        Case c = new Case(Status = 'New'); // no AccountId
        insert c;
        Test.stopTest();
        // Just verifying no exception thrown
        System.assert(true, 'Should handle case with no Account gracefully');
    }

    @isTest
    static void testReparentCase_updatesBotheAccounts() {
        Account a1 = makeAccount('Account 1');
        Account a2 = makeAccount('Account 2');
        Case c = makeCase(a1.Id, 'New');

        Test.startTest();
        c.AccountId = a2.Id;
        update c;
        Test.stopTest();

        System.assertEquals(0, getCount(a1.Id), 'Original account should have 0 open cases');
        System.assertEquals(1, getCount(a2.Id), 'New account should have 1 open case');
    }

    @isTest
    static void testBulk_200Cases() {
        Account a = makeAccount('Bulk Account');
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Case(AccountId = a.Id, Status = 'New'));
        }

        Test.startTest();
        insert cases;
        Test.stopTest();

        System.assertEquals(200, getCount(a.Id), 'Should handle 200 cases in bulk');
    }

    @isTest
    static void testARCaseCount_insertsAndCloses() {
        // Get AR record type — skip if not in this org
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Case' AND Id = '0128W000001QAtl'
            LIMIT 1
        ];
        if (rts.isEmpty()) return;
        Id arRtId = rts[0].Id;

        Account a = makeAccount('AR Test Account');
        Case c1 = new Case(AccountId = a.Id, Status = 'New', RecordTypeId = arRtId);
        Case c2 = new Case(AccountId = a.Id, Status = 'New', RecordTypeId = arRtId);
        insert new List<Case>{ c1, c2 };

        Test.startTest();
        c1.Status = 'Closed';
        update c1;
        Test.stopTest();

        System.assertEquals(1, getARCount(a.Id), 'AR count should drop to 1 after close');
        System.assertEquals(1, getCount(a.Id),   'Total open count should also be 1');
    }

    @isTest
    static void testNonARCaseDoesNotCountInARRollup() {
        // A case with no record type should count in total open but not AR
        Account a = makeAccount('Mixed Test Account');
        Test.startTest();
        makeCase(a.Id, 'New'); // no record type = not AR
        Test.stopTest();
        System.assertEquals(1, getCount(a.Id),   'Total open count should be 1');
        System.assertEquals(0, getARCount(a.Id), 'AR count should be 0 — wrong record type');
    }

    @isTest
    static void testBulk_200CasesAcrossMultipleAccounts() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i));
        }
        insert accounts;

        List<Case> cases = new List<Case>();
        for (Account a : accounts) {
            for (Integer i = 0; i < 40; i++) {
                cases.add(new Case(AccountId = a.Id, Status = 'New'));
            }
        }

        Test.startTest();
        insert cases;
        Test.stopTest();

        for (Account a : accounts) {
            System.assertEquals(40, getCount(a.Id), 'Each account should have 40 open cases');
        }
    }
}