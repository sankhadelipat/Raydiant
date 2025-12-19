@isTest
public class QuoteCalculateCallbackTest {

    @TestSetup
    static void setup() {
        
        TriggerHandler.bypass('AccountTriggerHandler');
        Account accVar = TestDataFactory.createTestAccount(false);
        accVar.Direction__c = 'Outbound';
        insert accVar;
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');

        Opportunity testOpp = TestDataFactory.createTestOpportunity(accVar.Id,false);
        testOpp.OwnerId = UserInfo.getUserId();
        insert testOpp;
        system.assertNotEquals(null, testOpp.Id, 'Opportunity Inserted');

        
    }
    
    static testMethod void testQuoteCallback() {
     
        Account accVar = [SELECT Id FROM Account LIMIT 1];
        
        Contact conVar = [SELECT Id FROM Contact LIMIT 1];
        
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, true);
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');
        
        QuoteModel theQuoteModel = new QuoteReader().read(testQuote.Id);
        
        Test.startTest();
        QuoteCalculator calculator = new QuoteCalculator();
        calculator.calculate(theQuoteModel, 'QuoteCalculateCallback');
        Test.stopTest();
        
    }
    
    static testMethod void testCloseOpportunity() {
     
        Account accVar = [SELECT Id FROM Account LIMIT 1];
        
        Contact conVar = [SELECT Id FROM Contact LIMIT 1];
        
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        SBQQ__Quote__c testQuote = TestDataFactory.createTestQuote(accVar.Id, conVar.Id, testOpp.Id, false);
        testQuote.SBQQ__ProrationDayOfMonth__c = '1';
        insert testQuote;
        system.assertNotEquals(null, testQuote.Id, 'Quote Inserted');
        
        blng__BillingRule__c billingRuleVar = TestDataFactory.createTestBillingRule(true);
        blng__RevenueRecognitionRule__c revRecRule = TestDataFactory.createTestRevRecRule(true);
        blng__TaxRule__c taxRuleVar = TestDataFactory.createTestTaxRule(true);
        
        //Insert Product
        Product2 testProd = TestDataFactory.createTestProduct('Test Product', 'PC-000000', false);
        testProd.Business_Use_Case__c = 'Customer Experience';
        testProd.Display_on_Marketplace__c = true;
        testProd.Grant_Scope_ID__c = 'testScope';
        testProd.SBQQ__ChargeType__c = 'One-Time';
        testProd.blng__BillingRule__c = billingRuleVar.Id;
        testProd.blng__RevenueRecognitionRule__c = revRecRule.Id;
        testProd.blng__TaxRule__c = taxRuleVar.Id;
        insert testProd;
        system.assertNotEquals(null, testProd.Id, 'Product Inserted');

        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;

        PricebookEntry pbe = TestDataFactory.createTestPriceBookEntry(testProd.Id, standardPricebook.Id, true);
        system.assertNotEquals(null, pbe.Id, 'PricebookEntry Inserted');
        
        SBQQ__QuoteLine__c testQuoteLine = TestDataFactory.createTestQuoteLine(testProd, pbe.Id, testQuote.Id, true);
        
        Test.startTest();
        QuoteCalculateCallback.closeOpportunity(testOpp.Id);
        Test.stopTest();
        
        Order orderVar = [SELECT Id FROM Order LIMIT 1];
        system.assertNotEquals(null, orderVar.Id, 'Order created');
        
    }
}