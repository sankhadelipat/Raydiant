@RestResource(urlMapping='/Invoices/*')
// Description: API to return account Invoice information

global without sharing class RestAPIGetAllInvoices {
    @HttpGet
    global static void doGet() {
        RestRequest request = RestContext.request;
    (new RestAPIGetALLInvoicesHandler()).processRequest();
    }
}