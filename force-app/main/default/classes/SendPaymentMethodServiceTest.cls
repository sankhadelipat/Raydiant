@istest
public  class SendPaymentMethodServiceTest {

    @istest
    private static void  testsendPaymentMethodEmail(){
        
        Test.startTest();
                
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
              
        req.requestURI = '/services/apexrest/sendPaymentMethod';
        req.httpMethod = 'PATCH';
        req.addParameter('emailId', 'testcustomercontact@test.com');
        RestContext.request = req;
        RestContext.response= res;

        SendPaymentMethodService.sendPaymentMethodEmail();
        
        blob expectedString = Blob.valueof('[{"message":"There are no Contracts/Accounts exist with the requested email","errorCode":"NOT_FOUND"}]');
        system.assertEquals(expectedString, res.responseBody, 'API Service did not work correctly');

        Test.stopTest();   
    }

}