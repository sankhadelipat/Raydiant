@isTest(SeeAllData=false)
private class StripeSubscriptionMigration_Test {
    private class MockStripeResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Long nowSeconds = Datetime.now().getTime() / 1000;
            Long anchorSeconds = nowSeconds + (30 * 24 * 60 * 60);
            Long cancelAtSeconds = nowSeconds + (365 * 24 * 60 * 60);
            
            String body = '{'
                + '"id":"sub_test_123",'
                + '"latest_invoice":"inv_test_456",'
                + '"customer":"cus_test_789",'
                + '"status":"active",'
                + '"billing_cycle_anchor":' + anchorSeconds + ','
                + '"cancel_at":' + cancelAtSeconds + ','
                + '"created":' + nowSeconds + ','
                + '"current_period_start":' + nowSeconds + ','
                + '"current_period_end":' + (nowSeconds + (30*24*60*60)) + ','
                + '"start_date":' + nowSeconds + ','
                + '"object":{"schedule":"sub_sched_abc"},'
                + '"items":{"data":[{'
                + '"id":"si_test_1",'
                + '"quantity":2,'
                + '"price":{"id":"price_test_1","product":"prod_test_1","unit_amount":5000}'
                + '}]}'
                + '}';
            res.setBody(body);
            return res;
        }
    }
    
    private class MockStripeErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }
    
    private class MockMalformedJsonResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":'); 
            return res;
        }
    }
    
    private static Contract createTestContract(Boolean withSubscription) {
        Stripe_Details__c sd = new Stripe_Details__c(
            Name = 'Stripe Details', 
            Serect_Key__c = 'sk_test_abc123'
        );
        insert sd;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            Stripe_Product_ID__c = 'pr_test_1234'
        );
        insert prod;
        
        Account acc = new Account(
            Name = 'Test Accoun1',
            Stripe_Customer_ID__c = 'cus_test_1234'
        );
        insert acc;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12
        );
        insert quote;
        
        SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = pbe.Id,
            Stripe_Price_ID__c = 'pi_test_1234'
        );
        insert quoteLine;
        
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            blng__BillingDayOfMonth__c = '1', 
            EffectiveDate = Date.today()    
        );
        insert ord;
        
        Contract con = new Contract(
            AccountId = acc.Id,
            SBQQ__Quote__c = quote.Id,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            ContractTerm = 30, // required field
            // Status = 'Draft',
            Stripe_Billing_Date__c = Date.today(),
            Stripe_Subscription_ID__c = null,
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c
        );
        insert con;
        
        
        if (withSubscription) {
            SBQQ__Subscription__c subRec = new SBQQ__Subscription__c(
                SBQQ__Contract__c = con.Id,
                SBQQ__Account__c = acc.Id,
                //SBQQ__SubscriptionType__c = 'Renewable',
                SBQQ__TerminatedDate__c = Date.today().addDays(30),
                SBQQ__Quantity__c = 2,
                SBQQ__NetPrice__c = 50,
                SBQQ__Product__c = prod.Id,
                Stripe_Subscription_ID__c = 'si_test_1234',
                Stripe_Product_ID__c = 'pr_test_1234',
                Stripe_Price_ID__c = 'pi_test_1234',
                SBQQ__BillingFrequency__c = 'Monthly',
                CurrencyIsoCode = 'USD'
            );
            insert subRec;
        }
        
        return con;
    }
    
    @isTest
    static void testBatchSuccess() {
        Contract con = createTestContract(true);
        
        Test.setMock(HttpCalloutMock.class, new MockStripeResponse());
        
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
        
        Contract conAfter = [SELECT Stripe_Subscription_ID__c, Stripe_Customer_ID__c, Stripe_Status__c
                             FROM Contract WHERE Id=:con.Id];
        System.assertEquals('sub_test_123', conAfter.Stripe_Subscription_ID__c);
        System.assertEquals('cus_test_789', conAfter.Stripe_Customer_ID__c);
        System.assertEquals('active', conAfter.Stripe_Status__c);
        
        System.assertEquals(0, [SELECT count() FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionMigration']);
    }
    
    @isTest
    static void testBatchErrorResponse() {
        Contract con = createTestContract(true);
        
        Test.setMock(HttpCalloutMock.class, new MockStripeErrorResponse());
        
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
        
        Integer errorCount = [SELECT count() FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionMigration'];
        System.assert(errorCount > 0, 'Error log should be created when Stripe returns non-200');
    }
    
    // --- MALFORMED JSON TEST ---
    @isTest
    static void testBatchMalformedJson() {
        Contract con = createTestContract(true);
        
        Test.setMock(HttpCalloutMock.class, new MockMalformedJsonResponse());
        
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
        
        // Should gracefully log an error instead of crashing
        Integer errorCount = [SELECT count() FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionMigration'];
        System.assert(errorCount > 0, 'Error log should be created when JSON is malformed');
    }
    
    @isTest
    static void testBatchNoContracts() {
        Stripe_Details__c sd = new Stripe_Details__c(Name='Stripe Details', Serect_Key__c='sk_test_abc123');
        insert sd;
        
        Test.setMock(HttpCalloutMock.class, new MockStripeResponse());
        
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
        
        System.assertEquals(0, [SELECT count() FROM Logger__c WHERE Apex_Class__c='StripeSubscriptionMigration']);
    }
}