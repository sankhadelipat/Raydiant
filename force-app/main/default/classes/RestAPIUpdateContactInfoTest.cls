@isTest
public class RestAPIUpdateContactInfoTest {
    
    @TestSetup
    static void setup() {
        Account accVar = TestDataFactory.createTestAccount(true);
        system.assertNotEquals(null, accVar.Id, 'Account Inserted');

        Contact conVar = TestDataFactory.createTestContact(accVar.Id, true);
        system.assertNotEquals(null, conVar.Id, 'Contact Inserted');

    }


    static testmethod void testInvalidRequests() {
        //No Body
        RestRequest req = new RestRequest(); 

        req.requestURI = '/Contact/UpdateInfo/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateContactInfo.doPOST();
        String response = RestContext.response.responseBody.toString();
        RestAPIResponse responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Blank Body        
        req = new RestRequest(); 
        req.requestBody = Blob.valueof(UPDATE_CONTACT_BODY_BLANK);
        req.requestURI = '/Contact/UpdateInfo/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateContactInfo.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);

        //Invalid Contact Id
        List<Contact> conList = [SELECT Id, FirstName, LastName, Email, MailingStreet,
                                    MailingCity, MailingState, MailingPostalCode, 
                                    MailingCountry FROM Contact ];

        req = new RestRequest(); 
        req.requestURI = '/Contact/UpdateInfo/';
        req.httpMethod = 'POST';
        RestAPIGetAccountAddressHandler.ContactInfo contactInfoRequest = new RestAPIGetAccountAddressHandler.ContactInfo(conList[0]);
        contactInfoRequest.contactId = 'invalid';
        req.requestBody = Blob.valueof(JSON.serializePretty(contactInfoRequest));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateContactInfo.doPOST();
        response = RestContext.response.responseBody.toString();
        responseObj = (RestAPIResponse)JSON.deserialize(response, RestAPIResponse.class);
        System.assertEquals('INVALID_INPUT', responseObj.errors[0].type);
        System.assertEquals(400, responseObj.errors[0].code);
    }

    static testmethod void testValidRequests() {
        List<Contact> conList = [SELECT Id, FirstName, LastName, Email, MailingStreet,
                                    MailingCity, MailingState, MailingPostalCode, 
                                    MailingCountry FROM Contact ];

        system.assertEquals(1, conList.size());

        RestRequest req = new RestRequest(); 

        req.requestURI = '/Contact/UpdateInfo/';
        req.httpMethod = 'POST';
        RestAPIGetAccountAddressHandler.ContactInfo contactInfoRequest = new RestAPIGetAccountAddressHandler.ContactInfo(conList[0]);
        contactInfoRequest.streetAddress = 'Changed Street';
        req.requestBody = Blob.valueof(JSON.serializePretty(contactInfoRequest));
        
        RestContext.request = req;
        RestContext.response = new RestResponse();

        RestAPIUpdateContactInfo.doPOST();
        System.assertEquals(200,RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assertEquals(true,response.containsIgnoreCase('"success":true'));

    }

    private static final String UPDATE_CONTACT_BODY_BLANK = '{' +
            '"contactId": "",' +
            '"firstName": "",' +
            '"lastName": "",' +
            '"emailAddress": "",' +
            '"streetAddress": "",' +
            '"city": "",' +
            '"state" : "",' +
            '"postalCode": "",' +
            '"country" : ""' +
            '}';
}