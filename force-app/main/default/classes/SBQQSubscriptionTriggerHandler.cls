public without sharing class SBQQSubscriptionTriggerHandler extends TriggerHandler {
    
    public SBQQSubscriptionTriggerHandler() {
        super('SBQQSubscriptionTriggerHandler');
    }

    public static List<Account_Webhook__e> accountsWebhookEvents;

    protected override void afterInsert() {
        checkAccountWebhooksOnInsert();
    }

    private void checkAccountWebhooksOnInsert() {
        Set<String> subscriptionAccountIds = new Set<String>();
        accountsWebhookEvents = new List<Account_Webhook__e>();

        if ( !AccountWebhookUtility.ContractTriggerCalled ) {
            for( SBQQ__Subscription__c newSubVar : (List<SBQQ__Subscription__c>)Trigger.new ) {
                if ( newSubVar.SBQQ__Account__c != null ) {
                    subscriptionAccountIds.add(newSubVar.SBQQ__Account__c);
                }           
            }
        }        

        if ( subscriptionAccountIds.size() > 0 ) {
            AccountWebhookUtility.SubscriptionTriggerCalled = true;
            Account_Webhook__e subscriptionAccWebhook = new Account_Webhook__e();
            subscriptionAccWebhook.Account_IDs__c = GeneralUtility.joinSet(subscriptionAccountIds,',');
            subscriptionAccWebhook.API_Action__c = AccountWebhookUtility.EVENT_TYPE_SUBSCRIPTION_CHANGED;
            accountsWebhookEvents.add(subscriptionAccWebhook);
        }

        if ( accountsWebhookEvents.size() > 0 ) {
            EventBus.publish(accountsWebhookEvents);
        }
    }
}