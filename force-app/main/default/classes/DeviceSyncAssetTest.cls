@isTest
public class DeviceSyncAssetTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

    }

    static testMethod void testSyncDeviceMultipleAssetIdError() {
        
        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c, AccountId, SerialNumber FROM Asset];
        system.assertEquals(1,assetList.size());

        Asset testAsset = TestDataFactory.createTestAsset(assetList[0].AccountId, assetList[0].F_52_MACAddress__c, assetList[0].SerialNumber, null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        //This will call a queueable and error out due to Multiple Asset Records for same MAC Id
        try {
            Test.startTest();
            DeviceSyncAsset.syncDeviceLicenses(deviceIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }        
    }

    static testMethod void testSyncDeviceInvocableCall() {
        
        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        system.assertEquals(1,assetList.size());

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        //This will call a queueable and error out due to no endpoint property
        try {
            Test.startTest();
            DeviceSyncAsset.syncDeviceLicenses(deviceIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        
    }
    
}