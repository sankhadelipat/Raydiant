@IsTest
public class StripeCreditNoteQueueable_Test {

    private class CreditNoteMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/v1/credit_notes/')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"id":"cn_test_123",' +
                    '"object":"credit_note",' +
                    '"customer":"cus_test_123",' +
                    '"status":"issued",' +
                    '"reason":"refund",' +
                    '"number":"CN-0001",' +
                    '"memo":"Refund issued",' +
                    '"type":"post_payment",' +
                    '"pdf":"https://stripe.com/cn.pdf",' +
                    '"effective_at":1766560000,' +
                    '"total":5000,' +
                    '"subtotal":5000,' +
                    '"out_of_band_amount":0,' +
                    '"post_payment_amount":5000,' +
                    '"pre_payment_amount":0,' +
                    '"lines":{"data":[' +
                        '{' +
                            '"id":"cnli_001",' +
                            '"invoice_line_item":"ili_001",' +
                            '"amount":5000,' +
                            '"unit_amount":5000,' +
                            '"quantity":1,' +
                            '"description":"Refund line"' +
                        '}' +
                    ']}' +
                    '}'
                );
            } else {
                res.setStatusCode(500);
                res.setBody('{"error":"server_error"}');
            }

            return res;
        }
    }
    
    private class CreditNoteErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('{"error":"boom"}');
            return r;
        }
    }

    @TestSetup
    static void setupData() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );

        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;

        Stripe_Invoice__c inv = new Stripe_Invoice__c(
            Name = 'INV-001',
            Stripe_Invoice_Id__c = 'in_test_123',
            Status__c = 'Paid',
            Account__c = acc.Id
        );
        insert inv;

        Stripe_Invoice_Line_Item__c ili = new Stripe_Invoice_Line_Item__c(
            Name = 'Invoice Line',
            Stripe_Invoice__c = inv.Id,
            Stripe_Invoice_Line_Item_ID__c = 'ili_001'
        );
        insert ili;
    }
    
    @IsTest
    static void testCreditNoteSuccess() {
        Test.setMock(HttpCalloutMock.class, new CreditNoteMock());

        Test.startTest();
        System.enqueueJob(
            new StripeCreditNoteQueueable(
                'cn_test_123',
                'in_test_123'
            )
        );
        Test.stopTest();

        Stripe_Credit_Note__c cn = [
            SELECT Id, Status__c, Total_Amount__c
            FROM Stripe_Credit_Note__c
            WHERE Stripe_Credit_Note_ID__c = 'cn_test_123'
            LIMIT 1
        ];

        System.assertEquals('issued', cn.Status__c);
        System.assertEquals(50, cn.Total_Amount__c);

        Stripe_Credit_Note_Line_Item__c li = [
            SELECT Id, Amount__c, Quantity__c
            FROM Stripe_Credit_Note_Line_Item__c
            WHERE Stripe_Credit_Note_Line_Item_ID__c = 'cnli_001'
            LIMIT 1
        ];

        System.assertEquals(50, li.Amount__c);
        System.assertEquals(1, li.Quantity__c);
    }

    @IsTest
    static void testCreditNoteErrorLogging() {
        Test.setMock(HttpCalloutMock.class, new CreditNoteErrorMock());
        
        delete [SELECT Id FROM Logger__c];

        Test.startTest();
        System.enqueueJob(
            new StripeCreditNoteQueueable(
                'cn_error',
                'in_test_123'
            )
        );
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeCreditNoteQueueable'
        ];

        System.assert(logCount > 0, 'Error must be logged');
    }
}