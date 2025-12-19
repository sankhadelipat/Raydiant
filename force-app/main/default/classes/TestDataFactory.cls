@isTest
public without sharing class TestDataFactory {
    
    public static Account createTestAccount(Boolean performDML) {        
        Account accVar = new Account();
        accVar.Name = 'Test Account';
        accVar.BillingCountry = 'United States';
        accVar.BillingState = 'California';
        accVar.BillingCity = 'San Francisco';
        accVar.ShippingCountry = 'United States';
        accVar.ShippingState = 'California';
        accVar.ShippingCity = 'San Francisco';
        if ( performDML ) {
            insert accVar;
        }
        return accVar;
    }

    public static Contact createTestContact(Id accountId, Boolean performDML) {
        Contact testCon = new Contact();
        testCon.AccountId = accountId;
        testCon.LastName = 'TestLastName';
        testCon.FirstName = 'Test';
        testCon.Email = 'test@testradiyant.com';
        if ( performDML ) {
            insert testCon;
        }
        return testCon;
    }
    
    public static Opportunity createTestOpportunity(Id accountId, Boolean performDML) {
        Opportunity testOpp = new Opportunity();
        testOpp.AccountId = accountId;
        testOpp.StageName = 'Qualified/Discovery Completed';
        testOpp.Name = 'Test Opportunity';
        testOpp.Amount = 1000.50;
        testOpp.Type = 'New';
        testOpp.CloseDate = System.today();
        if ( performDML ) {
            insert testOpp;
        }
        return testOpp;
    }

    public static SBQQ__Quote__c createTestQuote(Id accountId, Id contactId, Id opportunityId, Boolean performDML) {
        SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
        testQuote.SBQQ__Primary__c = true;
        testQuote.SBQQ__PrimaryContact__c = contactId;
        testQuote.SBQQ__Account__c = accountId;
        testQuote.SBQQ__Opportunity2__c = opportunityId;
        testQuote.RAY_Custom_T_C__c = 'Test';
        testQuote.RAY_Contract_Status__c = 'Activated';
        testQuote.F52_Billing_Frequency__c = 'Monthly';
        testQuote.SBQQ__BillingFrequency__c = 'Monthly';
        testQuote.RAY_Bill_to_Account__c = accountId;
        
        if(performDML) {
            insert testQuote;
        }
        
        return testQuote;
    }
    
    public static SBQQ__QuoteLine__c createTestQuoteLine(Product2 productVar, Id pbEntryId, Id quoteId, Boolean performDML) {
        SBQQ__QuoteLine__c quoteLineVar = new SBQQ__QuoteLine__c();
        quoteLineVar.SBQQ__Product__c = productVar.Id;
        quoteLineVar.SBQQ__Quote__c = quoteId;
        quoteLineVar.SBQQ__PricebookEntryId__c = pbEntryId;
        quoteLineVar.SBQQ__PricingMethod__c = 'List';
        quoteLineVar.SBQQ__StartDate__c = Date.today();
        quoteLineVar.SBQQ__ListPrice__c = 100;
        quoteLineVar.SBQQ__Quantity__c = 1;
        quoteLineVar.SBQQ__PriorQuantity__c = 0;
        quoteLineVar.SBQQ__RegularPrice__c = 100;
        quoteLineVar.SBQQ__NetPrice__c = 100;
        quoteLineVar.SBQQ__Number__c = 1;
        quoteLineVar.SBQQ__ProrateMultiplier__c = 1;
        quoteLineVar.SBQQ__SubscriptionPricing__c = 'Fixed Price';
        quoteLineVar.SBQQ__SubscriptionScope__c = 'Quote';
        quoteLineVar.SBQQ__DefaultSubscriptionTerm__c = 1;
        quoteLineVar.SBQQ__ChargeType__c = productVar.SBQQ__ChargeType__c;
        quoteLineVar.SBQQ__BillingType__c = productVar.SBQQ__BillingType__c;
        quoteLineVar.SBQQ__BillingFrequency__c = productVar.SBQQ__BillingFrequency__c;
        
        if(performDML) {
            insert quoteLineVar;
        }
        
        return quoteLineVar;
    }
    
    public static blng__BillingRule__c createTestBillingRule(Boolean performDML) {
       blng__BillingRule__c billingRuleVar = new blng__BillingRule__c();
       billingRuleVar.Name ='Generate Invoice - Separate Partial Period';
       billingRuleVar.blng__Active__c = true;
       billingRuleVar.blng__GenerateInvoices__c = 'Yes';
       billingRuleVar.blng__InitialBillingTrigger__c = 'Order Product Activation Date';
       billingRuleVar.blng__PartialPeriodTreatment__c = 'Separate';
       billingRuleVar.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
       if (performDML) { 
           insert billingRuleVar; 
       }
       return billingRuleVar;
    }
    
    public static blng__RevenueRecognitionRule__c createTestRevRecRule(Boolean performDML) {
        blng__RevenueRecognitionRule__c revRecRule = new blng__RevenueRecognitionRule__c();
        revRecRule.Name ='Standard Revenue Recognition Rule';
        revRecRule.blng__Active__c = true;
        revRecRule.blng__CreateRevenueSchedule__c = 'Yes';
        revRecRule.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (performDML) { 
            insert revRecRule; 
        }
        return revRecRule;
    }
    
    public static blng__TaxRule__c createTestTaxRule(Boolean performDML) {
        blng__TaxRule__c taxRuleVar = new blng__TaxRule__c();
        taxRuleVar.Name ='No Tax Calculation';
        taxRuleVar.blng__Active__c = true;
        taxRuleVar.blng__TaxableYesNo__c = 'Yes';
        taxRuleVar.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (performDML) { 
            insert taxRuleVar; 
        }
        return taxRuleVar;
    }

    public static Product2 createTestProduct(String prodName, String prodCode, Boolean performDML) {
        Product2 testProduct = new Product2();
        testProduct.Name = prodName;
        testProduct.ProductCode = prodCode;
        testProduct.Description = prodName;
        testProduct.Family = 'MRR';
        testProduct.RAY_Product_Sub_family__c = 'Software';
        testProduct.Product_Line__c = 'Raydiant';
        testProduct.Business_Use_Case__c = 'Employee Experience';
        testProduct.IsActive = true;
        if ( performDML ) {
            insert testProduct;
        }
        return testProduct;
    }

    public static PricebookEntry createTestPriceBookEntry(Id prodId, Id pricebookId, Boolean performDML) {
        PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = pricebookId;
        pbe.Product2Id = prodId;
        pbe.UnitPrice = 1020;
        pbe.IsActive = true;
        if ( performDML ) {
            insert pbe;
        }
        return pbe;
    }

    public static blng__PaymentMethod__c createTestPaymentMethod(Id accountId, String paymentType, Boolean performDML) {        
        blng__PaymentMethod__c paymentMethod = new blng__PaymentMethod__c();
        paymentMethod.blng__Account__c = accountId;
        paymentMethod.blng__Active__c = true;
        paymentMethod.blng__PaymentType__c = paymentType;

        paymentMethod.blng__BillingCompany__c = 'Test Company';
        paymentMethod.blng__BillingFirstName__c = 'First Name Test';
        paymentMethod.blng__BillingLastName__c = 'Last Name Test';
        paymentMethod.blng__BillingEmail__c = 'firstname@testcompany.com';        
        paymentMethod.blng__BillingPhone__c = '6985743252';

        paymentMethod.blng__BillingAddress__c = 'Radiyant';
        paymentMethod.blng__StreetAddress2__c = 'Test Street 2';
        paymentMethod.blng__BillingStreet__c = 'Test Street';
        paymentMethod.blng__BillingCity__c = 'NY';
        paymentMethod.blng__BillingStateProvince__c = 'NY';        
        paymentMethod.blng__BillingZipPostal__c = '12005';
        paymentMethod.blng__BillingCountry__c = 'US';

        paymentMethod.blng__CardExpirationMonth__c = '12';
        paymentMethod.blng__CardExpirationYear__c = String.valueOf(System.today().Year());
        paymentMethod.blng__CardLastFour__c = '4444';
        paymentMethod.blng__CardType__c = 'Mastercard';
        paymentMethod.blng__CardNumber__c = '1111222233334444';

        if ( performDML ) {
            insert paymentMethod;
        }
        return paymentMethod;
    }

    public static blng__Payment__c createTestPayment(Id accountId, Id paymentMethodId, Boolean performDML) {
        blng__Payment__c testPayment = new blng__Payment__c();
        testPayment.blng__Account__c = accountId;
        testPayment.blng__PaymentMethod__c = paymentMethodId;
        testPayment.blng__Amount__c = 50.75;

        if ( performDML ) {
            insert testPayment;
        }
        return testPayment;
    }

    public static blng__Invoice__c createTestInvoice(Id accountId, Id paymentMethodId, Boolean performDML) {
        blng__Invoice__c invoiceVar = new blng__Invoice__c();
        invoiceVar.blng__Account__c = accountId;
        invoiceVar.blng__PaymentMethod__c = paymentMethodId;

        if ( performDML ) {
            insert invoiceVar;
        }
        return invoiceVar;
    }

    public static blng__InvoiceLine__c createTestInvoiceLine(Id invoiceId, Id productId, String productName, Boolean performDML) {
        blng__InvoiceLine__c invoiceLine = new blng__InvoiceLine__c();
        invoiceLine.blng__Quantity__c = 1;
        invoiceLine.Name = productName;
        invoiceLine.blng__Product__c = productId;
        invoiceLine.blng__Invoice__c = invoiceId;

        if ( performDML ) {
            insert invoiceLine;
        }
        return invoiceLine;
    }

    public static blng__PaymentAllocationInvoiceLine__c createAllocationInvoiceLine(Id invoiceLineId, Id paymentId, Boolean performDML) {
        blng__PaymentAllocationInvoiceLine__c allocationInvoiceLine = new blng__PaymentAllocationInvoiceLine__c();
        allocationInvoiceLine.blng__Amount__c = 750.50;
        allocationInvoiceLine.blng__InvoiceLine__c = invoiceLineId;
        allocationInvoiceLine.blng__Payment__c = paymentId;

        if ( performDML ) {
            insert allocationInvoiceLine;
        }
        return allocationInvoiceLine;

    }

    public static blng__PaymentGateway__c createTestPaymentGateway(String gatewayName, Boolean performDML) {
        blng__PaymentGateway__c paymentGateway = new blng__PaymentGateway__c();
        paymentGateway.Name = gatewayName;
        paymentGateway.blng__GatewayType__c = 'CyberSource';
        paymentGateway.blng__Active__c = true;
        if ( performDML ) {
            insert paymentGateway;
        }
        return paymentGateway;
    }

    public static blng__LegalEntity__c createTestLegalEntity(String entityName, Boolean performDML) {
        blng__LegalEntity__c legalEntity = new blng__LegalEntity__c();
        legalEntity.Name = entityName;
        legalEntity.blng__Active__c = true;

        if ( performDML ) {
            insert legalEntity;
        }
        return legalEntity;
    }

    public static blng__PaymentTransaction__c createTestPaymentTransaction(Id paymentMethodId, Id accountId, Id paymentGatewayId, String typeValue, String cardType, Boolean performDML) {
        blng__PaymentTransaction__c paymentTransaction = new blng__PaymentTransaction__c();
        paymentTransaction.blng__PaymentMethod__c = paymentMethodId;
        paymentTransaction.blng__Account__c = accountId;
        paymentTransaction.blng__PaymentGateway__c = paymentGatewayId;
        paymentTransaction.blng__Amount__c = 1500.75;
        paymentTransaction.blng__Type__c = typeValue;
        paymentTransaction.blng__Status__c = 'Processed';
        paymentTransaction.blng__GatewayStatus__c = 'Success';
        paymentTransaction.blng__CardType__c = cardType;
        paymentTransaction.blng__RequestTransactionType__c = 'Charge';
        paymentTransaction.blng__RequestTypeOfPayment__c = 'Credit Card';
        paymentTransaction.blng__ResponseCode__c = '100';
        paymentTransaction.blng__ResponseStatus__c = 'Approved';
        paymentTransaction.blng__ResponseMessage__c = 'Successful transaction';

        if ( performDML ) {
            insert paymentTransaction;
        }

        return paymentTransaction;
    }

    public static Contract createTestContract(Id accountId, Id quoteId, Id opportunityId, String emailAddress, Boolean performDML) {
        Contract testContract = new Contract();
        testContract.AccountId = accountId;
        testContract.SBQQ__Opportunity__c = opportunityId;
        testContract.SBQQ__Quote__c = quoteId;
        testContract.RAY_Dashboard_Email__c = emailAddress;
        testContract.StartDate = System.today().addDays(-1);
        testContract.Status = 'Draft';

        if ( performDML ) {
            insert testContract;
        }
        return testContract;
    }

    public static Asset createTestAsset(Id accountId, String MACId, String serialNumber, Id productId, Id orderProductId, Boolean performDML) {
        Asset testAsset = new Asset();
        testAsset.AccountId = accountId;
        testAsset.F_52_MACAddress__c = MACId;
        testAsset.Name = MACId;
        testAsset.SerialNumber = serialNumber;
        testAsset.Product2Id = productId;
        testAsset.SBQQ__OrderProduct__c = orderProductId;
        
        if ( performDML ) {
            insert testAsset;
        }
        return testAsset;
    }

    public static SBQQ__Subscription__c createTestSubscription(Id accountId, Id contractId, Id productId, Id quoteLineId, Boolean performDML) {
        SBQQ__Subscription__c testSub = new SBQQ__Subscription__c();
        testSub.SBQQ__Account__c = accountId;
        testSub.SBQQ__Product__c = productId;
        testSub.SBQQ__Contract__c = contractId;
        testSub.SBQQ__QuoteLine__c = quoteLineId;
        testSub.SBQQ__Quantity__c = 1.0;

        if ( performDML ) {
            insert testSub;
        }
        return testSub;
    }

    public static Endpoint_Properties__c createTestEndpoint(String name, String instance, String url, Boolean performDML) {
        Endpoint_Properties__c endpoint = new Endpoint_Properties__c();
        endpoint.Name = name;
        endpoint.Endpoint_URL__c = url;
        endpoint.Endpoint_Instance__c = instance;
        
        if ( performDML ) {
            insert endpoint;
        }
        return endpoint;
    }

    public static List<blng__PaymentMethod__c> createPaymentMethods(Integer noOfPaymentMethods, Boolean doInsert, List<Account> accountList) {
        List<blng__PaymentMethod__c> paymentMethodList = new List<blng__PaymentMethod__c>();
        for(Integer i = 0 ; i < noOfPaymentMethods ; i++) {
            blng__PaymentMethod__c paymentMethodObject = new blng__PaymentMethod__c(
            blng__BillingFirstName__c = 'First ' + i,
            blng__BillingLastName__c = 'Last ' + i,
            blng__PaymentType__c = 'Credit Card',
            blng__Account__c = accountList[i].Id,
            blng__Active__c = true
            );
            paymentMethodList.add(paymentMethodObject);
        }
        if(doInsert) {
            insert paymentMethodList;
        }
        
        return paymentMethodList;
    }    
   
    
/* 
* ******************************************************
* This method contains test data for Account    F52_Payment_Method_Auto_Pay__c = paymentMethodList[i].Id,  , List<blng__PaymentMethod__c> paymentMethodList
* ******************************************************
*/    
    public static List<Account> createAccounts(Integer noOfAccounts, Boolean doInsert) {
        List<Account> accountList = new List<Account>();
        for(Integer i = 0 ; i < noOfAccounts ; i++) {
            Account accountObject = new Account(
            Name = 'Test Account ' + i,
           // CurrencyIsoCode = 'USD',
            BillingCountry = 'Test',
            BillingCity = 'Test',
            BillingPostalCode = '123456',
            BillingState = 'Test',
            BillingStreet = 'Test'
            );
            accountList.add(accountObject);
        }
        if(doInsert) {
            insert accountList;
        }
        
        return accountList;
    }
    
    
/* 
* ******************************************************
* This method contains test data for Contact
* ******************************************************
*/    
    public static List<Contact> createContacts(Integer noOfContacts, Boolean doInsert, List<Account> accountList) {
        List<Contact> contactList = new List<Contact>();
        for(Integer i = 0 ; i < noOfContacts ; i++) {
            Contact contactObject = new Contact(
            Salutation = 'Mr.',
            FirstName = 'Test',
            LastName = 'Contact ' + i,
            AccountId = accountList[i].Id,
            Email = 'test@gmail.com'
            //CurrencyIsoCode = 'USD'
            );
            contactList.add(contactObject);
        }
        if(doInsert) {
            insert contactList;
        }
        
        return contactList;
    }
    
/* 
* ******************************************************
* This method contains test data for Opportunity
* ******************************************************
*/    
    public static List<Opportunity> createOpportunities(Integer noOfOpportunities, Boolean doInsert, List<Account> accountList) {
        List<Opportunity> opportunityList = new List<Opportunity>();
        for(Integer i = 0 ; i < noOfOpportunities ; i++) {
            Opportunity opportunityObject = new Opportunity(
            Name = 'Test Opportunity '  + i,
            CloseDate = System.today(),
            StageName = 'Qualified/Discovery Completed',
            ForecastCategoryName = 'Upside',
            Type = 'Monthly (1-year agreement)',
            AccountId = accountList[i].Id,
            Classification__c = 'New'
            );
            opportunityList.add(opportunityObject);
        }
        if(doInsert) {
            insert opportunityList;
        }
        
        return opportunityList;
    }
    
/* 
* *************************************************************
* This method contains test data for Opportunity Contact roles
* *************************************************************
*/    
    public static List<OpportunityContactRole> createOpportunityContactRoles(Integer noOfOpportunityContactRoles, Boolean doInsert, List<Contact> contactList, List<Opportunity> opportunityList) {
        List<OpportunityContactRole> opportunityContactRoleList = new List<OpportunityContactRole>();
        for(Integer i = 0 ; i < noOfOpportunityContactRoles ; i++) {
            OpportunityContactRole opportunityContactRoleObject = new OpportunityContactRole(
              ContactId = contactList[i].Id,
              OpportunityId = opportunityList[i].Id,
              IsPrimary = true
            );
            opportunityContactRoleList.add(opportunityContactRoleObject);
        }
        if(doInsert) {
            insert opportunityContactRoleList;
        }
        
        return opportunityContactRoleList;
    }

    
/* 
* ******************************************************
* This method contains test data for Quote
* ******************************************************
*/    
    public static List<SBQQ__Quote__c> createQuotes(Integer noOfQuotes, Boolean doInsert, List<Contact> contactList, List<Opportunity> opportunityList) {
        List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
        for(Integer i = 0 ; i < noOfQuotes ; i++) {
            SBQQ__Quote__c quoteObject = new SBQQ__Quote__c(
            SBQQ__Primary__c = true,
            SBQQ__PrimaryContact__c = contactList[i].id,
            SBQQ__Account__c = contactList[i].AccountId,
            SBQQ__Opportunity2__c = opportunityList[i].id,
            RAY_Custom_T_C__c = 'Test',
            RAY_Contract_Status__c = 'Activated',
            F52_Billing_Frequency__c = 'Monthly',
            SBQQ__BillingFrequency__c = 'Monthly',
            RAY_Bill_to_Account__c = contactList[i].AccountId
            );
            quoteList.add(quoteObject);
        }
        if(doInsert) {
            insert quoteList;
        }
        
        return quoteList;
    }
    
    
/* 
* ******************************************************
* This method contains test data for Order
* ******************************************************
*/    
    public static List<Order> createOrders(Integer noOfOrders, Boolean doInsert, List<SBQQ__Quote__c> quoteList) {
        List<Order> orderList = new List<Order>();
        for(Integer i = 0 ; i < noOfOrders ; i++) {
            Order orderObject = new Order(
            AccountId = quoteList[i].SBQQ__Account__c,
            OpportunityId = quoteList[i].SBQQ__Opportunity2__c,
            SBQQ__Quote__c =  quoteList[i].Id,
            EffectiveDate = system.today(),
            blng__BillingDayOfMonth__c = '1',
            Status = 'Draft'
            );
            orderList.add(orderObject);
        }
        if(doInsert) {
            insert orderList;
        }
        
        return orderList;
    }
    
/* 
* ******************************************************
* This method contains test data for Invoice
* ******************************************************
*/    
    public static List<blng__Invoice__c> createInvoices(Integer noOfInvoices, Boolean doInsert, List<Contact> contactList, List<Order> orderList) {
        List<blng__Invoice__c> invoiceList = new List<blng__Invoice__c>();
        for(Integer i = 0 ; i < noOfInvoices ; i++) {
            blng__Invoice__c invoiceObject = new blng__Invoice__c(
            blng__Order__c = orderList[i].Id,
            blng__BillToContact__c = contactList[i].Id,
            blng__Account__c = orderList[i].AccountId
            );
            invoiceList.add(invoiceObject);
        }
        if(doInsert) {
            insert invoiceList;
        }
        
        return invoiceList;
    }
    
    
/* 
* ******************************************************
* This method contains test data for ContentVersion
* ******************************************************
*/    
    public static List<ContentVersion> createContentVersions(Integer noOfContentVersions, Boolean doInsert) {
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 
        for(Integer i = 0 ; i < noOfContentVersions ; i++) {
            ContentVersion contentVersionObject = new ContentVersion(
             Title = 'Header',
             Origin = 'H',
             PathOnClient = 'www.google.com',
             VersionData=bodyBlob
            );
            contentVersionList.add(contentVersionObject);
        }
        if(doInsert) {
            insert contentVersionList;
        }
        
        return contentVersionList;
    } 
    
/* 
* ******************************************************
* This method contains test data for ContentDocumentLink
* ******************************************************
*/    
    public static List<ContentDocumentLink> createContentDocumentLinks(Integer noOfContentDocumentLinks, Boolean doInsert, List<blng__Invoice__c> invoiceList, List<ContentVersion> contentVersionList) {
       
        List<ContentDocumentLink> contentDocumentLinkList = new List<ContentDocumentLink>();
        for(Integer i = 0 ; i < noOfContentDocumentLinks ; i++) {
            ContentDocumentLink contentDocumentLinkObject = new ContentDocumentLink(
              ShareType = 'V', 
              Visibility='AllUsers',
              ContentDocumentId = contentVersionList[i].ContentDocumentId,
              LinkedEntityId = invoiceList[i].id
            );
            contentDocumentLinkList.add(contentDocumentLinkObject);
        }
        if(doInsert) {
            insert contentDocumentLinkList;
        }
        System.debug('Contentdoclink method called for get record ' + contentDocumentLinkList.size());
        return contentDocumentLinkList;
    }
    
}