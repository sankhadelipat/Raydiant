@RestResource(urlMapping='/Account/GetInfo/*')
global class RestAPIAccountInfo {

    @HttpGet
    global static void doGet() {
        (new RestAPIGetAccountAddressHandler()).processRequest();
    }

}