@RestResource(urlMapping='/Account/UpdateEmail/*')
// Description: Updates the email change address associated with an accounts contracts

global without sharing class RestAPIEmailChange {

    @HttpPost
    global static void doPost() {
        (new RestAPIEmailChangeHandler()).processRequest();
    }
}