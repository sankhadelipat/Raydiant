@RestResource(urlMapping='/Account/ToggleEmail/*')
global class RestAPIEmailToggle {
    @HttpPost
    global static void doPost() {
        (new RestAPIEmailToggleHandler()).processRequest();
    }
}