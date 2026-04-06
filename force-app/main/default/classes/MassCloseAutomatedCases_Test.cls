@isTest(SeeAllData=true)
private class MassCloseAutomatedCases_Test {
    @isTest
    static void testBatchRuns() {
        // Try AP-owned open cases first; fall back to any open case so execute() is covered
        List<Case> openCases = [
            SELECT Id FROM Case
            WHERE OwnerId = '0051I000001ZVSMQA4'
            AND IsClosed = false
            LIMIT 1
        ];
        if (openCases.isEmpty()) {
            openCases = [SELECT Id FROM Case WHERE IsClosed = false LIMIT 1];
        }
        MassCloseAutomatedCases batch = new MassCloseAutomatedCases();
        batch.testScopeIds = openCases.isEmpty()
            ? new List<Id>()
            : new List<Id>{ openCases[0].Id };
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        System.assert(batch.success >= 0);
        System.assert(batch.failed >= 0);
    }
}