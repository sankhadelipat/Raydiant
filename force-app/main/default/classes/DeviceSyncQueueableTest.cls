@isTest
public class DeviceSyncQueueableTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

    }

    static testMethod void testDeviceSyncNightlyMode() {

        //This will call a queueable and error out due to no endpoint property
        try {
            System.enqueueJob(new DeviceSyncQueueable(1));
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }

        List<AsyncApexJob> scheduledJobs = [SELECT Id, JobItemsProcessed, JobType, ApexClass.Name
                                            FROM AsyncApexJob
                                            WHERE JobType = 'Queueable'];

        system.assertEquals(1,scheduledJobs.size());
        system.assertEquals('DeviceSyncQueueable',scheduledJobs[0].ApexClass.Name);

    }

    static testMethod void testDeviceSyncResyncMode() {

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        system.assertEquals(1,assetList.size());

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        //This will call a queueable and error out due to no endpoint property
        try {
            System.enqueueJob(new DeviceSyncQueueable(deviceIds));
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }

        List<AsyncApexJob> scheduledJobs = [SELECT Id, JobItemsProcessed, JobType, ApexClass.Name
                                            FROM AsyncApexJob
                                            WHERE JobType = 'Queueable'];

        system.assertEquals(1,scheduledJobs.size());
        system.assertEquals('DeviceSyncQueueable',scheduledJobs[0].ApexClass.Name);

    }

    static testMethod void testAccountDeviceSyncResyncMode() {

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c, AccountId FROM Asset];
        system.assertEquals(1,assetList.size());

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        //This will call a queueable and error out due to no endpoint property
        try {
            System.enqueueJob(new DeviceSyncQueueable(deviceIds, assetList[0].AccountId));
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }

        List<AsyncApexJob> scheduledJobs = [SELECT Id, JobItemsProcessed, JobType, ApexClass.Name
                                            FROM AsyncApexJob
                                            WHERE JobType = 'Queueable'];

        system.assertEquals(1,scheduledJobs.size());
        system.assertEquals('DeviceSyncQueueable',scheduledJobs[0].ApexClass.Name);

    }
}