trigger AccountWebhookTrigger on Account_Webhook__e (after insert) {

    for (Account_Webhook__e accWebhook : Trigger.New) {
        if ( accWebhook.API_Action__c == AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT ) {

            Map<String,Object> rawResponse = (Map<String,Object>)JSON.deserializeUntyped(accWebhook.Account_IDs__c);
            Map<Id,Set<String>> accountMergeSetById = new Map<Id,Set<String>>();
            for ( String key : rawResponse.keySet() ) {
                Id keyId = Id.valueOf(key);
                List<String> accIdsAsStrings = (List<String>) JSON.deserialize(JSON.serialize(rawResponse.get(key)), List<String>.class);
                accountMergeSetById.put(keyId,new Set<String>(accIdsAsStrings));
            }
            System.enqueueJob(new AccountWebhookQueueable(accountMergeSetById,accWebhook.API_Action__c));

        } else {
            List<String> accountIdList = accWebhook.Account_IDs__c.split(',');
            Set<String> accountsIds = new Set<String>(accountIdList);
            System.enqueueJob(new AccountWebhookQueueable(accountsIds,accWebhook.API_Action__c));
        }
    }
}