@RestResource(urlMapping='/Account/UpdatePaymentMethod')
global without sharing class RestAPIUpdatePayment {
    
    @HttpPost
    global static void doPost() {
        (new RestAPIPaymentMethodHandler()).processRequest();
    }

}