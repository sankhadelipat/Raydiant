@isTest
public class ConversionSyncHelperTest {

    private class MockHttpCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    @isTest
    static void testSyncLeadToOpportunityDirect() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company'
        );
        insert testLead;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert testOpp;

        // Build old and new lead maps to call helper directly
        Lead oldLead = testLead.clone(true, true, true, true);
        oldLead.Converted_Opportunity__c = null;

        testLead.Converted_Opportunity__c = testOpp.Id;

        Map<Id, Lead> oldLeadMap = new Map<Id, Lead>();
        oldLeadMap.put(testLead.Id, oldLead);

        List<Lead> newLeads = new List<Lead>{ testLead };

        Test.startTest();
        ConversionSyncHelper.syncLeadToOpportunity(newLeads, oldLeadMap);
        Test.stopTest();

        Opportunity updatedOpp = [SELECT From_Converted_Lead__c FROM Opportunity WHERE Id = :testOpp.Id];
        System.assertEquals(testLead.Id, updatedOpp.From_Converted_Lead__c, 'Opp should have Lead reference');
    }

    @isTest
    static void testSyncOpportunityToLeadDirect() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead2',
            Company = 'Test Company'
        );
        insert testLead;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp 2',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert testOpp;

        // Build old and new opp maps to call helper directly
        Opportunity oldOpp = testOpp.clone(true, true, true, true);
        oldOpp.From_Converted_Lead__c = null;

        testOpp.From_Converted_Lead__c = testLead.Id;

        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>();
        oldOppMap.put(testOpp.Id, oldOpp);

        List<Opportunity> newOpps = new List<Opportunity>{ testOpp };

        Test.startTest();
        ConversionSyncHelper.syncOpportunityToLead(newOpps, oldOppMap);
        Test.stopTest();

        Lead updatedLead = [SELECT Converted_Opportunity__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(testOpp.Id, updatedLead.Converted_Opportunity__c, 'Lead should have Opp reference');
    }

    @isTest
    static void testLeadToOppSkipsWhenNoChange() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead3',
            Company = 'Test Company'
        );
        insert testLead;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp 3',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert testOpp;

        // Both old and new have same value - no change
        Lead oldLead = testLead.clone(true, true, true, true);
        oldLead.Converted_Opportunity__c = testOpp.Id;
        testLead.Converted_Opportunity__c = testOpp.Id;

        Map<Id, Lead> oldLeadMap = new Map<Id, Lead>();
        oldLeadMap.put(testLead.Id, oldLead);

        List<Lead> newLeads = new List<Lead>{ testLead };

        Test.startTest();
        ConversionSyncHelper.syncLeadToOpportunity(newLeads, oldLeadMap);
        Test.stopTest();

        // Opp should NOT have been updated since field didn't change
        Opportunity updatedOpp = [SELECT From_Converted_Lead__c FROM Opportunity WHERE Id = :testOpp.Id];
        System.assertEquals(null, updatedOpp.From_Converted_Lead__c, 'Opp should not sync when field unchanged');
    }

    @isTest
    static void testOppToLeadSkipsWhenNoChange() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead4',
            Company = 'Test Company'
        );
        insert testLead;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp 4',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert testOpp;

        // Both old and new have same value - no change
        Opportunity oldOpp = testOpp.clone(true, true, true, true);
        oldOpp.From_Converted_Lead__c = testLead.Id;
        testOpp.From_Converted_Lead__c = testLead.Id;

        Map<Id, Opportunity> oldOppMap = new Map<Id, Opportunity>();
        oldOppMap.put(testOpp.Id, oldOpp);

        List<Opportunity> newOpps = new List<Opportunity>{ testOpp };

        Test.startTest();
        ConversionSyncHelper.syncOpportunityToLead(newOpps, oldOppMap);
        Test.stopTest();

        Lead updatedLead = [SELECT Converted_Opportunity__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(null, updatedLead.Converted_Opportunity__c, 'Lead should not sync when field unchanged');
    }

    @isTest
    static void testLeadToOppNullField() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());

        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead5',
            Company = 'Test Company'
        );
        insert testLead;

        // Both old and new are null
        Lead oldLead = testLead.clone(true, true, true, true);
        oldLead.Converted_Opportunity__c = null;
        testLead.Converted_Opportunity__c = null;

        Map<Id, Lead> oldLeadMap = new Map<Id, Lead>();
        oldLeadMap.put(testLead.Id, oldLead);

        List<Lead> newLeads = new List<Lead>{ testLead };

        Test.startTest();
        ConversionSyncHelper.syncLeadToOpportunity(newLeads, oldLeadMap);
        Test.stopTest();

        // Should complete without error
        System.assert(true, 'No error when field is null');
    }

    @isTest
    static void testHelperStaticFlags() {
        System.assertEquals(false, ConversionSyncHelper.getIsLeadUpdating());
        System.assertEquals(false, ConversionSyncHelper.getIsOppUpdating());
    }

    @isTest
    static void testBulkLeadToOppDirect() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                FirstName = 'Bulk' + i,
                LastName = 'Lead',
                Company = 'Co'
            ));
        }
        insert leads;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 5; i++) {
            opps.add(new Opportunity(
                Name = 'BulkOpp' + i,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30)
            ));
        }
        insert opps;

        // Build old/new maps
        Map<Id, Lead> oldLeadMap = new Map<Id, Lead>();
        List<Lead> newLeads = new List<Lead>();

        for (Integer i = 0; i < 5; i++) {
            Lead oldLead = leads.get(i).clone(true, true, true, true);
            oldLead.Converted_Opportunity__c = null;
            oldLeadMap.put(leads.get(i).Id, oldLead);

            leads.get(i).Converted_Opportunity__c = opps.get(i).Id;
            newLeads.add(leads.get(i));
        }

        Test.startTest();
        ConversionSyncHelper.syncLeadToOpportunity(newLeads, oldLeadMap);
        Test.stopTest();

        List<Opportunity> syncedOpps = [SELECT From_Converted_Lead__c FROM Opportunity WHERE Id IN :opps];
        System.assertEquals(5, syncedOpps.size());
        for (Opportunity o : syncedOpps) {
            System.assertNotEquals(null, o.From_Converted_Lead__c);
        }
    }
}