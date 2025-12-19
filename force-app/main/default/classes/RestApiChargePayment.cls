@RestResource(urlMapping='/Account/ChargePayment/*')
global with sharing class RestApiChargePayment {
    @HttpPut
    global static void doPost() {
        (new RestApiChargePaymentHandler()).processRequest();
    }
}