@istest
public class RayShipmentConfirmStagingTriggerTest {
    @testSetup
    static void setup() {
        Account account = new Account();
        account.Name = 'Test';
        account.BillingCountry = 'United States';
        account.ShippingStreet  = 'Test';
        account.ShippingCountry = 'United States';
        account.ShippingPostalCode = 'Test';
        account.ShippingCity = 'Michigan';
        account.ShippingState = 'Michigan';
        insert account;
        
        Contact cont = new Contact();
        cont.accountId = account.id;
        cont.LastName = 'Test';
        cont.Email = 'Test@email.com';
        cont.Phone = '5657557768';
        insert cont;

        Product2 product = new Product2();
        product.Name = 'Test product name';
        product.IsActive = TRUE; 
        product.SBQQ__SubscriptionPricing__c = 'Fixed Price';
        product.SBQQ__SubscriptionTerm__c = 12;
        product.SBQQ__SubscriptionType__c = 'Renewable';
        product.F52_Core_Product_Name__c = 'V1';
        product.Business_Use_Case__c = 'Customer Experience';
        insert product;
        
        PricebookEntry pbEntry = new PricebookEntry();
        pbEntry.Pricebook2Id = Test.getStandardPricebookId();
        pbEntry.Product2Id = product.Id;
        pbEntry.UnitPrice = 100;
        pbEntry.IsActive = TRUE;
        insert pbEntry;

        
        Opportunity opportunity = new Opportunity();
        opportunity.AccountId = account.Id;
        opportunity.Name = 'Multiple2';
        opportunity.CloseDate = System.today();
        opportunity.StageName = 'Prospecting';
        opportunity.SBQQ__Ordered__c = true;
        insert opportunity;
        
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        quote.SBQQ__Account__c = account.Id;
        quote.SBQQ__PricebookId__c = Test.getStandardPricebookId();
        quote.SBQQ__Opportunity2__c = opportunity.Id;
        quote.SBQQ__StartDate__c = System.today();
        quote.SBQQ__Status__c = 'Approved';
        quote.ApprovalStatus__c = 'Approved';
        quote.SBQQ__SubscriptionTerm__c = 1; 
        quote.SBQQ__Primary__c = TRUE;
        quote.SBQQ__PrimaryContact__c =  cont.id;
        insert quote;
        
        
        SBQQ__QuoteLine__c line = new SBQQ__QuoteLine__c();
        line.SBQQ__Product__c = product.Id;
        line.SBQQ__Product__c = '01t6C0000029GlUQAU';
        line.SBQQ__Quote__c = quote.Id;
        line.SBQQ__PricebookEntryId__c = pbEntry.Id;
        line.SBQQ__DefaultSubscriptionTerm__c = 1;
        line.SBQQ__Quantity__c = 1;
        
        opportunity.Business_Use_Case__c = 'Workplace';
        opportunity.StageName = 'Closed Won';
        update opportunity;
        
        blng__BillingRule__c billingRule = new blng__BillingRule__c();
        billingRule.blng__Active__c = TRUE;
        billingRule.blng__GenerateInvoices__c = 'Yes';
        billingRule.blng__InitialBillingTrigger__c = 'Order Product Activation Date';
        billingRule.blng__AmendmentBillCycleDateAlignment__c = 'Do not align amended Order Product';
        billingRule.blng__GenerateInvoices__c = 'No';
        billingRule.blng__PartialPeriodTreatment__c = 'Separate';
        insert billingRule;
        
        blng__RevenueRecognitionRule__c recRule = new blng__RevenueRecognitionRule__c();
        recRule.blng__CreateRevenueSchedule__c = 'No';
        insert recRule;
        
        blng__TaxRule__c taxRule = new blng__TaxRule__c();
        taxRule.blng__Active__c = true;
        taxRule.blng__TaxableYesNo__c = 'No';
        
        insert taxRule;
        
        Id bRuleId = [SELECT id FROM blng__BillingRule__c].get(0).id;
        Id rRuleId = [SELECT id FROM blng__RevenueRecognitionRule__c].get(0).id;
        Id tRuleId = [SELECT id FROM blng__TaxRule__c].get(0).id;

        
        Order order = new Order();
        
        order.AccountId = account.Id;
        order.OpportunityId = opportunity.Id;
        order.SBQQ__Quote__c = quote.Id;
        order.blng__BillingDayOfMonth__c = '1';
        order.EffectiveDate = System.today();
        order.status = 'Draft';
        order.RAY_Ship_to_Account__c = account.id;
        order.RAY_Ship_to_Account__c = account.id;
        order.F52_Shipping_Option__c = 'GROUND SHIPPING';
        order.ShipToContactId = cont.id;
        
        insert order;
        System.debug('billingRule: ' + billingRule);        
        System.debug('blng__RevenueRecognitionRule__c: ' + recRule);
        System.debug('taxRule: ' + taxRule.id);

        OrderItem orderItem = new OrderItem();
        orderItem.SBQQ__Activated__c = false;
        //line.SBQQ__Product__c = '01t6C0000029GlUQAU';    
        orderItem.SBQQ__OrderedQuantity__c = 1;
        orderItem.F52_Shipped_Quantity__c = 0;
        orderItem.blng__BillingRule__c = 'a3K6C000000F9ksUAC';
        orderItem.blng__RevenueRecognitionRule__c = 'a446C000000Y9YdQAK';
        orderItem.blng__TaxRule__c = 'a4C6C000000ErenUAC';
        orderItem.OrderId = order.Id;
        orderItem.SBQQ__QuoteLine__c = line.Id;
        orderItem.PricebookEntryId = pbEntry.id;
        orderItem.SBQQ__ChargeType__c = 'Recurring';
        orderItem.SBQQ__BillingFrequency__c = 'Monthly';
        orderItem.SBQQ__BillingType__c = 'Advance';
        orderItem.UnitPrice = 10;
        orderItem.Quantity = 1;
        orderItem.is_Test__c = true;
        
        
        OrderItem orderItem2 = new OrderItem();
        orderItem2.SBQQ__Activated__c = false;
        orderItem2.SBQQ__OrderedQuantity__c = 1;
        orderItem2.F52_Shipped_Quantity__c = 0;
        orderItem2.blng__BillingRule__c = billingRule.Id;
        orderItem2.blng__RevenueRecognitionRule__c = recRule.Id;
        orderItem2.blng__TaxRule__c = taxRule.Id;
        orderItem2.OrderId = order.Id;
        orderItem2.SBQQ__QuoteLine__c = line.Id;
        orderItem2.PricebookEntryId = pbEntry.id;
        orderItem2.SBQQ__ChargeType__c = 'Recurring';
        orderItem2.SBQQ__BillingFrequency__c = 'Monthly';
        orderItem2.SBQQ__BillingType__c = 'Advance';
        orderItem2.UnitPrice = 100;
        orderItem2.is_Test__c = true;
        orderItem2.Quantity = 2;
        
        insert new List<OrderItem> {orderItem, orderItem2};
        
        Asset asset1 = new Asset();
        asset1.Name = 'Test1';
        asset1.Status = 'Shipped';
        asset1.SBQQ__OrderProduct__c = orderItem.Id;
        asset1.SerialNumber = 'Test';
        asset1.F52_Shipment_Tracking__c = 'Test';
        asset1.AccountId = account.id;
        asset1.ContactId = cont.id;
        
        Asset asset2 = new Asset();
        asset2.Name = 'Test2';
        asset2.Status = 'Shipped';
        asset2.SBQQ__OrderProduct__c = orderItem2.Id;
        asset2.SerialNumber = 'Test';
        asset2.F52_Shipment_Tracking__c = 'Test';
        asset2.AccountId = account.id;
        asset2.ContactId = cont.id;
            
		insert new List<Asset> {asset1, asset2};
            
    }
    
