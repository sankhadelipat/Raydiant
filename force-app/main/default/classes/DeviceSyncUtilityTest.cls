@isTest
public class DeviceSyncUtilityTest {

    private static string endpointUrl = 'www.testurl.com';
    private static String instance = DeviceSyncUtility.deviceSyncInstance;
    private static String endpointName = DeviceSyncUtility.DEVICE_SYNC_ENDPOINT_NAME;
    
    @TestSetup
    static void setup() {
        //TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
        //TriggerHandler.clearBypass('AccountTriggerHandler');

        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

    }

    private static void createEndpointInstance() {
        
        Endpoint_Properties__c testEndpoint = TestDataFactory.createTestEndpoint(endpointName,instance,endpointUrl,false);
        testEndpoint.Content_Type__c = 'application/json';
        testEndpoint.Custom_Header_Key__c = 'abc123';
        insert testEndpoint;
        system.assertNotEquals(null, testEndpoint.Id, 'Endpoint Property Inserted');

    }

    static testMethod void testSyncDeviceNoDeviceIdError(){

        List<String> deviceIds = new List<String>();
    
        //This will error out due to no device Id
        Test.startTest();
        DeviceSyncUtility.syncDevices(deviceIds);
        Test.stopTest();
        
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncDeviceMultipleAssetIdError(){

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c, AccountId, SerialNumber FROM Asset];
        system.assertEquals(1,assetList.size());

        Asset testAsset = TestDataFactory.createTestAsset(assetList[0].AccountId, assetList[0].F_52_MACAddress__c, assetList[0].SerialNumber, null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);
        
        //This will error out due to multiple asset Ids against given MAC ID
        Test.startTest();
        DeviceSyncUtility.syncDevices(deviceIds);
        Test.stopTest();
        
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }
    
