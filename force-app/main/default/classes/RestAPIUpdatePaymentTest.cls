@IsTest
public class RestAPIUpdatePaymentTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',true);
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');

        blng__LegalEntity__c legalEntity = TestDataFactory.createTestLegalEntity('Radiyant',true);
        system.assertNotEquals(null, legalEntity.Id, 'legalEntity Inserted');

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        paymentMethod.blng__Active__c = true;
        paymentMethod.blng__LegalEntity__c = legalEntity.Id;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');
        
    }

    static testmethod void testInvalidRequests() {
        //No Body
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/UpdatePaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdatePayment.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Blank Body        
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(UPDATE_PAY_REQ_BODY_BLANK);
        req.requestURI = '/Account/UpdatePaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdatePayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Body
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(UPDATE_PAY_REQ_BODY_INVALID);
        req.requestURI = '/Account/AddPaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIAddPayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);
    }

    static testmethod void testValidRequest() {

        List<blng__PaymentGateway__c> paymentGateways = [SELECT Id FROM blng__PaymentGateway__c];
        system.assertEquals(1,paymentGateways.size());

        List<blng__LegalEntity__c> legalEntities = [SELECT Id FROM blng__LegalEntity__c];
        system.assertEquals(1,legalEntities.size());

        List<blng__PaymentMethod__c> paymentMethods = [SELECT Id, blng__Active__c FROM blng__PaymentMethod__c];
        system.assertEquals(1,legalEntities.size());

        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accList[0].Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateways[0].Id;
        paymentMethod.blng__Active__c = true;
        paymentMethod.blng__LegalEntity__c = legalEntities[0].Id;
        paymentMethod.blng__CardExpirationMonth__c = '01';
        paymentMethod.blng__CardExpirationYear__c = String.valueOf(System.today().Year() + 1);
        paymentMethod.blng__CardLastFour__c = '1051';
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');

        RestRequest req = new RestRequest(); 
        req.requestBody = Blob.valueof(fetchUpdatePaymentRequestBody(accList[0].Id, paymentMethod.Id));
        req.requestURI = '/Account/UpdatePaymentMethod';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();        

        RestAPIUpdatePayment.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

        System.assertEquals(1, [SELECT Id FROM blng__PaymentMethod__c WHERE blng__Active__c = true].size());
        Id olderPaymentMethodId = paymentMethods[0].Id;
        paymentMethods = [SELECT Id, blng__Active__c,IsDeleted__c FROM blng__PaymentMethod__c WHERE Id =: olderPaymentMethodId];
        system.assertEquals(false,paymentMethods[0].blng__Active__c);
        system.assertEquals(true,paymentMethods[0].IsDeleted__c);

    }


    private static final String UPDATE_PAY_REQ_BODY_BLANK = '{' +
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
            '"paymentType": "",' +
            '"paymentMethodId": ""' +
            '}';

    private static final String UPDATE_PAY_REQ_BODY_INVALID = '{' +
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
            '"paymentMethodId": ""' +
            '}';

    private static String fetchUpdatePaymentRequestBody(String accountId, String paymentMethodId) {
        String UPDATE_PAY_REQ_BODY_SUCCESS = '{' +
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
            '"paymentType": "Credit Card",' +
            '"paymentMethodId": "' + paymentMethodId + '"' +
            '}';
        return UPDATE_PAY_REQ_BODY_SUCCESS;
    }

}