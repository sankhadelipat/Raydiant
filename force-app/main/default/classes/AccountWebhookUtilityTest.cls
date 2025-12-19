@isTest
public class AccountWebhookUtilityTest {
    
    private static string endpointUrl = 'www.testurl.com';
    private static String instance = AccountWebhookUtility.currentInstance;
    private static String endpointName = AccountWebhookUtility.ACC_WEBHOOK_ENDPOINT_NAME;
    private static String cpq_account_id = '033494c8-0a70-4156-ad8b-2bbaa347fe61';

    
    private static void createEndpointInstance() {    
        Endpoint_Properties__c testEndpoint = TestDataFactory.createTestEndpoint(endpointName,instance,endpointUrl,false);
        testEndpoint.Content_Type__c = 'application/json';
        insert testEndpoint;
        system.assertNotEquals(null, testEndpoint.Id, 'Endpoint Property Inserted');
    }

    static testMethod void testAccountWebhookUtilityExceptions() {

        TriggerHandler.bypass('AccountTriggerHandler');
        
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted'); 
        
        TriggerHandler.clearBypass('AccountTriggerHandler');

        try {
            Test.startTest();
            AccountWebhookUtility.accountWebhook(new Set<String>{accVar.Id}, AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT);
            Test.stopTest();
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('No Endpoint'),ex.getMessage());
        }
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());

        createEndpointInstance();

        try {
            AccountWebhookUtility.accountWebhook(new Set<String>{accVar.Id}, 'Invalid Action');
        } catch ( HttpCalloutException ex ) {
            system.assert(ex.getMessage().contains('Invalid apiAction'),ex.getMessage());
        }
        system.assertEquals(2,[SELECT Id FROM API_Log__c].size());
    }

    static testMethod void testNewAccountWebhookUtilitySuccess() {

        TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted'); 
        TriggerHandler.clearBypass('AccountTriggerHandler');
        
        createEndpointInstance();
        String mockBody = MOCK_SUCCESS_RESPONSE;
        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success',mockBody,new Map<String,String>()));

        Test.startTest();
        AccountWebhookUtility.accountWebhook(new Set<String>{accVar.Id}, AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT);
        Test.stopTest();
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());

        accVar = [SELECT Id, Account_Webhook_Event_Type__c, Account_Webhook_Profile_Id__c 
                    FROM Account 
                    WHERE Id =: accVar.Id LIMIT 1];

        system.assertEquals(cpq_account_id,accVar.Account_Webhook_Profile_Id__c);
        system.assertEquals(AccountWebhookUtility.EVENT_TYPE_NEW_ACCOUNT,accVar.Account_Webhook_Event_Type__c);

    }

    static testMethod void testMergeAccountWebhookUtilitySuccess() {

        List<Account> accounts = new List<Account>();
        TriggerHandler.bypass('AccountTriggerHandler');
        
        Account acc1 = TestDataFactory.createTestAccount(false);
        accounts.add(acc1);

        Account acc2 = TestDataFactory.createTestAccount(false);
        acc2.Name = 'Deleted Account';
        accounts.add(acc2);

        insert accounts;
        TriggerHandler.clearBypass('AccountTriggerHandler');

        List<Account> totalAccounts = [SELECT Id FROM Account];
        system.assertEquals(2, totalAccounts.size());

        Map<Id,Set<String>> accountsMergedMap = new Map<Id,Set<String>>();
        accountsMergedMap.put(acc1.Id, new Set<String>{acc2.Id});
        
        createEndpointInstance();
        String mockBody = MOCK_SUCCESS_RESPONSE;
        Test.setMock(HttpCalloutMock.class, new GenericHTTPCalloutMock(200,'Success',mockBody,new Map<String,String>()));

        Test.startTest();
        AccountWebhookUtility.accountWebhook(accountsMergedMap, AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT);
        Test.stopTest();
        system.assertEquals(1,[SELECT Id FROM API_Log__c].size());

        acc1 = [SELECT Id, Account_Webhook_Event_Type__c, Account_Webhook_Profile_Id__c 
                    FROM Account 
                    WHERE Id =: acc1.Id LIMIT 1];

        system.assertEquals(cpq_account_id,acc1.Account_Webhook_Profile_Id__c);
        system.assertEquals(AccountWebhookUtility.EVENT_TYPE_MERGE_ACCOUNT,acc1.Account_Webhook_Event_Type__c);

    }

    private static String MOCK_SUCCESS_RESPONSE = '{' + 
        '"cpq_account_id":"0014C00000uLtIhQAK",' + 
        '"profile_id":" ' + cpq_account_id + '",' + 
        '"profile_email":"test@raydiant.com",' + 
        '"message":"profile already exists with matching cpq_account_id",' + 
        '"grants":{"content_grant_scopes":["public","postermywall","screenfeed"],"device_licenses":{"lite":1}}' + 
        '}';
}