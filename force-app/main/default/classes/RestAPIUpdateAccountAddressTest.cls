@isTest
public class RestAPIUpdateAccountAddressTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
    }

    static testMethod void testInvalidRequests() {

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/UpdateAddress/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        //No Request Body
        RestAPIUpdateAccountAddress.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        RestAPIUpdateAccountAddressHandler.inboundRequest updateRequest = new RestAPIUpdateAccountAddressHandler.inboundRequest();
        
        //Blank Account ID
        req = new RestRequest(); 
        req.requestURI = '/Account/UpdateAddress/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(updateRequest));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateAccountAddress.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Account Id
        updateRequest.accountId = 'invalid';
        req = new RestRequest(); 
        req.requestURI = '/Account/UpdateAddress/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(updateRequest));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateAccountAddress.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1, accList.size());

        RestAPIUpdateAccountAddressHandler.inboundRequest updateRequest = new RestAPIUpdateAccountAddressHandler.inboundRequest();
        updateRequest.accountId = accList[0].Id;
        updateRequest.BillingStreet = 'Test';
        updateRequest.BillingCity = 'NY';
        updateRequest.BillingState = 'NY';
        updateRequest.BillingCountry = 'United States';
        updateRequest.BillingPostalCode = '10101';
        updateRequest.ShippingStreet = 'Test';
        updateRequest.ShippingCity = 'NY';
        updateRequest.ShippingState = 'NY';
        updateRequest.ShippingCountry = 'United States';
        updateRequest.ShippingPostalCode = '10101';

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/UpdateAddress/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serializePretty(updateRequest));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();      

        RestAPIUpdateAccountAddress.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));
        
        Account accVar = [SELECT Id, BillingCity, ShippingCountry FROM Account WHERE Id =: accList[0].Id];
        system.assertEquals('NY',accVar.BillingCity);
        system.assertEquals('United States',accVar.ShippingCountry);
    }

}