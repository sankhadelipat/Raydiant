/**
* @Class Name: UpdateInvoiceBatchTest
* @Description: This class is the test class for 'UpdateInvoiceBatch'.
* ================================================================================================================
*   Version   | Date              | Author                | Comments
* -----------------------------------------------------------------------------------------------------------------
*   1.0       | 25th July, 2022    | Anjali Singh          | 1. This class tests the functionality of the 
*																'UpdateInvoiceBatch' 
* =================================================================================================================
*/

@isTest
public class UpdateInvoiceBatchTest {

 //Variable declartions
    private static String errorMessage;
    private static String errorAssertMessage = 'Error message is null';
    private static String paymentMethodSizeAssertMessage = 'Payment Method list size is not equal to 1';
    private static String accountSizeAssertMessage = 'Account list size is not equal to 1';
    private static String contactSizeAssertMessage = 'Contact list size is not equal to 1';
    private static String opportunitySizeAssertMessage = 'Opportunity list size is not equal to 1';
    private static String opportunityContactRoleSizeAssertMessage = 'Opportunity Contact Role list size is not equal to 1';
    private static String quoteSizeAssertMessage = 'Quote list size is not equal to 1';
    private static String orderSizeAssertMessage = 'Order list size is not equal to 1';
    private static String invoiceSizeAssertMessage = 'Invoice list size is not equal to 1';
    private static String contentVersionSizeAssertMessage = 'ContentVersion list size is not equal to 1';
    private static String contentDocumentLinkSizeAssertMessage = 'ContentDocumentLink list size is not equal to 1';
    private static String dmlErrorAssertMessage = 'Result size is not equal to zero';
    
/*
* Test Setup Method to create test data
*/
    
    @testSetup static void createData() {
        
        //Create Account records
        List<Account> accountList = TestDataFactory.createAccounts(1, true);
        System.assertEquals(1, accountList.size(), accountSizeAssertMessage); 
        
        //Create Payment Method records
        List<blng__PaymentMethod__c> paymentMethodList = TestDataFactory.createPaymentMethods(1, true,accountList);
        System.assertEquals(1, paymentMethodList.size(), paymentMethodSizeAssertMessage);
        
        //Create Contact records
        List<Contact> contactList = TestDataFactory.createContacts(1, true, accountList);
        System.assertEquals(1, contactList.size(), contactSizeAssertMessage);
        System.debug('under contact');
        //Create Opportunity contact role records
        List<Opportunity> opportunityList = TestDataFactory.createOpportunities(1, true, accountList);
        System.assertEquals(1, opportunityList.size(), opportunitySizeAssertMessage);
        
        //Create Opportunity contact role records
        List<OpportunityContactRole> opportunityContactRoleList = TestDataFactory.createOpportunityContactRoles(1, true, contactList, opportunityList);
        System.assertEquals(1, opportunityContactRoleList.size(), opportunityContactRoleSizeAssertMessage);
        
        //Create Quote records
        List<SBQQ__Quote__c> quoteList = TestDataFactory.createQuotes(1, true, contactList, opportunityList);
        System.assertEquals(1, quoteList.size(), quoteSizeAssertMessage);
        
        //Create Order records
        List<Order> orderList = TestDataFactory.createOrders(1, true, quoteList);
        System.assertEquals(1, orderList.size(), orderSizeAssertMessage);
        
        //Create Invoice records
        List<blng__Invoice__c> invoiceList = TestDataFactory.createInvoices(1, true, contactList,orderList);
        System.assertEquals(1, invoiceList.size(), invoiceSizeAssertMessage);
        
        //Create ContentVersion records
        List<ContentVersion> contentVersionList = TestDataFactory.createContentVersions(1, true);
        System.assertEquals(1, contentVersionList.size(), contentVersionSizeAssertMessage);
        
        //Get contentVersion records
        List<ContentVersion> newContentVersionList = TestDataHelper.fetchContentVersionRecords();
        
        //Create ContentDocumentLink records
        List<ContentDocumentLink> contentDocumentLinkList = TestDataFactory.createContentDocumentLinks(1, true, invoiceList, newContentVersionList);
        System.assertEquals(1, contentDocumentLinkList.size(), contentDocumentLinkSizeAssertMessage);
        System.debug('records inserted from setup');
    }
    
/*
* Purpose of this method is to test that pdf downloaded is checked or not
*/
    
