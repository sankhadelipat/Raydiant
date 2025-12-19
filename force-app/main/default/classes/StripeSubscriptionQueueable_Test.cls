@IsTest
public class StripeSubscriptionQueueable_Test {
    
    @TestSetup
    static void setupTestData() {
        Stripe_Details__c stripeSetting = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );
        insert stripeSetting;
    }
    
    @IsTest
    static void testQueueableExecution() {
        // Test data setup
        String mockStripeResponse = getMockStripeSubscriptionResponse();
        
        Test.startTest();
        // Enqueue the job
        System.enqueueJob(new StripeSubscriptionQueueable(mockStripeResponse));
        Test.stopTest();
    }

    // Helper method to create mock Stripe response
    private static String getMockStripeSubscriptionResponse() {
        return '{' +
            '"id": "sub_1SAmx8PuJCefzpgmwVntZFvA",' +
            '"object": "subscription",' +
            '"billing_cycle_anchor": 1758698246,' +
            '"cancel_at": null,' +
            '"canceled_at": null,' +
            '"created": 1758698246,' +
            '"current_period_start": 1758698246,' +
            '"current_period_end": 1761290246,' +
            '"start_date": 1758698246,' +
            '"customer": "cus_T6R2Odlg1GFV2j",' +
            '"customer_email": "sankha.delipat@gmail.com",' +
            '"customer_name": "test acct 09-23-2025",' +
            '"latest_invoice": "in_1SAmx8PuJCefzpgmvTjyAQEv",' +
            '"status": "active",' +
            '"schedule": null,' +
            '"items": {' +
                '"object": "list",' +
                '"data": [' +
                    '{' +
                        '"id": "si_T70zZcOie8KBO6",' +
                        '"object": "subscription_item",' +
                        '"created": 1758698246,' +
                        '"current_period_start": 1758698246,' +
                        '"current_period_end": 1761290246,' +
                        '"quantity": 2,' +
                        '"price": {' +
                            '"id": "price_1RvCLNPuJCefzpgmP4oO8LTO",' +
                            '"object": "price",' +
                            '"active": true,' +
                            '"unit_amount": 5900,' +
                            '"product": "prod_Squ9kXUFSf8muO",' +
                            '"recurring": {' +
                                '"interval": "month",' +
                                '"interval_count": 1' +
                            '}' +
                        '}' +
                    '},' +
                    '{' +
                        '"id": "si_T70zH0fJTigcju",' +
                        '"object": "subscription_item",' +
                        '"created": 1758698246,' +
                        '"current_period_start": 1758698246,' +
                        '"current_period_end": 1761290246,' +
                        '"quantity": 3,' +
                        '"price": {' +
                            '"id": "price_1S2TdQPuJCefzpgmcnulLWly",' +
                            '"object": "price",' +
                            '"active": true,' +
                            '"unit_amount": 10000,' +
                            '"product": "prod_SyQUm4vU6S1kzH",' +
                            '"recurring": {' +
                                '"interval": "month",' +
                                '"interval_count": 1' +
                            '}' +
                        '}' +
                    '}' +
                '],' +
                '"has_more": false,' +
                '"total_count": 2' +
            '}' +
        '}';
    }
}