@RestResource(urlMapping='/Contact/UpdateInfo/*')
global without sharing class RestAPIUpdateContactInfo {
   
    @HttpPost
    global static void doPost() {
        (new RestAPIUpdateContactInfoHandler()).processRequest();
    }

}