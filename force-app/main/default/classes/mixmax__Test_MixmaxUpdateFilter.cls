@isTest
private class Test_MixmaxUpdateFilter {
    @isTest
    static void returnedObjectIncludesAllFields() {
        Set<String> syncedFields = new Set<String>{ 'Company', 'NumberOfEmployees' };
        Lead oldLead = makeLead('Foo', 'Bar', 'TestMax', 2);
        Lead newLead = makeLead('NotFoo', 'Bar', 'TestMax', 5);
        Map<String, Object> expectedRecord = new Map<String, Object>{
            'FirstName' => 'NotFoo',
            'LastName' => 'Bar',
            'Company' => 'TestMax',
            'NumberOfEmployees' => 5
        };

        MixmaxUpdateFilter updateFilter = new MixmaxUpdateFilter(syncedFields);
        SObjectUpdate syncedUpdate = updateFilter.getSyncedUpdate(oldLead, newLead);
        System.assertEquals(syncedUpdate.record, expectedRecord);
        // .changedFields doesn't consider non-synced fields either
        System.assertEquals(syncedUpdate.changedFields, new Set<String>{ 'NumberOfEmployees'});
    }

    @isTest
    static void returnsNullIfNoChangesToSyncedFields() {
        Set<String> syncedFields = new Set<String>{ 'Company', 'FirstName' };
        Lead oldLead = makeLead('Foo', 'Bar', 'TestMax', 2);
        Lead newLead = makeLead('Foo', 'Bar', 'TestMax', 5);

        MixmaxUpdateFilter updateFilter = new MixmaxUpdateFilter(syncedFields);
        SObjectUpdate syncedUpdate = updateFilter.getSyncedUpdate(oldLead, newLead);
        System.assertEquals(syncedUpdate, null);
    }

    static Lead makeLead(String firstName, String lastName, String company, Integer numEmployees) {
        return new Lead(
                FirstName = firstName,
                LastName = lastName,
                Company = company,
                NumberOfEmployees = numEmployees
        );
    }
}