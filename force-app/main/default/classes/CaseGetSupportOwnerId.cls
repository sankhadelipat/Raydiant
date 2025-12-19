public without sharing class CaseGetSupportOwnerId {
    @AuraEnabled (cacheable=true)
    public static String getCaseOwnerId() {
        String supportQueueId;

        List<Group> sQiList = new List<Group>([SELECT Id from Group WHERE DeveloperName='Raydiant_Support']);
        System.debug('select list size is' + sQiList.size());
        if (sQiList.size() > 0){
            supportQueueId = sQiList[0].Id;
            System.debug('supportQueueId is:' + supportQueueId + ':');
        }
        return supportQueueId;

    }
}