@isTest
private class OpenCaseCountBackfillBatchTest {

    @isTest
    static void testBackfillBatch() {
        Account a1 = new Account(Name = 'Backfill Test Account 1');
        Account a2 = new Account(Name = 'Backfill Test Account 2');
        insert new List<Account>{ a1, a2 };

        insert new List<Case>{
            new Case(AccountId = a1.Id, Status = 'New'),
            new Case(AccountId = a1.Id, Status = 'Working'),
            new Case(AccountId = a1.Id, Status = 'Closed'),
            new Case(AccountId = a2.Id, Status = 'New')
        };

        Test.startTest();
        Database.executeBatch(new OpenCaseCountBackfillBatch(), 200);
        Test.stopTest();

        Account result1 = [SELECT Number_of_Open_Cases__c FROM Account WHERE Id = :a1.Id];
        Account result2 = [SELECT Number_of_Open_Cases__c FROM Account WHERE Id = :a2.Id];

        System.assertEquals(2, result1.Number_of_Open_Cases__c.intValue(), 'Account 1 should have 2 open cases');
        System.assertEquals(1, result2.Number_of_Open_Cases__c.intValue(), 'Account 2 should have 1 open case');
    }

    @isTest
    static void testBackfillBatch_noOpenCases() {
        Account a = new Account(Name = 'Backfill No Open Cases');
        insert a;

        Case c = new Case(AccountId = a.Id, Status = 'New');
        insert c;
        c.Status = 'Closed';
        update c;

        Test.startTest();
        Database.executeBatch(new OpenCaseCountBackfillBatch(), 200);
        Test.stopTest();

        Account result = [SELECT Number_of_Open_Cases__c FROM Account WHERE Id = :a.Id];
        System.assertEquals(0, result.Number_of_Open_Cases__c.intValue(), 'Account should have 0 open cases');
    }
}