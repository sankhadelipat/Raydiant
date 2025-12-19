@IsTest
private class CapturePaymentMethodControllerTest {
	
    @IsTest
    static void getPaymentMethodsTest() {
        //Create Data
        Account objAccount = new Account(
        	Name = 'Test Account'
        );
        insert objAccount;
        blng__PaymentMethod__c objPM = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        insert objPM;
        
        List<blng__PaymentMethod__c> listPM = [SELECT Id, F52_Customer_PM_Id__c FROM blng__PaymentMethod__c WHERE Id =: objPM.Id];
        
        Test.startTest();
        List<blng__PaymentMethod__c> listPMActual = CapturePaymentMethodController.getPaymentMethods(listPM[0].F52_Customer_PM_Id__c);
        Test.stopTest();
        
        System.assertEquals(objPM.Id, listPMActual[0].Id);
    }
    
    @IsTest
    static void updatePaymentMethodsOnObjectsTest() {
        //Create Data
        Account objAccount = new Account(
        	Name = 'Test Account'
        );
        insert objAccount;
        blng__PaymentMethod__c objPM = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        blng__PaymentMethod__c objPMOld = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        insert new List<blng__PaymentMethod__c> {
        	objPM, objPMOld
        };
                
        Test.startTest();
        CapturePaymentMethodController.updatePaymentMethodsOnObjects(objPMOld.Id, objPM.Id);
        Test.stopTest();
        
        List<blng__PaymentMethod__c> listPM = [SELECT Id, F52_Old_Payment_Id__c FROM blng__PaymentMethod__c WHERE Id =: objPM.Id];
        System.assertEquals(objPMOld.Id, listPM[0].F52_Old_Payment_Id__c);
    }
}