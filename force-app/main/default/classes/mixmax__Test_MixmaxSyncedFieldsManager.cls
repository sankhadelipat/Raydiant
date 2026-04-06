@isTest
private class Test_MixmaxSyncedFieldsManager {
    @testSetup
    static void setup() {
        // Create test settings
        MixmaxSettings__c settings = new MixmaxSettings__c();
        settings.MixmaxToken__c = 'test-api-token';
        settings.ErrorLoggingEnabled__c = true;
        insert settings;
    }

    @isTest
    static void testRecordCreatedIfAbsentSOBjectTypeArg() {
        Test.startTest();
        MixmaxSyncedFields__c returned = new MixmaxSyncedFieldsManager().getOrCreate(Lead.SObjectType);
        System.assert(returned != null);
        Test.stopTest();
    }

    @isTest
    static void testRecordCreatedIfAbsentFieldNameArg() {
        Test.startTest();
        MixmaxSyncedFields__c returned = new MixmaxSyncedFieldsManager().getOrCreate('ConfiguredCustomObjects__c');
        System.assert(returned != null);
        Test.stopTest();
    }

    @isTest
    static void testRecordReturnedIfPresentSOBjectTypeArg() {
        // setup
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFields__c(
                ExternalId__c = 'mixmax',
                LeadFields__c = 'Id'
        );
        insert mixmaxSyncedFields;

        Test.startTest();
        MixmaxSyncedFields__c returned = new MixmaxSyncedFieldsManager().getOrCreate(Lead.SObjectType);
        // Expect the returned MixmaxSyncedFields__c instance is the one we inserted before
        System.assertEquals(returned.Id, mixmaxSyncedFields.Id);

         // Expect the returned MixmaxSyncedFields__c object has the field for the object type we asked for
        System.assertEquals(returned.LeadFields__c, 'Id');
        Test.stopTest();
    }

    @isTest
    static void testRecordReturnedIfPresentFieldNameArg() {
        // setup
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFields__c(
                ExternalId__c = 'mixmax',
                ConfiguredCustomObjects__c = 'My_Custom_Object__c'
        );
        insert mixmaxSyncedFields;

        Test.startTest();
        MixmaxSyncedFields__c returned = new MixmaxSyncedFieldsManager().getOrCreate('ConfiguredCustomObjects__c');
        // Expect the returned MixmaxSyncedFields__c instance is the one we inserted before
        System.assertEquals(returned.Id, mixmaxSyncedFields.Id);

         // Expect the returned MixmaxSyncedFields__c object has the field for the object type we asked for
        System.assertEquals(returned.ConfiguredCustomObjects__c, 'My_Custom_Object__c');
        Test.stopTest();
    }
}