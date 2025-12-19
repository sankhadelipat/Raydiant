@RestResource(urlMapping='/Account/AddPaymentMethod')
global without sharing class RestAPIAddPayment {
    
    @HttpPost
    global static void doPost() {
        (new RestAPIPaymentMethodHandler()).processRequest();
    }

}