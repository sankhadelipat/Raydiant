@isTest
private class PaymentMethodSendEmailRequestTest {
	
    @testSetup
      private static void testSetupData(){
		  
		List<Account> accountList = new List<Account>();

        //Account creation for Contract Dahsboard email and Paymenthod Email testing
        Account acc1 = new Account(Name='Test Acc');
        accountList.add(acc1);

        //Account creation for Account Primary Contact email and Paymenthod Email testing
        Account acc2 = new Account(Name='Test Acc Primary Contact');
        accountList.add(acc2);

        insert accountList;

        List<Contact> contactList = new List<Contact>();

        Contact con1 = new Contact(LastName = 'Test Primary Contact', AccountId = accountList[1].Id, Email = 'testprimarycontact@test.com');
        contactList.add(con1);
        
        insert contactList;

        acc2.F52_Primary_Contact__c = contactList[0].Id;
        update acc2;
 
        //Opportunity creation
        Opportunity opp=new Opportunity(AccountId = accountList[0].Id,Name='Opp1',
                                        StageName='Closed Won',Type='2-year',CloseDate=system.today());
        insert opp;
        //Quote creation
        SBQQ__Quote__c quote = new SBQQ__Quote__c(SBQQ__Account__c=accountList[0].Id,
                                                SBQQ__Opportunity2__c=opp.Id,RAY_Contract_Status__c='Activated', 
                                                RAY_Bill_to_Account__c=accountList[0].Id,RAY_Dashboard_Email__c='test@raydiant.com'
                                                );
        insert quote;
        //Order creation
        Order order=new Order(AccountId = accountList[0].Id,Status='Draft',EffectiveDate=system.today(), blng__BillingDayOfMonth__c = '1');
        insert order;
        
        blng__PaymentMethod__c objPM = new blng__PaymentMethod__c(blng__Account__c = accountList[0].Id, 
                                                                blng__PaymentType__c = 'Debit Card',
                                                                blng__Active__c=True,
                                                                blng__BillingEmail__c = 'test@raydianttest1.com');
        blng__PaymentMethod__c objPM1 = new blng__PaymentMethod__c(blng__Account__c = accountList[0].Id, 
                                                                blng__PaymentType__c = 'Credit Card',
                                                                blng__Active__c=False,
                                                                blng__BillingEmail__c = 'test@raydianttest2.com');
        
        insert new List<blng__PaymentMethod__c> { objPM, objPM1 };   
    }
    
    // More than one contract exist with the Dashboard Email
	@isTest
    private static void testAPIPaymentMethodMutipleContract(){

        Account acc = [SELECT Id from Account].get(0);
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c].get(0);
        
		Contract con = new Contract(AccountId = acc.Id, RAY_Billing_Account__c =acc.Id, SBQQ__Quote__c = quote.Id,
                                      RAY_Dashboard_Email__c ='test1@raydiant.com',
                                      Status ='Draft');
		Contract con1 = new Contract(AccountId = acc.Id, RAY_Billing_Account__c =acc.Id, SBQQ__Quote__c = quote.Id,
                                      RAY_Dashboard_Email__c ='test1@raydiant.com',
                                      Status ='Draft');
        insert new List<Contract> { con, con1 };
        con.Status = 'Activated';
        con1.Status = 'Activated';
        update new List<Contract> {con,con1};
		
        Test.startTest();
		
        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('test1@raydiant.com');
		
        Test.stopTest();
		
