@RestResource(urlMapping='/Account/BalanceDue/*')
// Description: API to support the retrieval of accounts’ total balance

global without sharing class RestAPIGetAccountBalance {
    @HttpGet
    global static void doGet() {
        RestRequest request = RestContext.request;
    (new RestAPIGetAccountBalanceHandler()).processRequest();
    }
}