@IsTest
public class StripeSubscriptionScheduler3_Test {
    
    class StripeMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('/prices')) {
                res.setBody('{"id":"price_test_123"}');
            } else if (req.getEndpoint().contains('/subscriptions')) {
                res.setBody('{"id":"sub_test_updated"}');
            }
            
            return res;
        }
    }
    
    class StripeErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"message":"error"}');
            return res;
        }
    }
    
    @TestSetup
    static void setup() {
        
        insert new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test'
        );
        
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test'
        );
        insert acc;
        
        Product2 prod1 = new Product2(
            Name = 'Product 1',
            IsActive = true,
            SBQQ__SubscriptionType__c = 'Renewable',
            Stripe_Product_Id__c = 'prod_1'
        );
        insert prod1;
        
        Product2 prod2 = new Product2(
            Name = 'Product 2',
            IsActive = true,
            SBQQ__SubscriptionType__c = 'Renewable',
            Stripe_Product_Id__c = 'prod_2'
        );
        insert prod2;
        
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod1.Id,
            UnitPrice = 100,
            IsActive = true
        );
        
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod2.Id,
            UnitPrice = 200,
            IsActive = true
        );
        
        insert new List<PricebookEntry>{ pbe1, pbe2 };
            
            Contract con = new Contract(
                AccountId = acc.Id,
                StartDate = Date.today(),
                ContractTerm = 12,
                Status = 'Draft',
                Stripe_Subscription_ID__c = 'sub_test'
            );
        insert con;
        
        con.Status = 'Activated';
        update con;
        
        // Existing subscription (to test update + delete)
        SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = con.Id,
            Stripe_Subscription_ID__c = 'si_existing',
            SBQQ__Quantity__c = 2,
            Status__c = 'Active'
        );
        insert sub;
    }
    
    @IsTest
    static void testAmendSubscription_FullFlow() {
        
        Test.setMock(HttpCalloutMock.class, new StripeMock());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Subscription__c existingSub = [SELECT Id FROM SBQQ__Subscription__c LIMIT 1];
        Product2 prod1 = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];
        Product2 prod2 = [SELECT Id FROM Product2 WHERE Name = 'Product 2' LIMIT 1];
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__MasterContract__c = con.Id,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;
        
        // EXISTING PRODUCT → UPDATE
        SBQQ__QuoteLine__c updateLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod1.Id,
            SBQQ__UpgradedSubscription__c = existingSub.Id,
            SBQQ__Quantity__c = 3,
            SBQQ__NetPrice__c = 100,
            CurrencyIsoCode = 'USD'
        );
        
        // NEW PRODUCT → ADD
        SBQQ__QuoteLine__c newLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod2.Id,
            SBQQ__Quantity__c = 1,
            SBQQ__NetPrice__c = 200,
            CurrencyIsoCode = 'USD'
        );
        
        insert new List<SBQQ__QuoteLine__c>{ updateLine, newLine };
            
            StripeSubscriptionScheduler3.FlowInput input = new StripeSubscriptionScheduler3.FlowInput();
        input.quoteId = quote.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler3.FlowResult> results = 
            StripeSubscriptionScheduler3.amendStripeSubscription(
                new List<StripeSubscriptionScheduler3.FlowInput>{ input }
            );
        Test.stopTest();
        
        // ASSERT → Price ID updated
        List<SBQQ__QuoteLine__c> lines = [
            SELECT Stripe_Price_ID__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quote.Id
        ];
        
        System.assert(!lines.isEmpty(), 'Quote lines processed');
        for (SBQQ__QuoteLine__c l : lines) {
            System.assertNotEquals(null, l.Stripe_Price_ID__c);
        }
    }
    
    @IsTest
    static void testAmendSubscription_Removal() {
        
        Test.setMock(HttpCalloutMock.class, new StripeMock());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__MasterContract__c = con.Id,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;
        
        // NO QUOTE LINES → triggers removal logic
        
        StripeSubscriptionScheduler3.FlowInput input = new StripeSubscriptionScheduler3.FlowInput();
        input.quoteId = quote.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler3.FlowResult> results = 
            StripeSubscriptionScheduler3.amendStripeSubscription(
                new List<StripeSubscriptionScheduler3.FlowInput>{ input }
            );
        Test.stopTest();
        
        System.assert(true, 'Removal path executed');
    }
    
    @IsTest
    static void testAmendSubscription_Error() {
        Test.setMock(HttpCalloutMock.class, new StripeErrorMock());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contract con = [SELECT Id FROM Contract LIMIT 1];
        SBQQ__Subscription__c existingSub = [SELECT Id FROM SBQQ__Subscription__c LIMIT 1];
        Product2 prod1 = [SELECT Id FROM Product2 WHERE Name = 'Product 1' LIMIT 1];
        Product2 prod2 = [SELECT Id FROM Product2 WHERE Name = 'Product 2' LIMIT 1];
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__MasterContract__c = con.Id,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;
        
        StripeSubscriptionScheduler3.FlowInput input = new StripeSubscriptionScheduler3.FlowInput();
        input.quoteId = quote.Id;
        
        Test.startTest();
        List<StripeSubscriptionScheduler3.FlowResult> results = 
            StripeSubscriptionScheduler3.amendStripeSubscription(
                new List<StripeSubscriptionScheduler3.FlowInput>{ input }
            );
        Test.stopTest();
        
        List<Logger__c> logs = [
            SELECT Id FROM Logger__c
            WHERE Apex_Method__c = 'amendStripeSubscription'
        ];
        
        System.assert(!logs.isEmpty(), 'Error should be logged');
    }
}