@isTest
public class AccountTriggerHandlerTest {
 
    static testmethod void testNewAccountWebhookEvent() {
        TriggerHandler.bypass('AccountTriggerHandler');

        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        TriggerHandler.clearBypass('AccountTriggerHandler');

        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,true);
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, true);
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');

        Test.startTest();
        testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c LIMIT 1];

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');

        Test.stopTest();

        system.assertEquals(1, AccountTriggerHandler.accountsWebhookEvents.size());
    }

    static testmethod void testMergeAccountWebhookEvent() {
        List<Account> accounts = new List<Account>();
        TriggerHandler.bypass('AccountTriggerHandler');

        Account acc1 = TestDataFactory.createTestAccount(false);
        acc1.Dashboard_Email__c = 'testdashboard@email.com';
        insert acc1;
        system.assertNotEquals(null, acc1.Id, 'Account Inserted');

        Account acc2 = TestDataFactory.createTestAccount(false);
        acc2.Name = 'Deleted Account';
        accounts.add(acc2);

        insert accounts;

        TriggerHandler.clearBypass('AccountTriggerHandler');

        List<Account> totalAccounts = [SELECT Id FROM Account];
        system.assertEquals(2, totalAccounts.size());

        Test.startTest();
        Database.MergeResult[] results = Database.merge(acc1, accounts, false);
        Test.stopTest();

    }
}