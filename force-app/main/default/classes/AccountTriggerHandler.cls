public without sharing class AccountTriggerHandler extends TriggerHandler {
    
    public AccountTriggerHandler() {
        super('AccountTriggerHandler');
    }

    public static List<Account_Webhook__e> accountsWebhookEvents;

    protected override void afterUpdate() {
        newAccountWebhooks();
    }
    
    protected override void afterDelete() {
        sendMergedAccountsForWebhook();
    }

    private void newAccountWebhooks() {
        Set<Id> accountIds = new Set<Id>();
        Set<String> newAccountWebhookIds = new Set<String>();
        accountsWebhookEvents = new List<Account_Webhook__e>();

        for( Account newAccount : (List<Account>)Trigger.new ) {
            if ( String.isNotBlank(newAccount.Dashboard_Email__c) && isChanged('Dashboard_Email__c',newAccount) ) {
                accountIds.add(newAccount.Id);
            }
        }

        if ( accountIds.size() > 0 ) {
            for ( Account accVar : [SELECT Id, (SELECT Id FROM Contracts) 
                                    FROM Account WHERE ID IN : accountIds]) {

                if ( accVar.Contracts != null && accVar.Contracts.size() == 1 ) {
                    newAccountWebhookIds.add(accVar.Id);
                }
            }
        }

        if ( newAccountWebhookIds.size() > 0 ) {
            Account_Webhook__e newAccWebhook = new Account_Webhook__e();
            newAccWebhook.Account_IDs__c = GeneralUtility.joinSet(newAccountWebhookIds,',');
            newAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT;
            accountsWebhookEvents.add(newAccWebhook);
        }

        if ( accountsWebhookEvents.size() > 0 ) {
            EventBus.publish(accountsWebhookEvents);
        }
    }

    private void sendMergedAccountsForWebhook() {
        Map<Id,Set<String>> mergedAccountsMap = new Map<Id,Set<String>>();
        accountsWebhookEvents = new List<Account_Webhook__e>();
		Set<Id> mergedMasterAccountIds = new Set<Id>();
        Map<Id,Account> mergedMasterAccountMap = new Map<Id,Account>();
        
        for( Account oldAccount : (List<Account>)Trigger.old ) {
            if ( oldAccount.MasterRecordId != null ) {
                mergedMasterAccountIds.add(oldAccount.MasterRecordId);
            }
        }
        
        if ( mergedMasterAccountIds.size() == 0 ) {
            return;
        }
        for(Account acc : [SELECT Id, Dashboard_Email__c FROM Account WHERE Id IN : mergedMasterAccountIds]) {
            if ( String.isNotBlank(acc.Dashboard_Email__c) ) {
                mergedMasterAccountMap.put(acc.Id, acc);
            }            
        }
        if ( mergedMasterAccountMap.size() == 0 ) {
            return;
        }
        
        for( Account oldAccount : (List<Account>)Trigger.old ) {
            if ( oldAccount.MasterRecordId != null && String.isNotBlank(mergedMasterAccountMap.get(oldAccount.MasterRecordId)?.Dashboard_Email__c) ) {
                if ( mergedAccountsMap.containsKey(oldAccount.MasterRecordId) ) {
                    mergedAccountsMap.get(oldAccount.MasterRecordId).add(oldAccount.Id);
                } else {
                    mergedAccountsMap.put(oldAccount.MasterRecordId, new Set<String>{oldAccount.Id});
                }
            }
        }

        if ( mergedAccountsMap.size() > 0 ) {

            Account_Webhook__e subscriptionAccWebhook = new Account_Webhook__e();
            subscriptionAccWebhook.Account_IDs__c = JSON.serialize(mergedAccountsMap);
            subscriptionAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT;
            accountsWebhookEvents.add(subscriptionAccWebhook);
        }

        if ( accountsWebhookEvents.size() > 0 ) {
            EventBus.publish(accountsWebhookEvents);
        }
    }
}