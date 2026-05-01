global class OpenCaseCountBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Integer totalUpdated = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id FROM Account');
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> accountIds = new Set<Id>();
        for (Account a : scope) accountIds.add(a.Id);

        Map<Id, Integer> countMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) cnt
            FROM Case
            WHERE AccountId IN :accountIds
            AND IsClosed = false
            GROUP BY AccountId
        ]) {
            countMap.put((Id) ar.get('AccountId'), (Integer) ar.get('cnt'));
        }

        List<Account> toUpdate = new List<Account>();
        for (Account a : scope) {
            toUpdate.add(new Account(
                Id = a.Id,
                Number_of_Open_Cases__c = countMap.containsKey(a.Id) ? countMap.get(a.Id) : 0
            ));
        }

        update toUpdate;
        totalUpdated += toUpdate.size();
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Backfill complete. Total accounts updated: ' + totalUpdated);
    }
}