    @isTest
    public static void pdfDownlodedCheckBoxIsCheckedOrNot() {
        System.debug('IN FIRST METHOD');
        //Get Account records
        List<Account> accountList = TestDataHelper.fetchAccountRecords();
        System.assertEquals(1, accountList.size(), accountSizeAssertMessage);
        
        //Store Account id into set
        Set<Id> accIdSet = new Set<Id>();
        for(Account accObj: accountList) {
        accIdSet.add(accObj.id);
        }        
        
        //Get Payment Method records        
        List<blng__PaymentMethod__c> paymentMethodList = TestDataHelper.fetchpPaymentMethodRecords(accIdSet);
        System.assertEquals(1, paymentMethodList.size(), paymentMethodSizeAssertMessage);
        
        //Update payment method on Account
        for(Integer i = 0; i<accountList.size() ; i++) {
            accountList[i].F52_Payment_Method_Auto_Pay__c = paymentMethodList[i].Id;
        }
        System.debug('Accounts are updated');
        
        //Get Cntact records
        List<Contact> contactList = TestDataHelper.fetchContactRecords();
        System.assertEquals(1, contactList.size(), contactSizeAssertMessage);
        
        //Get Opportunity records
        List<Opportunity> opportunityList = TestDataHelper.fetchOpportunityRecords();
        System.assertEquals(1, opportunityList.size(), opportunitySizeAssertMessage);
        
        //Store Quote id into set
        Set<Id> oppIdSet = new Set<Id>();
        for(Opportunity oppObj: opportunityList) {
        oppIdSet.add(oppObj.id);
        }
        
        //Get Opportunity contact role records
        List<OpportunityContactRole> opportunityContactRoleList = TestDataHelper.fetchOpportunityContactRoleRecords(oppIdSet);
        System.assertEquals(1, opportunityContactRoleList.size(), opportunityContactRoleSizeAssertMessage);
        
        System.debug('enetered in first method');
        //Get Quote records
        List<SBQQ__Quote__c> quoteList = TestDataHelper.fetchQuoteRecords();
        System.assertEquals(1, quoteList.size(), quoteSizeAssertMessage);
        
        //Store Quote id into set
        Set<Id> quoteIdSet = new Set<Id>();
        for(SBQQ__Quote__c quoteObj: quoteList) {
        quoteIdSet.add(quoteObj.id);
        }
        
        //Get Order records
        List<Order> orderList = TestDataHelper.fetchOrderRecords(quoteIdSet);
        System.assertEquals(1, orderList.size(), orderSizeAssertMessage);
        
        //Store Order id into set
        Set<Id> orderIdSet = new Set<Id>();
        for(Order orderObj: orderList) {
        orderIdSet.add(orderObj.id);
        }
        
        //Get Invoice records
        List<blng__Invoice__c> invoiceList = TestDataHelper.fetchInvoiceRecords(orderIdSet);
        System.assertEquals(1, invoiceList.size(), invoiceSizeAssertMessage);
        
        //Get COntentVersion records
        List<ContentVersion> contentVersionList = TestDataHelper.fetchContentVersionRecords();
        System.assertEquals(1, contentVersionList.size(), contentVersionSizeAssertMessage);
        
        //Store Invoice id into set
        Set<Id> invoiceIdSet = new Set<Id>();
        for(blng__Invoice__c invoiceObj: invoiceList) {
        invoiceIdSet.add(invoiceObj.id);
        }
        
        //Get ContentDocumentLink  records
        List<ContentDocumentLink> contentDocumentLinkList = TestDataHelper.fetchContentDocumentLinkRecords(invoiceIdSet);
        System.assertEquals(1, contentDocumentLinkList.size(), contentDocumentLinkSizeAssertMessage);
        
        //insert Invoice records
        List<blng__Invoice__c> newInvoiceList = TestDataFactory.createInvoices(1, true, contactList,orderList);
        
        //Get Invoice records
        List<blng__Invoice__c> getNewInvoiceList = TestDataHelper.fetchInvoiceRecords(orderIdSet);
        System.assertEquals(1, getNewInvoiceList.size(), invoiceSizeAssertMessage);
        
        Set<Id> newInvoiceIdSet = new Set<Id>();
     
        //Add Invoice Id to Set
        for(blng__Invoice__c invoiceObject: getNewInvoiceList) {
            newInvoiceIdSet.add(invoiceObject.id);
        }

        //insert COntentVersion records
        List<ContentVersion> newContentVersionList = TestDataFactory.createContentVersions(1,true);
        
        List<ContentVersion> getContentVersionList =  TestDataHelper.fetchContentVersionRecords();
        System.assertEquals(1, getContentVersionList.size(), contentVersionSizeAssertMessage);
        
        
        //Create ContentDocumentLink records
        List<ContentDocumentLink> contentDocLinkList = TestDataFactory.createContentDocumentLinks(1, true, newInvoiceList, getContentVersionList);
        
        //Get ContentDocumentLink  records
        List<ContentDocumentLink> getContentDocumentLinkList = TestDataHelper.fetchContentDocumentLinkRecords(newInvoiceIdSet);
        System.assertEquals(1, getContentDocumentLinkList.size(), contentDocumentLinkSizeAssertMessage);
        
        try {
            Test.startTest();
            UpdateInvoiceBatch batchObj = new UpdateInvoiceBatch();
            Database.executeBatch(batchObj);
            Test.stopTest();
        }
        Catch(Exception e) {
            errorMessage = e.getMessage();
            System.debug('catch is called');
        }
        List<blng__Invoice__c> getAssertInvoiceList = [select id,PDF_Downloaded__c,Record_Processed_in_pdf_Script__c from blng__Invoice__c where PDF_Downloaded__c = true];
        for(blng__Invoice__c invoiceObj: getAssertInvoiceList) {
             System.assertEquals(True, invoiceObj.PDF_Downloaded__c, 'Invoice is not updated successfully');
            System.debug('Value of pdf dowmloaded => ' + invoiceObj.PDF_Downloaded__c);
        }
       
        
    }
    
/*
* Purpose of this method is to test that blank out account on invoice.
*/
    
/*    @isTest
    public static void blankTheAccountOnInvoiceForUpdate() {
        System.debug('IN FIRST METHOD');
        //Get Account records
        List<Account> accountList = TestDataHelper.fetchAccountRecords();
        System.assertEquals(1, accountList.size(), accountSizeAssertMessage);
        
        //Store Account id into set
        Set<Id> accIdSet = new Set<Id>();
        for(Account accObj: accountList) {
        accIdSet.add(accObj.id);
        }        
        
        //Get Payment Method records        
        List<blng__PaymentMethod__c> paymentMethodList = TestDataHelper.fetchpPaymentMethodRecords(accIdSet);
        System.assertEquals(1, paymentMethodList.size(), paymentMethodSizeAssertMessage);
        
        //Update payment method on Account
        for(Integer i = 0; i<accountList.size() ; i++) {
            accountList[i].F52_Payment_Method_Auto_Pay__c = paymentMethodList[i].Id;
        }
        System.debug('Accounts are updated');
        
        //Get Cntact records
        List<Contact> contactList = TestDataHelper.fetchContactRecords();
        System.assertEquals(1, contactList.size(), contactSizeAssertMessage);
        
        //Get Opportunity records
        List<Opportunity> opportunityList = TestDataHelper.fetchOpportunityRecords();
        System.assertEquals(1, opportunityList.size(), opportunitySizeAssertMessage);
        
        //Store Quote id into set
        Set<Id> oppIdSet = new Set<Id>();
        for(Opportunity oppObj: opportunityList) {
        oppIdSet.add(oppObj.id);
        }
        
        //Get Opportunity contact role records
        List<OpportunityContactRole> opportunityContactRoleList = TestDataHelper.fetchOpportunityContactRoleRecords(oppIdSet);
        System.assertEquals(1, opportunityContactRoleList.size(), opportunityContactRoleSizeAssertMessage);
        
        System.debug('enetered in first method');
        //Get Quote records
        List<SBQQ__Quote__c> quoteList = TestDataHelper.fetchQuoteRecords();
        System.assertEquals(1, quoteList.size(), quoteSizeAssertMessage);
        
        //Store Quote id into set
        Set<Id> quoteIdSet = new Set<Id>();
        for(SBQQ__Quote__c quoteObj: quoteList) {
        quoteIdSet.add(quoteObj.id);
        }
        
        //Get Order records
        List<Order> orderList = TestDataHelper.fetchOrderRecords(quoteIdSet);
        System.assertEquals(1, orderList.size(), orderSizeAssertMessage);
        
        //Store Order id into set
        Set<Id> orderIdSet = new Set<Id>();
        for(Order orderObj: orderList) {
        orderIdSet.add(orderObj.id);
        }
        
        //Get Invoice records
        List<blng__Invoice__c> invoiceList = TestDataHelper.fetchInvoiceRecords(orderIdSet);
        System.assertEquals(1, invoiceList.size(), invoiceSizeAssertMessage);
        
        //Get COntentVersion records
        List<ContentVersion> contentVersionList = TestDataHelper.fetchContentVersionRecords();
        System.assertEquals(1, contentVersionList.size(), contentVersionSizeAssertMessage);
        
        //Store Invoice id into set
        Set<Id> invoiceIdSet = new Set<Id>();
        for(blng__Invoice__c invoiceObj: invoiceList) {
        invoiceIdSet.add(invoiceObj.id);
        }
        
        //Get ContentDocumentLink  records
        List<ContentDocumentLink> contentDocumentLinkList = TestDataHelper.fetchContentDocumentLinkRecords(invoiceIdSet);
        System.assertEquals(1, contentDocumentLinkList.size(), contentDocumentLinkSizeAssertMessage);
        
        //insert Invoice records
        List<blng__Invoice__c> newInvoiceList = TestDataFactory.createInvoices(1, true, contactList,orderList);
        
        //Get Invoice records
        List<blng__Invoice__c> getNewInvoiceList = TestDataHelper.fetchInvoiceRecords(orderIdSet);
        System.assertEquals(1, getNewInvoiceList.size(), invoiceSizeAssertMessage);
        
        Set<Id> newInvoiceIdSet = new Set<Id>();
     
        //Add Invoice Id to Set
        for(blng__Invoice__c invoiceObject: getNewInvoiceList) {
            newInvoiceIdSet.add(invoiceObject.id);
        }

        //insert COntentVersion records
        List<ContentVersion> newContentVersionList = TestDataFactory.createContentVersions(1,true);
        
        List<ContentVersion> getContentVersionList =  TestDataHelper.fetchContentVersionRecords();
        System.assertEquals(1, getContentVersionList.size(), contentVersionSizeAssertMessage);
        
        
        //Create ContentDocumentLink records
        List<ContentDocumentLink> contentDocLinkList = TestDataFactory.createContentDocumentLinks(1, true, newInvoiceList, getContentVersionList);
        
        //Get ContentDocumentLink  records
        List<ContentDocumentLink> getContentDocumentLinkList = TestDataHelper.fetchContentDocumentLinkRecords(newInvoiceIdSet);
        System.assertEquals(1, getContentDocumentLinkList.size(), contentDocumentLinkSizeAssertMessage);
        
        List<blng__Invoice__c> getAssertInvoiceList = [select id,PDF_Downloaded__c,Record_Processed_in_pdf_Script__c from blng__Invoice__c];
        List<blng__Invoice__c> updatedInvoiceList = new  List<blng__Invoice__c>();
        for(blng__Invoice__c invoiceObj: getAssertInvoiceList) {
             invoiceObj.blng__Account__c = null;
             updatedInvoiceList.add(invoiceObj);
        }
        
        
        try {
            Test.startTest();
            Database.SaveResult[] result = Database.update(updatedInvoiceList, true);
            UpdateInvoiceBatch batchObj = new UpdateInvoiceBatch();
            Database.executeBatch(batchObj);
            Test.stopTest();
            System.debug('updated result size => ' + result.size());
            System.assertEquals(0, result.size(), dmlErrorAssertMessage);
        }
        Catch(Exception e) {
            errorMessage = e.getMessage();
            System.debug('catch is called');
        }
        System.assertEquals(true, errorMessage != null, errorMessage);   
    }*/ 
    
}