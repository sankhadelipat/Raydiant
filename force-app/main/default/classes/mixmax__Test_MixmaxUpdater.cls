@isTest
private class Test_MixmaxUpdater {
    private class TestException extends Exception {
    }

    @testSetup
    static void setup() {
        // Create test settings to be used when handling updates.
        MixmaxSettings__c settings = new MixmaxSettings__c();
        settings.MixmaxToken__c = 'test-api-token';
        settings.ErrorLoggingEnabled__c = true;
        insert settings;
    }

    @isTest
    static void testHandle() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock());
        Test.startTest();
        List<Lead> leads = new List<Lead>{ new Lead(Id = Test_Utils.getFakeId(Lead.SOBjectType)) };
        MixmaxUpdater.handle('Lead', 'create', JSON.serialize(leads));
        Test.stopTest();
    }

    @isTest
    static void testHandleInFutureContext() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock());
        Test.startTest();
        List<Lead> leads = new List<Lead>{ new Lead(Id = Test_Utils.getFakeId(Lead.SOBjectType)) };
        Test_MixmaxUpdater.nestedHandle('Lead', 'create', JSON.serialize(leads));
        Test.stopTest();
    }

    @isTest
    static void testCustomObjectHandleWithConfiguredCustomObjectsNotSetUp() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
            false, // filtered
            true, // customObjectId == null
            PayloadObjectsType.objects // objects key
        ));
        Test.startTest();
        List<MixmaxError__c> errors = new List<MixmaxError__c>{ new MixmaxError__c(Id = Test_Utils.getFakeId(MixmaxError__c.SOBjectType)) };
        Test_MixmaxUpdater.nestedHandle('MixmaxError__c', 'create', JSON.serialize(errors));
        Test.stopTest();
    }

    @isTest
    static void testCustomObjectHandleWithConfiguredCustomObjects() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
            false, // filtered
            false, // customObjectId == null
            PayloadObjectsType.objects // objects key
        ));
        setupSyncedFieldSettings(true);
        Test.startTest();
        List<MixmaxError__c> errors = new List<MixmaxError__c>{ new MixmaxError__c(Id = Test_Utils.getFakeId(MixmaxError__c.SOBjectType)) };
        Test_MixmaxUpdater.nestedHandle('MixmaxError__c', 'create', JSON.serialize(errors));
        Test.stopTest();
    }

    @isTest
    static void testHandleException() {
        Exception e = new TestException('Test Exception');
        MixmaxUpdater.handleException(e, 'Lead,create');

        MixmaxError__c error = [SELECT Message__c, Info__c FROM MixmaxError__c LIMIT 1];
        System.assertEquals('Test Exception', error.Message__c);
        System.assertEquals('Lead,create', error.Info__c);
    }

    @future
    static void nestedHandle(String type, String verb, String objectString) {
        MixmaxUpdater.handle(type, verb, objectString);
    }

    @isTest
    static void testMakePayload(){
        String result = MixmaxUpdater.makePayload('atype', 'averb', '{}', null, true, 'atype');
        System.assert(Pattern.compile(
            '\\{ "organizationId": "[^"]+", "verb": "averb", "type": "atype", "filtered": true, "atype": \\{\\} \\}'
        ).matcher(result).matches());

        String result2 = MixmaxUpdater.makePayload('atype', 'averb', '[]', 'anId', false, 'atype');
        System.assert(Pattern.compile(
            '\\{ "organizationId": "[^"]+", "verb": "averb", "type": "atype", "filtered": false, "customObjectId": "anId", "atype": \\[\\] \\}'
        ).matcher(result2).matches());
    }

    @isTest
    static void testBatchInsertion() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
            false, // filtered
            true, // customObjectId
            PayloadObjectsType.objects // objects key
        ));

        Test_Utils.insertLeads(5);
        Test_Utils.insertContacts(5);

        Test.startTest();
        Test_BatchClass tbc = new Test_BatchClass('foo');
        // Database.executeBatch(tbc, 2 /* force it to process in smaller batches */);
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testBatchInsertionWithQueueable() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock());

        Test_Utils.insertLeads(5);

        Test.startTest();
        Test_BatchWithQueueable tbc = new Test_BatchWithQueueable('foo');
        // Database.executeBatch(tbc, 2 /* force it to process in smaller batches */);
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testBatchUpdateWithSyncedFieldSettingsNotConfigured() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
            false, // filtered
            true, // customObjectId
            PayloadObjectsType.objects // objects key
        ));

        setupSyncedFieldSettings(false /* IsObjectConfigured */);
        Test_Utils.insertLeads(5);

        Test.startTest();
        Test_BatchClass tbc = new Test_BatchClass('foo');
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testBatchUpdateWithSyncedFieldSettingsConfigured() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
                true, // filtered
                false, // customObjectId
                PayloadObjectsType.objectsWithChanges // objects key
        ));

        setupSyncedFieldSettings(true /* IsObjectConfigured */);
        Test_Utils.insertLeads(5);

        Test.startTest();
        Test_BatchClass tbc = new Test_BatchClass('foo');
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testBatchUpdateWithQueueableAndSyncedFieldSettingsNotConfigured() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
                false, // filtered
                true, // customObjectId
                PayloadObjectsType.objects // objects key
        ));

        setupSyncedFieldSettings(false /* IsObjectConfigured */);
        Test_Utils.insertLeads(5);

        Test.startTest();
        Test_BatchWithQueueable tbc = new Test_BatchWithQueueable('foo');
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testBatchUpdateWithQueueableAndSyncedFieldSettingsConfigured() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
                true, // filtered
                false, // customObjectId
                PayloadObjectsType.objectsWithChanges // objects key
        ));

        setupSyncedFieldSettings(true /* IsObjectConfigured */);
        Test_Utils.insertLeads(5);

        Test.startTest();
        Test_BatchWithQueueable tbc = new Test_BatchWithQueueable('foo');
        Database.executeBatch(tbc);
        Test.stopTest();
    }

    @isTest
    static void testTooManyFutures() {
        Test.setMock(HttpCalloutMock.class, new MixmaxUpdateHandlerCalloutMock(
            false, // filtered
            true, // customObjectId
            PayloadObjectsType.objects
        ));

        List<Lead> newLeads = new List<Lead>();
        for (Integer i = 0; i < 1001; i++) {
            newLeads.add(new Lead(
                    Company = 'Company:' + i,
                    FirstName = 'FirstName:' + i,
                    LastName = 'LastName:' + i
            ));
        }
        insert newLeads;

        Test.startTest();

        for (Lead[] leads : [select id, Company from Lead limit 1000]) {
            for (Lead l : leads) {
                l.Company = l.Company + '  foo';
            }
            update leads;
        }

        Test.stopTest();
    }

    static void setupSyncedFieldSettings(Boolean isObjectConfigured) {
        MixmaxSyncedFields__c mixmaxSyncedFields = new MixmaxSyncedFields__c(
                ExternalId__c = 'mixmax',
                LeadFields__c = 'Id',
                ContactFields__c = 'Id',
                IsObjectConfigured__c = isObjectConfigured
        );
        insert mixmaxSyncedFields;
    }
}