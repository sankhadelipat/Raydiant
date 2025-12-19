/**
* @Class Name: TestDataHelper
* @Description: This class contains the reusable queries.
* ================================================================================================================
*   Version   | Date              | Author                | Comments
* -----------------------------------------------------------------------------------------------------------------
*   1.0       | 25th July, 2022    | Anjali Singh         | 1. Class conatins reusable queries
* =================================================================================================================
*/

@isTest
public class TestDataHelper {

/*
* This method fetch all the Payment Method Records based First Name
*/
    public static List<blng__PaymentMethod__c> fetchpPaymentMethodRecords(Set <Id> accIdSet) {
        List<blng__PaymentMethod__c> paymentMethodList = [
            SELECT
                Id
            FROM
                blng__PaymentMethod__c
            WHERE
               blng__Account__c IN: accIdSet
        ];
        
        return paymentMethodList;
    }    
    
/*
* This method fetch all the Account Records based Account Name
*/
    public static List<Account> fetchAccountRecords() {
        List<Account> accountList = [
            SELECT
                Id,
                F52_Payment_Method_Auto_Pay__c
            FROM
                Account
            WHERE
                Name LIKE 'Test Account%'
        ];
        
        return accountList;
    }     
    
/*
* This method fetch all the Contacts Records based First Name
*/
    public static List<Contact> fetchContactRecords() {
        List<Contact> contactList = [
            SELECT
                Id,
                AccountId
            FROM
                Contact
            WHERE
                FirstName LIKE 'Test%'
        ];
        
        return contactList;
    }
    
/*
* This method fetch all the Opportunities Records based Opportunity Name
*/
    public static List<Opportunity> fetchOpportunityRecords() {
        List<Opportunity> opportunityList = [
            SELECT
                Id,
                F52_BypassValidationForProcessBuilder__c
            FROM
                Opportunity
            WHERE
                Name LIKE 'Test Opportunity%'
        ];
        
        return opportunityList;
    }
    
/*
* This method fetch all the Opportunity Contact Role Records based Opportunity
*/
    public static List<OpportunityContactRole> fetchOpportunityContactRoleRecords(Set<Id> oppIdSet) {
        List<OpportunityContactRole> opportunityContactRoleList = [
            SELECT
                Id
            FROM
                OpportunityContactRole
            WHERE
                OpportunityId IN: oppIdSet
        ];
        
        return opportunityContactRoleList;
    }    
    
/*
* This method fetch all the Quotes Records based Opportunity Name
*/
    public static List<SBQQ__Quote__c> fetchQuoteRecords() {
        List<SBQQ__Quote__c> quoteList = [
            SELECT
                Id
            FROM
                SBQQ__Quote__c
            WHERE
                SBQQ__Opportunity2__r.Name LIKE 'Test Opportunity%'
            ORDER By CreatedDate Desc
            Limit 5
        ];
        
        return quoteList;
    }
    
/*
* This method fetch all the Orders Records based Quote Name
*/
    public static List<Order> fetchOrderRecords(Set<Id> quoteIdSet) {
        List<Order> orderList = [
            SELECT
                Id,
                AccountId
            FROM
                Order
            WHERE
                SBQQ__Quote__c IN: quoteIdSet
        ];
        
        return orderList;
    }


/*
* This method fetch all the Invoices Records based Order Name
*/
    public static List<blng__Invoice__c> fetchInvoiceRecords(Set<Id> orderIdSet) {
        List<blng__Invoice__c> invoiceList = [
            SELECT
                Id,
                blng__Account__c
            FROM
                blng__Invoice__c
            WHERE
                blng__Order__c IN: orderIdSet
            Order By 
                CreatedDate Desc
            Limit 1
        ];
        
        return invoiceList;
    }    

/*
* This method fetch all the ContentVersion Records based on PathOnClient
*/ 
  public static List<ContentVersion> fetchContentVersionRecords() {
        List<ContentVersion> contentVersionList = [
            SELECT
                Id,
                ContentDocumentId
            FROM
                ContentVersion
            WHERE
                PathOnClient =: 'www.google.com'
            ORDER By CreatedDate Desc
            Limit 1
        ];
        
        return contentVersionList;
    } 

/*
* This method fetch all the ContentDocumentLink Records based LinkedEntityId
*/
  public static List<ContentDocumentLink> fetchContentDocumentLinkRecords(Set<Id> invoiceIdSet) {
        List<ContentDocumentLink> contentDocumentLinkList = [
            SELECT
                Id,
                LinkedEntityId 
            FROM
                ContentDocumentLink
            WHERE
                LinkedEntityId IN: invoiceIdSet
        ];
        
        return contentDocumentLinkList;
    } 
}