@IsTest
private class StripeTriggerHandler_Test {

    @IsTest
    static void testSingleObjectBypass() {
        // Ensure default state
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled('Tag__c'),
            'Bypass should be false initially');

        // Enable bypass
        StripeTriggerHandler.enableBypass('Tag__c');
        System.assertEquals(true, StripeTriggerHandler.isBypassEnabled('Tag__c'),
            'Bypass should be true after enabling');

        // Disable bypass
        StripeTriggerHandler.disableBypass('Tag__c');
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled('Tag__c'),
            'Bypass should be false after disabling');
    }

    @IsTest
    static void testMultipleObjectsBypass() {
        List<String> objs = new List<String>{'Tag__c', 'Campaign__c', 'Contact'};

        // Enable bypass for all
        StripeTriggerHandler.enableBypassForAll(objs);
        for (String obj : objs) {
            System.assertEquals(true, StripeTriggerHandler.isBypassEnabled(obj),
                obj + ' bypass should be true after enableBypassForAll');
        }

        // Disable bypass for all
        StripeTriggerHandler.disableBypassForAll(objs);
        for (String obj : objs) {
            System.assertEquals(false, StripeTriggerHandler.isBypassEnabled(obj),
                obj + ' bypass should be false after disableBypassForAll');
        }
    }

    @IsTest
    static void testResetAll() {
        // Enable a few bypasses
        StripeTriggerHandler.enableBypass('Tag__c');
        StripeTriggerHandler.enableBypass('Contact');

        // Ensure they’re active
        System.assert(StripeTriggerHandler.isBypassEnabled('Tag__c'));
        System.assert(StripeTriggerHandler.isBypassEnabled('Contact'));

        // Reset everything
        StripeTriggerHandler.resetAll();

        // Now all should be false
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled('Tag__c'),
            'Bypass should be false after resetAll');
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled('Contact'),
            'Bypass should be false after resetAll');
    }

    @IsTest
    static void testInvalidInputs() {
        // Null or blank inputs should not throw errors and always return false
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled(null));
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled(''));
        System.assertEquals(false, StripeTriggerHandler.isBypassEnabled('  '));

        // Enabling/disabling with null or blank should not cause errors
        StripeTriggerHandler.enableBypass(null);
        StripeTriggerHandler.disableBypass('');
        StripeTriggerHandler.enableBypassForAll(null);
        StripeTriggerHandler.disableBypassForAll(null);
    }
}