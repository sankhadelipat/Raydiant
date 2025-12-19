@isTest
public class DeviceSyncAccountTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
    }

    static testMethod void testSyncAccountNoDeviceError() {
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Id> accIds = new List<Id>();
        accIds.add(accList[0].Id);

        //This will call a queueable and error out due to no Device Id
        try {
            Test.startTest();
            DeviceSyncAccount.syncAccountDeviceLicenses(accIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }   
    }
    
    static testMethod void testSyncAccountInvalidAccountIdError() {
        
        List<Id> accIds = new List<Id>();
        accIds.add(UserInfo.getUserId());

        //This will call a queueable and error out due to Invalid Account Id
        try {
            Test.startTest();
            DeviceSyncAccount.syncAccountDeviceLicenses(accIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        
    }
    
    static testMethod void testSyncAccountInvocableCall() {
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Id> accIds = new List<Id>();
        accIds.add(accList[0].Id);
        
        Asset testAsset = TestDataFactory.createTestAsset(accList[0].Id, '12:23:34:ab', 'SN1017500', null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

        //This will call a queueable and error out due to no endpoint property
        try {
            Test.startTest();
            DeviceSyncAccount.syncAccountDeviceLicenses(accIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        
    }
}