@isTest
public class RestAPIBuyNowTest {
    
    @TestSetup
    static void setup() {
        TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', true);
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');

        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',false);
        paymentGateway.Default_for_API__c = true;
        insert paymentGateway;
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');
        
        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        paymentMethod.blng__Account__c = accVar.Id;
        paymentMethod.blng__Active__c = true;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');


    }

    static testmethod void testInvalidRequests() {
        //No Body
        RestRequest req = new RestRequest(); 

        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiBuyNow.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Blank Body        
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(BUY_NOW_REQ_BODY_BLANK);
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiBuyNow.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Product2> prodList = [SELECT Id, ProductCode FROM Product2];
        system.assertEquals(1,prodList.size());

        Opportunity oppVar = TestDataFactory.createTestOpportunity(accList[0].Id, false);
        oppVar.Buy_Now_Opp_Unique_Key__c = 'BN-0000';
        insert oppVar;
        system.assertNotEquals(null, oppVar.Id, 'Opportunity Inserted');

        List<blng__PaymentMethod__c> paymentMethods = [SELECT Id FROM blng__PaymentMethod__c];
        system.assertEquals(1,paymentMethods.size());

        //Opporutnity exists for given uniqueKey
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchBuyNowReqBodySuccess(accList[0].Id, prodList[0].Id, 'BN-0000', paymentMethods[0].Id));
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestApiBuyNow.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('VALIDATION_ERROR', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Account Id
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchBuyNowReqBodySuccess(prodList[0].Id, prodList[0].Id, 'BN-0001', paymentMethods[0].Id));
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestApiBuyNow.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Prod Id
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchBuyNowReqBodySuccess(accList[0].Id, accList[0].Id, 'BN-0001', paymentMethods[0].Id));
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestApiBuyNow.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Payment Method Id
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchBuyNowReqBodySuccess(accList[0].Id, prodList[0].Id, 'BN-0001', prodList[0].Id));
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestApiBuyNow.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);
    }

    static testmethod void testValidRequests() {

        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        List<Product2> prodList = [SELECT Id, ProductCode FROM Product2];
        system.assertEquals(1,prodList.size());

        List<blng__PaymentMethod__c> paymentMethods = [SELECT Id FROM blng__PaymentMethod__c];
        system.assertEquals(1,paymentMethods.size());
        
        RestRequest req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchBuyNowReqBodySuccess(accList[0].Id, prodList[0].Id, 'BN-0000', paymentMethods[0].Id));
        req.requestURI = '/RestApiBuyNow/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        
        Test.startTest();
        RestApiBuyNow.doPOST();
        Test.stopTest();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));
        System.assertEquals(1, [SELECT Id FROM Opportunity].size());
        System.assertEquals(1, [SELECT Id FROM SBQQ__Quote__c].size());
    }

    private static final String BUY_NOW_REQ_BODY_BLANK = '{' +
            '"accountId": "",' +
            '"productId": "",' +
            '"uniqueKey": "",' +
            '"quantity": null,' +
            '"billingFrequency": "",' +
            '"paymentMethodId" : ""' +
            '}';

    private static String fetchBuyNowReqBodySuccess(String accId, String prodId, String uniqueKey, String paymentMethod) {
        String BUY_NOW_REQ_BODY_SUCCESS = '{' +
            '"accountId": "' + accId + '",' +
            '"productId": "' + prodId + '",' +
            '"uniqueKey": "' + uniqueKey + '",' +
            '"quantity": 10,' +
            '"billingFrequency": "Annual",' +
            '"paymentMethodId": "' + paymentMethod + '"' +
            '}';

        return BUY_NOW_REQ_BODY_SUCCESS;
    }
}