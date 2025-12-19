@isTest
public class RestAPIEmailToggleTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
    }

    static testMethod void testInvalidRequests() {
        
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/ToggleEmail/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        //No Body
        RestAPIEmailToggle.doPost();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Blank AccountId
        RestAPIEmailToggleHandler.InboundRequest toggle = new RestAPIEmailToggleHandler.InboundRequest();
        toggle.toggle = true;
        toggle.accountId = '';

        req = new RestRequest();
        req.requestURI = '/Account/ToggleEmail/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(toggle));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIEmailToggle.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);
        
        //Invalid Account Id
        toggle = new RestAPIEmailToggleHandler.InboundRequest();
        toggle.toggle = true;
        toggle.accountId = 'invalidId';

        req = new RestRequest();
        req.requestURI = '/Account/ToggleEmail/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(toggle));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIEmailToggle.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1, accList.size());


        RestAPIEmailToggleHandler.InboundRequest toggle = new RestAPIEmailToggleHandler.InboundRequest();
        toggle.toggle = true;
        toggle.accountId = accList[0].Id;

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/ToggleEmail/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(toggle));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();      

        RestAPIEmailToggle.doPost();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));
        
        toggle = new RestAPIEmailToggleHandler.InboundRequest();
        toggle.toggle = false;
        toggle.accountId = accList[0].Id;
        
        req = new RestRequest();
        req.requestURI = '/Account/ToggleEmail/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(toggle));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIEmailToggle.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));
    }
    
}