@IsTest
public class StripeCheckoutHandler_Test {
    
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
    static void testCreateStripeSubscription_HappyPath() {
        SBQQ__Quote__c q = createQuoteForTest('monthlyA', 'Monthly', 'Net 30', 'Renewable', 100.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockSuccess());

        Test.startTest();
        System.enqueueJob(new StripeCheckoutHandler(q.Id, 'sub_123'));
        Test.stopTest();
    }

    @isTest
    static void testCreateStripeSubscription_ErrorPath() {
        SBQQ__Quote__c q = createQuoteForTest('quarterlyA', 'Quarterly', 'Prepayment', 'Renewable', 110.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());

        Test.startTest();
        System.enqueueJob(new StripeCheckoutHandler(q.Id, 'sub_err_1'));
        Test.stopTest();

        Integer logCount = [SELECT COUNT() FROM Logger__c];
        System.assert(logCount > 0, 'Logger__c should have entries when error occurs');
    }
    
    @isTest
    static void testCreateStripeSubscription_ErrorPath_variation() {
        SBQQ__Quote__c q = createQuoteForTest('annualA', 'Annual', 'Monthly', 'Renewable', 120.00);
        Test.setMock(HttpCalloutMock.class, new StripeHttpMockError());

        Test.startTest();
        System.enqueueJob(new StripeCheckoutHandler(q.Id, 'sub_err_2'));
        Test.stopTest();

        Integer logCount = [SELECT COUNT() FROM Logger__c];
        System.assert(logCount > 0, 'Logger__c should have entries when error occurs');
    }
}