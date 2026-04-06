@isTest
private class Test_MixmaxCustomObjectTriggerHandler {

    @isTest
    static void sobjectTypeIsParsed() {
        Test.startTest();
        Lead oldLead = makeLead('Foo', 'Bar');
        Lead newLead = makeLead('NotFoo', 'Bar');
        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        Map<Id, Lead> newMap = new Map<Id, Lead>{ newLead.Id => newLead };

        MixmaxCustomObjectTriggerHandler customObjectHandler = new MixmaxCustomObjectTriggerHandler(
            new RawTriggerValues(oldMap, newMap)
        );

        SObjectType parsedType = customObjectHandler.getType();
        System.assertEquals(parsedType, Lead.getSObjectType());
        Test.stopTest();
    }

    @isTest
    static void sobjectTypeIsParsedWhenNewMapIsNull() {
        Test.startTest();
        Contact oldLead = makeContact('Foo', 'Bar');
        Contact newLead = makeContact('NotFoo', 'Bar');
        Map<Id, Contact> oldMap = new Map<Id, Contact>{ oldLead.Id => oldLead };
        Map<Id, Contact> newMap = null;

        MixmaxCustomObjectTriggerHandler customObjectHandler = new MixmaxCustomObjectTriggerHandler(
            new RawTriggerValues(oldMap, newMap)
        );

        SObjectType parsedType = customObjectHandler.getType();
        System.assertEquals(parsedType, Contact.getSObjectType());
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
}