@isTest
public class RestAPIGetW9Test {
    @isTest
    static void W9PositiveTest(){
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        
        req.requestURI = '/services/apexrest/RestApiGetW9Form/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestApiGetW9Form.doGet();
        Test.stopTest(); 
        res = RestContext.response;
        System.debug(RestContext.response);
        System.debug(RestContext.response.responseBody.toString());


        Map<String, Object> rawResponse = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> responseMap = (Map<String, Object>)rawResponse.get('response');
        String url = String.valueOf(responseMap.get('URL'));
        
        System.assertEquals(System.Label.W9_URL, url, 'failed to return valid url');
    }
}