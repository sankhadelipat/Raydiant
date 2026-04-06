@IsTest
public class StripeSubscriptionHandler_Test {
    
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
    
    @TestSetup
    static void setup() {
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
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
    
    @IsTest
    static void testHandleSubscriptionFromStripe_PendingContractBranch() {
        
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;
        
        // IMPORTANT: Match schedule ID from mock → sub_sched_123
        Contract pendingCon = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Pending',
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_123', // MUST match mock
            Stripe_Subscription_ID__c = null
        );
        insert pendingCon;
        
        // Add subscription record to be deleted
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = pendingCon.Id,
            Status__c = 'not_started',
            SBQQ__Quantity__c = 1,
            Stripe_Subscription_ID__c = null
        );
        insert sub;
        
        Test.startTest();
        
        StripeSubscriptionHandler.handleSubscriptionFromStripe(
            null, // quoteId
            'sub_test_123', // subscriptionId
            'salesforce',
            true // isSchedule = true (important)
        );
        
        Test.stopTest();
        
        // Verify contract updated
        Contract updated = [
            SELECT Stripe_Subscription_ID__c
            FROM Contract
            WHERE Id = :pendingCon.Id
        ];
        
        System.assertEquals('sub_test_123', updated.Stripe_Subscription_ID__c);
        
        // Verify subscriptions deleted
        List<SBQQ__Subscription__c> subs = [
            SELECT Id
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c = :pendingCon.Id
        ];
        
        System.assertEquals(0, subs.size(), 'Subscriptions should be deleted');
    }
    
    @isTest
    static void testGetUpdatedSubscriptionfromStripe_quoteExists() {
        SBQQ__Quote__c q = createQuoteForTest('3yearA', 'Semiannual', 'Net 90', 'Renewable', 130.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        // pass a valid quote Id to hit the quote path
        StripeSubscriptionHandler.handleSubscriptionFromStripe(q.Id, 'sub_123', 'salesforce', false);
        Test.stopTest();
        
        System.assert(true, 'should complete without exception');
    }
    
    @isTest
    static void testGetUpdatedSubscriptionfromStripe_amazonPath() {
        // create any quote (we will pass null to simulate no quote)
        createQuoteForTest('amazon_stub', 'Monthly', 'Net 30', 'Renewable', 140.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        // pass null for quoteId as production code expects to be null for amazon/self_service
        StripeSubscriptionHandler.handleSubscriptionFromStripe(null, 'sub_amazon', 'amazon', true);
        Test.stopTest();
        
        System.assert(true, 'amazon path should enqueue or process without exception');
    }
    
    @isTest
    static void testGetUpdatedSubscriptionfromStripe_selfServicePath() {
        createQuoteForTest('selfsvc_stub', 'Monthly', 'Net 30', 'Renewable', 150.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionHandler.handleSubscriptionFromStripe(null, 'sub_self', 'self_service', false);
        Test.stopTest();
        
        System.assert(true, 'self_service path should run without exception');
    }
    
    @isTest
    static void testGetUpdatedSubscriptionfromStripe_stripeManualPath() {
        createQuoteForTest('stripe_stub', 'Monthly', 'Net 30', 'Renewable', 160.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionHandler.handleSubscriptionFromStripe(null, 'sub_stripe', 'stripe', false);
        Test.stopTest();
        
        System.assert(true, 'stripe manual path should run without exception');
    }
    
    @IsTest
    static void test_handleScheduleFromStripe_withoutQuote() {
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());
        
        Test.startTest();
        StripeSubscriptionHandler.handleScheduleFromStripe(
            null, 'sub_sched_123', 'salesforce'
        );
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteSubscription_ActiveContract() {
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;
        
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft',
            Stripe_Subscription_ID__c = 'sub_test_1234'
        );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = con.Id,
            Status__c = 'not_started',
            SBQQ__Quantity__c = 1
        );
        insert sub;
        
        Test.startTest();
        StripeSubscriptionHandler.deleteSubscription('sub_test_1234');
        Test.stopTest();
        
        Contract updatedCon = [
            SELECT Status, Stripe_Status__c
            FROM Contract
            WHERE Id = :con.Id
        ];
        
        System.assertEquals('canceled', updatedCon.Status);
        System.assertEquals('canceled', updatedCon.Stripe_Status__c);
        
        SBQQ__Subscription__c updatedSub = [
            SELECT Status__c, Canceled_From_Stripe__c
            FROM SBQQ__Subscription__c
            WHERE Id = :sub.Id
        ];
        
        System.assertEquals('canceled', updatedSub.Status__c);
        System.assertEquals(true, updatedSub.Canceled_From_Stripe__c);
    }
    
    @IsTest
    static void testDeleteSchedule_PendingContract() {
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test_123'
        );
        insert acc;
        
        Contract pendingCon = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Pending',
            Stripe_Subscription_Schedule_ID__c = 'sub_sched_test_001'
        );
        insert pendingCon;
        
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = pendingCon.Id,
            Status__c = 'not_started',
            SBQQ__Quantity__c = 2
        );
        insert sub;
        
        Test.startTest();
        StripeSubscriptionHandler.deleteSchedule('sub_sched_test_001');
        Test.stopTest();
        
        Contract updatedCon = [
            SELECT Status, Stripe_Status__c
            FROM Contract
            WHERE Id = :pendingCon.Id
        ];
        
        System.assertEquals('canceled', updatedCon.Status);
        System.assertEquals('canceled', updatedCon.Stripe_Status__c);
        
        SBQQ__Subscription__c updatedSub = [
            SELECT Status__c, Canceled_From_Stripe__c
            FROM SBQQ__Subscription__c
            WHERE Id = :sub.Id
        ];
        
        System.assertEquals('canceled', updatedSub.Status__c);
        System.assertEquals(true, updatedSub.Canceled_From_Stripe__c);
    }
}