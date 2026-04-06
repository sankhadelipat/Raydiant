@isTest
class Test_MixmaxTriggerHandler {
    @isTest
    static void unconfiguredCustomObjectChange() {
        Test.startTest();

        MixmaxSyncedFields__c syncedFields = new MixmaxSyncedFields__c(ExternalId__c = 'mixmax');
        syncedFields.IsObjectConfigured__c = true;
        syncedFields.ConfiguredCustomObjects__c = 'Mixmax_Custom_Object__c';
        insert syncedFields;

        // Simulate a custom object update using the MixmaxError__c custom object bundled into this package.
        MixmaxError__c oldMixmaxError = makeMixmaxError('Foo');
        MixmaxError__c newMixmaxError = makeMixmaxError('Foo1');
        Map<Id, MixmaxError__c> oldMap = new Map<Id, MixmaxError__c>{ oldMixmaxError.Id => oldMixmaxError};
        Map<Id, MixmaxError__c> newMap = new Map<Id, MixmaxError__c>{ newMixmaxError.Id => newMixmaxError};

        MixmaxTriggerHandler triggerHandler = new MixmaxTriggerHandler(
            MixmaxError__c.getSObjectType(), 'update'
        );

        MixmaxTriggerHandler.MixmaxCustomObjectFilterResult customObjectFilterResult = triggerHandler.isChangeEventForUnsupportedCustomObject();

        // Because "MixmaxError__c" is not in "MixmaxSyncedFields__c.ConfiguredCustomObjects__c", we should consider this
        // change event as unsupported.
        System.assertEquals(customObjectFilterResult.isChangeEventForUnsupportedCustomObject, true);
        System.assertEquals(customObjectFilterResult.customObjectId, null);

        Test.stopTest();
    }

    @isTest
    static void customObjectChangeWithoutSyncedFieldsSetup() {
        Test.startTest();

        // Simulate a custom object update using the MixmaxError__c custom object bundled into this package.
        MixmaxError__c oldMixmaxError = makeMixmaxError('Foo');
        MixmaxError__c newMixmaxError = makeMixmaxError('Foo1');
        Map<Id, MixmaxError__c> oldMap = new Map<Id, MixmaxError__c>{ oldMixmaxError.Id => oldMixmaxError};
        Map<Id, MixmaxError__c> newMap = new Map<Id, MixmaxError__c>{ newMixmaxError.Id => newMixmaxError};

        MixmaxTriggerHandler triggerHandler = new MixmaxTriggerHandler(
            MixmaxError__c.getSObjectType(), 'update'
        );

        MixmaxTriggerHandler.MixmaxCustomObjectFilterResult customObjectFilterResult = triggerHandler.isChangeEventForUnsupportedCustomObject();

        // Because the "MixmaxSyncedFields__c" singleton isn't set up, we should let this event go through.
        System.assertEquals(customObjectFilterResult.isChangeEventForUnsupportedCustomObject, false);
        System.assert(customObjectFilterResult.customObjectId != null);

        Test.stopTest();
    }

    static MixmaxError__c makeMixmaxError(String message) {
        return new MixmaxError__c(
            Message__c = message
        );
    }
}