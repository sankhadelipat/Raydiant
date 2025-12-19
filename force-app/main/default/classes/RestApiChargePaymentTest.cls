@IsTest
public class RestApiChargePaymentTest {
    
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

        blng__Invoice__c invoice = TestDataFactory.createTestInvoice(accVar.Id, paymentMethod.Id, true);
        system.assertNotEquals(null, invoice.Id, 'Payment Method Inserted');
        
        blng__InvoiceLine__c invoiceLine = TestDataFactory.createTestInvoiceLine(invoice.Id, null, 'TestName', false);
        invoiceLine.blng__Subtotal__c = 50.50;
        insert invoiceLine;

    }

    static testmethod void testInvalidRequests() {
        
        //No Params
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1, accList.size());

        List<blng__PaymentMethod__c> paymentMethodList = [SELECT Id FROM blng__PaymentMethod__c LIMIT 1];
        system.assertEquals(1, paymentMethodList.size());

        List<blng__Invoice__c> invoiceList = [SELECT Id FROM blng__Invoice__c LIMIT 1];
        system.assertEquals(1, invoiceList.size());

        //Invalid Account Id
        req = new RestRequest();
        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        req.addParameter('accountId', paymentMethodList[0].Id);             //invalid accountId
        req.addParameter('paymentMethodId', paymentMethodList[0].Id);
        req.addParameter('invoiceId', invoiceList[0].Id);
        req.addParameter('transactionId', 'PT-0000');
        req.addParameter('amount', '150.75');
        req.addParameter('currencyCodeId', 'USD');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        
        //Greater Payment Amount
        req = new RestRequest();
        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        req.addParameter('accountId', accList[0].Id);
        req.addParameter('paymentMethodId', paymentMethodList[0].Id);
        req.addParameter('invoiceId', invoiceList[0].Id);
        req.addParameter('transactionId', 'PT-0000');
        req.addParameter('amount', '150.75');		//greater amount than invoice
        req.addParameter('currencyCodeId', 'USD');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('VALIDATION_ERROR', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);
        
        
        //Invalid Payment Method Id
        req = new RestRequest();
        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        req.addParameter('accountId', accList[0].Id);
        req.addParameter('paymentMethodId', accList[0].Id);       //invalid payment method id
        req.addParameter('invoiceId', invoiceList[0].Id);
        req.addParameter('transactionId', 'PT-0000');
        req.addParameter('amount', '1.75');
        req.addParameter('currencyCodeId', 'USD');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Invoice Id
        req = new RestRequest();
        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        req.addParameter('accountId', accList[0].Id);
        req.addParameter('paymentMethodId', paymentMethodList[0].Id);       
        req.addParameter('invoiceId', accList[0].Id);                   //invalid Invoice id
        req.addParameter('transactionId', 'PT-0000');
        req.addParameter('amount', '150.75');
        req.addParameter('currencyCodeId', 'USD');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest() {
        
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        system.assertEquals(1, accList.size());

        List<blng__PaymentMethod__c> paymentMethodList = [SELECT Id FROM blng__PaymentMethod__c LIMIT 1];
        system.assertEquals(1, paymentMethodList.size());

        List<blng__Invoice__c> invoiceList = [SELECT Id, blng__Balance__c FROM blng__Invoice__c LIMIT 1];
        system.assertEquals(1, invoiceList.size());

        
        RestRequest req = new RestRequest();
        req.requestURI = '/Account/ChargePayment/';
        req.httpMethod = 'PUT';
        req.addParameter('accountId', accList[0].Id);
        req.addParameter('paymentMethodId', paymentMethodList[0].Id);
        req.addParameter('invoiceId', invoiceList[0].Id);
        req.addParameter('transactionId', 'PT-0000');
        req.addParameter('amount', String.valueOf(invoiceList[0].blng__Balance__c));
        req.addParameter('currencyCodeId', 'USD');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestApiChargePayment.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

        System.assertEquals(1, [Select Id FROM blng__Payment__c].size());
        System.assertEquals(1, [Select Id FROM blng__PaymentTransaction__c].size());

    }


}