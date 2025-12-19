@isTest 
private class MassUpdatePMTest 
{
    @testSetup
    private static void testSetupData() {
        Account objAccount = new Account(
          Name = 'Test Account'
        );
        insert objAccount;
        
        blng__PaymentMethod__c objPM = new blng__PaymentMethod__c(blng__Account__c = objAccount.Id, 
                                                                  blng__PaymentType__c = 'Debit Card',
                                                                  blng__BillingEmail__c = 'test@raydianttest1.com');
        blng__PaymentMethod__c objPM1 = new blng__PaymentMethod__c(blng__Account__c = objAccount.Id, 
                                                                  blng__PaymentType__c = 'Credit Card',
                                                                  blng__BillingEmail__c = 'test@raydianttest2.com');
        insert new List<blng__PaymentMethod__c> { objPM, objPM1 };
            
        blng__Invoice__c inv = new blng__Invoice__c(blng__Account__c=objAccount.Id,
                                                        blng__PaymentMethod__c = objPM.Id);
        blng__Invoice__c inv1 = new blng__Invoice__c(blng__Account__c=objAccount.Id,
                                                     blng__PaymentMethod__c = objPM1.Id);
        insert new List<blng__Invoice__c> { inv, inv1 };
    }
    
    @isTest
    private static void testConstructor()
    {
        List<blng__Invoice__c> listinv = [SELECT id,blng__PaymentMethod__c FROM blng__Invoice__c];
        
        Test.startTest();
        Test.setCurrentPage(Page.MassUpdatePMEmail);
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(listinv);
        stdSetController.setSelected(listinv);
        MassUpdatePM ext = new MassUpdatePM(stdSetController);
        ext.getRedirectToInvoices();
        Test.stopTest();
    }
    
    @isTest
    private static void testNothingSelected()
    {
        List<blng__Invoice__c> listinv = [SELECT id,blng__PaymentMethod__c FROM blng__Invoice__c];
        
        Test.startTest();
        Test.setCurrentPage(Page.MassUpdatePMEmail);
        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(listinv);

        MassUpdatePM ext = new MassUpdatePM(stdSetController);
        ext.back();
        Test.stopTest();
    }
}