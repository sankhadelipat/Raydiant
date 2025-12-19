@IsTest
public class RestAPIListPaymentMethodTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',true);
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');

        blng__PaymentTransaction__c paymentTransaction = TestDataFactory.createTestPaymentTransaction(paymentMethod.Id, accVar.Id, paymentGateway.Id, 'Charge', 'Mastercard', true);
        system.assertNotEquals(null, paymentTransaction.Id, 'Payment Transaction Inserted');

    }

    static testmethod void testInvalidRequests() {
        
        //No Params
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/ListPaymentMethod/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIListPaymentMethod.doGET();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        
    }

    static testmethod void testSuccessfulRequest() {
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1, accList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/ListPaymentMethod/';
        req.httpMethod = 'GET';
        req.addParameter('accountId', accList[0].Id);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIListPaymentMethod.doGET();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

        Map<String, Object> rawResponse = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        system.assertEquals(true, rawResponse.containsKey('response'));
        String responseBody = JSON.serialize(rawResponse.get('response'));
        RestAPIListPaymentMethodHandler.RestAPIListPaymentMethodResponse listPaymentResponse = (RestAPIListPaymentMethodHandler.RestAPIListPaymentMethodResponse)JSON.deserialize(responseBody, RestAPIListPaymentMethodHandler.RestAPIListPaymentMethodResponse.class);

        system.assertEquals(1, listPaymentResponse.paymentMethods.size());
    }

}