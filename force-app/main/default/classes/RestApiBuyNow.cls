@RestResource(urlMapping='/RestApiBuyNow/*')    
global class RestApiBuyNow {
    
    @HttpPost
    global static void doPost(){
        (new RestAPIBuyNowHandler()).processRequest();
    }
    
}