@isTest
public class RestAPIGetAllInvoicesTest {
    
    @TestSetup
    static void setup(){
        
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
        
        Contact con = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, con.Id, 'Contact Inserted');
        
        accVar.blng__BillToContact__c = con.Id;
        update accVar;
        
        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',true);
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');
        
        blng__Payment__c testPayment = TestDataFactory.createTestPayment(accVar.Id, paymentMethod.Id, true);
        system.assertNotEquals(null, testPayment.Id, 'Payment Inserted');
        
        blng__Invoice__c invoice = TestDataFactory.createTestInvoice(accVar.Id, paymentMethod.Id, false);
        invoice.blng__DueDate__c = System.today();
        invoice.blng__InvoiceDate__c = System.today();
        insert invoice;
        system.assertNotEquals(null, invoice.Id, 'Invoice Inserted');
        
        List<blng__InvoiceLine__c> invoiceLines = new List<blng__InvoiceLine__c>();
        blng__InvoiceLine__c invoiceLine = TestDataFactory.createTestInvoiceLine(invoice.Id, null, 'TestName', false);
        invoiceLines.add(invoiceLine);        
        blng__InvoiceLine__c invoiceLine2 = TestDataFactory.createTestInvoiceLine(invoice.Id, null, 'TestName', false);
        invoiceLines.add(invoiceLine2);        
        insert invoiceLines;
        
        List<blng__PaymentAllocationInvoiceLine__c> allocationLineItems = new List<blng__PaymentAllocationInvoiceLine__c>();        
        blng__PaymentAllocationInvoiceLine__c allocationLineItem = TestDataFactory.createAllocationInvoiceLine(invoiceLine.Id, testPayment.Id, false);
        allocationLineItems.add(allocationLineItem);
        blng__PaymentAllocationInvoiceLine__c allocationLineItem2 = TestDataFactory.createAllocationInvoiceLine(invoiceLine2.Id, testPayment.Id, false);
        allocationLineItems.add(allocationLineItem2);
        insert allocationLineItems;
        
    }
    
    static testmethod void testInvalidRequests() {

        //Invalid Account Id Param
        RestRequest req = new RestRequest(); 

        req.requestURI = '/services/apexrest/Invoices/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIGetAllInvoices.doGet();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

    }
    
    static testmethod void RESTAPIGetAllInvoicesPositiveTest(){
        
        List<Account> accList = [SELECT Id FROM Account];
        system.assertEquals(1,accList.size());
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/Invoices/';
        req.addParameter('accountId', accList[0].Id);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
                
        RestAPIGetAllInvoices.doGet();        
        
        Map<String, Object> rawResponse = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        system.assertEquals(true, rawResponse.containsKey('response'));
        Map<String, Object> responseMap = (Map<String, Object>)rawResponse.get('response');
        String firstName = String.valueOf(responseMap.get('firstName'));
        
        Contact con = [SELECT Id, FirstName FROM Contact LIMIT 1];
            
        System.assertEquals(con.FirstName, firstName);
        System.assertNotEquals( null, responseMap.get('invoices'));
                          
    }
}