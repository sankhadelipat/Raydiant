@isTest
private class CSMAssignmentBatchTest {

    // Bypass the Stripe trigger AND seed the custom setting — belt + suspenders.
    // The trigger has isBypassEnabled() check so enableBypass() prevents the
    // queueable from ever being called. The upsert covers the edge case where
    // the class still loads (static-init needs Stripe_Details__c.getInstance).
    private static void stripeSetup() {
        StripeTriggerHandler.enableBypass('Account');
        Stripe_Details__c sd = new Stripe_Details__c(
            Name          = 'Stripe Details',
            Serect_Key__c = 'sk_test_dummy'
        );
        upsert sd Name;
    }

    // No @TestSetup — the sandbox already has exactly one active user per CSM name
    // (Annette Broussard, Francisco Fiedler, Ali Aziz, Vilen Gabrielyan).
    // Creating duplicates causes the batch constructor and uid() to run at slightly
    // different times and pick different users from the tie-broken set.
    // ORDER BY Id ASC LIMIT 1 is deterministic: lowest Id = the one real org user.
    private static Id uid(String name) {
        return [SELECT Id FROM User
                WHERE Name = :name AND IsActive = true
                ORDER BY Id ASC LIMIT 1].Id;
    }

    private static void makeSub(Id acctId, String prodName) {
        Product2 prod = new Product2(Name = prodName, IsActive = true);
        insert prod;
        insert new SBQQ__Subscription__c(
            SBQQ__Account__c  = acctId,
            SBQQ__Product__c  = prod.Id,
            SBQQ__Quantity__c = 1
        );
    }

    @isTest
    static void test_hoopla_trumps_low_mrr() {
        stripeSetup();
        Account a = new Account(Name = 'Hoopla Co', Account_Value__c = 50);
        insert a;
        makeSub(a.Id, 'Hoopla User License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(uid('Annette Broussard'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'Hoopla always Annette');
    }

    @isTest
    static void test_mrr_null_francisco() {
        stripeSetup();
        Account a = new Account(Name = 'Null MRR Co');
        insert a;
        makeSub(a.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(uid('Francisco Fiedler'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'Null MRR Francisco');
    }

    @isTest
    static void test_mrr_low_francisco() {
        stripeSetup();
        Account a = new Account(Name = 'Low MRR Co', Account_Value__c = 75);
        insert a;
        makeSub(a.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(uid('Francisco Fiedler'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'MRR 75 Francisco');
    }

    @isTest
    static void test_mrr_mid_ali() {
        stripeSetup();
        // Sub on child to avoid CPQ trigger zeroing parent Account_Value__c
        Account a = new Account(Name = 'Mid MRR Co', Account_Value__c = 250);
        insert a;
        Account child = new Account(Name = 'Mid MRR Child', ParentId = a.Id);
        insert child;
        makeSub(child.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(uid('Ali Aziz'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'MRR 250 Ali');
    }

    @isTest
    static void test_mrr_high_vilen() {
        stripeSetup();
        // Sub on child to avoid CPQ trigger zeroing parent Account_Value__c
        Account a = new Account(Name = 'High MRR Co', Account_Value__c = 750);
        insert a;
        Account child = new Account(Name = 'High MRR Child', ParentId = a.Id);
        insert child;
        makeSub(child.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(uid('Vilen Gabrielyan'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'MRR 750 Vilen');
    }

    @isTest
    static void test_no_subs_clears_csm() {
        stripeSetup();
        Id fId = uid('Francisco Fiedler');
        Account a = new Account(Name = 'Churned Co', Account_Value__c = 200,
            Account_Team_CSM__c = fId);
        insert a;
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(null,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'No subs clears CSM');
    }

    @isTest
    static void test_no_subs_family_clears_all() {
        stripeSetup();
        Id vId = uid('Vilen Gabrielyan');
        Account parent = new Account(Name = 'Churned Parent', Account_Team_CSM__c = vId);
        insert parent;
        Account child = new Account(Name = 'Churned Child', ParentId = parent.Id, Account_Team_CSM__c = vId);
        insert child;
        Account gc = new Account(Name = 'Churned GC', ParentId = child.Id, Account_Team_CSM__c = vId);
        insert gc;
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(null, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent cleared');
        System.assertEquals(null, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child cleared');
        System.assertEquals(null, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC cleared');
    }

    @isTest
    static void test_family_inheritance() {
        stripeSetup();
        Account parent = new Account(Name = 'Parent Co', Account_Value__c = 600);
        insert parent;
        Account c1 = new Account(Name = 'Child 1', ParentId = parent.Id);
        Account c2 = new Account(Name = 'Child 2', ParentId = parent.Id);
        insert new List<Account>{ c1, c2 };
        makeSub(c1.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        Id vId = uid('Vilen Gabrielyan');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Vilen');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :c1.Id].Account_Team_CSM__c,     'Child 1 Vilen');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :c2.Id].Account_Team_CSM__c,     'Child 2 Vilen');
    }

    @isTest
    static void test_grandchildren_inherit() {
        stripeSetup();
        Account gp = new Account(Name = 'GP Co', Account_Value__c = 300);
        insert gp;
        Account parent = new Account(Name = 'Parent Co', ParentId = gp.Id);
        insert parent;
        Account gc = new Account(Name = 'GC Co', ParentId = parent.Id);
        insert gc;
        makeSub(gc.Id, 'Display License - Standard'); // sub on gc keeps gp.Account_Value__c intact
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        Id aId = uid('Ali Aziz');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gp.Id].Account_Team_CSM__c,     'GP Ali');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Ali');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC Ali');
    }

    @isTest
    static void test_hoopla_on_child() {
        stripeSetup();
        Account parent = new Account(Name = 'Parent Co', Account_Value__c = 50);
        insert parent;
        Account child = new Account(Name = 'Hoopla Child', ParentId = parent.Id);
        insert child;
        makeSub(child.Id, 'Hoopla Gold Package [legacy]');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        Id aId = uid('Annette Broussard');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child Annette');
    }

    @isTest
    static void test_hoopla_on_grandchild() {
        stripeSetup();
        Account gp = new Account(Name = 'GP Co', Account_Value__c = 50);
        insert gp;
        Account parent = new Account(Name = 'Mid Co', ParentId = gp.Id);
        insert parent;
        Account gc = new Account(Name = 'Hoopla GC', ParentId = parent.Id);
        insert gc;
        makeSub(gc.Id, 'Hoopla Dynamics 365 Integration');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        Id aId = uid('Annette Broussard');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gp.Id].Account_Team_CSM__c,     'GP Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC Annette');
    }

    @isTest
    static void test_already_correct() {
        stripeSetup();
        Id fId = uid('Francisco Fiedler');
        Account a = new Account(Name = 'Already Correct', Account_Value__c = 50,
            Account_Team_CSM__c = fId);
        insert a;
        makeSub(a.Id, 'Display License - Standard');
        Test.startTest();
        Database.executeBatch(new CSMAssignmentBatch(), 200);
        Test.stopTest();
        System.assertEquals(fId,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c,
            'Already correct no change');
    }

    @isTest
    static void test_schedulable() {
        Test.startTest();
        String jobId = System.schedule('CSM Nightly Test', '0 0 2 * * ?', new CSMAssignmentBatch());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler returns job Id');
    }
}