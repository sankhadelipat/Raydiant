@isTest
private class CSMAssignmentBatchTest {

    private static void stripeSetup() {
        StripeTriggerHandler.enableBypass('Account');
        Stripe_Details__c sd = new Stripe_Details__c(
            Name          = 'Stripe Details',
            Serect_Key__c = 'sk_test_dummy'
        );
        upsert sd Name;
    }

    private static Id uid(String name) {
        return [SELECT Id FROM User WHERE Name = :name AND IsActive = true ORDER BY Id ASC LIMIT 1].Id;
    }

    private static void makeSub(Id acctId, String prodName) {
        Product2 prod = new Product2(Name = prodName, IsActive = true, Business_Use_Case__c = 'Digital Signage');
        insert prod;
        insert new SBQQ__Subscription__c(
            SBQQ__Account__c  = acctId,
            SBQQ__Product__c  = prod.Id,
            SBQQ__Quantity__c = 1
        );
    }

    @isTest static void test_hoopla_trumps_low_mrr() {
        stripeSetup();
        Account a = new Account(Name = 'Hoopla Co', Account_Value__c = 50); insert a;
        makeSub(a.Id, 'Hoopla User License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Annette Broussard'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'Hoopla -> Annette');
    }

    @isTest static void test_hoopla_on_child() {
        stripeSetup();
        Account parent = new Account(Name = 'Parent Co', Account_Value__c = 50); insert parent;
        Account child  = new Account(Name = 'Hoopla Child', ParentId = parent.Id); insert child;
        makeSub(child.Id, 'Hoopla Gold Package [legacy]');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        Id aId = uid('Annette Broussard');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child Annette');
    }

