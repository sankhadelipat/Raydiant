@isTest
public class ContractWebhookUtilsTest {
	@isTest
    static void convertToEpochTimeTest(){
        Datetime dt = DateTime.now();
        Long actualResult = ContractWebhookUtils.convertToEpochTime(dt);
        Long expectedResult = dt.getTime()/1000;
        
        Long actualResult2 = ContractWebhookUtils.convertToEpochTime(null);
        Long expectedResult2 = 0;
        System.assertEquals(expectedResult2, actualResult2);
    }
    
    @isTest
    static void checkStringNullTest(){
        String actualResult = ContractWebhookUtils.checkStringNull('Test');
        String expectedResult = 'Test';
        System.assertEquals(expectedResult, actualResult);
        
        String actualResult2 = ContractWebhookUtils.checkStringNull(null);
        String expectedResult2 = '';
        System.assertEquals(expectedResult2, actualResult2);
    }
    
        @isTest
    public static void convertEventTypeisWebhookTest() {
        Contract cont = new Contract();
        cont.is_New_Webhook__c  = true;
     	String actualResult = ContractWebhookUtils.convertEventType(cont);
        String expectedResult = 'subscription_created';
        System.assertEquals(expectedResult, actualResult);
    }
    
        @isTest
    public static void convertEventTypeActivatedTest() {
        Contract cont = new Contract();
        cont.is_New_Webhook__c  = false;
        cont.Status = 'Activated';
     	String actualResult = ContractWebhookUtils.convertEventType(cont);
        String expectedResult = 'subscription_changed';
        System.assertEquals(expectedResult, actualResult);
    }

    @isTest
    public static void convertEventTypePausedTest() {
        Contract cont = new Contract();
        cont.is_New_Webhook__c  = false;
        cont.Status = 'Paused';
     	String actualResult = ContractWebhookUtils.convertEventType(cont);
        String expectedResult = 'subscription_paused';
        System.assertEquals(expectedResult, actualResult);
    }
    @isTest
    public static void convertEventTypeCancelledTest() {
        Contract cont = new Contract();
        cont.is_New_Webhook__c  = false;
        cont.Status = 'Cancelled';
     	String actualResult = ContractWebhookUtils.convertEventType(cont);
        String expectedResult = 'subscription_cancelled';
        System.assertEquals(expectedResult, actualResult);
    }
    @isTest
    public static void convertEventTypeTest() {
        Contract cont = new Contract();
        cont.is_New_Webhook__c  = false;
     	String actualResult = ContractWebhookUtils.convertEventType(cont);
        String expectedResult = '';
        System.assertEquals(expectedResult, actualResult);
    }  
    
    @isTest
    public static void checkContractWebhookWrapperValidityTest(){
        ContractWebhookWrapper jsonObj= new ContractWebhookWrapper();
        Boolean actualResult = ContractWebhookUtils.checkContractWebhookWrapperValidity(JSON.serialize(jsonObj));
        System.assertEquals(true, actualResult);
    }
    
        @isTest
    public static void checkContractWebhookWrapperValidityTest2(){
        Boolean actualResult = ContractWebhookUtils.checkContractWebhookWrapperValidity(JSON.serialize('Teest'));
        System.assertEquals(false, actualResult);
    }
    
    @isTest
    public static void handleSuccessConractTest(){
        Contract cont = new Contract();
        Contract cont2 = ContractWebhookUtils.handleSuccessConract(cont);

        System.assertEquals('Success', cont2.Backend_Integration_Status__c);
    }
    
      @isTest
    public static void handleErrorContractTest(){
        Contract cont = new Contract();
        Contract cont2 = ContractWebhookUtils.handleErrorContract('ErrorTest', cont);

        System.assertEquals('Error', cont2.Backend_Integration_Status__c);
        System.assertEquals('ErrorTest', cont2.Error_Message__c);
    }
    
    @isTest
    public static void sendEmailAboutErrorsTest(){
        Account acc = new Account();
        acc.Name = 'Test';
        insert acc;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        insert quote; 

        Contract cont1 = new Contract();
        cont1.accountId = acc.Id;
        cont1.Status = 'Draft';
        cont1.SBQQ__Quote__c = quote.Id;

        Contract cont2 = new Contract();
        cont2.accountId = acc.Id;
        cont2.Status = 'Draft';
        cont2.SBQQ__Quote__c = quote.Id;
        cont2.Backend_Integration_Status__c = 'Error';

        
        insert new List<Contract> {cont1, cont2};

        List<Contract> listContracts = new List<Contract>{cont1, cont2};
        ContractWebhookUtils.sendEmailAboutErrors(listContracts);
            
        Integer invocations = Limits.getEmailInvocations();
        System.assertEquals(0, invocations, 'Email has not been sent');
    }
    
    
}