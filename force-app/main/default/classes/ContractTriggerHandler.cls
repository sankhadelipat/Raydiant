public without sharing class ContractTriggerHandler extends TriggerHandler {
    
    public ContractTriggerHandler() {
        super('ContractTriggerHandler');
    }

    public static List<Account_Webhook__e> accountsWebhookEvents;

    protected override void afterInsert() {
        checkAccountWebhooksOnInsert();
    }
    
    protected override void afterUpdate() {
        checkAccountWebhooksOnUpdate();
    }

    private void checkAccountWebhooksOnInsert() {
        AccountWebhookUtility.ContractTriggerCalled = true;
        accountsWebhookEvents = new List<Account_Webhook__e>();
        
        Set<String> contractAccountIds = new Set<String>();
        Set<String> contractIds = new Set<String>();
        Set<String> newAccountWebhookIds = new Set<String>();
        Set<String> accountSubscriptionWebhookIds = new Set<String>();

        for( Contract newContract : (List<Contract>)Trigger.new ) {
            contractIds.add(newContract.Id);
            if ( newContract.AccountId != null ) {
                contractAccountIds.add(newContract.AccountId);
            }           
        }

        if ( contractAccountIds.size() > 0 ) {
            for ( Account accVar : [SELECT Id, (SELECT Id FROM Contracts WHERE ID NOT IN : contractIds) 
                                    FROM Account WHERE ID IN : contractAccountIds]) {

                if ( accVar.Contracts != null && accVar.Contracts.size() > 0 ) {
                    accountSubscriptionWebhookIds.add(accVar.Id);
                }
            }
        }

        if ( accountSubscriptionWebhookIds.size() > 0 ) {
            Account_Webhook__e subscriptionAccWebhook = new Account_Webhook__e();
            subscriptionAccWebhook.Account_IDs__c = GeneralUtility.joinSet(accountSubscriptionWebhookIds,',');
            subscriptionAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_SUBSCRIPTION_CHANGED;
            accountsWebhookEvents.add(subscriptionAccWebhook);
        }

        if ( accountsWebhookEvents.size() > 0 ) {
            EventBus.publish(accountsWebhookEvents);
        }
    }

    private void checkAccountWebhooksOnUpdate() {
        if ( AccountWebhookUtility.ContractTriggerCalled ) {
            return;
        }
        if ( AccountWebhookUtility.SubscriptionTriggerCalled ) {
            return;
        }

        accountsWebhookEvents = new List<Account_Webhook__e>();
        Set<String> contractAccountIds = new Set<String>();

        for( Contract contractVar : (List<Contract>)Trigger.new ) {
            if ( isChanged('Status',contractVar) &&  contractVar.AccountId != null ) {
                contractAccountIds.add(contractVar.AccountId);
            }           
        }
        
        if ( contractAccountIds.size() > 0 ) {
            AccountWebhookUtility.ContractTriggerCalled = true;
            Account_Webhook__e subscriptionAccWebhook = new Account_Webhook__e();
            subscriptionAccWebhook.Account_IDs__c = GeneralUtility.joinSet(contractAccountIds,',');
            subscriptionAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_SUBSCRIPTION_CHANGED;
            accountsWebhookEvents.add(subscriptionAccWebhook);
        }

        if ( accountsWebhookEvents.size() > 0 ) {
            EventBus.publish(accountsWebhookEvents);
        }
    }
}