    @isTest static void test_hoopla_on_grandchild() {
        stripeSetup();
        Account gp     = new Account(Name = 'GP Co',  Account_Value__c = 50); insert gp;
        Account parent = new Account(Name = 'Mid Co', ParentId = gp.Id);      insert parent;
        Account gc     = new Account(Name = 'Hoopla GC', ParentId = parent.Id); insert gc;
        makeSub(gc.Id, 'Hoopla Dynamics 365 Integration');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        Id aId = uid('Annette Broussard');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gp.Id].Account_Team_CSM__c,     'GP Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Annette');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC Annette');
    }

    @isTest static void test_mrr_null_francisco() {
        stripeSetup();
        Account a   = new Account(Name = 'Null MRR Co'); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Francisco Fiedler'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'Null -> Francisco');
    }

    @isTest static void test_mrr_low_francisco() {
        stripeSetup();
        Account a   = new Account(Name = 'Low MRR Co', Account_Value__c = 75); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Francisco Fiedler'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'MRR 75 -> Francisco');
    }

    @isTest static void test_mrr_boundary_200_ali() {
        stripeSetup();
        Account a   = new Account(Name = 'Boundary MRR Co', Account_Value__c = 200); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Ali Aziz'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'MRR exactly 200 -> Ali');
    }

    @isTest static void test_mrr_mid_ali() {
        stripeSetup();
        Account a   = new Account(Name = 'Mid MRR Co', Account_Value__c = 250); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Ali Aziz'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'MRR 250 -> Ali');
    }

    @isTest static void test_mrr_high_vilen() {
        stripeSetup();
        Account a   = new Account(Name = 'High MRR Co', Account_Value__c = 750); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Vilen Gabrielyan'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'MRR 750 -> Vilen');
    }

    @isTest static void test_batch_corrects_wrong_csm() {
        stripeSetup();
        Id fId = uid('Francisco Fiedler');
        Account a   = new Account(Name = 'Wrong CSM Co', Account_Value__c = 750, Account_Team_CSM__c = fId); insert a;
        Account sub = new Account(Name = 'Sub Holder', ParentId = a.Id); insert sub;
        makeSub(sub.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(uid('Vilen Gabrielyan'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'Batch corrects to Vilen');
    }

    @isTest static void test_no_subs_preserves_csm() {
        stripeSetup();
        Id fId = uid('Francisco Fiedler');
        Account a = new Account(Name = 'Churned Co', Account_Value__c = 200, Account_Team_CSM__c = fId); insert a;
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(fId,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :a.Id].Account_Team_CSM__c, 'No subs: CSM preserved');
    }

    @isTest static void test_no_subs_family_preserves_all() {
        stripeSetup();
        Id vId = uid('Vilen Gabrielyan');
        Account parent = new Account(Name = 'Churned Parent', Account_Team_CSM__c = vId); insert parent;
        Account child  = new Account(Name = 'Churned Child',  ParentId = parent.Id, Account_Team_CSM__c = vId); insert child;
        Account gc     = new Account(Name = 'Churned GC',     ParentId = child.Id,  Account_Team_CSM__c = vId); insert gc;
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent preserved');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child preserved');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC preserved');
    }

    @isTest static void test_family_inheritance() {
        stripeSetup();
        Account parent = new Account(Name = 'Parent Co', Account_Value__c = 600); insert parent;
        Account c1     = new Account(Name = 'Child 1', ParentId = parent.Id);
        Account c2     = new Account(Name = 'Child 2', ParentId = parent.Id);
        insert new List<Account>{ c1, c2 };
        makeSub(c1.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        Id vId = uid('Vilen Gabrielyan');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Vilen');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :c1.Id].Account_Team_CSM__c,     'Child 1 Vilen');
        System.assertEquals(vId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :c2.Id].Account_Team_CSM__c,     'Child 2 Vilen');
    }

    @isTest static void test_grandchildren_inherit() {
        stripeSetup();
        Account gp     = new Account(Name = 'GP Co',     Account_Value__c = 300); insert gp;
        Account parent = new Account(Name = 'Parent Co', ParentId = gp.Id);       insert parent;
        Account gc     = new Account(Name = 'GC Co',     ParentId = parent.Id);   insert gc;
        makeSub(gc.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        Id aId = uid('Ali Aziz');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gp.Id].Account_Team_CSM__c,     'GP Ali');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent Ali');
        System.assertEquals(aId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :gc.Id].Account_Team_CSM__c,     'GC Ali');
    }

    @isTest static void test_child_inherits_parent_mrr_csm() {
        stripeSetup();
        Account parent = new Account(Name = 'Low MRR Parent', Account_Value__c = 0); insert parent;
        Account child  = new Account(Name = 'Inheriting Child', ParentId = parent.Id); insert child;
        makeSub(child.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        Id fId = uid('Francisco Fiedler');
        System.assertEquals(fId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c, 'Parent gets Francisco');
        System.assertEquals(fId, [SELECT Account_Team_CSM__c FROM Account WHERE Id = :child.Id].Account_Team_CSM__c,  'Child inherits Francisco');
    }

    // ?? CSM_LOCK__C ?????????????????????????????????????????????????????????

    @isTest static void test_csm_lock_skips_account() {
        stripeSetup();
        Id vId = uid('Vilen Gabrielyan');
        // $0 MRR + locked � batch would normally assign Francisco, but lock must win
        Account parent = new Account(
            Name                = 'Locked Parent Co',
            Account_Value__c    = 0,
            Account_Team_CSM__c = vId,
            CSM_Lock__c         = true
        ); insert parent;
        Account child = new Account(Name = 'Locked Child', ParentId = parent.Id); insert child;
        makeSub(child.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        System.assertEquals(vId,
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c,
            'Locked account: Vilen must be preserved');
    }

    // ?? FAMILY MRR via Parent_MRR__c rollup drives CSM tier ?????????????????
    // Texas Roadhouse scenario:
    //   ##Parent ($0 own) -> Market ($600 Account_Value__c) -> Location (holds sub)
    // Rollup sets ##Parent.Parent_MRR__c = 600 automatically.
    // Batch reads 0 + 600 = $600 total -> Vilen.

    @isTest static void test_family_mrr_drives_csm_tier() {
        stripeSetup();
        Account parent = new Account(Name = 'TX ##Parent', Account_Value__c = 0); insert parent;
        // Child market with $600 Account_Value__c triggers rollup: parent.Parent_MRR__c = 600
        Account market = new Account(Name = 'TX Market', ParentId = parent.Id, Account_Value__c = 600); insert market;
        // Grandchild holds the sub so CPQ trigger does not overwrite market's Account_Value__c
        Account loc = new Account(Name = 'TX Location', ParentId = market.Id); insert loc;
        makeSub(loc.Id, 'Display License - Standard');
        Test.startTest(); Database.executeBatch(new CSMAssignmentBatch(), 200); Test.stopTest();
        // parent: Account_Value__c(0) + Parent_MRR__c(600) = $600 -> Vilen
        System.assertEquals(uid('Vilen Gabrielyan'),
            [SELECT Account_Team_CSM__c FROM Account WHERE Id = :parent.Id].Account_Team_CSM__c,
            'Family MRR $600 via rollup -> Vilen');
    }

    @isTest static void test_schedulable() {
        Test.startTest();
        String jobId = System.schedule('CSM Nightly Test', '0 0 2 * * ?', new CSMAssignmentBatch());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler returns job Id');
    }
}