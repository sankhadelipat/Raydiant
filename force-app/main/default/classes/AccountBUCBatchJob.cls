public class AccountBUCBatchJob implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Business_Use_Case__c
            FROM Account
            WHERE Id IN (
                SELECT SBQQ__Account__c
                FROM SBQQ__Subscription__c
                WHERE F52_Active__c = true
                AND SBQQ__Product__r.Business_Use_Case__c IN ('Hoopla', 'Digital Signage')
            )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> accounts) {
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

        List<SBQQ__Subscription__c> subs = [
            SELECT SBQQ__Account__c, SBQQ__Product__r.Business_Use_Case__c
            FROM SBQQ__Subscription__c
            WHERE F52_Active__c = true
            AND SBQQ__Account__c IN :accountIds
            AND SBQQ__Product__r.Business_Use_Case__c IN ('Hoopla', 'Digital Signage')
        ];

        Map<Id, Boolean> hasHoopla = new Map<Id, Boolean>();
        Map<Id, Boolean> hasDS     = new Map<Id, Boolean>();

        for (SBQQ__Subscription__c sub : subs) {
            Id accId = sub.SBQQ__Account__c;
            String buc = sub.SBQQ__Product__r.Business_Use_Case__c;
            if (!hasHoopla.containsKey(accId)) hasHoopla.put(accId, false);
            if (!hasDS.containsKey(accId))     hasDS.put(accId, false);
            if (buc == 'Hoopla')          hasHoopla.put(accId, true);
            if (buc == 'Digital Signage') hasDS.put(accId, true);
        }

        List<Account> toUpdate = new List<Account>();

        for (Account acc : accounts) {
            Boolean hoopla = hasHoopla.containsKey(acc.Id) ? hasHoopla.get(acc.Id) : false;
            Boolean ds     = hasDS.containsKey(acc.Id)     ? hasDS.get(acc.Id)     : false;

            String newBUC;
            if      (hoopla && ds) newBUC = 'Both';
            else if (hoopla)       newBUC = 'Hoopla';
            else if (ds)           newBUC = 'Digital Signage';
            else continue;

            if (acc.Business_Use_Case__c != newBUC) {
                toUpdate.add(new Account(Id = acc.Id, Business_Use_Case__c = newBUC));
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    public void finish(Database.BatchableContext bc) { }
}