    @isTest
    static void test() {
        
     
        
        Ray_Shipment_Confirmation_Staging__c stag = new Ray_Shipment_Confirmation_Staging__c();
        stag.RAY_MAC_Address__c = '51';
        stag.RAY_Core_Product_Name__c = 'V1';
        stag.RAY_Order_Number_Text__c = 'CPQ00001';
        
        Test.startTest();
        insert stag;
        Test.stopTest();

        }
    
        @isTest
    static void test2() {
         OrderItem orderItem = [SELECT Id, OrderItemNumber, blng__TaxRule__c FROM OrderItem WHERE Quantity = 1 LIMIT 1];
         OrderItem orderItem2 = [SELECT Id, OrderItemNumber FROM OrderItem WHERE Quantity = 2 LIMIT 1];

        
        Ray_Shipment_Confirmation_Staging__c stag = new Ray_Shipment_Confirmation_Staging__c();
        Order ord = [SELECT id, OrderNumber FROM Order].get(0);
        stag.RAY_MAC_Address__c = '51';
        stag.RAY_Order_Number_Text__c = ord.OrderNumber;
        stag.RAY_Core_Product_Name__c = 'V1';
        
        Test.startTest();
        insert stag;
        stag.RAY_Order_Number_Text__c = ord.OrderNumber;
        update stag;
        Test.stopTest();
        
        System.debug('orderItem rule: ' + orderItem.blng__TaxRule__c);        

        }
    
        
//    @isTest
//     static void test3() {
//          OrderItem orderItem = [SELECT Id, OrderItemNumber FROM OrderItem WHERE Quantity = 1 LIMIT 1];
//          OrderItem orderItem2 = [SELECT Id, OrderItemNumber FROM OrderItem WHERE Quantity = 2 LIMIT 1];
//          Order ord = [SELECT id, OrderNumber FROM Order].get(0);


//         List<Ray_Shipment_Confirmation_Staging__c> rscs = new List<Ray_Shipment_Confirmation_Staging__c>();
        
//         Ray_Shipment_Confirmation_Staging__c stag = new Ray_Shipment_Confirmation_Staging__c();
//         stag.RAY_MAC_Address__c = '51';
//         stag.RAY_Order_Number_Text__c = ord.OrderNumber;
//         stag.RAY_Core_Product_Name__c = 'V1';
//         rscs.add(stag);
        
//          Ray_Shipment_Confirmation_Staging__c stag2 = new Ray_Shipment_Confirmation_Staging__c();
//         stag2.RAY_MAC_Address__c = '51';
//         stag2.RAY_Order_Number_Text__c = ord.OrderNumber;
//         stag2.RAY_Core_Product_Name__c = 'V1';
//         rscs.add(stag2);
        
//         Ray_Shipment_Confirmation_Staging__c stag3 = new Ray_Shipment_Confirmation_Staging__c();
//         stag3.RAY_MAC_Address__c = '51';
//         stag3.RAY_Order_Number_Text__c = ord.OrderNumber;
//         stag3.RAY_Core_Product_Name__c = 'V1';
//         rscs.add(stag3);
        
//         Test.startTest();
//         insert rscs;
//         insert stag3;
//         Test.stopTest();
        
//         }
}