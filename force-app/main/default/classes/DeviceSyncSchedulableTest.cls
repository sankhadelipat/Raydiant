@isTest
public class DeviceSyncSchedulableTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', null, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

    }

    static testMethod void callSchedulable() {
        String cronexpression = '0 0 0 ? * * *';
        DeviceSyncSchedulable deviceSync = new DeviceSyncSchedulable();
        
        Test.startTest();
        String jobId = System.schedule('Test Device Sync Schedulable', cronexpression, deviceSync);
        Test.stopTest();

        List<CronTrigger> cronJobs = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

        system.assertEquals(1,cronJobs.size());
        system.assertEquals(cronexpression, cronJobs[0].CronExpression);
    }
}