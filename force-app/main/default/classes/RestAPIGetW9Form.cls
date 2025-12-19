@RestResource(urlMapping='/RestApiGetW9Form/*')
// Description: Returns a W9 form

global without sharing class RestAPIGetW9Form {
    @HttpGet
    global static void doGET() {
        (new RestAPIGetW9FormHandler()).processRequest();
    }
}