@RestResource(urlMapping='/Describe/StateCountry/*')
global class RestAPIStateCountry {
    @HttpGet
    global static void doGet() {
        
        (new RestAPIStateCountryHandler()).processRequest();
    }
}