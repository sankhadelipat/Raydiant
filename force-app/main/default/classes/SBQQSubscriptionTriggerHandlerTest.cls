@isTest
public class SBQQSubscriptionTriggerHandlerTest {
    
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

        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.RAY_JSON_Text__c = '{"content_grant_scopes" : ["testGrantScope"]}';
        insert testProd;
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');

        Test.startTest();
        SBQQ__Subscription__c testSub = TestDataFactory.createTestSubscription(accVar.Id,  testContract.Id, testProd.Id, null, true);
        system.assertNotEquals(null, testSub.Id, 'Subscription Inserted');
        Test.stopTest();

        system.assertEquals(1, SBQQSubscriptionTriggerHandler.accountsWebhookEvents.size());
    }
}