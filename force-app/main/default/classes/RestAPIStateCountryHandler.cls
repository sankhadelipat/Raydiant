/**
 * @name            RestResourceCountryState
 * @description     Rest resource to be used a service 
 * @author
 * @date
 */
public without sharing class RestAPIStateCountryHandler extends RestAPIHandler {
    
    public RestAPIStateCountryHandler() {
        super();
        operation = 'RestAPIStateCountryHandler';
        className = 'RestAPIStateCountryHandler';
    }
    
    public void processGET() {
        //initialize save point
        initializeSavePoint();
        
        List<Country__c> countryList = [SELECT Name, State_Label__c, (SELECT Name FROM States__r) FROM Country__c];
        response = new RestAPIResponse(new CountryResponse(countryList));
    }
    
    private void processPOST() {

    }

    public class CountryResponse {
        public List<Country> countries = new List<Country>();
        public CountryResponse(List<Country__c> countryList) {
            for(Country__c c: countryList) {
                countries.add(new Country(c));
            }
        }
    }
    public class Country {
        public String name;
        public String stateLabel;
        public List<State> states = new List<State>();
        public Country(Country__c c) {
            this.name = c.Name;
            this.stateLabel = c.State_Label__c;
            for(State__c s: c.States__r) {
                states.add(new State(s));
            }
        }
    }
    public class State {
        public String name;
        public State(State__c s) {
            this.name = s.Name;
        }
    }
    
}