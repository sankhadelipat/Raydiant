@isTest
private class AccountCSMCascadeHandlerTest {

    private static void stripeSetup() {
        StripeTriggerHandler.enableBypass('Account');
        Stripe_Details__c sd = new Stripe_Details__c(
            Name          = 'Stripe Details',
            Serect_Key__c = 'sk_test_dummy'
        );
        upsert sd Name;
    }

    private static User makeCSMUser(String suffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String un = 'cascadetest.' + suffix + '.' + UserInfo.getOrganizationId() + '@cascade.test.invalid';
        User u = new User(
            FirstName = 'Cascade', LastName = suffix,
            Username = un.toLowerCase(), Email = un.toLowerCase(),
            Alias = suffix.left(8).toLowerCase(),
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    // 1. Changing parent CSM cascades to all descendants (children + grandchildren)
    @isTest static void test_cascade_all_generations() {
        stripeSetup();
        User csm1 = makeCSMUser('CsmA'); User csm2 = makeCSMUser('CsmB');
        Account gp     = new Account(Name = 'GP',     Account_Team_CSM__c = csm1.Id); insert gp;
        Account parent = new Account(Name = 'Parent', Account_Team_CSM__c = csm1.Id, ParentId = gp.Id); insert parent;
        Account child  = new Account(Name = 'Child',  Account_Team_CSM__c = csm1.Id, ParentId = parent.Id); insert child;
        Account gc     = new Account(Name = 'GC',     Account_Team_CSM__c = csm1.Id, ParentId = child.Id); insert gc;
        Test.startTest();
        update new Account(Id = gp.Id, Account_Team_CSM__c = csm2.Id);
        Test.stopTest();
        System.assertEquals(csm2.Id, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent cascaded');
        System.assertEquals(csm2.Id, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child cascaded');
        System.assertEquals(csm2.Id, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC cascaded');
    }

    // 2. Clearing CSM (set to null) does NOT cascade
    @isTest static void test_no_cascade_on_null() {
        stripeSetup();
        User csm1 = makeCSMUser('CsmC');
        Account parent = new Account(Name = 'Parent', Account_Team_CSM__c = csm1.Id); insert parent;
        Account child  = new Account(Name = 'Child',  Account_Team_CSM__c = csm1.Id, ParentId = parent.Id); insert child;
        Test.startTest();
        update new Account(Id = parent.Id, Account_Team_CSM__c = null);
        Test.stopTest();
        System.assertEquals(csm1.Id,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,
            'Child not cleared when parent CSM is nulled');
    }

    // 3. No change to CSM (same value) does NOT cascade unnecessarily
    @isTest static void test_no_cascade_when_unchanged() {
        stripeSetup();
        User csm1 = makeCSMUser('CsmD'); User csm2 = makeCSMUser('CsmE');
        Account parent = new Account(Name = 'Parent', Account_Team_CSM__c = csm1.Id); insert parent;
        Account child  = new Account(Name = 'Child',  Account_Team_CSM__c = csm2.Id, ParentId = parent.Id); insert child;
        Test.startTest();
        // Update parent Name only — CSM unchanged
        update new Account(Id = parent.Id, Name = 'Parent Updated');
        Test.stopTest();
        // Child's csm2 should be untouched
        System.assertEquals(csm2.Id,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,
            'Child CSM unchanged when parent not updated');
    }

    // 4. isCascading flag is reset after cascade completes
    @isTest static void test_cascading_flag_resets() {
        stripeSetup();
        User csm1 = makeCSMUser('CsmF'); User csm2 = makeCSMUser('CsmG');
        Account parent = new Account(Name = 'Parent', Account_Team_CSM__c = csm1.Id); insert parent;
        Account child  = new Account(Name = 'Child',  ParentId = parent.Id); insert child;
        Test.startTest();
        update new Account(Id = parent.Id, Account_Team_CSM__c = csm2.Id);
        Test.stopTest();
        System.assertEquals(false, AccountCSMCascadeHandler.isCascading, 'Flag reset after cascade');
        System.assertEquals(csm2.Id,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c, 'Child cascaded');
    }
}