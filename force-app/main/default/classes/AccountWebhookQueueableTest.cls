@isTest
public class AccountWebhookQueueableTest {
    
    static testmethod void testNewAccountQueueable() {
        TriggerHandler.bypass('AccountTriggerHandler');
        
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted'); 
        
        TriggerHandler.clearBypass('AccountTriggerHandler');

        Set<String> accountIds = new Set<String>{accVar.Id};
        String apiAction = AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT;

        Test.startTest();
        System.enqueueJob(new AccountWebhookQueueable(accountIds,apiAction));
        Test.stopTest();
    }

    static testMethod void testAccountMergeQueueable() {
        List<Account> accounts = new List<Account>();

        TriggerHandler.bypass('AccountTriggerHandler');
        
        Account acc1 = TestDataFactory.createTestAccount(false);
        accounts.add(acc1);

        Account acc2 = TestDataFactory.createTestAccount(false);
        acc2.Name = 'Deleted Account';
        accounts.add(acc2);

        insert accounts;
        
        TriggerHandler.clearBypass('AccountTriggerHandler');

        List<Account> totalAccounts = [SELECT Id FROM Account];
        system.assertEquals(2, totalAccounts.size());

        Map<Id,Set<String>> accountsMergedMap = new Map<Id,Set<String>>();
        accountsMergedMap.put(acc1.Id, new Set<String>{acc2.Id});

        String apiAction = AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT;

        Test.startTest();
        System.enqueueJob(new AccountWebhookQueueable(accountsMergedMap,apiAction));
        Test.stopTest();
    }
}