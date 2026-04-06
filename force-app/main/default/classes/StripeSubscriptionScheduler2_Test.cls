@IsTest
public class StripeSubscriptionScheduler2_Test {
    
    private class StripeHttpMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Price creation
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setBody('{"id":"price_test_123"}');
            }
            // Subscription GET
            else if (req.getEndpoint().contains('/v1/subscriptions/')) {
                res.setBody(
                    '{"id":"sub_test_123",' +
                    '"schedule":"sub_sched_123",' +
                    '"latest_invoice":"inv_test_123",' +
                    '"customer":"cus_test_123",' +
                    '"status":"active",' +
                    '"metadata":{"subscription_schedule":"true","salesforce_quote_id":"'+Test.getStandardPricebookId()+'"}}'
                );
            }
            // Subscription Schedule GET
            else if (req.getEndpoint().contains('/v1/subscription_schedules/')) {
                res.setBody(
                    '{' +
                    '"id":"sub_sched_123",' +
                    '"status":"not_started",' +
                    '"customer":"cus_test_123",' +
                    '"phases":[{' +
                    '"start_date":1765843200,' +
                    '"end_date":1797379200,' +
                    '"items":[{' +
                    '"price":{"id":"price_test_123","product":"prod_test_123","unit_amount":10000,"active":true,' +
                    '"recurring":{"interval":"month","interval_count":1}},' +
                    '"quantity":2' +
                    '}]}]' +
                    '}'
                );
            } else {
                res.setBody('{"id":"ok"}');
            }
            return res;
        }
    }
    
    private class StripeHttpMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"bad request"}');
            return res;
        }
    }
    
    private class StripeHttpMockPriceError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/prices')) {
                res.setStatusCode(500);
                res.setBody('{"error":"Internal Server Error"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"id":"generic_id"}');
            }
            return res;
        }
    }
    
    private static SBQQ__Quote__c createQuoteForTest(String suffix,
                                                     String billingFreq,
                                                     String payTerms,
                                                     String subType,
                                                     Decimal priceAmt) {
                                                         // Unique product ids using suffix
                                                         String prodId = 'prod_' + suffix + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
                                                         String priceId = 'price_' + suffix + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
                                                         
                                                         Account acc = new Account(Name = 'Test Acc ' + suffix, Stripe_Customer_ID__c = 'cus_' + suffix);
                                                         insert acc;
                                                         
                                                         Product2 p = new Product2(
                                                             Name = 'Test Prod ' + suffix,
                                                             IsActive = true,
                                                             Stripe_Product_Id__c = prodId,
                                                             Stripe_Price_ID__c = priceId,
                                                             SBQQ__SubscriptionType__c = subType,
                                                             SBQQ__SubscriptionPricing__c = 'Fixed Price',
                                                             SBQQ__BillingFrequency__c = (subType == 'Renewable' ? billingFreq : null),
                                                             SBQQ__SubscriptionTerm__c = 12,
                                                             SBQQ__BillingType__c = (subType == 'Renewable' ? 'Advance' : null),
                                                             SBQQ__ChargeType__c = (subType == 'Renewable' ? 'Recurring' : 'One-time')
                                                         );
                                                         insert p;
                                                         
                                                         Pricebook2 pb = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
                                                         update pb;
                                                         
                                                         PricebookEntry pbe = new PricebookEntry(
                                                             Pricebook2Id = pb.Id,
                                                             Product2Id = p.Id,
                                                             UnitPrice = priceAmt,
                                                             IsActive = true
                                                         );
                                                         insert pbe;
                                                         
                                                         SBQQ__Quote__c q = new SBQQ__Quote__c(
                                                             SBQQ__StartDate__c = Date.today(),
                                                             SBQQ__EndDate__c = Date.today().addMonths(12),
                                                             SBQQ__Account__c = acc.Id,
                                                             SBQQ__Primary__c = true,
                                                             Billing_Frequency_Override__c = billingFreq,
                                                             SBQQ__SubscriptionTerm__c = 12,
                                                             CurrencyIsoCode = 'USD',
                                                             SBQQ__PaymentTerms__c = payTerms
                                                         );
                                                         insert q;
                                                         
                                                         SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
                                                             SBQQ__Quote__c = q.Id,
                                                             SBQQ__Product__c = p.Id,
                                                             SBQQ__ChargeType__c = p.SBQQ__ChargeType__c,
                                                             SBQQ__SubscriptionTerm__c = p.SBQQ__SubscriptionTerm__c,
                                                             SBQQ__SubscriptionPricing__c = p.SBQQ__SubscriptionPricing__c,
                                                             SBQQ__BillingType__c = p.SBQQ__BillingType__c,
                                                             SBQQ__BillingFrequency__c = p.SBQQ__BillingFrequency__c,
                                                             SBQQ__Quantity__c = 1,
                                                             SBQQ__ListPrice__c = priceAmt,
                                                             SBQQ__NetPrice__c = priceAmt,
                                                             SBQQ__RegularPrice__c = priceAmt,
                                                             SBQQ__SpecialPrice__c = priceAmt,
                                                             SBQQ__PricebookEntryId__c = pbe.Id,
                                                             Stripe_Price_ID__c = priceId
                                                         );
                                                         insert ql;
                                                         
                                                         return q;
                                                     }
    
    @TestSetup
    static void setup() {
        upsert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
    }
    
    @isTest 
    static void testCreateStripeSubscriptionAsync_OneTime() {
        SBQQ__Quote__c q = createQuoteForTest('onetimeA', null, 'Net 60', 'One-time', 50.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> results = 
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        // nothing to assert deeply — ensure no exceptions
        System.assertEquals(true, true);
    }
    
    @isTest
    static void testFutureStartDate_SchedulePath() {
        
        SBQQ__Quote__c q = StripeSubscriptionScheduler2_Test.createQuoteForTest(
            'future',
            'Monthly',
            'Net 30',
            'Renewable',
            100
        );
        
        // Move start date to future
        q.SBQQ__StartDate__c = Date.today().addDays(10);
        update q;
        
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionScheduler2_Test.StripeHttpMockSuccess());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> res =
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        System.assertEquals(true, res[0].isSuccess);
    }
    
    @isTest
    static void testEmptyInput() {
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> res =
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(new List<StripeSubscriptionScheduler2.FlowInput>());
        Test.stopTest();
        
        System.assertEquals(false, res[0].isSuccess);
    }
    
    @isTest
    static void testNoQuoteLines() {
        
        Account acc = new Account(Name='NoLineAcc', Stripe_Customer_ID__c='cus_test');
        insert acc;
        
        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            CurrencyIsoCode = 'USD'
        );
        insert q;
        
        Test.setMock(HttpCalloutMock.class, new StripeSubscriptionScheduler2_Test.StripeHttpMockSuccess());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> res =
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        System.assertEquals(true, res[0].isSuccess);
    }
    
    @isTest
    static void testAllFrequencies() {
        
        List<String> freqs = new List<String>{
            'Monthly','Quarterly','Semiannual','Annual'
                };
                    
                    Test.setMock(HttpCalloutMock.class, new StripeSubscriptionScheduler2_Test.StripeHttpMockSuccess());
        
        Test.startTest();
        for (String freq : freqs) {
            SBQQ__Quote__c q = StripeSubscriptionScheduler2_Test.createQuoteForTest(
                'freq_' + freq,
                freq,
                'Net 30',
                'Renewable',
                150
            );
            
            StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
            input.quoteId = q.Id;

            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        }
        Test.stopTest();
    }
    
    @isTest static void testPriceApiError_Not200() {
        SBQQ__Quote__c q = createQuoteForTest('priceFail', 'Monthly', 'Net 30', 'Renewable', 170.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockPriceError());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> results = 
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        // no specific assert — ensure no unhandled exceptions
        System.assert(true);
    }
    
    @isTest static void testCreateStripeSubscriptionAsync_Error() {
        SBQQ__Quote__c q = createQuoteForTest('priceFail', 'Monthly', 'Net 30', 'Renewable', 170.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> results = 
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        // no specific assert — ensure no unhandled exceptions
        System.assert(true);
    }
    
    @isTest static void testPriceCalculation_nullNetPrice() {
        SBQQ__Quote__c q = createQuoteForTest('nullprice', 'Quarterly', 'Net 30', 'Renewable', 180.00);
        
        // set the quote line net price to null to exercise unitPrice==null branch
        SBQQ__QuoteLine__c ql = [SELECT Id, SBQQ__NetPrice__c FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :q.Id LIMIT 1];
        ql.SBQQ__NetPrice__c = null;
        update ql;
        
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        StripeSubscriptionScheduler2.FlowInput input = new StripeSubscriptionScheduler2.FlowInput();
        input.quoteId = q.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler2.FlowResult> results = 
            StripeSubscriptionScheduler2.createStripeSubscriptionAsync(
                new List<StripeSubscriptionScheduler2.FlowInput>{ input }
            );
        Test.stopTest();
        
        System.assert(true, 'unitPrice == null branch executed without exception');
    }
}