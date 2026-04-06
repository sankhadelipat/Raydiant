public class MixmaxTriggerHandler {
    /*
     * Send data in chunks to reduce burden on server. See the `CHUNK_SIZE` section in the project README for more details.
     */
    static Integer CHUNK_SIZE = 100;
    SObjectType type;
    String verb;

    /*
     * @param type The SObject type e.g. Account.SObjectType
     * @param verb The trigger action, either 'delete', 'update', or 'create'
     */
    public MixmaxTriggerHandler(SObjectType type, String verb) {
        this.type = type;
        this.verb = verb;
    }

    /*
     * @param oldMap The value of Trigger.oldMap
     * @param newMap The value of Trigger.newMap
     */
    public void handle(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        List<Object> objs;
        if (verb == 'delete') {
            objs = oldMap.values();
        } else {
            objs = newMap.values();
        }

        // Default values of arguments for the MixmaxUpdater.handle call. Only applicable for updates, but provided
        // in all cases for simplicity.
        Boolean filtered = false;
        String customObjectId = null;
        PayloadObjectsType objectsType = PayloadObjectsType.objects;

        // Additional logic related to managed-package-level filtering.
        if (MixmaxUtils.isCustomObject(this.type)) {
            MixmaxCustomObjectFilterResult customObjectFilterResult = this.isChangeEventForUnsupportedCustomObject();
            if (customObjectFilterResult.isChangeEventForUnsupportedCustomObject) return;

            // The change event was not for an unsupported custom object - if applicable, grab the newly inserted MixmaxSyncedFields__c's ID.
            customObjectId = customObjectFilterResult.customObjectId;
        } else if (verb == 'update' && MixmaxSupportedStandardObjects.SUPPORTED_STANDARD_OBJECTS.contains(type)) {
            // Determine if this change event should be filtered and grab that filtered data if so.
            MixmaxUpdateFilterPayload updateFilterPayload = this.applyManagedPackageFiltering(oldMap, newMap, objs);

            filtered = updateFilterPayload.filtered;
            customObjectId = updateFilterPayload.customObjectId;
            objectsType = updateFilterPayload.objectsType;
            objs = updateFilterPayload.objs;
        }

        String typeStr = String.valueOf(type);
        List<Object> objectChunk = new List<Object>();
        for (Integer i = 0; i < objs.size(); i++) {
            Object obj = objs.get(i);
            objectChunk.add(obj);
            if (objectChunk.size() == CHUNK_SIZE || i + 1 == objs.size()) {
                String objectString = JSON.serialize(objectChunk);
                MixmaxUpdater.handle(typeStr, verb, objectString, customObjectId, filtered, objectsType);
                objectChunk = new List<Object>(); // Creating a new list so it can be serialized without `null`s.
            }
        }
    }

    public List<SObjectUpdate> getObjectsForUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap, Set<String> syncedFields) {
        List<SObjectUpdate> result = new List<SObjectUpdate>();
        MixmaxUpdateFilter updateFilter = new MixmaxUpdateFilter(syncedFields);
        for (Id id: newMap.keySet()) {
            SObjectUpdate changed = updateFilter.getSyncedUpdate(oldMap.get(id), newMap.get(id));
            if (changed != null) {
                result.add(changed);
            }
        }
        return result;
    }

    /**
     * Determines if the change event is for unsupported custom object (by comparing against MixmaxSyncedFields__c.ConfiguredCustomObjects).
     *
     * @return     MixmaxCustomObjectFilterResult
     */
    public MixmaxCustomObjectFilterResult isChangeEventForUnsupportedCustomObject() {
        Boolean isChangeEventForUnsupportedCustomObject = false;
        String customObjectId = null;

        // For custom objects, filter the records if those custom objects have not been configured within Mixmax.
        ConfiguredCustomObjectSettings configuredCustomObjectsSettings = this.getConfiguredCustomObjectSettings();
        if (!configuredCustomObjectsSettings.isObjectConfigured) {
            // The synced fields custom object hasn't been set up yet; don't filter anything.
            customObjectId = configuredCustomObjectsSettings.customObjectId;
        } else {
            Set<String> configuredCustomObjects = configuredCustomObjectsSettings.configuredCustomObjects;
            // Filter if the set of configured custom objects does not contain the string representation of the custom object being updated.
            isChangeEventForUnsupportedCustomObject = !configuredCustomObjects.contains(String.valueOf(this.type));
        }

        return new MixmaxCustomObjectFilterResult(customObjectId, isChangeEventForUnsupportedCustomObject);
    }

    /**
     * Determines if this change event should be filtered before we make the external callout, and computes that filtered data if so.
     *
     * @param      Map<Id, SObject>
     * @param      Map<Id, SObject>
     * @param      List<Object>
     *
     * @return     MixmaxUpdateFilterPayload
     */
    public MixmaxUpdateFilterPayload applyManagedPackageFiltering(Map<Id, SObject> oldMap, Map<Id, SObject> newMap, List<Object> objs) {
        // Default values of arguments for the MixmaxUpdater.handle call. Only applicable for updates, but provided
        // in all cases for simplicity.
        Boolean filtered = false;
        String customObjectId = null;
        PayloadObjectsType objectsType = PayloadObjectsType.objects;

        // For supported standard objects, filter the records if the user has synced fields and the changed fields are not in those synced fields.
        SyncedFieldSettings syncedFieldSettings = this.getSyncedFieldSettings();
        if (!syncedFieldSettings.isObjectConfigured) {
            customObjectId = syncedFieldSettings.customObjectId;
        } else if (!syncedFieldSettings.fields.isEmpty()) {
            Set<string> syncedFields = this.filterExistantFields(syncedFieldSettings.fields);
            objs = this.getObjectsForUpdate(oldMap, newMap, syncedFields);
            filtered = true;
            objectsType = PayloadObjectsType.objectsWithChanges;
        }

        return new MixmaxUpdateFilterPayload(filtered, customObjectId, objectsType, objs);
    }

    /**
     * Helper function to validate synced fields. This ensures we only attempt to retrieve synced
     * fields that actually exist on the object.
     *
     * @param      fullSyncedFields  Sync Condition fields for the object
     *
     * @return     Set<String>
     */
    private Set<String> filterExistantFields(Set<String> fullSyncedFields) {
        Set<String> syncedFields = new Set<String>();
        Map<String, Schema.SObjectField> fieldMap = this.type.getDescribe().fields.getMap();
        for (String field: fullSyncedFields) {
            if (fieldMap.containsKey(field)) {
                syncedFields.add(field);
            }
        }
        return syncedFields;
    }

    /**
     * Helper function to grab configured custom object settings from the MixmaxSyncedFields__c singleton.
     *
     * @return     SyncedFieldSettings
     */
    private ConfiguredCustomObjectSettings getConfiguredCustomObjectSettings() {
        final String CONFIGURED_CUSTOM_OBJECTS_FIELD = 'ConfiguredCustomObjects__c';
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFieldsManager().getOrCreate(CONFIGURED_CUSTOM_OBJECTS_FIELD);
        String configuredCustomObjectsStr = (String) mixmaxSyncedFields.get(CONFIGURED_CUSTOM_OBJECTS_FIELD);
        Set<String> configuredCustomObjects = new Set<String>();
        if (configuredCustomObjectsStr != null) {
            configuredCustomObjects.addAll(configuredCustomObjectsStr.split('\n'));
        }
        return new ConfiguredCustomObjectSettings(mixmaxSyncedFields.Id, configuredCustomObjects, mixmaxSyncedFields.IsObjectConfigured__c);
    }

    /**
     * Helper function to grab synced field settings from the MixmaxSyncedFields__c singleton.
     *
     * @return     SyncedFieldSettings
     */
    private SyncedFieldSettings getSyncedFieldSettings() {
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFieldsManager().getOrCreate(this.type);
        String syncedFieldsStr = (String) mixmaxSyncedFields.get(MixmaxSyncedFieldsManager.getSyncedFieldsName(this.type));
        Set<String> syncedFields = new Set<String>();
        if (syncedFieldsStr != null) {
            syncedFields.addAll(syncedFieldsStr.split('\n'));
        }
        return new SyncedFieldSettings(mixmaxSyncedFields.Id, syncedFields, mixmaxSyncedFields.IsObjectConfigured__c == true);
    }

    class SyncedFieldSettings {
        public ID customObjectId;
        public Set<String> fields;
        public Boolean isObjectConfigured;

        public SyncedFieldSettings(ID customObjectId, Set<String> fields, Boolean isObjectConfigured) {
            this.customObjectId = customObjectId;
            this.fields = fields;
            this.isObjectConfigured = isObjectConfigured;
        }
    }

    class ConfiguredCustomObjectSettings {
        public ID customObjectId;
        public Set<String> configuredCustomObjects;
        public Boolean isObjectConfigured;

        public ConfiguredCustomObjectSettings(ID customObjectId, Set<String> configuredCustomObjects, Boolean isObjectConfigured) {
            this.customObjectId = customObjectId;
            this.configuredCustomObjects = configuredCustomObjects;
            this.isObjectConfigured = isObjectConfigured;
        }
    }

    public class MixmaxCustomObjectFilterResult {
        public String customObjectId;
        public Boolean isChangeEventForUnsupportedCustomObject;

        public MixmaxCustomObjectFilterResult(String customObjectId, Boolean isChangeEventForUnsupportedCustomObject) {
            this.customObjectId = customObjectId;
            this.isChangeEventForUnsupportedCustomObject = isChangeEventForUnsupportedCustomObject;
        }
    }

    public class MixmaxUpdateFilterPayload {
        public Boolean filtered;
        public String customObjectId;
        public PayloadObjectsType objectsType;
        public List<Object> objs;

        public MixmaxUpdateFilterPayload(Boolean filtered, String customObjectId, PayloadObjectsType objectsType, List<Object> objs) {
            this.filtered = filtered;
            this.customObjectId = customObjectId;
            this.objectsType = objectsType;
            this.objs = objs;
        }
    }
}