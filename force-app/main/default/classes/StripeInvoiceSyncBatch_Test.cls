@IsTest
private class StripeInvoiceSyncBatch_Test {

    private class StripeInvoiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/v1/invoices/in_valid_001')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_valid_001",' +
                        '"parent":{' +
                            '"subscription_details":{' +
                                '"subscription":"sub_valid_001"' +
                            '}' +
                        '}' +
                    '}'
                );
                return res;
            }

            if (req.getEndpoint().contains('/v1/invoices/in_no_contract')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                        '"id":"in_no_contract",' +
                        '"parent":{' +
                            '"subscription_details":{' +
                                '"subscription":"sub_missing_001"' +
                            '}' +
                        '}' +
                    '}'
                );
                return res;
            }

            res.setStatusCode(404);
            res.setBody('{"error":"Invoice not found"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        // Stripe config
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123456',
            Publishable_Key__c = 'pk_test_123456'
        );

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Contract lifecycle: Draft -> Activated
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_valid_001'
        );
        insert con;

        con.Status = 'Activated';
        update con;

        // Invoice that SHOULD be linked
        insert new Stripe_Invoice__c(
            Stripe_Invoice_Id__c = 'in_valid_001',
            Account__c = acc.Id
        );

        // Invoice with no matching contract
        insert new Stripe_Invoice__c(
            Stripe_Invoice_Id__c = 'in_no_contract',
            Account__c = acc.Id
        );
    }

    @IsTest
    static void testInvoiceContractBackfill() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());

        Test.startTest();
        Database.executeBatch(new StripeInvoiceSyncBatch(), 5);
        Test.stopTest();

        // Invoice with valid subscription should be updated
        Stripe_Invoice__c updatedInvoice = [
            SELECT Contract__c
            FROM Stripe_Invoice__c
            WHERE Stripe_Invoice_Id__c = 'in_valid_001'
            LIMIT 1
        ];

        System.assertNotEquals(
            null,
            updatedInvoice.Contract__c,
            'Contract should be populated for valid subscription'
        );

        // Invoice with missing contract should remain untouched
        Stripe_Invoice__c untouchedInvoice = [
            SELECT Contract__c
            FROM Stripe_Invoice__c
            WHERE Stripe_Invoice_Id__c = 'in_no_contract'
            LIMIT 1
        ];

        System.assertEquals(
            null,
            untouchedInvoice.Contract__c,
            'Invoice without matching Contract must remain unchanged'
        );
    }

    @IsTest
    static void testErrorLoggedWhenContractMissing() {

        Test.setMock(HttpCalloutMock.class, new StripeInvoiceMock());

        Test.startTest();
        Database.executeBatch(new StripeInvoiceSyncBatch(), 5);
        Test.stopTest();

        List<Logger__c> logs = [
            SELECT Id, Apex_Class__c
            FROM Logger__c
            WHERE Apex_Class__c = 'StripeInvoiceSyncBatch'
        ];

        System.assert(
            !logs.isEmpty(),
            'Error log should be created for missing contract cases'
        );
    }
}