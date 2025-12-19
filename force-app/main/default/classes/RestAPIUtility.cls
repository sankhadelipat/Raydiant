public without sharing class RestAPIUtility {
    public class RestAPIUtilityException extends Exception {}
    //int mysize;

    public static Contract getContract(String emailAddress) {
        List <Contract> listContract = [SELECT ID, AccountId, RAY_Dashboard_Email__c FROM Contract WHERE RAY_Dashboard_Email__c =: emailAddress];
        if (listContract != null && listContract.size() > 0){
            return listContract[0];
        } else {
            return null;
        }
    }

    public static Account getAccount(Id accountId) {
        return [SELECT Id, Primary_Contact_Email__c, F52_Primary_Contact__c, BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode, 
                   ShippingStreet, ShippingCity, ShippingState, ShippingCountry, ShippingPostalCode, Invoice_delivery_method__c,
                   Dashboard_Email__c, blng__BillToContact__c, 
                   F52_Primary_Contact__r.Id, F52_Primary_Contact__r.Email,F52_Primary_Contact__r.FirstName, F52_Primary_Contact__r.LastName, 
                   F52_Primary_Contact__r.MailingStreet, F52_Primary_Contact__r.MailingCity, F52_Primary_Contact__r.MailingState, 
                   F52_Primary_Contact__r.MailingCountry, F52_Primary_Contact__r.MailingPostalCode,

                   
                   blng__BillToContact__r.Id, blng__BillToContact__r.Email,blng__BillToContact__r.FirstName, blng__BillToContact__r.LastName,
                   blng__BillToContact__r.MailingStreet, blng__BillToContact__r.MailingCity, blng__BillToContact__r.MailingState, 
                   blng__BillToContact__r.MailingCountry, blng__BillToContact__r.MailingPostalCode,
                   (SELECT blng__AccountBalance__c FROM blng__AccountBalanceSnapshots__r ORDER BY CreatedDate DESC LIMIT 1)
                FROM Account
                WHERE Id =: accountId];
    }

    public static Account getAccountByBillToEmail(String email) {
        return [SELECT Id, Primary_Contact_Email__c, F52_Primary_Contact__c, BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode, 
                   ShippingStreet, ShippingCity, ShippingState, ShippingCountry, ShippingPostalCode,  blng__DefaultPaymentType__c,
                   
                   F52_Primary_Contact__r.Email,F52_Primary_Contact__r.FirstName, F52_Primary_Contact__r.LastName, 
                   F52_Primary_Contact__r.MailingStreet, F52_Primary_Contact__r.MailingCity, F52_Primary_Contact__r.MailingState, 
                   F52_Primary_Contact__r.MailingCountry, F52_Primary_Contact__r.MailingPostalCode,
                   
                   blng__BillToContact__r.Email,blng__BillToContact__r.FirstName, blng__BillToContact__r.LastName, 
                   blng__BillToContact__r.MailingStreet, blng__BillToContact__r.MailingCity, blng__BillToContact__r.MailingState, 
                   blng__BillToContact__r.MailingCountry, blng__BillToContact__r.MailingPostalCode,
                    (SELECT blng__AccountBalance__c FROM blng__AccountBalanceSnapshots__r ORDER BY CreatedDate DESC LIMIT 1)
                FROM Account
                WHERE blng__BillToContact__r.Email =: email];
    }

    public static List<blng__Invoice__c> getInvoices(Id accountId, Date minDueDate, Date minInvoiceDate, Boolean hasBalance, String invoiceStatus) {
        return getInvoices(accountId, minDueDate, minInvoiceDate, null, hasBalance, invoiceStatus);
    }

    public static Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> getPaymentAllocationsByInvoiceId(List<blng__Invoice__c> invoices) {
        Set<Id> invoiceIds = new Set<Id>();
        Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> allocationsByInvoice = new Map<Id, List<blng__PaymentAllocationInvoiceLine__c>>();
        for(blng__Invoice__c invoice: invoices) {
            invoiceIds.add(invoice.Id);
        }
        List<blng__PaymentAllocationInvoiceLine__c> pailList = [SELECT Id, blng__Payment__c, blng__Payment__r.blng__Amount__c, blng__Payment__r.Name, blng__Payment__r.blng__PaymentMethod__c, blng__Amount__c, 
                                                                blng__Payment__r.blng__Status__c, blng__InvoiceLine__r.blng__Invoice__c, blng__InvoiceLine__r.blng__Invoice__r.blng__InvoiceDate__c 
                                                                FROM blng__PaymentAllocationInvoiceLine__c
                                                                WHERE blng__InvoiceLine__r.blng__Invoice__c IN : invoiceIds];
        for(blng__PaymentAllocationInvoiceLine__c pail: pailList) {
            List<blng__PaymentAllocationInvoiceLine__c> allocations = allocationsByInvoice.get(pail.blng__InvoiceLine__r.blng__Invoice__c);
            if(allocations == null) {
                allocations = new List<blng__PaymentAllocationInvoiceLine__c>();
            }
            allocations.add(pail);
            allocationsByInvoice.put(pail.blng__InvoiceLine__r.blng__Invoice__c, allocations);
        }
        return allocationsByInvoice;
    }
    
    public static List<blng__Invoice__c> getInvoices(Id accountId, Date minDueDate, Date minInvoiceDate, Date maxInvoiceDate, Boolean hasBalance, String invoiceStatus) {
        String query = 'SELECT Id, Name, blng__DueDate__c, blng__PaymentStatus__c, blng__TotalAmount__c, blng__InvoiceDate__c, blng__TaxAmount__c, blng__Subtotal__c, ' +
                        'RAY_BillTo_Street__c, RAY_BillTo_City__c, RAY_BillTo_State__c, RAY_BillTo_PostalCode__c, RAY_BillTo_Country__c, blng__InvoiceStatus__c, ' +
                        '(SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId FROM ContentDocumentLinks ), ' +
                        '(SELECT Id, blng__Status__c FROM blng__RequestInvoiceTransactions__r ORDER BY CreatedDate DESC LIMIT 1) FROM blng__Invoice__c ';
        String whereClause = 'WHERE blng__Account__c =: accountId';
        whereClause += ' AND F52_Overall_Status__c != \'Cancelled\'';
        whereClause += ' AND Overall_Status__c != \'Cancelled\'';
        if(hasBalance != null && hasBalance == true){ 
            whereClause += ' AND  blng__Balance__c > 0';
        }
        if(hasBalance != null && hasBalance == false){ 
            whereClause += ' AND  blng__Balance__c < 1';
        }
        if(minDueDate != null) {
            whereClause += ' AND blng__DueDate__c >: minDueDate ';
        }
        if(minInvoiceDate != null) {
            whereClause += ' AND blng__InvoiceDate__c >: minInvoiceDate ';
        }
        if(maxInvoiceDate != null){
            whereclause += ' AND blng__InvoiceDate__c <: maxInvoiceDate ';
        }
        if ( String.isNotBlank(invoiceStatus) ) {
            whereclause += ' AND blng__InvoiceStatus__c =: invoiceStatus ';
        }
        return (List<blng__Invoice__c>)Database.query(query + whereClause);
        
    }

    public static Contact getContact(String email) {
        List<Contact> contactList =  [SELECT Id, Email, AccountId,
                   FirstName, LastName, MailingStreet, MailingCity, MailingState, MailingCountry, MailingPostalCode
                FROM Contact
                WHERE Email =: email AND AccountId != null];
        if (contactList.size() > 1){
            throw new RestAPIUtilityException('Non Unique Email for Contact');
        } else if (contactList.size() == 1) {
            return contactList[0];
        } else {
            throw new RestAPIUtilityException('No Contact found');
        }
    }

    public static Contact getContactById(String contactId) {
        return [SELECT Id, Email, AccountId, FirstName, LastName, MailingStreet, 
                MailingCity, MailingState, MailingCountry, MailingPostalCode
                FROM Contact
                WHERE Id =: contactId LIMIT 1];
    }

    public static List<blng__PaymentMethod__c> getPaymentMethod(String accountId) {
        return [SELECT Id, blng__CardType__c, blng__CardLastFour__c, blng__CardExpirationYear__c, blng__BillingAddress__c, 
                blng__BillingStreet__c, blng__StreetAddress2__c, blng__CardExpirationMonth__c, blng__Nameoncard__c, 
                blng__BillingStateProvince__c, blng__BillingCountry__c,blng__BillingCity__c, blng__BillingZipPostal__c, 
                blng__Active__c, IsDeleted__c, blng__BillingCompany__c, blng__BillingFirstName__c, blng__BillingLastName__c, 
                blng__BillingEmail__c, blng__BillingPhone__c, blng__NickName__c, blng__Notes__c, blng__PaymentType__c, 
                    (SELECT Id, blng__Status__c, blng__ResponseStatus__c
                    FROM blng__PaymentMethodTransactions__r ORDER BY CreatedDate DESC LIMIT 1) 
                FROM blng__PaymentMethod__c
                WHERE blng__Account__c =: accountId
                AND IsDeleted__c = false];
    }

    public static List<blng__PaymentMethod__c> getActiveOrNonDeletedPaymentMethods(String accountId) {
        return [SELECT Id, blng__Active__c, IsDeleted__c, blng__AutoPay__c  
                FROM blng__PaymentMethod__c
                WHERE blng__Account__c =: accountId
                AND (blng__Active__c = true
                OR IsDeleted__c = false)];
    }

    public static blng__PaymentMethod__c getPaymentMethodById(String paymentMethodId) {
        return [SELECT Id, blng__Active__c, blng__PaymentGateway__c, blng__PaymentGatewayToken__c, 
                blng__BillingEmail__c, blng__PaymentType__c, blng__CardType__c, blng__CardLastFour__c, 
                blng__CardExpirationYear__c, blng__CardExpirationMonth__c, blng__Account__c  
                FROM blng__PaymentMethod__c
                WHERE Id =: paymentMethodId];
    }

    public static blng__PaymentMethod__c getActivePaymentMethodByIdForAccount(String paymentMethodId, String accountId) {
        return [SELECT Id, blng__Active__c, blng__PaymentGateway__c, blng__PaymentGatewayToken__c, 
                blng__BillingEmail__c, blng__PaymentType__c, blng__CardType__c, blng__CardLastFour__c, 
                blng__CardExpirationYear__c, blng__CardExpirationMonth__c, blng__Account__c  
                FROM blng__PaymentMethod__c
                WHERE Id =: paymentMethodId
                AND blng__Account__c =: AccountId
                AND blng__Active__c =: true];
    }

    public static blng__PaymentGateway__c getPaymentGatewayById(String paymentGatewayId) {
        return [SELECT Id, csblng__MerchantId__c, csblng__MerchantReference__c, 
                csblng__TransactionSecurityKey__c, csblng__TestMode__c 
                FROM blng__PaymentGateway__c 
                WHERE Id =: paymentGatewayId];
    }

    public static List<blng__PaymentGateway__c> getDefaultApiPaymentGateway() {
        return [SELECT Id, csblng__MerchantId__c, csblng__MerchantReference__c 
                FROM blng__PaymentGateway__c
                WHERE blng__Active__c = true
                AND Default_for_API__c = true
                LIMIT 1];
    }

    public static List<blng__LegalEntity__c> getDefaultApiLegalEntity() {
        return [SELECT Id FROM blng__LegalEntity__c
                WHERE blng__Active__c = true
                AND Default_for_API__c = true
                LIMIT 1];
    }

    public static blng__Invoice__c getInvoiceById(String invoiceId) {
         return [SELECT Id, blng__Account__c, blng__Balance__c, blng__PaymentStatus__c, 
                 CurrencyIsoCode, 
                    (SELECT Id, blng__Balance__c FROM blng__InvoiceInvoiceLines__r 
                        WHERE blng__Balance__c >: 0 ) 
                    FROM blng__Invoice__c WHERE Id =: invoiceId];
    }

    public static List<SBQQ__Subscription__c> getSubscriptionByAccountId(String accountId){
        return  [SELECT Id, SBQQ__ProductName__c, Name, SBQQ__Product__r.RAY_JSON_Text__c, SBQQ__SubscriptionStartDate__c
  
         FROM SBQQ__Subscription__c WHERE SBQQ__Account__c=: accountId];
    }
    
    public static List<Asset> getAssetByAccountId(String accountId){
        return  [SELECT Id, Name, Product2Id,StockKeepingUnit, F_52_MACAddress__c
  
         FROM Asset WHERE AccountId=: accountId];
    }

    public static List<Product2> getProductsList(String accId, String productId, String grantScope, String businessUseCase, Boolean displayInMarketplace) {    
        String query = 'SELECT ';
        Set<String> productFieldsSet = fetchProductListApiFields();

        if ( String.isNotBlank(accId) ) {
            String subQuery = fetchActiveSubscriptionQueryOnProduct(accId);
            productFieldsSet.add(subQuery);

            String assetQuery = fetchAssetQueryOnProduct(accId);
            productFieldsSet.add(assetQuery);
        }

        String productFields = GeneralUtility.joinSet(productFieldsSet, ', ');
        query += productFields + ' FROM Product2 ';

        List<String> whereClauseList = new List<String>();
        if ( displayInMarketplace ) {
            whereClauseList.add(' Display_on_Marketplace__c = TRUE ');
        }        
        
        if( String.isNotBlank(productId) ){ 
            whereClauseList.add(' Id =: productId ');
        }
        if( String.isNotBlank(grantScope) ){ 
            whereClauseList.add(' Grant_Scope_ID__c =: grantScope ');
        }
        if( String.isNotBlank(businessUseCase) ){ 
            whereClauseList.add(' Business_Use_Case__c =: businessUseCase ');
        }
        
        String whereClause = '';
        
        if ( whereClauseList.size() > 0 ) {
            whereClause = 'WHERE ' + String.join(whereClauseList, ' AND ');
        }

        return (List<Product2>)Database.query(query + whereClause);
        
    }


    public static Set<String> fetchProductListApiFields() {
        Set<String> productFields = new Set<String>{'Id', 'Name', 'ProductCode', 'Manual_Enablement_Required__c', 
        'Business_Use_Case__c, App_Plan__c', 'Product_Line__c', 'Grant_Scope_ID__c', 'Family', 
        'Marketplace_Quantity_Editable__c', 'Default_Quantity__c', 'SBQQ__SubscriptionType__c',  
        'SBQQ__SubscriptionTerm__c', 'Client_Facing_Pricing__c', 'Client_Facing_Plan_Description__c', 
        'Customer_Facing_Pricing__c', 'Display_on_Marketplace__c'};
        
        productFields.add('(SELECT Id, UnitPrice FROM PricebookEntries WHERE IsActive = TRUE)');
        
        return productFields;
    }


    public static String fetchAssetQueryOnProduct(String accId) {
        String query = 'SELECT Id, Name, Product2Id, CreatedDate, Quantity, Price ' +
                        'FROM Assets ';

        List<String> whereClauseList = new List<String>();
        
        //These are mandatory filters.
        whereClauseList.add(' Product2Id != null ');
        whereClauseList.add(' AccountId =: accId ');   
        whereClauseList.add( 'Quantity != null ');     
        
        String whereClause = '';
        
        if ( whereClauseList.size() > 0 ) {
            whereClause = 'WHERE ' + String.join(whereClauseList, ' AND ');
        }

        String orderByClause = ' ORDER BY CreatedDate DESC ';
        query = '( ' + query + whereClause + orderByClause + ' )';

        return query;
    }

    public static String fetchActiveSubscriptionQueryOnProduct(String accId) {
        String query = 'SELECT Id, SBQQ__Quantity__c, SBQQ__Product__c, Quote_Billing_Freq__c, ' +
                        'SBQQ__StartDate__c, SBQQ__Account__c, F52_Billing_Interval_Months__c, ' +
                        'SBQQ__NetPrice__c, SBQQ__ProrateMultiplier__c ' + 
                        'FROM SBQQ__Subscriptions__r ';

        List<String> whereClauseList = new List<String>();

        //These are mandatory filters.
        whereClauseList.add(' SBQQ__Product__c != null ');
        whereClauseList.add(' SBQQ__Account__c =: accId ');  
        //whereClauseList.add(' SBQQ__EndDate__c >= TODAY AND SBQQ__StartDate__c <= TODAY ');
        whereClauseList.add(' SBQQ__StartDate__c <= TODAY '); 
        whereClauseList.add(' SBQQ__Contract__r.Status = \'Activated\' ');

        String whereClause = '';
        
        if ( whereClauseList.size() > 0 ) {
            whereClause = 'WHERE ' + String.join(whereClauseList, ' AND ');
        }

        String orderByClause = ' ORDER BY CreatedDate DESC ';
        query = '( ' + query + whereClause + orderByClause + ' )';

        return query;                       
    }
    
    public static List<blng__Invoice__c> getPastDueDateUnpaidInvoices(String accountId) {
        
        return [SELECT Id FROM blng__Invoice__c 
                WHERE (blng__PaymentStatus__c = 'Partially Paid' OR blng__PaymentStatus__c = 'Unpaid') 
                AND blng__DueDate__c <: System.now().dateGMT()
                AND blng__Account__c =: accountId
                AND blng__InvoiceStatus__c = 'Posted'];
    }

}