@isTest
public class ContractTriggerHandlerTest {

    @TestSetup
    static void setup(){
        TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted'); 
        TriggerHandler.clearBypass('AccountTriggerHandler');

        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,true);
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, true);
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');
    }
    
    static testmethod void testSubscriptionAccountWebhookEventOnInsert() {
        
        SBQQ__Quote__c testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c LIMIT 1];
        Account accVar = [SELECT Id FROM Account LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];

        TriggerHandler.bypass('ContractTriggerHandler');

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');
        
        TriggerHandler.clearBypass('ContractTriggerHandler');


        Test.startTest();
        Contract testContract2 = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract2.Id, 'Contract Inserted');
        Test.stopTest();

        system.assertEquals(1, ContractTriggerHandler.accountsWebhookEvents.size());

    }

    static testmethod void testSubscriptionAccountWebhookEventOnUpdate() {
        
        SBQQ__Quote__c testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c LIMIT 1];
        Account accVar = [SELECT Id FROM Account LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];

        TriggerHandler.bypass('ContractTriggerHandler');

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');
        
        TriggerHandler.clearBypass('ContractTriggerHandler');

        Test.startTest();
        testContract.Status = 'Cancelled';
        update testContract;
        Test.stopTest();

    }
}