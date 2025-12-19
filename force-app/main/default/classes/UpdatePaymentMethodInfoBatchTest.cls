@IsTest
private class UpdatePaymentMethodInfoBatchTest {
	private class DNUBatch implements Database.BatchableContext{
        private ID job,childJob;
        public DNUBatch(ID job,ID childJob){
            this.job=job;
            this.childJob=childJob;
        }
        public ID getChildJobID(){
            return childJob;
        }
        public ID getJobID(){
            return job;
        }
    }
    @IsTest
    static void updatePaymentMethodBatchTest() {
        //Create Data
        Account objAccount = new Account(
        	Name = 'Test Account'
        );
        insert objAccount;
        blng__PaymentMethod__c objPM1 = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        blng__PaymentMethod__c objPM2 = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        blng__PaymentMethod__c objPM3 = new blng__PaymentMethod__c(
        	blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card'
        );
        insert new List<blng__PaymentMethod__c> {
            objPM1, objPM2, objPM3
        };
        objAccount.F52_Payment_Method_Auto_Pay__c = objPM1.Id;
        update objAccount;
		blng__PaymentMethod__c objPM4 = new blng__PaymentMethod__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card',
            F52_Old_Payment_Id__c = String.valueOf(objPM1.Id),
            F52_Is_Processed__c = false
        );
        blng__PaymentMethod__c objPM5 = new blng__PaymentMethod__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card',
            F52_Old_Payment_Id__c = String.valueOf(objPM2.Id),
            F52_Is_Processed__c = false
        );
        blng__PaymentMethod__c objPM6 = new blng__PaymentMethod__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentType__c = 'Debit Card',
            F52_Old_Payment_Id__c = String.valueOf(objPM3.Id),
            F52_Is_Processed__c = false
        );
        List<blng__PaymentMethod__c> listPmToUpdate = new List<blng__PaymentMethod__c> {
            objPM4, objPM5, objPM6
		};
        insert listPmToUpdate;
        SBQQ__Quote__c objQuote1 = new SBQQ__Quote__c(
            SBQQ__Account__c = objAccount.Id,
        	F52_Payment_Method__c = objPM1.Id
        );
        SBQQ__Quote__c objQuote2 = new SBQQ__Quote__c(
            SBQQ__Account__c = objAccount.Id,
        	F52_Payment_Method__c = objPM2.Id
        );
        SBQQ__Quote__c objQuote3 = new SBQQ__Quote__c(
            SBQQ__Account__c = objAccount.Id,
        	F52_Payment_Method__c = objPM3.Id
        );
        insert new List<SBQQ__Quote__c> {
            objQuote1, objQuote2, objQuote3
        };
            
        blng__Invoice__c objInvoice1 = new blng__Invoice__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentMethod__c = objPM1.Id
        );
        blng__Invoice__c objInvoice2 = new blng__Invoice__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentMethod__c = objPM2.Id
        );
        blng__Invoice__c objInvoice3 = new blng__Invoice__c(
            blng__Account__c = objAccount.Id,
            blng__PaymentMethod__c = objPM3.Id
        );
        insert new List<blng__Invoice__c> {
            objInvoice1, objInvoice2, objInvoice3
        };
            
        blng__GLRule__c objGlRule = new blng__GLRule__c(
        	Name = 'Test'
        );
        insert objGlRule;
        
        blng__BillingRule__c objBillingRule = new blng__BillingRule__c(
        	Name = 'Billing Rule',
            blng__GenerateInvoices__c = 'Yes',
            blng__InitialBillingTrigger__c = 'Order Product Activation Date	'
        );
        insert objBillingRule;
        
        blng__RevenueRecognitionRule__c objRRR = new blng__RevenueRecognitionRule__c(
        	Name = 'Test',
            blng__Active__c = true,
            blng__CreateRevenueSchedule__c = 'Yes'
        );
        insert objRRR;
        
        blng__TaxRule__c objTaxRule = new blng__TaxRule__c(
        	Name = 'TaxRule1',
            blng__TaxableYesNo__c = 'Yes',
            blng__Active__c = true
        );
        insert objTaxRule;

        Order objOrder = new Order(
        	AccountId = objAccount.Id,
            EffectiveDate = Date.today(),
            blng__BillingDayOfMonth__c = '1',
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert objOrder;
        Product2 objP = new Product2(
        	Name = 'TestP',
            Business_Use_Case__c = 'Customer Experience'
        );
        insert objP;
        
        PricebookEntry objPBE = new PricebookEntry(
        	Product2Id = objP.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            IsActive = true,
            UnitPrice = 10
        );
        insert objPBE;
        
        OrderItem objOrder1 = new OrderItem(
            RAY_Payment_Method__c = objPM1.Id,
            blng__BillingGLRule__c = objGlRule.Id,
            blng__BillingRule__c = objBillingRule.Id,
            blng__RevenueRecognitionRule__c = objRRR.Id,
            blng__TaxRule__c = objTaxRule.Id,
            OrderId = objOrder.Id,
            PricebookEntryId = objPBE.Id,
            SBQQ__ChargeType__c = 'One-Time',
            UnitPrice = 100,
            is_Test__c = true,
            Quantity = 1
        );
        OrderItem objOrder2 = new OrderItem(
            RAY_Payment_Method__c = objPM2.Id,
            blng__BillingGLRule__c = objGlRule.Id,
            blng__BillingRule__c = objBillingRule.Id,
            blng__RevenueRecognitionRule__c = objRRR.Id,
            blng__TaxRule__c = objTaxRule.Id,
            OrderId = objOrder.Id,
            PricebookEntryId = objPBE.Id,
            SBQQ__ChargeType__c = 'One-Time',
            UnitPrice = 100,
            is_Test__c = true,
            Quantity = 1
        );
        OrderItem objOrder3 = new OrderItem(
            RAY_Payment_Method__c = objPM3.Id,
            blng__BillingGLRule__c = objGlRule.Id,
            blng__BillingRule__c = objBillingRule.Id,
            blng__RevenueRecognitionRule__c = objRRR.Id,
            blng__TaxRule__c = objTaxRule.Id,
            OrderId = objOrder.Id,
            PricebookEntryId = objPBE.Id,
            SBQQ__ChargeType__c = 'One-Time',
            UnitPrice = 100,
            is_Test__c = true,
            Quantity = 1
        );
        insert new List<OrderItem> {
            objOrder1, objOrder2, objOrder3
        };
            
        Contract objContract1 = new Contract(
        	AccountId = objAccount.Id,
            Ray_Payment_Method__c = objPM1.Id,
            Status = 'Draft',
            SBQQ__Quote__c = objQuote1.Id
        );
        Contract objContract2 = new Contract(
        	AccountId = objAccount.Id,
            Ray_Payment_Method__c = objPM2.Id,
            Status = 'Draft',
            SBQQ__Quote__c = objQuote2.Id
        );
        Contract objContract3 = new Contract(
        	AccountId = objAccount.Id,
            Ray_Payment_Method__c = objPM3.Id,
            Status = 'Draft',
            SBQQ__Quote__c = objQuote3.Id
        );
        insert new List<Contract> {
            objContract1, objContract2, objContract3
        };
         
        Test.startTest();
        UpdatePaymentMethodInfoBatch objUpdatePaymentMethodInfoBatch = new UpdatePaymentMethodInfoBatch();
        objUpdatePaymentMethodInfoBatch.execute(new DNUBatch(objContract1.Id, objContract1.Id), listPmToUpdate);
        Test.stopTest();
    }
    
    @IsTest
    static void testBatch() {
        Test.startTest();
        Database.executeBatch(new UpdatePaymentMethodInfoBatch());
        Test.stopTest();
    }
}