        blob expectedString = Blob.valueof(
            '[{"message":"More than one Contracts exist with the requested email","errorCode":"CONTRACT_TOO_MANY_CONTRACTS"}]'
        );
        system.assertEquals(expectedString, responseString, 'API logic did not work - CONTRACT_TOO_MANY_CONTRACTS');
    }
    
    //Dashboard Email is populated but Payment Method is not populated for the Contract
    @isTest
    private static void testAPIPaymentMethodPMNotpopulated(){

        Account acc = [SELECT Id from Account].get(0);
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c].get(0);
        
		Contract con = new Contract(AccountId = acc.Id, RAY_Billing_Account__c =acc.Id, SBQQ__Quote__c = quote.Id,
                                      RAY_Dashboard_Email__c ='test1@raydiant.com',
                                      Status ='Draft');
		insert con;
        con.Status = 'Activated';
        update con;

       Test.startTest();

       blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('test1@raydiant.com');
       
       Test.stopTest();

       blob expectedString = Blob.valueof('[{"message":"No Payment Method populated for Contract","errorCode":"CONTRACT_UPDATE_FAILED_NO_PM"}]');
       system.assertEquals(expectedString, responseString, 'API logic did not work - CONTRACT_UPDATE_FAILED_NO_PM');
     }
    
    //With payment method having different emails
    @isTest
    private static void testAPIPaymentMethodPMDiffEmail(){

        Account acc = [SELECT Id from Account].get(0);
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c].get(0);
        blng__PaymentMethod__c paymentMethod = [Select Id, blng__BillingEmail__c FROM blng__PaymentMethod__c].get(0);
        Contract con = new Contract(AccountId = acc.Id, RAY_Billing_Account__c =acc.Id, SBQQ__Quote__c = quote.Id,
                                      RAY_Dashboard_Email__c ='test1@raydiant.com',
                                      Status ='Draft');
		insert con;
        con.Status = 'Activated';
        con.Ray_Payment_Method__c = paymentMethod.Id;
        update con;
        
       Test.startTest();

       blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('test1@raydiant.com');
       Test.stopTest();

       blob expectedString = Blob.valueof('[{"message":"Payment Method Updated successfully and email is sent","errorCode":"Success"}]');
       system.assertEquals(expectedString, responseString, 'API logic did not work - Success');
    }

    //With payment method having same emails
    @isTest
     private static void testAPIPaymentMethodPMSameEmail(){

        Account acc = [SELECT Id from Account].get(0);
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c].get(0);
        blng__PaymentMethod__c paymentMethod = [Select Id, blng__BillingEmail__c FROM blng__PaymentMethod__c].get(0);
        //updating the same email as contract in order to meet the same criteria
        paymentMethod.blng__BillingEmail__c = 'test1@raydiant.com';
        update paymentMethod;

        Contract con = new Contract(AccountId = acc.Id, RAY_Billing_Account__c =acc.Id, SBQQ__Quote__c = quote.Id,
                                      RAY_Dashboard_Email__c ='test1@raydiant.com',
                                      Status ='Draft');
		insert con;
        con.Status = 'Activated';
        con.Ray_Payment_Method__c = paymentMethod.Id;
        update con;
        
       Test.startTest();

       blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('test1@raydiant.com');

       Test.stopTest();

       blob expectedString = Blob.valueof('[{"message":"Payment Method Updated successfully and email is sent","errorCode":"Success"}]');
       system.assertEquals(expectedString, responseString, 'API logic did not work - Success');
    }

    // No contract exist with requested email, Account exist, but more than one Account exist
    @isTest
    private static void testAPIPaymentMethodNoContractTooManyAcc(){

        DuplicateRule dR = [SELECT id FROM DuplicateRule WHERE  DeveloperName = 'Standard_Contact_Duplicate_Rule'];
        DuplicateRecordSet dupRS = new DuplicateRecordSet(DuplicateRuleId = dR.id);
        insert dupRS;

        Account acc2 = new Account (Name = 'Test Acc Primary Contact');
        insert acc2;

        //inserting another contact with the same email and associating with acc2
        Contact contact2 = new Contact(LastName = 'Test Primary Contact 2', AccountId = acc2.Id, Email = 'testprimarycontact@test.com');
        Database.DMLOptions insertDML = new Database.DMLOptions();
        insertDML.DuplicateRuleHeader.AllowSave = true;
        Database.SaveResult sr = Database.insert(contact2, insertDML);
        DuplicateRecordItem dup = new DuplicateRecordItem(DuplicateRecordSetId = dupRS.id, RecordId=contact2.id);
        insert dup;

        acc2.F52_Primary_Contact__c = contact2.Id;
        update acc2;

        List<Account> accList = [SELECT Id, Primary_Contact_Email__c FROM Account WHERE Name = 'Test Acc Primary Contact']; 
            
        Test.startTest();

        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('testprimarycontact@test.com');

        Test.stopTest();

        blob expectedString = Blob.valueof('[{"message":"More than one Account exist with the requested email","errorCode":"ACCOUNT_TOO_MANY_ACCOUNTS"}]');
        system.assertEquals(expectedString, responseString, 'API logic did not work - ACCOUNT_TOO_MANY_ACCOUNTS');
    }

    // No contract exist with requested email, single Account exist, but with out Payment Method
    @isTest
    private static void testAPIPaymentMethodNoContractNoPM(){

        Account acc = [Select Id, F52_Primary_Contact__c FROM Account WHERE Name = 'Test Acc Primary Contact'].get(0);
         
        Test.startTest();

        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('testprimarycontact@test.com');

        Test.stopTest();

       blob expectedString = Blob.valueof('[{"message":"Account exist but there are no active Payment Method exist with the requested email","errorCode":"ACCOUNT_PM_NOT_FOUND"}]');
       system.assertEquals(expectedString, responseString, 'API logic did not work - ACCOUNT_PM_NOT_FOUND');
    }

    // No contract exist with requested email, single Account exist, with single Payment Method
    @isTest
    private static void testAPIPaymentMethodAccountWithPM(){

        Account acc = [Select Id, F52_Primary_Contact__c FROM Account WHERE Name = 'Test Acc Primary Contact'].get(0);

        blng__PaymentMethod__c paymentMethod = new blng__PaymentMethod__c(
            blng__Account__c = acc.Id, 
            blng__PaymentType__c = 'Debit Card',
            blng__Active__c = True,
            blng__BillingEmail__c = 'testprimarycontact@test.com'
        );

        insert paymentMethod;
            
        Test.startTest();

        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('testprimarycontact@test.com');

        Test.stopTest();

        blob expectedString = Blob.valueof('[{"message":"Payment Method Updated successfully and email is sent","errorCode":"Success"}]');
        system.assertEquals(expectedString, responseString, 'API logic did not work - Success');
    }

    // No contract exist with requested email, single Account exist, with mutiple Payment Method
    @isTest
    private static void testAPIPaymentMethodAccountWithTooManyPM(){

        Account acc = [Select Id, F52_Primary_Contact__c FROM Account WHERE Name = 'Test Acc Primary Contact'].get(0);

        List<blng__PaymentMethod__c> paymentMethodList = new List<blng__PaymentMethod__c>();

        paymentMethodList.add(new blng__PaymentMethod__c(
            blng__Account__c = acc.Id, 
            blng__PaymentType__c = 'Debit Card',
            blng__Active__c = True,
            blng__BillingEmail__c = 'testprimarycontact@test.com'
        ));

        paymentMethodList.add(new blng__PaymentMethod__c(
            blng__Account__c = acc.Id, 
            blng__PaymentType__c = 'Credit Card',
            blng__Active__c = True,
            blng__BillingEmail__c = 'testprimarycontact@test.com'
        ));
        
        insert paymentMethodList;
            
        Test.startTest();

        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('testprimarycontact@test.com');

        Test.stopTest();

        blob expectedString = Blob.valueof('[{"message":"More than one active Payment Method exist with the requested email","errorCode":"ACCOUNT_TOO_MANY_ACTIVE_PAYMENT_METHODS"}]');
        system.assertEquals(expectedString, responseString, 'API logic did not work - ACCOUNT_TOO_MANY_ACTIVE_PAYMENT_METHODS');
    }

    // No contract exist with requested email, single Account exist, with mutiple Payment Method
    @isTest
    private static void testAPIPaymentMethodNoEmailFound(){

        Test.startTest();

        blob responseString = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail('test@test.com');

        Test.stopTest();

        blob expectedString = Blob.valueof('[{"message":"There are no Contracts/Accounts exist with the requested email","errorCode":"NOT_FOUND"}]');
        system.assertEquals(expectedString, responseString, 'API logic did not work - NOT_FOUND');
    }
}