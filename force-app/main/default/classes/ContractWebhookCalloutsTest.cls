@isTest
public class ContractWebhookCalloutsTest {
    @isTest 
    public static void sendContractWebhookTest() {
        String dataBody = '{"user": "test@email.com", "source": "Salesforce", '
            + '"occurred_at": 1614707402, "id": "8016C000000A222111", '
            + '"event_type": "subscription_changed","content": {"contract": '
            + '{"contract_number": "8006C000000B222111"}}}';
        
        Test.setMock(HttpCalloutMock.class, new ContractWebhookMockHttpResponseSuccess());
        
        Test.startTest();
        HttpResponse res = ContractWebhookCallouts.sendContractWebhook(dataBody, 'callout:Webhook');
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('OK', res.getStatus());
    }
}