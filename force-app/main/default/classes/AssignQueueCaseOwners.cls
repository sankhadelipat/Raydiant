global class AssignQueueCaseOwners implements Database.Batchable<SObject>, Database.Stateful {
    public Integer processed = 0;
    public Integer updated = 0;
    public Integer skipped = 0;
    @TestVisible private List<Id> testScopeIds = null;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (testScopeIds != null) {
            return Database.getQueryLocator([SELECT Id, OwnerId FROM Case WHERE Id IN :testScopeIds]);
        }
        return Database.getQueryLocator([
            SELECT Id, OwnerId FROM Case
            WHERE Owner.Type = 'Queue'
            AND Owner.Name != 'Hoopla Free Lead Queue'
            AND CreatedDate >= 2025-01-01T00:00:00Z
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        Set<Id> caseIds = new Map<Id, Case>(scope).keySet();
        Map<String, Id> nameToId = new Map<String, Id>();
        for (User u : [SELECT Id, Name FROM User WHERE IsActive = true]) {
            nameToId.put(u.Name, u.Id);
        }
        Map<Id, Id> caseToUser = new Map<Id, Id>();
        for (CaseHistory h : [
            SELECT CaseId, NewValue
            FROM CaseHistory
            WHERE CaseId IN :caseIds
            AND Field = 'Owner'
            ORDER BY CaseId, CreatedDate DESC
        ]) {
            if (caseToUser.containsKey(h.CaseId)) continue;
            String nv = String.valueOf(h.NewValue);
            if (nv == null) continue;
            if (nv.length() >= 15 && nv.startsWith('005')) {
                try { caseToUser.put(h.CaseId, Id.valueOf(nv)); } catch(Exception e) {}
            } else if (nameToId.containsKey(nv)) {
                caseToUser.put(h.CaseId, nameToId.get(nv));
            }
        }
        List<Case> toUpdate = new List<Case>();
        for (Case c : scope) {
            if (caseToUser.containsKey(c.Id)) {
                c.OwnerId = caseToUser.get(c.Id);
                toUpdate.add(c);
            } else {
                skipped++;
            }
        }
        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Database.SaveResult r : results) {
                if (r.isSuccess()) updated++;
                else System.debug('FAIL: ' + r.getId() + ' | ' + r.getErrors());
            }
        }
        processed += scope.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('BATCH DONE - Processed: ' + processed + ' | Owner Updated: ' + updated + ' | Left in Queue: ' + skipped);
    }
}