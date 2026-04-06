global class CSMAssignmentBatch implements Database.Batchable<SObject>,
                                           Database.Stateful,
                                           Schedulable {

    public static Boolean isRunning = false;

    private static final Set<String> HOOPLA_PRODUCTS = new Set<String>{
        'Hoopla User License - Standard',
        'Hoopla Dynamics 365 Integration',
        'Hoopla Gold Package [legacy]',
        'Hoopla User License - Fan',
        'Display License - Hoopla TV'
    };

    private Id annetteId;
    private Id franciscoId;
    private Id aliId;
    private Id vilenId;

    private Integer totalUpdated        = 0;
    private Integer totalSkipped        = 0;
    private Integer totalAlreadyCorrect = 0;

    global CSMAssignmentBatch() {
        Map<String, Id> csmById = new Map<String, Id>();
        for (User u : [
            SELECT Id, Name FROM User
            WHERE Name IN ('Annette Broussard','Francisco Fiedler','Ali Aziz','Vilen Gabrielyan')
            AND IsActive = true ORDER BY Id ASC LIMIT 10
        ]) {
            csmById.put(u.Name, u.Id);
        }
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
            SELECT Id, ParentId, Account_Value__c, Account_Team_CSM__c
            FROM Account WHERE ParentId = null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> topIds = new Map<Id, Account>(scope).keySet();
        Set<Id> allFamilyIds = new Set<Id>(topIds);

        Map<Id, List<Account>> childrenByParent = new Map<Id, List<Account>>();
        Set<Id> childIds = new Set<Id>();

        for (Account child : [
            SELECT Id, ParentId, Account_Value__c, Account_Team_CSM__c
            FROM Account WHERE ParentId IN :topIds
        ]) {
            if (!childrenByParent.containsKey(child.ParentId)) {
                childrenByParent.put(child.ParentId, new List<Account>());
            }
            childrenByParent.get(child.ParentId).add(child);
            allFamilyIds.add(child.Id);
            childIds.add(child.Id);
        }

        Map<Id, List<Account>> grandchildrenByParent = new Map<Id, List<Account>>();
        if (!childIds.isEmpty()) {
            for (Account gc : [
                SELECT Id, ParentId, Account_Value__c, Account_Team_CSM__c
                FROM Account WHERE ParentId IN :childIds
            ]) {
                if (!grandchildrenByParent.containsKey(gc.ParentId)) {
                    grandchildrenByParent.put(gc.ParentId, new List<Account>());
                }
                grandchildrenByParent.get(gc.ParentId).add(gc);
                allFamilyIds.add(gc.Id);
            }
        }

        Map<Id, Boolean> acctHasHoopla = new Map<Id, Boolean>();
        Map<Id, Boolean> acctHasAnySub = new Map<Id, Boolean>();
        for (SBQQ__Subscription__c sub : [
            SELECT Id, SBQQ__Account__c, SBQQ__Product__r.Name
            FROM SBQQ__Subscription__c WHERE SBQQ__Account__c IN :allFamilyIds
        ]) {
            Id acctId = sub.SBQQ__Account__c;
            String prodName = sub.SBQQ__Product__r != null ? sub.SBQQ__Product__r.Name : '';
            acctHasAnySub.put(acctId, true);
            if (HOOPLA_PRODUCTS.contains(prodName)) acctHasHoopla.put(acctId, true);
        }

        List<Account> toUpdate = new List<Account>();

        for (Account topAcct : scope) {
            List<Account> children = childrenByParent.get(topAcct.Id);
            Boolean isFamily = (children != null && !children.isEmpty());

            Boolean familyHasHoopla = acctHasHoopla.containsKey(topAcct.Id);
            Boolean familyHasAnySub = acctHasAnySub.containsKey(topAcct.Id);

            if (isFamily) {
                for (Account child : children) {
                    if (!familyHasHoopla && acctHasHoopla.containsKey(child.Id)) familyHasHoopla = true;
                    if (!familyHasAnySub && acctHasAnySub.containsKey(child.Id)) familyHasAnySub = true;
                    List<Account> gcs = grandchildrenByParent.get(child.Id);
                    if (gcs != null) {
                        for (Account gc : gcs) {
                            if (!familyHasHoopla && acctHasHoopla.containsKey(gc.Id)) familyHasHoopla = true;
                            if (!familyHasAnySub && acctHasAnySub.containsKey(gc.Id)) familyHasAnySub = true;
                            if (familyHasHoopla && familyHasAnySub) break;
                        }
                    }
                    if (familyHasHoopla && familyHasAnySub) break;
                }
            }

            if (!familyHasAnySub) {
                if (topAcct.Account_Team_CSM__c != null) {
                    toUpdate.add(new Account(Id = topAcct.Id, Account_Team_CSM__c = null));
                    totalUpdated++;
                }
                if (isFamily) {
                    for (Account child : children) {
                        if (child.Account_Team_CSM__c != null) {
                            toUpdate.add(new Account(Id = child.Id, Account_Team_CSM__c = null));
                            totalUpdated++;
                        }
                        List<Account> gcs = grandchildrenByParent.get(child.Id);
                        if (gcs != null) {
                            for (Account gc : gcs) {
                                if (gc.Account_Team_CSM__c != null) {
                                    toUpdate.add(new Account(Id = gc.Id, Account_Team_CSM__c = null));
                                    totalUpdated++;
                                }
                            }
                        }
                    }
                }
                totalSkipped++;
                continue;
            }

            Id determinedCSM = familyHasHoopla ? annetteId : csmFromMRR(topAcct.Account_Value__c);

            if (determinedCSM == null) { totalSkipped++; continue; }

            if (topAcct.Account_Team_CSM__c != determinedCSM) {
                toUpdate.add(new Account(Id = topAcct.Id, Account_Team_CSM__c = determinedCSM));
                totalUpdated++;
            } else { totalAlreadyCorrect++; }

            if (isFamily) {
                for (Account child : children) {
                    if (child.Account_Team_CSM__c != determinedCSM) {
                        toUpdate.add(new Account(Id = child.Id, Account_Team_CSM__c = determinedCSM));
                        totalUpdated++;
                    } else { totalAlreadyCorrect++; }
                    List<Account> gcs = grandchildrenByParent.get(child.Id);
                    if (gcs != null) {
                        for (Account gc : gcs) {
                            if (gc.Account_Team_CSM__c != determinedCSM) {
                                toUpdate.add(new Account(Id = gc.Id, Account_Team_CSM__c = determinedCSM));
                                totalUpdated++;
                            } else { totalAlreadyCorrect++; }
                        }
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
            ' | Already correct: ' + totalAlreadyCorrect +
            ' | Skipped (no subs): ' + totalSkipped);
    }

    private Id csmFromMRR(Decimal mrr) {
        if (mrr == null || mrr <= 100) return franciscoId;
        if (mrr <= 499) return aliId;
        return vilenId;
    }
}