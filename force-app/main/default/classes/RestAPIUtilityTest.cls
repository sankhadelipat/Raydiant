@IsTest
public class RestAPIUtilityTest {
    
    static testmethod void testAccounts() {

        try {
            RestAPIUtility.getAccount(null);
        } catch (Exception e) {
            System.assertEquals('System.QueryException', e.getTypeName());
        }

        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Account accountReturned = RestAPIUtility.getAccount(accVar.Id);
        system.assertNotEquals(null, accountReturned.Id, 'Account found');

        try {
            RestAPIUtility.getAccountByBillToEmail('testEmail@email.com');
        } catch (Exception e) {
            System.assertEquals('System.QueryException', e.getTypeName());
        }

        Contact con = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, con.Id, 'Contact Inserted');

        accVar.blng__BillToContact__c = con.Id;
        update accVar;

        Account accountByEmail = RestAPIUtility.getAccountByBillToEmail(con.Email);
        system.assertNotEquals(null, accountByEmail.Id, 'Account found');

    }


    static testmethod void testInvoices() {

        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        blng__PaymentGateway__c paymentGateway = TestDataFactory.createTestPaymentGateway('Test Gateway',true);
        system.assertNotEquals(null, paymentGateway.Id, 'Payment Gateway Inserted');

        blng__PaymentMethod__c paymentMethod = TestDataFactory.createTestPaymentMethod(accVar.Id, 'Credit Card', false);
        paymentMethod.blng__PaymentGateway__c = paymentGateway.Id;
        insert paymentMethod;
        system.assertNotEquals(null, paymentMethod.Id, 'Payment Method Inserted');

        blng__Invoice__c invoice = TestDataFactory.createTestInvoice(accVar.Id, paymentMethod.Id, false);
        invoice.blng__DueDate__c = System.today();
        invoice.blng__InvoiceDate__c = System.today();
        insert invoice;
        system.assertNotEquals(null, invoice.Id, 'Invoice Inserted');

        List<blng__Invoice__c> invoices = RestAPIUtility.getInvoices(null, System.today().addDays(-5), null, false, null);
        system.assertEquals(0, invoices.size());

        invoices = RestAPIUtility.getInvoices(accVar.Id, System.today().addDays(-5), null, true, null);
        system.assertEquals(0, invoices.size());

        invoices = RestAPIUtility.getInvoices(accVar.Id, System.today().addDays(-5), System.today().addDays(-5), false, null);
        system.assertEquals(1, invoices.size());

        blng__Invoice__c invoiceReturned = RestAPIUtility.getInvoiceById(invoice.Id);
        system.assertNotEquals(null, invoiceReturned.Id, 'Invoice found');

        Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> allocationMap = RestAPIUtility.getPaymentAllocationsByInvoiceId(invoices);
        system.assertEquals(0,allocationMap.size());

        Test.startTest();

        blng__Payment__c testPayment = TestDataFactory.createTestPayment(accVar.Id, paymentMethod.Id, true);
        system.assertNotEquals(null, testPayment.Id, 'Payment Inserted');

        blng__InvoiceLine__c invoiceLine = TestDataFactory.createTestInvoiceLine(invoiceReturned.Id, null, 'TestName', true);
        system.assertNotEquals(null, invoiceLine.Id, 'Invoice Line Inserted');

        blng__PaymentAllocationInvoiceLine__c allocationLineItem = TestDataFactory.createAllocationInvoiceLine(invoiceLine.Id, testPayment.Id, true);
        system.assertNotEquals(null, allocationLineItem.Id, 'Payment Allocation Invoice Line Inserted');

        allocationMap = RestAPIUtility.getPaymentAllocationsByInvoiceId(invoices);
        system.assertEquals(1,allocationMap.size());

        Test.stopTest();
        
        invoices = RestAPIUtility.getPastDueDateUnpaidInvoices(accVar.Id);
        system.assertEquals(0, invoices.size());
        
    }

    static testmethod void testContacts() {

        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        try {
            RestAPIUtility.getContact('Testemail@test.com');
        } catch (Exception ex) {
            system.assert(true, 'Contact not found');
        }

        Contact con = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, con.Id, 'Contact Inserted');

        Contact contactReturned = RestAPIUtility.getContact(con.Email);
        system.assertNotEquals(null, contactReturned.Id, 'Contact found');
    }

    static testmethod void testPaymentMethodAndGatewaysAndLegalEntity() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
        
        List<blng__PaymentMethod__c> paymentMethods = RestAPIUtility.getPaymentMethod(accVar.Id);
        system.assertEquals(0, paymentMethods.size());
        
        paymentMethods = RestAPIUtility.getActiveOrNonDeletedPaymentMethods(accVar.Id);
        system.assertEquals(0, paymentMethods.size());
        
        List<blng__PaymentGateway__c> paymentGateways = RestAPIUtility.getDefaultApiPaymentGateway();
        system.assertEquals(0, paymentGateways.size());
        
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
        
        paymentMethods = RestAPIUtility.getPaymentMethod(accVar.Id);
        system.assertEquals(1, paymentMethods.size());
        
        paymentMethods = RestAPIUtility.getActiveOrNonDeletedPaymentMethods(accVar.Id);
        system.assertEquals(1, paymentMethods.size());
        
        blng__PaymentMethod__c paymentMethodReturned = RestAPIUtility.getPaymentMethodById(paymentMethods[0].Id);
        system.assertNotEquals(null, paymentMethodReturned.Id, 'Payment Method found');
        
        paymentMethodReturned = RestAPIUtility.getActivePaymentMethodByIdForAccount(paymentMethods[0].Id,accVar.Id);
        system.assertEquals(paymentMethods[0].Id, paymentMethodReturned.Id, 'Payment Method found');
        
        paymentGateways = RestAPIUtility.getDefaultApiPaymentGateway();
        system.assertEquals(1, paymentGateways.size());
        
        blng__PaymentGateway__c paymentGatewayReturned = RestAPIUtility.getPaymentGatewayById(paymentGateways[0].Id);
        system.assertNotEquals(null, paymentGatewayReturned.Id, 'Payment Gateway found');
        
        List<blng__LegalEntity__c> entities = RestAPIUtility.getDefaultApiLegalEntity();
        system.assertEquals(0, entities.size());
        
        blng__LegalEntity__c entity = TestDataFactory.createTestLegalEntity('Test Entity',false);
        entity.Default_for_API__c = true;
        insert entity;
        system.assertNotEquals(null, entity.Id, 'Legal Entity Inserted');
        
        entities = RestAPIUtility.getDefaultApiLegalEntity();
        system.assertEquals(1, entities.size());
        
    }

    static testmethod void testContract() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Contact con = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, con.Id, 'Contact Inserted');

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,true);
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, con.Id, testOpp.Id, false);
        testQuote.RAY_Dashboard_Email__c = 'testEmail@test.com';
        insert testQuote;
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');

        testQuote = [SELECT Id, RAY_Dashboard_Email__c FROM SBQQ__Quote__c WHERE Id =: testQuote.Id];

        Contract testContract = TestDataFactory.createTestContract(accVar.Id, testQuote.Id, testOpp.Id, testQuote.RAY_Dashboard_Email__c, true);
        system.assertNotEquals(null, testContract.Id, 'Contract Inserted');
        
        Contract testContractReturned = RestAPIUtility.getContract('invalidEmail');
        system.assertEquals(null,testContractReturned);

        testContractReturned = RestAPIUtility.getContract(testContract.RAY_Dashboard_Email__c);
        system.assertNotEquals(null,testContractReturned.Id, 'Contract found');
    }

    static testmethod void testSubscriptionAndAsset() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        List<SBQQ__Subscription__c> subscriptions = RestAPIUtility.getSubscriptionByAccountId(accVar.Id);
        system.assertEquals(0,subscriptions.size());

        List<Asset> assets = RestAPIUtility.getAssetByAccountId(accVar.Id);
        system.assertEquals(0,assets.size());
        
        //Insert Product and then asset
        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.Business_Use_Case__c = 'Employee Experience';
        testProd.Grant_Scope_ID__c = 'testScope';
        insert testProd;
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');
        
        Asset testAsset = TestDataFactory.createTestAsset(accVar.Id, '12:23:34:ab', 'SN1017500', testProd.Id, null, true);
        system.assertNotEquals(null, testAsset.Id, 'Asset Inserted');
        
        assets = RestAPIUtility.getAssetByAccountId(accVar.Id);
        system.assertEquals(1,assets.size());

    }
    
    static testMethod void testProducts(){

        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');
        
        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.Business_Use_Case__c = 'Marketplace';
        testProd.Grant_Scope_ID__c = 'testScope';
        testProd.Display_on_Marketplace__c = true;
        insert testProd;
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');
        
        List<Product2> productList = RestAPIUtility.getProductsList(accVar.Id,testProd.Id,'invalidScope','',true);
        system.assertEquals(0, productList.size(), 'No Products found');
        
		productList = RestAPIUtility.getProductsList('',testProd.Id,testProd.Grant_Scope_ID__c,'',true);
        system.assertEquals(1, productList.size(), '1 Product found');        
        
    }

}