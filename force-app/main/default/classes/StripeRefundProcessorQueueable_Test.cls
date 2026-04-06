@IsTest
public class StripeRefundProcessorQueueable_Test {

    private class PaymentIntentMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/v1/payment_intents/')) {
                res.setStatusCode(200);
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'id' => 'pi_test_123',
                    'payment_details' => new Map<String, Object>{
                        'order_reference' => 'in_test_invoice'
                    }
                }));
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"not found"}');
            }

            return res;
        }
    }
    
    private class PaymentFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('{"error":"stripe down"}');
            return r;
        }
    }

    @TestSetup
    static void setupData() {

        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Stripe_Invoice__c invoice = new Stripe_Invoice__c(
            Name = 'INV-001',
            Stripe_Invoice_Id__c = 'in_test_invoiceXYZ',
            Status__c = 'Paid',
            Amount_Paid__c = 21,
            Amount_Refunded__c = 0,
            Account__c = acc.Id,
            CurrencyIsoCode = 'USD'
        );
        insert invoice;
    }

    @IsTest
    static void testRefundProcessor_Success() {

        Test.setMock(HttpCalloutMock.class, new PaymentIntentMock());

        Test.startTest();
        System.enqueueJob(
            new StripeRefundProcessorQueueable(
                'pi_test_123',
                21
            )
        );
        Test.stopTest();

        Stripe_Invoice__c updated = [
            SELECT Status__c, Amount_Refunded__c
            FROM Stripe_Invoice__c
            WHERE Stripe_Invoice_Id__c LIKE 'in_test_invoice%'
            LIMIT 1
        ];

        System.assertEquals(
            'Refunded',
            updated.Status__c,
            'Invoice must be marked Refunded'
        );

        System.assertEquals(
            21,
            updated.Amount_Refunded__c,
            'Refunded amount must be set'
        );
    }

    @IsTest
    static void testRefundProcessor_NoInvoiceFound() {

        Test.setMock(HttpCalloutMock.class, new PaymentIntentMock());

        // Remove invoices so LIKE returns nothing
        delete [SELECT Id FROM Stripe_Invoice__c];
        delete [SELECT Id FROM Logger__c];

        Test.startTest();
        System.enqueueJob(
            new StripeRefundProcessorQueueable(
                'pi_test_123',
                10
            )
        );
        Test.stopTest();

        // Should not throw, should not insert logs
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Logger__c],
            'No error should be logged when invoice not found'
        );
    }

    @IsTest
    static void testRefundProcessor_StripeFailure() {

        Test.setMock(HttpCalloutMock.class, new PaymentFailureMock());

        delete [SELECT Id FROM Logger__c];

        Test.startTest();
        System.enqueueJob(
            new StripeRefundProcessorQueueable(
                'pi_fail',
                5
            )
        );
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeRefundProcessorQueueable'
        ];

        System.assertEquals(
            1,
            logCount,
            'Stripe failure must be logged'
        );
    }
}