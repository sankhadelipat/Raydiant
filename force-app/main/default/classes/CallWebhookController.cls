public without sharing class CallWebhookController {

    @AuraEnabled(cacheable=true)
    public static Boolean isAdminUser(String userId) {
        String userProfileId = [SELECT ProfileId FROM User WHERE Id = :userId].ProfileId;
        // System Administrator || System Administrator (No Calendar Sync) || CSM || Accounting
        if (userProfileId == '00e1I000001hx7kQAA' 
            || userProfileId == '00e1I000000JVE2QAO' 
            || userProfileId == '00e1I000000a3vwQAA' 
            || userProfileId == '00e1I000000JTqiQAG') {
            return true;
        }
        return false;
    }

    @AuraEnabled(cacheable=true)
    public static void callWebhookFromLwc(Id contractId){
        List<Id> IdList = new List<Id>{contractId};
        ContractWebhookHandler.callWebhook(IdList);
    }

}