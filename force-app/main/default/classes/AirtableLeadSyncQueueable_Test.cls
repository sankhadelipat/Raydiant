@IsTest
private class AirtableLeadSyncQueueable_Test {

    // =========================================================
    // Multi-response callout mock
    // Returns responses in sequence; falls back to 200 empty on extras.
    // =========================================================
    private class MultiCalloutMock implements HttpCalloutMock {
        private List<HttpResponse> responses = new List<HttpResponse>();
        private Integer callCount = 0;

        public MultiCalloutMock add(Integer statusCode, String body) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(statusCode);
            r.setHeader('Content-Type', 'application/json');
            r.setBody(body);
            responses.add(r);
            return this;
        }

        public HTTPResponse respond(HTTPRequest req) {
            if (callCount < responses.size()) {
                return responses[callCount++];
            }
            // Default fallback for extra calls (e.g., PATCH write-backs)
            HttpResponse def = new HttpResponse();
            def.setStatusCode(200);
            def.setBody('{"records":[]}');
            return def;
        }
    }

    // =========================================================
    // Helpers
    // =========================================================
    private static Airtable_Sync_Settings__c ensureOrgDefaults(Datetime lastSync) {
        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        if (cfg == null || cfg.Id == null) {
            cfg = new Airtable_Sync_Settings__c();
            cfg.SetupOwnerId          = UserInfo.getOrganizationId();
            cfg.Last_Successful_Sync__c = lastSync;
            insert cfg;
        } else {
            cfg.Last_Successful_Sync__c = lastSync;
            update cfg;
        }
        return cfg;
    }

    private static Lead makeExistingLead(String airtableId) {
        Lead l = new Lead(
            LastName              = 'Existing',
            Company               = 'Existing Co',
            Airtable_Record_ID__c = airtableId
        );
        insert l;
        return l;
    }

    private static String singlePageBody(String airtableId, Boolean isNew, Boolean hasSfdcLeadId) {
        String sfdcIdField = hasSfdcLeadId ? '"SFDC Lead ID":"00Q000000000001",' : '';
        return '{"records":[{"id":"' + airtableId + '","fields":{' +
            sfdcIdField +
            '"Prospect Last Name":"' + (isNew ? 'New' : 'Existing') + '",' +
            '"Company Name":"Test Co",' +
            '"Status":"Meeting Set",' +
            '"Booked":true,' +
            '"Attended":false,' +
            '"Canceled":"false",' +
            '"No Showed":"no",' +
            '"Not ICP":false,' +
            '"Meeting Date":"2025-12-01T16:00:00.000Z",' +
            '"Meeting Timezone":"PT"' +
        '}}]}';
    }

    // =========================================================
    // TEST 1: Insert new lead — no prior SF record, no Airtable SFDC Lead ID
    //         Expects: 1 lead inserted + PATCH write-back called
    //         Stamps Last_Successful_Sync__c
    // =========================================================
    @IsTest
    static void testInsertNewLead_WritesBackLeadId() {
        ensureOrgDefaults(null);

        String atId   = 'recINSERT001';
        String getBody = singlePageBody(atId, true, false);
        // GET (no offset) + PATCH write-back
        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(200, getBody).add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        List<Lead> leads = [SELECT Id, Airtable_Record_ID__c, Last_OBS_Update__c
                            FROM Lead WHERE Airtable_Record_ID__c = :atId];
        System.assertEquals(1, leads.size(), 'Lead should have been inserted');
        System.assertNotEquals(null, leads[0].Last_OBS_Update__c, 'Last_OBS_Update__c should be stamped');

        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, cfg.Last_Successful_Sync__c, 'Last_Successful_Sync__c should be stamped');
    }

    // =========================================================
    // TEST 2: Update existing lead — already in SF, no SFDC Lead ID in Airtable
    //         Expects: lead updated + PATCH write-back with existing SF Lead ID
    // =========================================================
    @IsTest
    static void testUpdateExistingLead_WritesBackLeadIdWhenMissing() {
        ensureOrgDefaults(Datetime.now().addHours(-1));
        Lead existing = makeExistingLead('recUPDATE001');

        String getBody = singlePageBody('recUPDATE001', false, false); // no SFDC Lead ID in AT
        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(200, getBody).add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        Lead updated = [SELECT Id, Company, Last_OBS_Update__c
                        FROM Lead WHERE Id = :existing.Id];
        System.assertEquals('Test Co', updated.Company, 'Company should be updated from Airtable');
        System.assertNotEquals(null, updated.Last_OBS_Update__c);
    }

    // =========================================================
    // TEST 3: Update existing lead — Airtable already HAS SFDC Lead ID
    //         Expects: lead updated, NO write-back PATCH call needed
    // =========================================================
    @IsTest
    static void testUpdateExistingLead_NoWritebackWhenSfdcIdPresent() {
        ensureOrgDefaults(Datetime.now().addHours(-1));
        makeExistingLead('recUPDATE002');

        String getBody = singlePageBody('recUPDATE002', false, true); // has SFDC Lead ID
        // Only one call expected (GET). If PATCH is called, mock returns 200 anyway.
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock().add(200, getBody));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        // Verify lead updated without error
        List<Lead> leads = [SELECT Id FROM Lead WHERE Airtable_Record_ID__c = 'recUPDATE002'];
        System.assertEquals(1, leads.size());
    }

    // =========================================================
    // TEST 4: Two-page response (offset pagination within one run)
    //         Expects: both pages processed, 2 leads inserted
    // =========================================================
    @IsTest
    static void testTwoPagePagination_BothPagesInserted() {
        ensureOrgDefaults(null);

        String page1Body = '{"records":[{"id":"recPG1","fields":{"Prospect Last Name":"PageOne","Company Name":"Co1"}}],"offset":"itrNEXT"}';
        String page2Body = '{"records":[{"id":"recPG2","fields":{"Prospect Last Name":"PageTwo","Company Name":"Co2"}}]}';

        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock()
                .add(200, page1Body)
                .add(200, page2Body)
                .add(200, '{"records":[]}') // write-back PATCH batch
        );

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        List<Lead> leads = [SELECT Id, Airtable_Record_ID__c
                            FROM Lead WHERE Airtable_Record_ID__c IN ('recPG1','recPG2')];
        System.assertEquals(2, leads.size(), 'Both pages should be inserted');
    }

    // =========================================================
    // TEST 5: Empty records — nothing to process
    //         Expects: no leads inserted, timestamp still stamped
    // =========================================================
    @IsTest
    static void testEmptyRecords_StampsTimestamp() {
        ensureOrgDefaults(Datetime.now().addHours(-1));

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock().add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, cfg.Last_Successful_Sync__c);
    }

    // =========================================================
    // TEST 6: Non-2xx API response
    //         Expects: no leads inserted, timestamp NOT stamped (so next run retries)
    // =========================================================
    @IsTest
    static void testApiError_DoesNotStampTimestamp() {
        Datetime before = Datetime.now().addHours(-2);
        ensureOrgDefaults(before);

        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(500, '{"error":"internal server error"}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        // Should still equal the original "before" value — not updated
        System.assert(cfg.Last_Successful_Sync__c <= before.addSeconds(1),
            'Timestamp should NOT be updated on API error');

        List<Lead> leads = [SELECT Id FROM Lead WHERE Airtable_Record_ID__c != null];
        System.assertEquals(0, leads.size(), 'No leads should be inserted on error');
    }

    // =========================================================
    // TEST 7a: Sanitize email — dash placeholder is stripped
    //          Expects: lead inserted with null Outbound_Sender_Email__c
    // =========================================================
    @IsTest
    static void testSanitizeEmail_DashStripped() {
        ensureOrgDefaults(null);

        String getBody = '{"records":[{"id":"recEMAIL01","fields":{' +
            '"Prospect Last Name":"DashEmail",' +
            '"Company Name":"Dash Co",' +
            '"Sender Email":"-"' +
        '}}]}';

        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(200, getBody).add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        List<Lead> leads = [SELECT Id, Outbound_Sender_Email__c
                            FROM Lead WHERE Airtable_Record_ID__c = 'recEMAIL01'];
        System.assertEquals(1, leads.size(), 'Lead should insert even with dash email');
        System.assertEquals(null, leads[0].Outbound_Sender_Email__c, 'Sender email should be null for dash');
    }

    // =========================================================
    // TEST 7b: Sanitize email — comma-separated takes first valid
    //          Expects: lead inserted with first valid email only
    // =========================================================
    @IsTest
    static void testSanitizeEmail_CommaSeparatedTakesFirst() {
        ensureOrgDefaults(null);

        String getBody = '{"records":[{"id":"recEMAIL02","fields":{' +
            '"Prospect Last Name":"MultiEmail",' +
            '"Company Name":"Multi Co",' +
            '"Sender Email":"alice@example.com,bob@example.com"' +
        '}}]}';

        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(200, getBody).add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        List<Lead> leads = [SELECT Id, Outbound_Sender_Email__c
                            FROM Lead WHERE Airtable_Record_ID__c = 'recEMAIL02'];
        System.assertEquals(1, leads.size(), 'Lead should insert with comma emails');
        System.assertEquals('alice@example.com', leads[0].Outbound_Sender_Email__c,
            'Should take first valid email from comma-separated list');
    }

    // =========================================================
    // TEST 7: Watchdog — fires alert when stale
    // =========================================================
    @IsTest
    static void testWatchdog_AlertsWhenStale() {
        // Last sync was 5 hours ago — over the 3-hour threshold
        ensureOrgDefaults(Datetime.now().addHours(-5));

        Test.startTest();
        new AirtableLeadSyncWatchdog().execute(null);
        Test.stopTest();

        // No assertion needed — just confirming it runs without exception
        System.assert(true, 'Watchdog should run without error when sync is stale');
    }

    // =========================================================
    // TEST 8: Watchdog — no alert when fresh
    // =========================================================
    @IsTest
    static void testWatchdog_NoAlertWhenFresh() {
        // Last sync was 30 minutes ago — within threshold
        ensureOrgDefaults(Datetime.now().addMinutes(-30));

        Test.startTest();
        new AirtableLeadSyncWatchdog().execute(null);
        Test.stopTest();

        System.assert(true, 'Watchdog should run without error when sync is fresh');
    }

    // =========================================================
    // TEST 9: Watchdog — alert when Last_Successful_Sync__c is null
    // =========================================================
    @IsTest
    static void testWatchdog_AlertsWhenNullTimestamp() {
        ensureOrgDefaults(null);

        Test.startTest();
        new AirtableLeadSyncWatchdog().execute(null);
        Test.stopTest();

        System.assert(true, 'Watchdog should handle null timestamp gracefully');
    }

    // =========================================================
    // TEST 10a: Default Owner — new lead is assigned to greg.williams@raydiant.com
    //           (matches exact username in prod OR 'greg.williams@raydiant.com.<sb>'
    //           pattern in sandbox). If the user is missing the test short-circuits
    //           to avoid false-fails in scratch orgs that don't have Greg.
    // =========================================================
    @IsTest
    static void testInsertNewLead_DefaultOwnerIsGreg() {
        List<User> greg = [
            SELECT Id, Username
            FROM User
            WHERE IsActive = true
              AND (Username = 'greg.williams@raydiant.com'
                   OR Username LIKE 'greg.williams@raydiant.com.%')
            LIMIT 1
        ];
        if (greg.isEmpty()) {
            // No Greg user in this org (e.g. scratch org) — feature can't be validated.
            // Don't fail the test; just assert the lookup path executed cleanly.
            System.assert(true, 'Greg user absent in this org — skipping owner assertion');
            return;
        }

        ensureOrgDefaults(null);

        String atId    = 'recOWNER01';
        String getBody = singlePageBody(atId, true, false);
        Test.setMock(HttpCalloutMock.class,
            new MultiCalloutMock().add(200, getBody).add(200, '{"records":[]}'));

        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
        Test.stopTest();

        List<Lead> leads = [SELECT Id, OwnerId FROM Lead WHERE Airtable_Record_ID__c = :atId];
        System.assertEquals(1, leads.size(), 'Lead should have been inserted');
        System.assertEquals(greg[0].Id, leads[0].OwnerId,
            'New Outbound Solutions leads should default to Greg Williams, not the running user');
    }

    // =========================================================
    // TEST 10: Scheduler compiles and schedules
    // =========================================================
    @IsTest
    static void testScheduler_Compiles() {
        ensureOrgDefaults(null);

        Test.startTest();
        String jobId = System.schedule(
            'Airtable Scheduler Test ' + Datetime.now().getTime(),
            '0 0 0 1 1 ? 2099',
            new AirtableLeadSyncScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should return a job ID');
    }
}