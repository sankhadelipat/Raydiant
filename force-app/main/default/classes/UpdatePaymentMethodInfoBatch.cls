global class UpdatePaymentMethodInfoBatch implements Database.Batchable<SObject> {
	global Database.QueryLocator start(Database.BatchableContext BC){
        List<User> listUsers = [SELECT Id FROM User WHERE Name = 'Update Payment Method Site Guest User'];
       	return Database.getQueryLocator([SELECT Id, F52_Old_Payment_Id__c FROM blng__PaymentMethod__c WHERE F52_Old_Payment_Id__c != null and CreatedDate = TODAY AND CreatedById =: listUsers[0].Id AND F52_Is_Processed__c = false ORDER BY CreatedDate]);
   	}

   	global void execute(Database.BatchableContext BC, List<blng__PaymentMethod__c> listPaymentMethod){        
        Map<String, String> mapOldPaymentMethodId_NewId = new Map<String, String>();
        for(blng__PaymentMethod__c eachPM : listPaymentMethod) {
            mapOldPaymentMethodId_NewId.put(eachPM.F52_Old_Payment_Id__c, eachPM.Id);
            eachPM.F52_Is_Processed__c = true;
        }
        
        //Update Quotes
        List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();
        for(SBQQ__Quote__c eachQuote: [select Id, F52_Payment_Method__c from SBQQ__Quote__c  WHERE F52_Payment_Method__c IN: mapOldPaymentMethodId_NewId.keySet()]) {
            eachQuote.F52_Payment_Method__c = mapOldPaymentMethodId_NewId.get(eachQuote.F52_Payment_Method__c);
            quotesToUpdate.add(eachQuote);
        }
        if(!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;   
        }
        
        //Update Invoices
        List<blng__Invoice__c> listInvoices = new List<blng__Invoice__c>();
        for(blng__Invoice__c eachInvoice : [SELECT Id, blng__PaymentMethod__c FROM blng__Invoice__c WHERE blng__PaymentMethod__c IN: mapOldPaymentMethodId_NewId.keySet()]) {
            eachInvoice.blng__PaymentMethod__c = mapOldPaymentMethodId_NewId.get(eachInvoice.blng__PaymentMethod__c);
            listInvoices.add(eachInvoice);
        }
        if(!listInvoices.isEmpty()) {
            update listInvoices;
        }
        
        //Update Order Products
        List<OrderItem> listOrderItem = new List<OrderItem>();
        for(OrderItem eachOrderItem : [SELECT Id, RAY_Payment_Method__c FROM OrderItem WHERE RAY_Payment_Method__c IN: mapOldPaymentMethodId_NewId.keySet()]) {
            eachOrderItem.RAY_Payment_Method__c = mapOldPaymentMethodId_NewId.get(eachOrderItem.RAY_Payment_Method__c);
            listOrderItem.add(eachOrderItem);
        }
        if(!listOrderItem.isEmpty()) {
            update listOrderItem;
		}
         
        //Update contract
        List<Contract> listContract = new List<Contract>();
        for(Contract eachContract : [select Id, Ray_Payment_Method__c from Contract WHERE RAY_Payment_Method__c IN: mapOldPaymentMethodId_NewId.keySet()]) {
            eachContract.RAY_Payment_Method__c = mapOldPaymentMethodId_NewId.get(eachContract.RAY_Payment_Method__c);
            listContract.add(eachContract);
        }
        if(!listContract.isEmpty()) {
            update listContract;
		}
        
        if(!listPaymentMethod.isEmpty()) {
            update listPaymentMethod;   
		}
    }

    global void finish(Database.BatchableContext BC){
   	}
}