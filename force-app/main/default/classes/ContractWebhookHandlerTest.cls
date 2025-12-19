@istest
public class ContractWebhookHandlerTest {
    @testSetup static void setup() {
        Account acc = new Account();
        acc.Name = 'Test acc';
        insert acc;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        insert quote;       
    }
    
    @isTest
    public static void insertContractSuccessTest() {        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Contract contractToInsert = new Contract();
        contractToInsert.AccountId = acc.Id;
        contractToInsert.Status = 'Draft';
        contractToInsert.SBQQ__Quote__c = quote.Id;
        
        Test.setMock(HttpCalloutMock.class, new ContractWebhookMockHttpResponseSuccess());
        
        Test.startTest();
        insert contractToInsert;
        Test.stopTest();
        
        Contract contract = [SELECT Id, Backend_Integration_Status__c, Error_Message__c FROM Contract WHERE Id = :contractToInsert.Id LIMIT 1];
        System.assertEquals('Success', contract.Backend_Integration_Status__c);
        System.assertEquals(NULL, contract.Error_Message__c);
    }
    
    
    @isTest
    public static void insertContractErrorTest() {        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        
        Contract contractToInsert = new Contract();
        contractToInsert.AccountId = acc.Id;
        contractToInsert.Status = 'Draft';
        contractToInsert.SBQQ__Quote__c = quote.Id;
        
        Test.setMock(HttpCalloutMock.class, new ContractWebhookMockHttpResponseError());
        
        Test.startTest();
        insert contractToInsert;
        Test.stopTest(); 
        
        Contract contract = [SELECT Id, Backend_Integration_Status__c, Error_Message__c FROM Contract WHERE Id = :contractToInsert.Id LIMIT 1];
        System.assertEquals('Error', contract.Backend_Integration_Status__c);
        //'System.HttpResponse[Status=Bad Request, StatusCode=400]'
        //System.assertEquals(null, contract.Error_Message__c);
    }
    
  
}