@IsTest
public class RestAPIAccountInfoTest {
    
    @TestSetup
    static void setup(){
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted'); 
        
        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');
        
        accVar.F52_Primary_Contact__c = conVar.Id;
        update accVar;

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,true);
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, true);
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');

        testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c WHERE Id =: testQuote.Id];

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');

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

        SBQQ__Subscription__c testSub = TestDataFactory.createTestSubscription(accVar.Id,  testContract.Id, testProd.Id, null, true);
        system.assertNotEquals(null, testSub.Id, 'Subscription Inserted');
    }

    static testmethod void testInvalidRequests() {

        //Invalid Account Id Param
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/GetInfo/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAccountInfo.doGet();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/GetInfo/';
        req.httpMethod = 'GET';
        req.addParameter('accountId',accList[0].Id);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAccountInfo.doGet();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));
    }
}