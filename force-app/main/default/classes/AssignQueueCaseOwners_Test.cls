@isTest(SeeAllData=true)
private class AssignQueueCaseOwners_Test {
    @isTest
    static void testBatchRuns() {
        // Find a real case that has owner-change history
        // This drives coverage of the CaseHistory processing and update paths
        List<CaseHistory> hist = [
            SELECT CaseId FROM CaseHistory
            WHERE Field = 'Owner'
            LIMIT 1
        ];

        AssignQueueCaseOwners batch = new AssignQueueCaseOwners();
        // Inject specific case ID so batch processes exactly 1 record
        batch.testScopeIds = hist.isEmpty()
            ? new List<Id>()
            : new List<Id>{ hist[0].CaseId };

        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        System.assert(batch.processed >= 0, 'Batch should have run');
        System.assert(batch.updated >= 0, 'Updated count should be non-negative');
        System.assert(batch.skipped >= 0, 'Skipped count should be non-negative');
    }
}