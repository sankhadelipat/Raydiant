public without sharing class AccountWebhookQueueable implements Queueable, Database.AllowsCallouts {
    
    public Set<String> accIds = new Set<String>();
    public Map<Id,Set<String>> accountsMergedMap = new Map<Id,Set<String>>();
    public String apiAction;
    
    public AccountWebhookQueueable(Set<String> accountIds, String apiAction) {
        this.accIds.addAll(accountIds);
        this.apiAction = apiAction;
    }

    public AccountWebhookQueueable(Map<Id,Set<String>> mergedAccountsMap, String apiAction) {
        this.apiAction = apiAction;
        this.accountsMergedMap = new Map<Id,Set<String>>(mergedAccountsMap);
    }

    public void execute(QueueableContext context) {
        system.debug('called queueable');
        if ( accIds.size() > 0 ) {
            AccountWebhookUtility.accountWebhook(accIds,apiAction);
        } else if ( accountsMergedMap.size() > 0 ) {
            AccountWebhookUtility.accountWebhook(accountsMergedMap,apiAction);
        }
    }
}