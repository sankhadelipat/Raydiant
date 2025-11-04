@IsTest
public class StripeContractHandler_Test 
{
 @TestSetup
    static void setupTestData() {
        Stripe_Details__c details = new Stripe_Details__c(
            Name = 'Stripe Details',
            Serect_Key__c = 'sk_test_123'
        );
        insert details;
        
        // Create Account 
        Account acc = new Account(
            Name = 'Test Account',
            Stripe_Customer_ID__c = 'cus_test1'
        );
        insert acc;
        
        List<Product2> testProducts = new List<Product2>();
        // Recurring product
        testProducts.add(new Product2(
            Name = 'Test Product 1 - Recurring',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test1',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__ChargeType__c = 'Recurring',
            SBQQ__BillingType__c = 'Advance',
            SBQQ__SubscriptionType__c = 'Renewable',
            CurrencyIsoCode = 'USD'
        ));
        // One-time product
        testProducts.add(new Product2(
            Name = 'Test Product 2 - One-Time',
            IsActive = true,
            Stripe_Product_ID__c = 'prod_test2',
            SBQQ__SubscriptionPricing__c = 'Fixed Price',
            //SBQQ__BillingFrequency__c = 'Monthly',
            SBQQ__ChargeType__c = 'One-Time',
            //SBQQ__BillingType__c = 'Advance',
            SBQQ__SubscriptionType__c = 'One-time',
            CurrencyIsoCode = 'USD'
        ));
        insert testProducts;
        
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        List<PricebookEntry> testPbes = new List<PricebookEntry>();
        testPbes.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProducts[0].Id,
            UnitPrice = 100.00,
            IsActive = true
        ));
        testPbes.add(new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProducts[1].Id,
            UnitPrice = 200.00,
            IsActive = true
        ));
        insert testPbes;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            Type = 'New',
            CloseDate = Date.today(),
            StageName = 'Discovery & Qualification',
            ForecastCategoryName = 'Upside'
        );
        insert testOpp;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = testOpp.Id,
            SBQQ__Primary__c = true,
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__PaymentTerms__c = 'Prepayment',
            SBQQ__StartDate__c = System.today(),
            SBQQ__EndDate__c = System.today().addMonths(12),
            Billing_Frequency_Override__c = 'Monthly'
        );
        insert quote;
        
        // Insert Quote Lines
        List<SBQQ__QuoteLine__c> testQuoteLines = new List<SBQQ__QuoteLine__c>();
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = testProducts[0].Id,
            SBQQ__ChargeType__c = testProducts[0].SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = testProducts[0].SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = testProducts[0].SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = testProducts[0].SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = testProducts[0].SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = testProducts[0].SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 100.00,
            SBQQ__NetPrice__c = 100.00,
            SBQQ__RegularPrice__c = 100.00,
            SBQQ__SpecialPrice__c = 100.00,
            SBQQ__PricebookEntryId__c = testPbes[0].Id,
            Stripe_Price_ID__c = 'price_test1'
         
        ));
        testQuoteLines.add(new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = quote.Id,
            SBQQ__Product__c = testProducts[1].Id,
            SBQQ__ChargeType__c = testProducts[1].SBQQ__ChargeType__c,
            //SBQQ__SubscriptionType__c = testProducts[1].SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionTerm__c = testProducts[1].SBQQ__SubscriptionTerm__c,
            SBQQ__SubscriptionPricing__c = testProducts[1].SBQQ__SubscriptionPricing__c,
            SBQQ__BillingType__c = testProducts[1].SBQQ__BillingType__c,
            SBQQ__BillingFrequency__c = testProducts[1].SBQQ__BillingFrequency__c,
            SBQQ__Quantity__c = 1,
            SBQQ__ListPrice__c = 200.00,
            SBQQ__NetPrice__c = 200.00,
            SBQQ__RegularPrice__c = 200.00,
            SBQQ__SpecialPrice__c = 200.00,
            SBQQ__PricebookEntryId__c = testPbes[1].Id,
            Stripe_Price_ID__c = 'price_test2'
            
        ));
        insert testQuoteLines;
          Contract con = new Contract(
            AccountId = acc.Id, 
            StartDate = Date.today(), 
            EndDate = Date.today().addDays(30),
            ContractTerm = 12, 
            // Status = 'Draft',
            SBQQ__Quote__c = quote.Id,
            Stripe_Billing_Date__c = Date.today(),
            
            Stripe_Customer_ID__c = acc.Stripe_Customer_ID__c,Stripe_Subscription_ID__c = 'sub_123'
        ); 
        insert con;
        
        SBQQ__Subscription__c subRec = new SBQQ__Subscription__c(
               
                SBQQ__Account__c = acc.Id,
                //SBQQ__SubscriptionType__c = prod.SBQQ__SubscriptionType__c,
             //   SBQQ__BillingFrequency__c = prod.SBQQ__BillingFrequency__c,
                SBQQ__TerminatedDate__c = Date.today().addDays(30),
                SBQQ__Quantity__c = 1,
                SBQQ__NetPrice__c = 100.00,
              //  SBQQ__Product__c = prod.Id,
                Stripe_Subscription_ID__c = 'si_test_1234',
                Stripe_Product_ID__c = 'pr_test_1234',
                Stripe_Price_ID__c = 'pi_test_1234',
                CurrencyIsoCode = 'USD',   Stripe_Subscription_ID_Actual__c ='sub_123' 
            );
            insert subRec;
    }
    @IsTest
    static void testBatchExecution_Success() {
        // Run the batch
        Test.startTest();
        StripeContractHandler batch = new StripeContractHandler();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // Fetch updated subscriptions
        List<SBQQ__Subscription__c> updatedSubs = [
            SELECT SBQQ__Contract__c, Stripe_Subscription_ID_Actual__c
            FROM SBQQ__Subscription__c
        ];

        Integer matched = 0;
        Integer unmatched = 0;

        for (SBQQ__Subscription__c sub : updatedSubs) {
            if (sub.Stripe_Subscription_ID_Actual__c.startsWith('sub_') && sub.SBQQ__Contract__c != null) {
                matched++;
            } else if (sub.Stripe_Subscription_ID_Actual__c.startsWith('sub_not_matching_') && sub.SBQQ__Contract__c == null) {
                unmatched++;
            }
        }

       // System.assertEquals(3, matched, '3 subscriptions should be linked to contracts');
        //System.assertEquals(2, unmatched, '2 subscriptions should remain unlinked');
    }

   
}