@RestResource(urlMapping='/Account/UpdateAddress/*')
// DAPI to support the updating of “Bill-To” and/or “Ship-To” addresses for a given account
global without sharing class RestAPIUpdateAccountAddress {

    @HttpPost
    global static void doPost() {
        (new RestAPIUpdateAccountAddressHandler()).processRequest();
    }
}