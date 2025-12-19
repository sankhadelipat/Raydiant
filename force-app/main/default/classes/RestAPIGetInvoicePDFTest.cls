@IsTest
public class RestAPIGetInvoicePDFTest {

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
        system.assertNotEquals(null, invoice.Id, 'Invoice Inserted');      

        List<ContentVersion> versionsList = TestDataFactory.createContentVersions(1, true);
        List<ContentVersion> myCV = [SELECT Id, ContentDocumentId, VersionData FROM ContentVersion];
        system.assertEquals(1, myCV.size());

        List<blng__Invoice__c> invoiceList = new List<blng__Invoice__c>();
        invoiceList.add(invoice);
        
        List<ContentDocumentLink> contentPdf= TestDataFactory.createContentDocumentLinks(1, true, invoiceList, myCv); 
        
    
    }

    static testmethod void testInvalidRequest(){
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        Account account = [SELECT Id FROM Account];
        ContentDocument contentDocument = [SELECT Id FROM ContentDocument];
        req.requestURI = '/Invoices/GetPDF/accountId=' + account.Id + '&contentDocumentId=' + contentDocument.Id;
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPIGetInvoicePDF.doGet();
        Test.stopTest(); 
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }

    static testmethod void testSuccessfulRequest(){
        
        Account accountVar = [SELECT Id FROM Account];
        ContentDocument contentDocumentVar = [SELECT Id FROM ContentDocument];

        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        
        req.requestURI = '/Invoices/GetPDF/';
        req.httpMethod = 'GET';
        req.addParameter('accountId',accountVar.Id);
        req.addParameter('contentDocumentId',contentDocumentVar.Id);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        RestAPIGetInvoicePDF.doGet();
        Test.stopTest(); 
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

    }
}