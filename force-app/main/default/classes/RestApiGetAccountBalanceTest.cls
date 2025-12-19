@IsTest 
public class RestApiGetAccountBalanceTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
    }

    static testMethod void testInvalidRequests() {

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/BalanceDue';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        //No Account ID Param
        RestAPIGetAccountBalance.doGet();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Account ID
        req = new RestRequest(); 
        req.requestURI = '/Account/BalanceDue';
        req.httpMethod = 'GET';
        req.addParameter('accountId','invalidId');
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetAccountBalance.doGet();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1, accList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/BalanceDue';
        req.httpMethod = 'GET';
        req.addParameter('accountId',accList[0].Id);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetAccountBalance.doGet();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

    }

}