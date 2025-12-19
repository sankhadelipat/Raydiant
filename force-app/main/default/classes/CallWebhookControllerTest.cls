@isTest
private class CallWebhookControllerTest {
    @isTest
    static void isAdminUserTest() {
        User u = new User();
        u.profileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        u.firstName = 'admin';
        u.LastName = 'user';
        u.Username = 'tuser123@raydiant.com.' + Math.random();
        u.Email = 'test@example.com';
        u.Alias = 'tuser';
        u.LocaleSidKey = 'en_US';
        u.TimeZoneSidKey = 'GMT';
        u.LanguageLocaleKey = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        INSERT u;

        System.assertEquals(true, CallWebhookController.isAdminUser(u.Id), 'method should return true for admin users');

        u.ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator (No Calendar Sync)'].Id;
        UPDATE u;
        System.assertEquals(true, CallWebhookController.isAdminUser(u.Id), 'method should return true for admin users');

        u.ProfileId = [SELECT Id FROM Profile WHERE Name = 'CSM'].Id;
        UPDATE u;
        System.assertEquals(true, CallWebhookController.isAdminUser(u.Id), 'method should return true for CSM users');
        
        u.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Sales User'].Id;
        UPDATE u;
        System.assertEquals(false, CallWebhookController.isAdminUser(u.Id), 'method should return false for Sales users');
    }

    @isTest
    static void callWebhookFromLwcTest(){
        Account a = new Account(Name = 'Test Account');
        INSERT a;
        SBQQ__Quote__c q = new SBQQ__Quote__c(RAY_Contract_Status__c = 'Activated');
        INSERT q;
        Contract c = new Contract(AccountId = a.Id, Status = 'Draft', SBQQ__Quote__c = q.Id);
        INSERT c;

        CallWebhookController.callWebhookFromLwc(c.Id);
    }
}