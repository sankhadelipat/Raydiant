global class CSMAssignmentBatch implements Database.Batchable<SObject>,
                                           Database.Stateful,
                                           Schedulable {

    public static Boolean isRunning = false;

    private Id annetteId;
    private Id franciscoId;
    private Id aliId;
    private Id vilenId;

    private Integer totalUpdated = 0;
    private Integer totalSkipped = 0;
    private Integer totalLocked  = 0;

    global CSMAssignmentBatch() {
        Map<String, Id> csmById = new Map<String, Id>();
        for (User u : [
            SELECT Id, Name FROM User
            WHERE  Name IN ('Annette Broussard','Francisco Fiedler','Ali Aziz','Vilen Gabrielyan')
            AND    IsActive = true ORDER BY Id ASC LIMIT 10
        ]) { csmById.put(u.Name, u.Id); }
        annetteId   = csmById.get('Annette Broussard');
        franciscoId = csmById.get('Francisco Fiedler');
        aliId       = csmById.get('Ali Aziz');
        vilenId     = csmById.get('Vilen Gabrielyan');
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new CSMAssignmentBatch(), 50);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        isRunning = true;
        return Database.getQueryLocator([
            SELECT Id, ParentId, Account_Value__c, Parent_MRR__c, Account_Team_CSM__c, CSM_Lock__c
            FROM   Account WHERE ParentId = null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> topIds = new Map<Id, Account>(scope).keySet();
        Set<Id> allFamilyIds = new Set<Id>(topIds);

        Map<Id, List<Account>> childrenByParent = new Map<Id, List<Account>>();
        Set<Id> childIds = new Set<Id>();
        for (Account child : [SELECT Id, ParentId, Account_Value__c, Account_Team_CSM__c
                              FROM Account WHERE ParentId IN :topIds]) {
            if (!childrenByParent.containsKey(child.ParentId))
                childrenByParent.put(child.ParentId, new List<Account>());
            childrenByParent.get(child.ParentId).add(child);
            allFamilyIds.add(child.Id); childIds.add(child.Id);
        }

        Map<Id, List<Account>> grandchildrenByParent = new Map<Id, List<Account>>();
        if (!childIds.isEmpty()) {
            for (Account gc : [SELECT Id, ParentId, Account_Value__c, Account_Team_CSM__c
                               FROM Account WHERE ParentId IN :childIds]) {
                if (!grandchildrenByParent.containsKey(gc.ParentId))
                    grandchildrenByParent.put(gc.ParentId, new List<Account>());
                grandchildrenByParent.get(gc.ParentId).add(gc);
                allFamilyIds.add(gc.Id);
            }
        }

        Map<Id, Id> acctToTop = new Map<Id, Id>();
        for (Id topId : topIds) acctToTop.put(topId, topId);
        for (Id topId : childrenByParent.keySet()) {
            for (Account child : childrenByParent.get(topId)) {
                acctToTop.put(child.Id, topId);
                List<Account> gcs = grandchildrenByParent.get(child.Id);
                if (gcs != null) for (Account gc : gcs) acctToTop.put(gc.Id, topId);
            }
        }

        Set<Id> familiesWithHoopla  = new Set<Id>();
        Set<Id> familiesWithAnySub  = new Set<Id>();
        for (SBQQ__Subscription__c sub : [
            SELECT SBQQ__Account__c, SBQQ__Product__r.Name
            FROM   SBQQ__Subscription__c WHERE SBQQ__Account__c IN :allFamilyIds
        ]) {
            Id topId = acctToTop.get(sub.SBQQ__Account__c);
            if (topId == null) continue;
            familiesWithAnySub.add(topId);
            String pName = sub.SBQQ__Product__r != null ? sub.SBQQ__Product__r.Name : '';
            if (pName != null && pName.containsIgnoreCase('Hoopla')) familiesWithHoopla.add(topId);
        }

        List<Account> toUpdate = new List<Account>();

        for (Account topAcct : scope) {

            if (topAcct.CSM_Lock__c == true) { totalLocked++; continue; }

            List<Account> children = childrenByParent.get(topAcct.Id);
            Boolean isFamily = (children != null && !children.isEmpty());

            if (!familiesWithAnySub.contains(topAcct.Id)) { totalSkipped++; continue; }

            if (familiesWithHoopla.contains(topAcct.Id)) {
                assignIfDifferent(topAcct, annetteId, toUpdate);
                if (isFamily) {
                    for (Account child : children) {
                        assignIfDifferent(child, annetteId, toUpdate);
                        List<Account> gcs = grandchildrenByParent.get(child.Id);
                        if (gcs != null) for (Account gc : gcs) assignIfDifferent(gc, annetteId, toUpdate);
                    }
                }
                continue;
            }

            Decimal ownMRR   = topAcct.Account_Value__c != null ? topAcct.Account_Value__c : 0;
            Decimal childMRR = topAcct.Parent_MRR__c    != null ? topAcct.Parent_MRR__c    : 0;
            Id topCSM = csmFromMRR(ownMRR + childMRR);
            assignIfDifferent(topAcct, topCSM, toUpdate);

            if (!isFamily) continue;
            for (Account child : children) {
                Id childCSM = (topCSM != null) ? topCSM : csmFromMRR(child.Account_Value__c);
                assignIfDifferent(child, childCSM, toUpdate);
                List<Account> gcs = grandchildrenByParent.get(child.Id);
                if (gcs != null) {
                    for (Account gc : gcs) {
                        Id gcCSM = (childCSM != null) ? childCSM : csmFromMRR(gc.Account_Value__c);
                        assignIfDifferent(gc, gcCSM, toUpdate);
                    }
                }
            }
        }

        if (!toUpdate.isEmpty()) Database.update(toUpdate, false);
    }

    global void finish(Database.BatchableContext bc) {
        isRunning = false;
        System.debug(LoggingLevel.INFO,
            'CSMAssignmentBatch COMPLETE | Updated: ' + totalUpdated +
            ' | Skipped (no subs): ' + totalSkipped +
            ' | Locked (CSM_Lock__c): ' + totalLocked);
    }

    private void assignIfDifferent(Account acct, Id newCSM, List<Account> toUpdate) {
        if (acct.Account_Team_CSM__c != newCSM) {
            toUpdate.add(new Account(Id = acct.Id, Account_Team_CSM__c = newCSM));
            totalUpdated++;
        }
    }

    private Id csmFromMRR(Decimal mrr) {
        if (mrr == null || mrr < 200) return franciscoId;
        if (mrr < 500)               return aliId;
        return vilenId;
    }
}