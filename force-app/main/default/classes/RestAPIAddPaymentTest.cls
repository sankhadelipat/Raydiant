@IsTest
public class RestAPIAddPaymentTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',true);
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        paymentMethod.blng__AutoPay__c = true;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');

        blng__LegalEntity__c legalEntity = TestDataFactory.createTestLegalEntity('Radiyant',true);
        system.assertNotEquals(null, legalEntity.Id, 'legalEntity Inserted');
    }

    static testmethod void testInvalidRequests() {

        //No Body
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Blank Body        
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(NEW_PAY_REQ_BODY_BLANK);
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Body
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(NEW_PAY_REQ_BODY_INVALID);
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //No API Default Payment Gateway Exists
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1,accList.size());

        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchNewPaymentRequestBody(accList[0].Id));
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('UNEXPECTED_ERROR', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        List<blng__PaymentGateway__c> paymentGateways = [SELECT Id, Default_for_API__c FROM blng__PaymentGateway__c LIMIT 1];
        paymentGateways[0].Default_for_API__c = true;
        update paymentGateways;

        //No API Default Legal Entity Exists
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchNewPaymentRequestBody(accList[0].Id));
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('UNEXPECTED_ERROR', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        List<blng__LegalEntity__c> legalEntities = [SELECT Id, Default_for_API__c FROM blng__LegalEntity__c LIMIT 1];
        legalEntities[0].Default_for_API__c = true;
        update legalEntities;
        
    }

    static testmethod void testValidRequest() {

        List<blng__PaymentGateway__c> paymentGateways = [SELECT Id, Default_for_API__c FROM blng__PaymentGateway__c LIMIT 1];
        paymentGateways[0].Default_for_API__c = true;
        update paymentGateways;

        List<blng__LegalEntity__c> legalEntities = [SELECT Id, Default_for_API__c FROM blng__LegalEntity__c LIMIT 1];
        legalEntities[0].Default_for_API__c = true;
        update legalEntities;

        List<blng__PaymentMethod__c> paymentMethods = [SELECT Id, blng__Active__c FROM blng__PaymentMethod__c];
        system.assertEquals(1,paymentMethods.size());
        
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1,accList.size());

        //Active payment Method already Exists for account, will deactivate this and create the new one.
        RestRequest req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchNewPaymentRequestBody(accList[0].Id));
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestAPIAddPayment.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

        paymentMethods = [SELECT Id, blng__Active__c FROM blng__PaymentMethod__c];
        system.assertEquals(2,paymentMethods.size());
        
        System.assertEquals(1, [SELECT Id FROM blng__PaymentMethod__c WHERE blng__Active__c = true].size());

    }


    private static final String NEW_PAY_REQ_BODY_BLANK = '{' +
            '"accountId": "",' +
            '"billingCompany": "",' +
            '"billingFirstName": "",' +
            '"billingLastName": "",' +
            '"billingEmail": "",' +
            '"billingPhone": "",' +
            '"billingAddress" : "",' +
            '"streetAddress2": "",' +
            '"streetAddress1": "",' +
            '"billingCity": "",' +
            '"billingStateProvince": "",' +
            '"billingZipPostal": "",' +
            '"billingCountry": "",' +
            '"cardExpirationMonth": "",' +
            '"cardExpirationYear": "",' +
            '"cardLastFour": null,' +
            '"cardType": "",' +
            '"nameoncard": "",' +
            '"nickName": "",' +
            '"notes": "",' +
            '"paymentGatewayToken": "",' +
            '"paymentType": ""' +
            '}';

    private static final String NEW_PAY_REQ_BODY_INVALID = '{' +
            '"accountId": "",' +
            '"billingCompany": "",' +
            '"billingFirstName": "",' +
            '"billingLastName": "",' +
            '"billingEmail": "",' +
            '"billingPhone": "",' +
            '"billingAddress" : "",' +
            '"streetAddress2": "",' +
            '"streetAddress1": "",' +
            '"billingCity": "",' +
            '"billingStateProvince": "",' +
            '"billingZipPostal": "",' +
            '"billingCountry": "",' +
            '"cardExpirationMonth": "",' +
            '"cardExpirationYear": "",' +
            '"cardLastFour": null,' +
            '"cardType": "",' +
            '"nameoncard": "",' +
            '"nickName": "",' +
            '"notes": "",' +
            '"paymentGatewayToken": ""' +
            '"paymentType": ""' +
            '}';

    private static String fetchNewPaymentRequestBody(String accountId) {
        String NEW_PAY_REQ_BODY_SUCCESS = '{' +
            '"accountId": "' + accountId +'",' +
            '"billingCompany": "Test Company",' +
            '"billingFirstName": "Test",' +
            '"billingLastName": "Last Name",' +
            '"billingEmail": "test@testcompany.com",' +
            '"billingPhone": "9876543215",' +
            '"billingAddress" : "Rd",' +
            '"streetAddress2": "1/2",' +
            '"streetAddress1": "Park Lane",' +
            '"billingCity": "NY",' +
            '"billingStateProvince": "NY",' +
            '"billingZipPostal": "10555",' +
            '"billingCountry": "US",' +
            '"cardExpirationMonth": "12",' +
            '"cardExpirationYear": "2025",' +
            '"cardLastFour": "1254",' +
            '"cardType": "Mastercard",' +
            '"nameoncard": "Test Last Name",' +
            '"nickName": "TestAdd",' +
            '"notes": "Test",' +
            '"paymentGatewayToken": "1025641574258",' +
            '"paymentType": "Credit Card"' +
            '}';
        return NEW_PAY_REQ_BODY_SUCCESS;
    } 

}