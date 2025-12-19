@isTest
public class StripeSubscriptionMigration_Test {
    
    // --- MOCK: Successful Stripe subscription creation ---
    public class MockStripeResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{' +
                '"id":"sub_test_1234",' +
                '"object":"subscription",' +
                '"customer":"cus_test_1234",' +
                '"billing_cycle_anchor":1760140800,' +
                '"created":1757604547,' +
                '"items":{"object":"list","data":[{' +
                    '"id":"si_test_1234",' +
                    '"price":{"id":"pi_test_1234","product":"pr_test_1234","unit_amount":2900,"unit_amount_decimal":"2900","recurring":{"interval":"month","interval_count":1},"active":true},' +
                    '"quantity":1,' +
                    '"current_period_start":1757548800,' +
                    '"current_period_end":1760140800' +
                '}],"has_more":false},' +
                '"latest_invoice":null,' +
                '"livemode":false,' +
                '"metadata":{"subscription_source":"salesforceformigration","salesforce_Conatrct_id":"8001I000001Si1VQAS"},' +
                '"status":"active",' +
                '"start_date":1623567600' +
                '}'
            );
            return res;
        }
    }
    
    // Common data setup used by both tests
    @TestSetup
    static void setupData() {
        Stripe_Details__c sd = new Stripe_Details__c(Name = 'Stripe Details', Serect_Key__c = 'sk_test_abc123');
        insert sd;

        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TPR001',
            IsActive = true,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionType__c = 'Renewable',
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            Stripe_Product_ID__c = 'pr_test_1234',
            Stripe_Price_ID__c = 'pi_test_1234'
        );
        insert prod;

        Account acc = new Account(Name = 'Test Account', Stripe_Customer_ID__c = 'cus_test_1234');
        insert acc;

        Id standardPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            Type = 'New',
            CloseDate = Date.today(),
            StageName = 'Prospecting'
        );
        insert opp;

        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c = Date.today().addMonths(12),
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = prod.Id,
          //  SBQQ__ChargeType__c = 'Recurring',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100,
            SBQQ__NetPrice__c = 100,
            Stripe_Price_ID__c = 'pi_test_1234'
        );
        insert ql;

        // Evergreen contract (true branch)
        Contract evergreen = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            SBQQ__Quote__c = quote.Id,
            StartDate = Date.today().addMonths(-1),
            // EndDate = Date.today().addMonths(11),
            ContractTerm = 12,
            //Stripe_Billing_Date__c = Date.today().addDays(5),
            Stripe_Subscription_ID__c = null,
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c,
            SBQQ__Evergreen__c = true,
            Current_Migration_Start_Date__c = Date.today().addMonths(-1),
            Current_Migration_End_Date__c = Date.today().addMonths(10),
            Contract_Migration__c =false,
            Is_Migrating__c = true
        );
        insert evergreen;
        
        evergreen.Status = 'Activated';
        update evergreen;
        
        SBQQ__Subscription__c newSub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = evergreen.Id,
            SBQQ__Account__c = acc.Id,
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 1,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__Product__c = prod.Id,
            Stripe_Subscription_Migration__c = true,
            Stripe_Price_ID__c = 'pi_test_1234',
            Stripe_Product_ID__c = 'pr_test_1234',
            CurrencyIsoCode = 'USD'
        );
        insert newSub;

        // Non-Evergreen contract (false branch)
        Contract nonEver = new Contract(
            AccountId = acc.Id,
            SBQQ__Quote__c = quote.Id,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(30),
            ContractTerm = 1,
            Stripe_Billing_Date__c = Date.today().addDays(5),
            Stripe_Subscription_ID__c = null,
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c,
            SBQQ__Evergreen__c = false,
            Current_Migration_Start_Date__c = Date.today().addMonths(-1),
            Current_Migration_End_Date__c = Date.today().addDays(30),
            Contract_Migration__c =false,
            Is_Migrating__c = true
        );
        insert nonEver;
        
        nonEver.Status = 'Activated';
        update nonEver;

        SBQQ__Subscription__c existingSub = new SBQQ__Subscription__c(
            SBQQ__Contract__c = nonEver.Id,
            SBQQ__Account__c = acc.Id,
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__Quantity__c = 1,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__Product__c = prod.Id,
            Stripe_Subscription_Migration__c = true,
            Stripe_Price_ID__c = 'pi_test_1234',
            Stripe_Product_ID__c = 'pr_test_1234',
            CurrencyIsoCode = 'USD'
        );
        insert existingSub;
    }

    // --- TEST 1: Evergreen scenario (true branch) ---
    @isTest
    static void testEvergreenContractScenario() {
        Test.setMock(HttpCalloutMock.class, new MockStripeResponse());
        Contract con = [SELECT Id FROM Contract WHERE SBQQ__Evergreen__c = true LIMIT 1];
        SBQQ__Subscription__c sub = [SELECT Id, F52_Active__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c = :con.Id LIMIT 1];
        System.assert(sub.F52_Active__c, 'Subscription is not active'); // temporary check
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
    }

    // --- TEST 2: Non-Evergreen scenario (false branch) ---
    @isTest
    static void testNonEvergreenContractScenario() {
        Test.setMock(HttpCalloutMock.class, new MockStripeResponse());
        Contract con = [SELECT Id FROM Contract WHERE SBQQ__Evergreen__c = false LIMIT 1];
        SBQQ__Subscription__c sub = [SELECT Id, F52_Active__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c = :con.Id LIMIT 1];
        System.assert(sub.F52_Active__c, 'Subscription is not active'); // temporary check
        Test.startTest();
        Database.executeBatch(new StripeSubscriptionMigration(), 5);
        Test.stopTest();
    }
}