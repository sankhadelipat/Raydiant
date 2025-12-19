@isTest
public class AccountWebhookTriggerTest {
    
    static testMethod void testAccountWebhookEvents() {
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

        List<Account_Webhook__e> accountWebhookEvents = new List<Account_Webhook__e>();
        
        Account_Webhook__e newAccount = new Account_Webhook__e();
        newAccount.API_Action__c = AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT;
        newAccount.Account_IDs__c = String.valueOf(acc1.Id);
        accountWebhookEvents.add(newAccount);

        Map<Id,Set<String>> accountsMergedMap = new Map<Id,Set<String>>();
        accountsMergedMap.put(acc1.Id, new Set<String>{acc2.Id});
        Account_Webhook__e subscriptionAccWebhook = new Account_Webhook__e();
        subscriptionAccWebhook.Account_IDs__c = JSON.serialize(accountsMergedMap);
        subscriptionAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT;
        accountWebhookEvents.add(subscriptionAccWebhook);

        Test.startTest();
        EventBus.publish(accountWebhookEvents);
        Test.stopTest();

    }
}