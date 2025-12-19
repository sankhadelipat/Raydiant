@RestResource(urlMapping='/Account/ListPaymentMethod/*')
global without sharing class RestAPIListPaymentMethod {
    @HttpGet
    global static void doGet() {
        RestRequest request = RestContext.request;
    (new RestAPIListPaymentMethodHandler()).processRequest();
    }
}