@IsTest
private class StripeTransactionMigration_Test {

    private class StripePaymentIntentListMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // FIRST PAGE
            if (!req.getEndpoint().contains('starting_after')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"object":"list",' +
                        '"has_more":true,' +
                        '"data":[' +
                            '{' +
                                '"id":"pi_001",' +
                                '"status":"succeeded",' +
                                '"customer":"cus_001",' +
                                '"currency":"usd",' +
                                '"amount":1000,' +
                                '"amount_received":1000,' +
                                '"created":1700000000,' +
                                '"payment_method":"pm_001",' +
                                '"latest_charge":{' +
                                    '"id":"ch_001",' +
                                    '"receipt_url":"https://receipt/1"' +
                                '}' +
                            '},' +
                            '{' +
                                '"id":"pi_002",' +
                                '"status":"failed",' +
                                '"customer":"cus_001",' +
                                '"currency":"usd",' +
                                '"amount":2000,' +
                                '"amount_received":0,' +
                                '"created":1700000100' +
                            '}' +
                        ']' +
                    '}'
                );
                return res;
            }

            // SECOND (LAST) PAGE
            if (req.getEndpoint().contains('starting_after=pi_002')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"object":"list",' +
                        '"has_more":false,' +
                        '"data":[' +
                            '{' +
                                '"id":"pi_003",' +
                                '"status":"canceled",' +
                                '"customer":"cus_001",' +
                                '"currency":"usd",' +
                                '"amount":3000,' +
                                '"amount_received":0,' +
                                '"created":1700000200' +
                            '}' +
                        ']' +
                    '}'
                );
                return res;
            }

            res.setStatusCode(400);
            res.setBody('{"error":"Unexpected request"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123',
            Publishable_Key__c = 'pk_test_123'
        );

        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_001'
        );
        insert acc;

        insert new Stripe_Payment_Method__c(
            Name = 'Test PM',
            Stripe_Payment_Method_ID__c = 'pm_001'
        );
    }

    @IsTest
    static void testStripeTransactionMigration() {

        Test.setMock(HttpCalloutMock.class, new StripePaymentIntentListMock());

        Test.startTest();
        Database.executeBatch(
            new StripeTransactionMigration(),
            1
        );
        Test.stopTest();

        // ASSERT TRANSACTIONS CREATED
        List<Stripe_Payment_Transaction__c> txns = [
            SELECT
                Stripe_PaymentIntent_ID__c,
                Status__c,
                Amount__c,
                Amount_Paid__c,
                Account__c
            FROM Stripe_Payment_Transaction__c
        ];

        System.assertEquals(
            3,
            txns.size(),
            'All Stripe PaymentIntents should be migrated'
        );

        // ASSERT SUCCESSFUL LINKING
        for (Stripe_Payment_Transaction__c txn : txns) {
            System.assertNotEquals(
                null,
                txn.Account__c,
                'Transaction must be linked to Account'
            );
            System.assertNotEquals(
                null,
                txn.Stripe_PaymentIntent_ID__c,
                'PaymentIntent ID must be populated'
            );
        }
    }

    @IsTest
    static void testFinishLoggerCreated() {

        Test.setMock(HttpCalloutMock.class, new StripePaymentIntentListMock());

        Test.startTest();
        Database.executeBatch(
            new StripeTransactionMigration(),
            1
        );
        Test.stopTest();

        List<Logger__c> logs = [
            SELECT Id, Status__c
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeTransactionMigration'
        ];

        System.assert(
            !logs.isEmpty(),
            'Finish() should create a Logger record'
        );
    }
}