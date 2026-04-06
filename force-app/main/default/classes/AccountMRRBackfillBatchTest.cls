/**
 * AccountMRRBackfillBatchTest
 *
 * Author : Stargate / Blake Reeves
 * Created: 2026-04-03
 */
@isTest
private class AccountMRRBackfillBatchTest {

    @isTest
    static void testBatch() {
        StripeTriggerHandler.enableBypass('Account');
        Account acc = new Account(Name = 'Backfill Test');
        insert acc;

        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Account__c  = acc.Id,
            SBQQ__Quantity__c = 1
        );
        insert sub;

        Test.startTest();
        Database.executeBatch(new AccountMRRBackfillBatch(), 25);
        Test.stopTest();

        Account result = [SELECT Account_Value__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, result.Account_Value__c,
            'Backfill batch should set Account_Value__c');
    }
}