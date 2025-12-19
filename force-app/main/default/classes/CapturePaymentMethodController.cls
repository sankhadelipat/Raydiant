public without sharing class CapturePaymentMethodController {
    @AuraEnabled
    public static List<blng__PaymentMethod__c> getPaymentMethods(String customerId) {
        return [SELECT Id,blng__Account__c,blng__PaymentGateway__c FROM blng__PaymentMethod__c WHERE F52_Customer_PM_Id__c =: customerId];
    }
    
    @AuraEnabled
    public static void updatePaymentMethodsOnObjects(String oldPaymentMethodId, String newPaymentMethodId) {
        blng__PaymentMethod__c objPaymentMethodNew = new blng__PaymentMethod__c(Id = newPaymentMethodId, F52_Old_Payment_Id__c = oldPaymentMethodId);
        blng__PaymentMethod__c objPaymentMethodOld = new blng__PaymentMethod__c(Id = oldPaymentMethodId, F52NewPaymentMethod__c = newPaymentMethodId);
        update new List<blng__PaymentMethod__c> {objPaymentMethodNew, objPaymentMethodOld};
    }
}