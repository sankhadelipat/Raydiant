@isTest
public class RestAPIGetEXLicenseTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        //Insert Product and then asset
        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.Business_Use_Case__c = 'Employee Experience';
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
        
        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', testProd.Id, null, false);
        testAsset.Quantity = 1;
        insert testAsset;
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');

    }

    static testmethod void testInvalidRequests() {

        //No Account Id Param
        RestRequest req = new RestRequest(); 

        req.requestURI = '/EXLicense/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetEXLicense.doGet();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Account ID
        req = new RestRequest(); 

        req.requestURI = '/EXLicense/';
        req.httpMethod = 'GET';
        req.addParameter('accountId','invalid');
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetEXLicense.doGet();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/EXLicense/';
        req.httpMethod = 'GET';
        req.addParameter('accountId',accList[0].Id);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetEXLicense.doGet();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

    }

}