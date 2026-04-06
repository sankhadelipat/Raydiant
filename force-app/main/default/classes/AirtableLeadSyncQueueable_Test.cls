@IsTest
private class AirtableLeadSyncQueueable_Test {

    // -------------------------
    // Callout mock
    // -------------------------
    private class AirtableMock implements HttpCalloutMock {
        private Integer code;
        private String body;
        AirtableMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    // -------------------------
    // Hierarchy Custom Setting Org Defaults helper
    // FIX: treat cfg.Id == null as "not inserted yet"
    // -------------------------
    private static Airtable_Sync_Settings__c ensureOrgDefaults(Integer pageSize, String offsetVal) {
        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();

        if (cfg == null || cfg.Id == null) {
            cfg = new Airtable_Sync_Settings__c();
            cfg.SetupOwnerId = UserInfo.getOrganizationId(); // org defaults row
            cfg.PageSize__c = pageSize;
            cfg.Offset__c = offsetVal;
            insert cfg;
        } else {
            cfg.PageSize__c = pageSize;
            cfg.Offset__c = offsetVal;
            update cfg;
        }
        return cfg;
    }

    private static Lead makeExistingLead(String airtableId) {
        Lead l = new Lead(
            LastName = 'Existing',
            Company  = 'Existing Co',
            Airtable_Record_ID__c = airtableId
        );
        insert l;
        return l;
    }

    // -------------------------
    // TEST 1: UPDATE + INSERT in one run
    // -------------------------
    @IsTest
    static void testQueueable_InsertAndUpdate_CoversMostBranches() {
        ensureOrgDefaults(20, null);

        makeExistingLead('recEXIST');

        String body =
        '{ "records": [' +
          '{ "id":"recEXIST", "fields": {' +
            '"Booked":"checked",' +
            '"Attended":"true",' +
            '"Canceled":"0",' +
            '"No Showed":"1",' +
            '"Not ICP": true,' +
            '"Meeting Date":"2025-12-01T16:00:00.000Z",' +
            '"Meeting Timezone":"ET",' +
            '"Company Name":"Existing Co Updated",' +
            '"Prospect Last Name":"Existing"' +
          '}},' +
          '{ "id":"recNEW", "fields": {' +
            '"Booked":true,' +
            '"Attended":false,' +
            '"Canceled":"false",' +
            '"No Showed":"no",' +
            '"Not ICP":"checked",' +
            '"Meeting Date":"2025-12-02T18:30:00.000Z",' +
            '"Meeting Timezone":"PT",' +
            '"Company Name":"New Co",' +
            '"Prospect Last Name":"New"' +
          '}}' +
        '], "offset":"itrNEXT" }';

        Test.setMock(HttpCalloutMock.class, new AirtableMock(200, body));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(20, false, null));
        Test.stopTest();

        List<Lead> leads = [
            SELECT Id, Airtable_Record_ID__c, Not_ICP__c, Last_OBS_Update__c
            FROM Lead
            WHERE Airtable_Record_ID__c IN ('recEXIST','recNEW')
        ];
        System.assertEquals(2, leads.size());

        Map<String, Lead> byId = new Map<String, Lead>();
        for (Lead l : leads) byId.put(l.Airtable_Record_ID__c, l);

        System.assertEquals('1', byId.get('recEXIST').Not_ICP__c);
        System.assertEquals('1', byId.get('recNEW').Not_ICP__c);

        System.assertNotEquals(null, byId.get('recEXIST').Last_OBS_Update__c);
        System.assertNotEquals(null, byId.get('recNEW').Last_OBS_Update__c);

        Airtable_Sync_Settings__c cfgAfter = Airtable_Sync_Settings__c.getOrgDefaults();
        System.assertEquals('itrNEXT', cfgAfter.Offset__c);
    }

    // -------------------------
    // TEST 2: Empty records branch
    // -------------------------
    @IsTest
    static void testQueueable_EmptyRecords_UpdatesOffset() {
        ensureOrgDefaults(20, 'itrOLD');

        String body = '{ "records": [], "offset":"itrNEW" }';
        Test.setMock(HttpCalloutMock.class, new AirtableMock(200, body));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(20, false, null));
        Test.stopTest();

        Airtable_Sync_Settings__c cfgAfter = Airtable_Sync_Settings__c.getOrgDefaults();
        System.assertEquals('itrNEW', cfgAfter.Offset__c);
    }

    // -------------------------
    // TEST 3: records == null branch (missing key)
    // -------------------------
    @IsTest
    static void testQueueable_RecordsNullBranch() {
        ensureOrgDefaults(20, null);

        String body = '{ "offset":"itrONLY" }';
        Test.setMock(HttpCalloutMock.class, new AirtableMock(200, body));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(20, false, null));
        Test.stopTest();

        Airtable_Sync_Settings__c cfgAfter = Airtable_Sync_Settings__c.getOrgDefaults();
        System.assertEquals('itrONLY', cfgAfter.Offset__c);
    }

    // -------------------------
    // TEST 4: non-2xx does not throw
    // -------------------------
    @IsTest
    static void testQueueable_Non2xxDoesNotThrow() {
        ensureOrgDefaults(20, null);

        Test.setMock(HttpCalloutMock.class, new AirtableMock(500, '{"error":"server"}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(20, false, null));
        Test.stopTest();

        System.assert(true);
    }

    // -------------------------
    // TEST 5: scheduler compiles / schedules
    // -------------------------
    @IsTest
    static void testScheduler_Schedules() {
        ensureOrgDefaults(20, null);

        Test.startTest();
        String jobId = System.schedule(
            'Airtable Scheduler Test',
            '0 0 0 1 1 ? 2099',
            new AirtableLeadSyncScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}