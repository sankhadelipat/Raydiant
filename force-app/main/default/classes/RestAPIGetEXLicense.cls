@RestResource(urlMapping='/EXLicense/*')
//Query the number of EX licenses for each type

global without sharing class RestAPIGetEXLicense {
    @HttpGet
    global static void doGET() {
        (new RestAPIGetEXLicenseHandler()).processRequest();
    }
}