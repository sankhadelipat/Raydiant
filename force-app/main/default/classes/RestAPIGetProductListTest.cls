@isTest
public class RestAPIGetProductListTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,true);
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, true);
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');

        testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c WHERE Id =: testQuote.Id];

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');

        //Insert Product and then asset
        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.Business_Use_Case__c = 'Customer Experience';
        testProd.Display_on_Marketplace__c = true;
        testProd.Grant_Scope_ID__c = 'testScope';
        testProd.Customer_Facing_Pricing__c = 'Contact Sales';
        testProd.Client_Facing_Pricing__c = 'Contact Sales for the price {0}';
        insert testProd;
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');
        
        SBQQ__Subscription__c testSub = TestDataFactory.createTestSubscription(accVar.Id,  testContract.Id, testProd.Id, null, false);
        testSub.SBQQ__SubscriptionStartDate__c = System.today().addDays(-30);
        testSub.SBQQ__SubscriptionEndDate__c = System.today().addDays(330);
        insert testSub;
        system.assertNotEquals(null, testSub.Id, 'Subscription Inserted');


    }

    static testmethod void testInvalidRequests() {

        //Invalid Account Id Param
        RestRequest req = new RestRequest(); 

        req.requestURI = '/ProductList/';
        req.httpMethod = 'GET';
        req.addParameter('accountId','invalid');
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetProductList.doGet();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/ProductList/';
        req.httpMethod = 'GET';
        req.addParameter('accountId',accList[0].Id);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetProductList.doGet();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

    }

}