    static testMethod void testSyncDeviceWithError(){
        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        system.assertEquals(1,assetList.size());

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        //This will error out due to no endpoint property
        try {
            Test.startTest();
            DeviceSyncUtility.syncDevices(deviceIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncAccountNoDeviceError() {
        //TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
        //TriggerHandler.clearBypass('AccountTriggerHandler');

        List<Id> accIds = new List<Id>();
        accIds.add(accVar.Id);

        //This will error out due to no Device Id
        Test.startTest();
        DeviceSyncUtility.syncDevices(accIds);
        Test.stopTest();   

        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());

    }

    static testMethod void testSyncAccountInvalidAccountIdError() {
        
        List<Id> accIds = new List<Id>();
        accIds.add(UserInfo.getUserId());

        //This will error out due to Invalid Account Id
        Test.startTest();
        DeviceSyncUtility.syncDevices(accIds);
        Test.stopTest();   

        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
        
    }

    static testMethod void testSyncAccountWithError(){
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Id> accIds = new List<Id>();
        accIds.add(accList[0].Id);

        //This will call a queueable and error out due to no endpoint property
        try {
            Test.startTest();
            DeviceSyncUtility.syncDevices(accIds);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncDevicePageNumberWithError(){

        //This will error out due to no endpoint property
        try {
            Test.startTest();
            DeviceSyncUtility.syncDevices(1);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncDeviceSuccess(){

        createEndpointInstance();

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        system.assertEquals(1,assetList.size());

        List<String> deviceIds = new List<String>();
        deviceIds.add(assetList[0].F_52_MACAddress__c);

        List<DeviceSyncUtility.DeviceSyncCalloutResponse> mockResponses = new List<DeviceSyncUtility.DeviceSyncCalloutResponse>();

        DeviceSyncUtility.DeviceSyncCalloutResponse validMock = new DeviceSyncUtility.DeviceSyncCalloutResponse();
        validMock.id = assetList[0].F_52_MACAddress__c;
        validMock.registered_at = String.valueOf(System.now().addDays(-5));
        validMock.last_heartbeat_at = String.valueOf(System.now().addDays(-3));
        validMock.created_at = String.valueOf(System.now().addDays(-15));
        mockResponses.add(validMock);

        DeviceSyncUtility.DeviceSyncCalloutResponse missingDeviceMock = new DeviceSyncUtility.DeviceSyncCalloutResponse();
        missingDeviceMock.id = assetList[0].F_52_MACAddress__c + 'ABCD';
        missingDeviceMock.registered_at = String.valueOf(System.now().addDays(-6));
        missingDeviceMock.last_heartbeat_at = String.valueOf(System.now().addDays(-4));
        missingDeviceMock.created_at = String.valueOf(System.now().addDays(-10));
        mockResponses.add(missingDeviceMock);

        String mockBody = JSON.serializePretty(mockResponses);

        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success',mockBody,new Map<String,String>()));

        //This will error out due to no endpoint property
        Test.startTest();
        DeviceSyncUtility.syncDevices(deviceIds);
        Test.stopTest();
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncDevicePageNumberSuccess(){

        createEndpointInstance();

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        system.assertEquals(1,assetList.size());

        List<DeviceSyncUtility.DeviceSyncCalloutResponse> mockResponses = new List<DeviceSyncUtility.DeviceSyncCalloutResponse>();

        DeviceSyncUtility.DeviceSyncCalloutResponse validMock = new DeviceSyncUtility.DeviceSyncCalloutResponse();
        validMock.id = assetList[0].F_52_MACAddress__c;
        validMock.registered_at = String.valueOf(System.now().addDays(-5));
        validMock.last_heartbeat_at = String.valueOf(System.now().addDays(-3));
        validMock.created_at = String.valueOf(System.now().addDays(-15));
        mockResponses.add(validMock);

        DeviceSyncUtility.DeviceSyncCalloutResponse missingDeviceMock = new DeviceSyncUtility.DeviceSyncCalloutResponse();
        missingDeviceMock.id = assetList[0].F_52_MACAddress__c + 'ABCD';
        missingDeviceMock.registered_at = String.valueOf(System.now().addDays(-6));
        missingDeviceMock.last_heartbeat_at = String.valueOf(System.now().addDays(-4));
        missingDeviceMock.created_at = String.valueOf(System.now().addDays(-10));
        mockResponses.add(missingDeviceMock);

        String mockBody = JSON.serializePretty(mockResponses);

        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success',mockBody,new Map<String,String>()));

        //This will error out due to no endpoint property
        Test.startTest();
        DeviceSyncUtility.syncDevices(1);
        Test.stopTest();
    
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testSyncDeviceMultipleBatchSuccess(){

        createEndpointInstance();

        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Asset> assetInsertList = new List<Asset>();
        Integer maxSize = DeviceSyncUtility.DEVICE_SYNC_PAGE_SIZE + 10;
        for ( Integer i = 0; i < maxSize; i++ ) {
            Asset testAsset = TestDataFactory.createTestAsset(accList[0].Id, '12:23:34:ab' + i, 'SN1017500' + i, null, null, false);
            assetInsertList.add(testAsset);
        }
        insert assetInsertList;

        List<Asset> assetList = [SELECT Id,F_52_MACAddress__c FROM Asset];
        
        List<String> deviceIds = new List<String>();
        for ( Asset assetVar : assetList ) {
            deviceIds.add(assetVar.F_52_MACAddress__c);
        }       

        List<DeviceSyncUtility.DeviceSyncCalloutResponse> mockResponses = new List<DeviceSyncUtility.DeviceSyncCalloutResponse>();

        DeviceSyncUtility.DeviceSyncCalloutResponse validMock = new DeviceSyncUtility.DeviceSyncCalloutResponse();
        validMock.id = assetList[0].F_52_MACAddress__c;
        validMock.registered_at = String.valueOf(System.now().addDays(-5));
        validMock.last_heartbeat_at = String.valueOf(System.now().addDays(-3));
        validMock.created_at = String.valueOf(System.now().addDays(-15));
        mockResponses.add(validMock);

        String mockBody = JSON.serializePretty(mockResponses);

        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success',mockBody,new Map<String,String>()));

        //This will error out due to no endpoint property
        Test.startTest();
        DeviceSyncUtility.syncDevices(deviceIds,accList[0].Id);
        Test.stopTest();
    
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());
    }


}