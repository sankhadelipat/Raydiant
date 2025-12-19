public without sharing class RestAPIUpdateContactInfoHandler extends RestAPIHandler {
    
    public RestAPIUpdateContactInfoHandler() {
        super();
        operation = 'RestAPIUpdateContactInfoHandler';
        className = 'RestAPIUpdateContactInfoHandler';
    }

    // override GET
    private void processGET() {      
    }

    Contact conVar;

    // override POST
    private void processPOST() {
        //initialize save point
        initializeSavePoint();

        RestAPIGetAccountAddressHandler.ContactInfo contactInfoRequest;
        
        //try catch around deserializing to throw a valid request instead of a 500 Internal Server error.
        try {
            contactInfoRequest = (RestAPIGetAccountAddressHandler.ContactInfo)JSON.deserialize(requestBody, RestAPIGetAccountAddressHandler.ContactInfo.class);
        } catch ( Exception e ) {
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }

        //1 - Validate required field values
        validateRequiredFields(contactInfoRequest);

        //2 - Check if contact exists
        validateContact(contactInfoRequest.contactId);

        //3 - Form Contact Update Variable
        populateContactUpdateRecord(contactInfoRequest);
        
        //4 - Update Contact
        try {
            update conVar;
        } catch ( Exception ex ) {
            throw new UnexpectedException('Unable to update Contact: '+ex.getMessage());
        }

        //5 - Generate Response
        generateResponse();

    }

    private void generateResponse() {
        String message = 'The Contact was updated successfully.';
        response = new RestAPIResponse( message );
    }

    private void validateRequiredFields(RestAPIGetAccountAddressHandler.ContactInfo contactInfoRequest) {
        Set<String> requiredFields = new Set<String>();

        if( String.isBlank(contactInfoRequest.contactId) ) {
            requiredFields.add('contactId');
        }
        if( String.isBlank(contactInfoRequest.lastName) ) {
            requiredFields.add('lastName');
        }
        if( String.isBlank(contactInfoRequest.emailAddress) ) {
            requiredFields.add('emailAddress');
        }       

        if(!requiredFields.isEmpty()) {
            throw new InvalidInputException('Missing required fields: [' + GeneralUtility.joinSet(requiredFields, ',') + ']');
        }
    }

    private void validateContact(String contactId) {
        try {
            conVar = RestAPIUtility.getContactById(contactId);
        } catch ( Exception ex ) {
            throw new InvalidInputException('No contact found for given contactId: ' + contactId);
        }
    }

    private void populateContactUpdateRecord(RestAPIGetAccountAddressHandler.ContactInfo contactInfoRequest) {
        conVar.Id = contactInfoRequest.contactId;
        conVar.FirstName = contactInfoRequest.firstName;
        conVar.LastName = contactInfoRequest.lastName;
        conVar.Email = contactInfoRequest.emailAddress;
        conVar.MailingStreet = contactInfoRequest.streetAddress;
        conVar.MailingCity = contactInfoRequest.city;
        conVar.MailingState = contactInfoRequest.state;
        conVar.MailingPostalCode = contactInfoRequest.postalCode;
        conVar.MailingCountry = contactInfoRequest.country;
    }
}