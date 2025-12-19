@IsTest
public with sharing class PaymentMethodTest {
    @IsTest
    public static void testPaymentMethod() {
        Account a = TestDataFactory.createTestAccount(true);
        blng__PaymentMethod__c pm = TestDataFactory.createTestPaymentMethod(a.Id, 'Credit Card', true);
        PaymentMethod pmCustom = new PaymentMethod(pm);
        pmCustom.getPaymentMethod();
    }

}