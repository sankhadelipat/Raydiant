@RestResource(urlMapping='/ProductList/*')
//Query the account with Display In Marketplace = true

global without sharing class RestAPIGetProductList {
    @HttpGet
    global static void doGET() {
        (new RestAPIGetProductListHandler()).processRequest();
    }
}