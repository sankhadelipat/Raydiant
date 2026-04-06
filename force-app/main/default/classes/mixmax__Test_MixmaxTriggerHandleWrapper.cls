@isTest
private class Test_MixmaxTriggerHandleWrapper {

    @testSetup
    static void setup() {
        // Create test settings to be used when handling updates.
        MixmaxSettings__c settings = new MixmaxSettings__c();
        settings.MixmaxToken__c = 'test-api-token';
        settings.ErrorLoggingEnabled__c = true;
        insert settings;
    }

    @isTest
    static void triggerValuesAreParsedForUpdate() {
        Test.startTest();
        Lead oldLead = makeLead('Foo', 'Bar');
        Lead newLead = makeLead('NotFoo', 'Bar');
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldLead.Id => oldLead };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ newLead.Id => newLead };
        SObjectType type = Lead.getSObjectType();

        MixmaxTriggerHandleWrapper handleWrapper = new MixmaxTriggerHandleWrapper(
            type,
            new RawTriggerValues(true, false, oldMap, newMap)
        );

        ParsedTriggerValues parsedValues = handleWrapper.getParsedTriggerValues();
        System.assertEquals(parsedValues.verb, 'update');
        System.assertEquals(parsedValues.type, type);
        Test.stopTest();
    }

    @isTest
    static void triggerValuesAreParsedForCreate() {
        Test.startTest();
        Contact oldContact = null;
        Contact newContact = makeContact('Foo', 'Bar');
        Map<Id, SObject> oldMap = new Map<Id, SObject>{};
        Map<Id, SObject> newMap = new Map<Id, SObject>{ newContact.Id => newContact };
        SObjectType type = Contact.getSObjectType();

        MixmaxTriggerHandleWrapper handleWrapper = new MixmaxTriggerHandleWrapper(
            type,
            new RawTriggerValues(false, false, oldMap, newMap)
        );

        ParsedTriggerValues parsedValues = handleWrapper.getParsedTriggerValues();
        System.assertEquals(parsedValues.verb, 'create');
        System.assertEquals(parsedValues.type, type);
        Test.stopTest();
    }

    @isTest
    static void triggerValuesAreParsedForDelete() {
        Test.startTest();
        Account oldAccount = makeAccount('Mixmax', 'mixmax.com');
        Account newAccount = null;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldAccount.Id => oldAccount };
        Map<Id, SObject> newMap = new Map<Id, SObject>{};
        SObjectType type = Account.getSObjectType();

        MixmaxTriggerHandleWrapper handleWrapper = new MixmaxTriggerHandleWrapper(
            type,
            new RawTriggerValues(false, true, oldMap, newMap)
        );

        ParsedTriggerValues parsedValues = handleWrapper.getParsedTriggerValues();
        System.assertEquals(parsedValues.verb, 'delete');
        System.assertEquals(parsedValues.type, type);
        Test.stopTest();
    }

    static Lead makeLead(String firstName, String lastName) {
        return new Lead(
                FirstName = firstName,
                LastName = lastName
        );
    }

    static Contact makeContact(String firstName, String lastName) {
        return new Contact(
                FirstName = firstName,
                LastName = lastName
        );
    }

    static Account makeAccount(String name, String site) {
        return new Account(
                Name = name,
                Site = site
        );
    }
}