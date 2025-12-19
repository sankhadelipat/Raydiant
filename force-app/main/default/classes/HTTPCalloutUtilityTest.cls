@isTest
public class HTTPCalloutUtilityTest {
    
    static testMethod void testEndpointProperties() {
        Endpoint_Properties__c testEndpoint = HTTPCalloutUtility.fetchEndpointProperty('test',HTTPCalloutUtility.ENDPOINT_INSTANCE_DEV);
        system.assertEquals(null,testEndpoint,'Not Found');

        testEndpoint = TestDataFactory.createTestEndpoint('testName',HTTPCalloutUtility.ENDPOINT_INSTANCE_DEV,'www.testurl.com',true);
        system.assertNotEquals(null,testEndpoint.Id,'Endpoint Inserted');

        Endpoint_Properties__c returnedEndpoint = HTTPCalloutUtility.fetchEndpointProperty(testEndpoint.Name,testEndpoint.Endpoint_Instance__c);
        system.assertNotEquals(null,returnedEndpoint.Id,'Endpoint Found');
    }

    static testMethod void testHttpRequestMethods() {
        
        String dev = HTTPCalloutUtility.ENDPOINT_INSTANCE_DEV;
        String staging = HTTPCalloutUtility.ENDPOINT_INSTANCE_STAGING;
        String prod = HTTPCalloutUtility.ENDPOINT_INSTANCE_PRODUCTION;
        
        try {
            HTTPRequest request = HTTPCalloutUtility.newRequest(null,null,10000,'TestBody',null,null);
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('Request Endpoint and method are required'),ex.getMessage());
        }
        
        Endpoint_Properties__c testEndpoint = TestDataFactory.createTestEndpoint('testName',HTTPCalloutUtility.ENDPOINT_INSTANCE_DEV,'www.testurl.com',false);
        testEndpoint.Content_Type__c = 'application/json';
        insert testEndpoint;
        system.assertNotEquals(null,testEndpoint.Id,'Endpoint Inserted');

        String method = 'GET';

        Map<String,String> headers = new Map<String,String>();
        headers.put('Content-Type',testEndpoint.Content_Type__c);

        Map<String,String> params = new Map<String,String>();
        params.put('testParam','testValue');

        HTTPRequest request = HTTPCalloutUtility.newRequest(testEndpoint.Endpoint_URL__c,method,10000,'TestBody',headers,params);
        system.assertEquals(method,request.getMethod());

        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success','test body',new Map<String,String>()));

        HTTPResponse resp;
        Test.startTest();
        resp = HTTPCalloutUtility.sendRequest(request);
        Test.stopTest();

        system.assertNotEquals(null,resp);
        system.assertEquals(200,resp.getStatusCode());
    }
}