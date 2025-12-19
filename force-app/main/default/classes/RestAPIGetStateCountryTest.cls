@isTest
public class RestAPIGetStateCountryTest {

    static testMethod void RestAPIStateCountryPositiveTest(){
        Country__c countryVar = new Country__c (Name = 'Wakanda');
        insert countryVar;
        State__c stateVar = new State__c(Country__c = countryVar.Id, Name= 'Wakanda1');
        insert stateVar;
        
        RestRequest req = new RestRequest();
        RestResponse res= new RestResponse();

        req.requestURI = '/Describe/StateCountry/*';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestAPIStateCountry.doGet();
        Test.stopTest();

        Map<String, Object> rawResponse = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> responseMap = (Map<String, Object>)rawResponse.get('response');
        system.debug(rawResponse.get('response').toString());
        RestAPIStateCountryHandler.CountryResponse countriesTest = (RestAPIStateCountryHandler.CountryResponse) system.JSON.deserialize(JSON.serialize(rawResponse.get('response')), RestAPIStateCountryHandler.CountryResponse.class);
        
        System.assertEquals(true, countriesTest.countries.size()>0);

    }
}