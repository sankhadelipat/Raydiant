global class MassCloseAutomatedCases implements Database.Batchable<SObject>, Database.Stateful {
    @TestVisible private List<Id> testScopeIds = null;
    public Integer success = 0;
    public Integer failed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (testScopeIds != null) {
            return Database.getQueryLocator([SELECT Id, Status FROM Case WHERE Id IN :testScopeIds]);
        }
        return Database.getQueryLocator([
            SELECT Id, Status FROM Case
            WHERE OwnerId = '0051I000001ZVSMQA4'
            AND IsClosed = false
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        for (Case c : scope) {
            c.Status = 'Mass Closed';
        }
        List<Database.SaveResult> results = Database.update(scope, false);
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) success++;
            else {
                failed++;
                System.debug('FAIL: ' + r.getId() + ' | ' + r.getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('MassCloseAutomatedCases DONE - Success: ' + success + ' | Failed: ' + failed);
    }
}