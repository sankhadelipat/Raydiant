@IsTest
private class StripeTransactionQueueable_Test {

    private class StripePaymentIntentMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/v1/payment_intents/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"pi_test_123",' +
                    '"status":"succeeded",' +
                    '"amount":5900,' +
                    '"amount_received":5900,' +
                    '"currency":"usd",' +
                    '"created":1769248320,' +
                    '"payment_method":"pm_test_123",' +
                    '"latest_charge":{' +
                    '"id":"ch_test_123",' +
                    '"receipt_url":"https://stripe.test/receipt"' +
                    '}' +
                    '}'
                );
                return res;
            }

            res.setStatusCode(400);
            res.setBody('{"error":"Unhandled endpoint"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );

        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id
        );
        insert quote;

        Stripe_Payment_Method__c pm = new Stripe_Payment_Method__c(
            Name = 'Test PM',
            Stripe_Payment_Method_ID__c = 'pm_test_123'
        );
        insert pm;
    }

    @IsTest
    static void testPaymentIntentSucceeded() {

        Test.setMock(HttpCalloutMock.class, new StripePaymentIntentMock());

        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__Account__c
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(
            new StripeTransactionQueueable(
                'pi_test_123',
                'cus_test_123',
                quote.Id,
                'payment_intent.succeeded'
            )
        );
        Test.stopTest();

        Stripe_Payment_Transaction__c pt = [
            SELECT
                Stripe_PaymentIntent_ID__c,
                Amount__c,
                Amount_Paid__c,
                CurrencyIsoCode,
                Status__c,
                Account__c,
                Quote_CPQ__c,
                Stripe_Charge_ID__c,
                Receipt_URL__c
            FROM Stripe_Payment_Transaction__c
            WHERE Stripe_PaymentIntent_ID__c = 'pi_test_123'
            LIMIT 1
        ];

        System.assertEquals('Succeeded', pt.Status__c);
        System.assertEquals(59, pt.Amount__c);
        System.assertEquals(59, pt.Amount_Paid__c);
        System.assertEquals('USD', pt.CurrencyIsoCode);
        System.assertNotEquals(null, pt.Account__c);
        System.assertEquals(quote.Id, pt.Quote_CPQ__c);
        System.assertEquals('ch_test_123', pt.Stripe_Charge_ID__c);
    }

    private class StripePaymentIntentFailedMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            res.setStatusCode(200);
            res.setBody(
                '{' +
                '"id":"pi_test_fail",' +
                '"status":"requires_payment_method",' +
                '"amount":5900,' +
                '"amount_received":0,' +
                '"currency":"usd",' +
                '"created":1769248320,' +
                '"payment_method":"pm_test_123",' +
                '"last_payment_error":{' +
                '"message":"Card declined",' +
                '"code":"card_declined",' +
                '"decline_code":"insufficient_funds"' +
                '}' +
                '}'
            );
            return res;
        }
    }

    @IsTest
    static void testPaymentIntentFailed() {

        Test.setMock(HttpCalloutMock.class, new StripePaymentIntentFailedMock());

        SBQQ__Quote__c quote = [
            SELECT Id
            FROM SBQQ__Quote__c
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(
            new StripeTransactionQueueable(
                'pi_test_fail',
                'cus_test_123',
                quote.Id,
                'payment_intent.payment_failed'
            )
        );
        Test.stopTest();

        Stripe_Payment_Transaction__c pt = [
            SELECT
                Status__c,
                Error_Message__c,
                Error_Code__c,
                Decline_Code__c
            FROM Stripe_Payment_Transaction__c
            WHERE Stripe_PaymentIntent_ID__c = 'pi_test_fail'
            LIMIT 1
        ];

        System.assertEquals('Failed', pt.Status__c);
        System.assertEquals('Card declined', pt.Error_Message__c);
        System.assertEquals('card_declined', pt.Error_Code__c);
        System.assertEquals('insufficient_funds', pt.Decline_Code__c);
    }

    @IsTest
    static void testNoAccount_Logged() {

        Test.setMock(HttpCalloutMock.class, new StripePaymentIntentMock());

        Test.startTest();
        System.enqueueJob(
            new StripeTransactionQueueable(
                'pi_test_404',
                'cus_does_not_exist',
                null,
                'payment_intent.succeeded'
            )
        );
        Test.stopTest();

        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeTransactionQueueable'
        ];

        System.assert(!logs.isEmpty(), 'Error should be logged');
    }
}