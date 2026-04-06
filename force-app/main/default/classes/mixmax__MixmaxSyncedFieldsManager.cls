public class MixmaxSyncedFieldsManager {

    /**
     * The value of the `ExternalId__c` field for the `MixmaxSyncedFields__c` record used by this package.
     * The `ExternalId__c` field is unique (no two records can have the same value for it), effectively making
     * `MixmaxSyncedFields__c` a singleton.
     */
    static final String EXTERNAL_ID = 'mixmax';

    /*
     * @param type The SOBject type to retrieve synced fields for e.g. 'Contact', 'Lead', etc.
     * @param fieldName A field name
     */
    public MixmaxSyncedFields__c getOrCreate(String fieldName) {
        String externalId = EXTERNAL_ID;
        String query = 'SELECT Id, IsObjectConfigured__c, ' + fieldName + ' FROM MixmaxSyncedFields__c WHERE ExternalId__c = :externalId';
        List<MixmaxSyncedFields__c> mixmaxSyncedFieldsResults = Database.query(query);
        if (mixmaxSyncedFieldsResults.size() > 0) {
            // We're looking up by a unique field (ExternalId__c) so there can be at most one result.
            return mixmaxSyncedFieldsResults.get(0);
        }

        return this.upsertAndGet();
    }

    public MixmaxSyncedFields__c getOrCreate(SObjectType type) {
        return this.getOrCreate(getSyncedFieldsName(type));
    }

    /*
     * Upserts a MixmaxSyncedFields__c record by a static external id.
     */
    private MixmaxSyncedFields__c upsertAndGet() {
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFields__c(ExternalId__c = EXTERNAL_ID);
        upsert mixmaxSyncedFields ExternalId__c;

        return mixmaxSyncedFields;
    }

    public static String getSyncedFieldsName(SObjectType type) {
        return String.valueOf(type) + 'Fields__c';
    }
}