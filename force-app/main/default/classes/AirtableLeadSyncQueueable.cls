/**
 * AirtableLeadSyncQueueable — v3 (Date-Filter, Chained Write-Back)
 *
 * What changed from v2:
 *  - Write-back (PATCH SF Lead ID to Airtable) moved to a chained Queueable
 *    (AirtableLeadSyncWriteback) to avoid "uncommitted work pending" error.
 *    Salesforce prohibits callouts after DML in the same transaction.
 *  - Removed writeBackLeadIds() method from this class.
 *  - On success: stamps Last_Successful_Sync__c = NOW (used by both the filter
 *    next run and the watchdog).
 *
 * REQUIRED SETUP:
 *  - Named Credential: Outbound_Airtable (URL = https://api.airtable.com)
 *  - Airtable_Sync_Settings__c Hierarchy Custom Setting — Org Defaults row with
 *    Last_Successful_Sync__c (DateTime) field
 *  - Airtable table must have a "SFDC Lead ID" text field (add manually in Airtable)
 *  - Lead field: Airtable_Record_ID__c (Text; Unique recommended)
 *
 * MANUAL CATCHUP (Dev Console):
 *  System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
 *  -- To force a full re-sync from scratch, first clear Last_Successful_Sync__c:
 *  Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
 *  cfg.Last_Successful_Sync__c = null; update cfg;
 *  System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
 */
public with sharing class AirtableLeadSyncQueueable implements Queueable, Database.AllowsCallouts {

    // =========================
    // CONFIG — edit here
    // =========================
    private static final String  BASE_ID           = 'appYMsTqt5BPSDf5z';
    private static final String  TABLE_ID          = 'tblxFmAekGMYnuRR6';
    private static final String  NC_CALLOUT_PREFIX = 'callout:Outbound_Airtable';
    private static final Integer PAGE_SIZE         = 100;
    private static final String  ALERT_EMAIL       = 'blake.reeves@displai.ai';
    private static final String  AT_SFDC_LEAD_ID   = 'SFDC Lead ID'; // exact Airtable field name

    // Airtable field names
    private static final String AT_INITIAL_DATE         = 'Initial Date';
    private static final String AT_STATUS               = 'Status';
    private static final String AT_LAST_MODIFIED_DT     = 'Last Modified by Date & Time';
    private static final String AT_COMPANY_NAME         = 'Company Name';
    private static final String AT_INDUSTRY             = 'Industry';
    private static final String AT_INITIAL_REPLY        = 'Initial Reply';
    private static final String AT_NOTES               = 'Notes';
    private static final String AT_COLD_CALL_SUMMARY    = 'Cold Call Summary';
    private static final String AT_MEETING_DATE         = 'Meeting Date';
    private static final String AT_MEETING_TIMEZONE     = 'Meeting Timezone';
    private static final String AT_BOOKED               = 'Booked';
    private static final String AT_ATTENDED             = 'Attended';
    private static final String AT_CANCELED             = 'Canceled';
    private static final String AT_NO_SHOWED            = 'No Showed';
    private static final String AT_NOT_ICP              = 'Not ICP';
    private static final String AT_DO_NOT_CALL          = 'Do Not Call';
    private static final String AT_SENDER_EMAIL         = 'Sender Email';
    private static final String AT_LOCATION             = 'Location';
    private static final String AT_COMPANY_URL          = 'Company URL';
    private static final String AT_PROSPECT_FIRST_NAME  = 'Prospect First Name';
    private static final String AT_PROSPECT_LAST_NAME   = 'Prospect Last Name';
    private static final String AT_PROSPECT_TITLE       = 'Prospect Title';
    private static final String AT_PROSPECT_EMAIL       = 'Prospect Email';
    private static final String AT_LINKEDIN_PROFILE     = 'Linkedin Profile';
    private static final String AT_CAMPAIGN_NAME        = 'Campaign Name';
    private static final String AT_BETTERCONTACT_NUMBER = 'BetterContact Number';
    private static final String AT_SOURCE               = 'Source';
    private static final String AT_DOMAIN               = 'Domain';

    // SF Lead field API names
    private static final String SF_OUTBOUND_INITIAL_DATE  = 'Outbound_Initial_Date__c';
    private static final String SF_OUTBOUND_STATUS        = 'Outbound_Solutions_Status__c';
    private static final String SF_OUTBOUND_MEETING_DATE  = 'Outbound_Meeting_Date__c';
    private static final String SF_OUTBOUND_MEETING_TZ    = 'Outbound_Meeting_Timezone__c';
    private static final String SF_OUTBOUND_BOOKED        = 'Outbound_Booked__c';
    private static final String SF_OUTBOUND_ATTENDED      = 'Outbound_Attended__c';
    private static final String SF_OUTBOUND_CANCELED      = 'Outbound_Canceled__c';
    private static final String SF_OUTBOUND_NO_SHOWED     = 'Outbound_No_Showed__c';
    private static final String SF_NOT_ICP                = 'Not_ICP__c';
    private static final String SF_OUTBOUND_DNC           = 'Outbound_DNC__c';
    private static final String SF_OUTBOUND_SENDER_EMAIL  = 'Outbound_Sender_Email__c';
    private static final String SF_LINKEDIN_URL           = 'LinkedIn_Contact_Profile_URL__c';
    private static final String SF_OUTBOUND_CAMPAIGN      = 'Outbound_Campaign__c';
    private static final String SF_OUTBOUND_SOURCE        = 'Outbound_Source__c';
    private static final String SF_OUTBOUND_INITIAL_REPLY = 'Outbound_Initial_Reply__c';
    private static final String SF_OUTBOUND_NOTES         = 'Outbound_Notes__c';
    private static final String SF_LEAD_DOMAIN            = 'Lead_Domain__c';
    private static final String SF_OUTBOUND_COLD_SUMMARY  = 'Outbound_Cold_Call_Summary__c';
    private static final String SF_OUTBOUND_LAST_MODIFIED = 'Outbound_Last_Modified__c';
    private static final String SF_ASSIGNED_DT            = 'Assigned__c';
    private static final String SF_LAST_OBS_UPDATE        = 'Last_OBS_Update__c';
    private static final String SF_LEAD_ASSIGNED          = 'Lead_Assigned__c';
    private static final String SF_SOURCE_DETAIL          = 'Lead_Source_Detail__c';

    // Defaults applied on insert (or if blank on update)
    // Resolved at runtime from DEFAULT_OWNER_USERNAME (sandbox-safe — tolerates
    // the '.sandboxname' suffix Salesforce appends in sandboxes).
    private static final String DEFAULT_OWNER_USERNAME = 'greg.williams@raydiant.com';
    private static final String DEFAULT_STATUS_VALUE   = 'Assigned';
    private static final String DEFAULT_SOURCE_VALUE   = 'Outbound Solutions';

    // Constructor signature kept compatible with existing scheduler
    public AirtableLeadSyncQueueable(Integer unused1, Boolean unused2, String unused3) {}

    // =========================
    // EXECUTE
    // =========================
    public void execute(QueueableContext qc) {
        try {
            runInternal();
        } catch (Exception e) {
            String msg = 'Message: ' + e.getMessage() + '\n\nStack:\n' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, 'AIRTABLE_SYNC_FATAL: ' + msg);
            sendErrorEmail('Airtable Lead Sync — Fatal Error', msg);
        }
    }

    // =========================
    // CORE LOGIC
    // =========================
    private void runInternal() {
        Map<String, Schema.SObjectField> leadFieldMap = Lead.SObjectType.getDescribe().fields.getMap();
        Datetime nowDt = System.now();

        // Resolve default owner by Username (sandbox vs prod safe).
        // In sandboxes Salesforce appends '.<sandboxname>' to every username, so
        // we match the exact username OR the username + '.' + anything.
        Id   defaultOwnerId       = null;
        Boolean defaultOwnerIsValid = false;
        try {
            String sandboxPattern = DEFAULT_OWNER_USERNAME + '.%';
            List<User> defaultOwners = [
                SELECT Id
                FROM User
                WHERE IsActive = true
                  AND (Username = :DEFAULT_OWNER_USERNAME
                       OR Username LIKE :sandboxPattern)
                LIMIT 1
            ];
            if (!defaultOwners.isEmpty()) {
                defaultOwnerId      = defaultOwners[0].Id;
                defaultOwnerIsValid = true;
            }
        } catch (Exception e) {
            defaultOwnerIsValid = false;
        }

        // Load / create org-defaults custom setting row
        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Airtable_Sync_Settings__c();
            cfg.SetupOwnerId = UserInfo.getOrganizationId();
            insert cfg;
        }
        Datetime lastSync = cfg.Last_Successful_Sync__c;

        // -------------------------------------------------------
        // STEP 1: Pull all matching records from Airtable
        //         Paginate entirely within this transaction using
        //         in-memory temp offsets — no expiry risk.
        // -------------------------------------------------------
        List<Map<String, Object>> allRecords = new List<Map<String, Object>>();
        String tempOffset = null;

        do {
            HttpResponse res = callAirtableGet(lastSync, tempOffset);
            if (res == null) return; // callout exception — email already sent

            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                sendErrorEmail(
                    'Airtable Lead Sync — API Error ' + res.getStatusCode(),
                    'Airtable returned HTTP ' + res.getStatusCode() +
                    '\n\nResponse body:\n' + res.getBody() +
                    '\n\nLast successful sync was: ' +
                    (lastSync == null ? 'never (first run or reset)' : String.valueOf(lastSync))
                );
                return; // do NOT stamp Last_Successful_Sync__c
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> pageRecords   = (List<Object>) parsed.get('records');
            tempOffset                 = (String) parsed.get('offset');

            if (pageRecords != null) {
                for (Object o : pageRecords) {
                    allRecords.add((Map<String, Object>) o);
                }
            }
        } while (!String.isBlank(tempOffset));

        System.debug('AIRTABLE_TOTAL_RECORDS_THIS_RUN=' + allRecords.size());

        if (allRecords.isEmpty()) {
            cfg.Last_Successful_Sync__c = nowDt;
            update cfg;
            return;
        }

        // -------------------------------------------------------
        // STEP 2: Build upsert lists
        // -------------------------------------------------------
        Set<String> airtableIds = new Set<String>();
        for (Map<String, Object> rec : allRecords) {
            String recId = (String) rec.get('id');
            if (!String.isBlank(recId)) airtableIds.add(recId);
        }

        List<Lead> existingLeads = [
            SELECT Id, Airtable_Record_ID__c, OwnerId, Status, LeadSource,
                   Assigned__c, Last_OBS_Update__c, Lead_Assigned__c, Lead_Source_Detail__c
            FROM Lead
            WHERE Airtable_Record_ID__c IN :airtableIds
        ];
        Map<String, Lead> leadByAirtableId = new Map<String, Lead>();
        for (Lead l : existingLeads) leadByAirtableId.put(l.Airtable_Record_ID__c, l);

        List<Lead>    toInsert             = new List<Lead>();
        List<Lead>    toUpdate             = new List<Lead>();
        Map<Integer, String> insertIdxToAtId = new Map<Integer, String>(); // for post-insert ID lookup
        Map<String, String>  writebackMap    = new Map<String, String>();  // airtableId -> sfLeadId

        for (Map<String, Object> rec : allRecords) {
            String recId = (String) rec.get('id');
            if (String.isBlank(recId)) continue;

            Map<String, Object> f = (Map<String, Object>) rec.get('fields');
            if (f == null) f = new Map<String, Object>();

            Lead    existing = leadByAirtableId.get(recId);
            Boolean isInsert = (existing == null);
            Lead    l        = isInsert ? new Lead() : existing;
            SObject ls       = (SObject) l;

            l.Airtable_Record_ID__c = recId;

            // Date fields
            String initDate = getStr(f, AT_INITIAL_DATE);
            if (!String.isBlank(initDate) && leadFieldMap.containsKey(SF_OUTBOUND_INITIAL_DATE)) {
                ls.put(SF_OUTBOUND_INITIAL_DATE, initDate.trim());
            }
            String rawMeetingIso = getStr(f, AT_MEETING_DATE);
            String mtz = getStr(f, AT_MEETING_TIMEZONE);
            if (!String.isBlank(rawMeetingIso) && leadFieldMap.containsKey(SF_OUTBOUND_MEETING_DATE)) {
                ls.put(SF_OUTBOUND_MEETING_DATE, formatUtcToReadable(rawMeetingIso.trim(), mtz));
            }
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_MEETING_TZ,    mtz);
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_LAST_MODIFIED, getStr(f, AT_LAST_MODIFIED_DT));

            // Standard lead fields
            setStringIfPresent(ls, leadFieldMap, 'Company',   getStr(f, AT_COMPANY_NAME));
            setStringIfPresent(ls, leadFieldMap, 'Industry',  getStr(f, AT_INDUSTRY));
            setStringIfPresent(ls, leadFieldMap, 'FirstName', getStr(f, AT_PROSPECT_FIRST_NAME));
            setStringIfPresent(ls, leadFieldMap, 'LastName',  getStr(f, AT_PROSPECT_LAST_NAME));
            setStringIfPresent(ls, leadFieldMap, 'Title',     getStr(f, AT_PROSPECT_TITLE));
            setStringIfPresent(ls, leadFieldMap, 'Email',     getStr(f, AT_PROSPECT_EMAIL));
            setStringIfPresent(ls, leadFieldMap, 'Phone',     getStr(f, AT_BETTERCONTACT_NUMBER));
            setStringIfPresent(ls, leadFieldMap, 'Website',   getStr(f, AT_COMPANY_URL));
            setStringIfPresent(ls, leadFieldMap, 'City',      getStr(f, AT_LOCATION));

            // Custom fields
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_STATUS,        getStr(f, AT_STATUS));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_BOOKED,        getFlag01(f, AT_BOOKED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_ATTENDED,      getFlag01(f, AT_ATTENDED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_CANCELED,      getFlag01(f, AT_CANCELED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_NO_SHOWED,     getFlag01(f, AT_NO_SHOWED));
            setStringIfPresent(ls, leadFieldMap, SF_NOT_ICP,                getFlag01(f, AT_NOT_ICP));
            setBooleanIfPresent(ls, leadFieldMap, SF_OUTBOUND_DNC,          getBool(f, AT_DO_NOT_CALL));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_SENDER_EMAIL,  sanitizeEmail(getStr(f, AT_SENDER_EMAIL)));
            setStringIfPresent(ls, leadFieldMap, SF_LINKEDIN_URL,           getStr(f, AT_LINKEDIN_PROFILE));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_CAMPAIGN,      getStr(f, AT_CAMPAIGN_NAME));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_SOURCE,        getStr(f, AT_SOURCE));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_INITIAL_REPLY, getStr(f, AT_INITIAL_REPLY));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_NOTES,         getStr(f, AT_NOTES));
            setStringIfPresent(ls, leadFieldMap, SF_LEAD_DOMAIN,            getStr(f, AT_DOMAIN));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_COLD_SUMMARY,  getStr(f, AT_COLD_CALL_SUMMARY));

            // Required fields for insert
            if (isInsert) {
                if (String.isBlank((String) ls.get('LastName'))) ls.put('LastName', 'Unknown');
                if (String.isBlank((String) ls.get('Company')))  ls.put('Company',  'Unknown');
            }

            // Timestamps & defaults
            if (leadFieldMap.containsKey(SF_ASSIGNED_DT) && (isInsert || ls.get(SF_ASSIGNED_DT) == null)) {
                ls.put(SF_ASSIGNED_DT, nowDt);
            }
            if (leadFieldMap.containsKey(SF_LAST_OBS_UPDATE)) {
                ls.put(SF_LAST_OBS_UPDATE, nowDt);
            }
            if (leadFieldMap.containsKey(SF_LEAD_ASSIGNED) && (isInsert || ls.get(SF_LEAD_ASSIGNED) == null)) {
                ls.put(SF_LEAD_ASSIGNED, true);
            }
            if (leadFieldMap.containsKey(SF_SOURCE_DETAIL) &&
                (isInsert || String.isBlank((String) ls.get(SF_SOURCE_DETAIL)))) {
                ls.put(SF_SOURCE_DETAIL, DEFAULT_SOURCE_VALUE);
            }
            if (isInsert || String.isBlank((String) ls.get('LeadSource'))) {
                ls.put('LeadSource', DEFAULT_SOURCE_VALUE);
            }
            if (isInsert || String.isBlank((String) ls.get('Status'))) {
                ls.put('Status', DEFAULT_STATUS_VALUE);
            }
            if ((isInsert || String.isBlank((String) ls.get('OwnerId'))) && defaultOwnerIsValid) {
                ls.put('OwnerId', defaultOwnerId);
            }

            if (isInsert) {
                insertIdxToAtId.put(toInsert.size(), recId);
                toInsert.add(l);
            } else {
                toUpdate.add(l);
                // Write back SF Lead ID if Airtable doesn't have it yet
                if (String.isBlank(getStr(f, AT_SFDC_LEAD_ID))) {
                    writebackMap.put(recId, l.Id);
                }
            }
        }

        // -------------------------------------------------------
        // STEP 3: DML
        // -------------------------------------------------------
        if (!toInsert.isEmpty()) {
            List<Database.SaveResult> insertResults = Database.insert(toInsert, false);
            List<String> insertErrors = new List<String>();

            for (Integer i = 0; i < insertResults.size(); i++) {
                Database.SaveResult sr = insertResults[i];
                String atId = insertIdxToAtId.get(i);
                if (sr.isSuccess()) {
                    writebackMap.put(atId, sr.getId()); // new lead — always write back
                } else {
                    List<String> msgs = new List<String>();
                    for (Database.Error e : sr.getErrors()) msgs.add(e.getMessage());
                    insertErrors.add('Airtable ID ' + atId + ': ' + String.join(msgs, '; '));
                }
            }

            if (!insertErrors.isEmpty()) {
                // Non-fatal: alert but don't abort — still stamp success for records that worked
                sendErrorEmail(
                    'Airtable Lead Sync — ' + insertErrors.size() + ' Insert Error(s)',
                    'These Airtable records failed to create as SF Leads:\n\n' +
                    String.join(insertErrors, '\n')
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
        // -------------------------------------------------------
        // STEP 4: Stamp success -- watchdog reads this
        // -------------------------------------------------------
        cfg.Last_Successful_Sync__c = nowDt;
        update cfg;

        // -------------------------------------------------------
        // STEP 5: Enqueue write-back job (runs in separate transaction)
        //         Chained Queueable avoids callout-after-DML governor limit
        // -------------------------------------------------------
        if (!writebackMap.isEmpty()) {
            System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
        }

        System.debug('AIRTABLE_SYNC_COMPLETE inserted=' + toInsert.size() +
                     ' updated=' + toUpdate.size() +
                     ' writebacks_queued=' + writebackMap.size());
    }

    // =========================
    // AIRTABLE GET
    // =========================
    private HttpResponse callAirtableGet(Datetime lastSync, String tempOffset) {
        try {
            List<String> qs = new List<String>();
            qs.add('pageSize=' + PAGE_SIZE);
            qs.add('cellFormat=json');

            if (lastSync != null) {
                // Pull only records modified since last successful sync
                String isoTs  = lastSync.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.000\'Z\'');
                String formula = 'IS_AFTER({Last Modified by Date & Time},\'' + isoTs + '\')';
                qs.add('filterByFormula=' + EncodingUtil.urlEncode(formula, 'UTF-8'));
            }
            // null lastSync = first run / manual reset: no filter → pull everything

            if (!String.isBlank(tempOffset)) {
                qs.add('offset=' + EncodingUtil.urlEncode(tempOffset, 'UTF-8'));
            }

            String endpoint = NC_CALLOUT_PREFIX + '/v0/' + BASE_ID + '/' + TABLE_ID +
                              '?' + String.join(qs, '&');
            System.debug('AIRTABLE_GET=' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(120000);
            return new Http().send(req);

        } catch (Exception e) {
            sendErrorEmail(
                'Airtable Lead Sync — Callout Exception',
                e.getMessage() + '\n\n' + e.getStackTraceString()
            );
            return null;
        }
    }
    // EMAIL ALERT
    // =========================
    private static void sendErrorEmail(String subject, String body) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ ALERT_EMAIL });
            email.setSubject('[Displai SF] ' + subject);
            email.setPlainTextBody(
                body +
                '\n\n---' +
                '\nOrg: '  + UserInfo.getOrganizationName() +
                '\nUser: ' + UserInfo.getUserName() +
                '\nTime: ' + System.now()
            );
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ALERT_EMAIL_FAILED: ' + e.getMessage());
        }
    }

    // =========================
    // HELPERS
    // =========================
    private static String getStr(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        Object v = fields.get(key);
        if (v == null) return null;
        String s = (v instanceof String) ? (String) v : String.valueOf(v);
        return String.isBlank(s) ? null : s;
    }

    private static Boolean getBool(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        Object v = fields.get(key);
        if (v == null) return null;
        if (v instanceof Boolean) return (Boolean) v;
        if (v instanceof String) {
            String s = ((String) v).trim().toLowerCase();
            if (s == 'true'  || s == 'yes' || s == '1' || s == 'checked') return true;
            if (s == 'false' || s == 'no'  || s == '0' || s == 'unchecked' || s == '') return false;
        }
        if (v instanceof Integer) return ((Integer) v) != 0;
        if (v instanceof Long)    return ((Long) v)    != 0;
        if (v instanceof Decimal) return ((Decimal) v) != 0;
        return null;
    }

    private static String getFlag01(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        if (!fields.containsKey(key)) return null;
        Object v = fields.get(key);
        if (v == null) return '0';
        if (v instanceof Boolean) return ((Boolean) v) ? '1' : '0';
        if (v instanceof Integer) return ((Integer) v) != 0 ? '1' : '0';
        if (v instanceof Long)    return ((Long) v)    != 0 ? '1' : '0';
        if (v instanceof Decimal) return ((Decimal) v) != 0 ? '1' : '0';
        String s = String.valueOf(v).trim().toLowerCase();
        if (s == 'checked' || s == 'true' || s == 'yes' || s == 'y' || s == '1' || s == 't') return '1';
        if (s == '' || s == 'false' || s == 'no' || s == 'n' || s == '0' || s == 'f' || s == 'unchecked') return '0';
        return null; // unknown — don't overwrite
    }

    private static String sanitizeEmail(String raw) {
        if (String.isBlank(raw)) return null;
        raw = raw.trim();
        // Reject placeholder dashes
        if (raw == '-' || raw == '--' || raw == 'N/A' || raw == 'n/a') return null;
        // If comma-separated, take only the first valid-looking email
        if (raw.contains(',')) {
            for (String part : raw.split(',')) {
                part = part.trim();
                if (part.contains('@') && part.contains('.')) return part;
            }
            return null; // no valid email found
        }
        // Basic sanity check
        if (!raw.contains('@') || !raw.contains('.')) return null;
        return raw;
    }

    private static void setStringIfPresent(SObject sobj, Map<String, Schema.SObjectField> fmap,
                                           String fieldApi, String value) {
        if (String.isBlank(fieldApi) || value == null) return;
        value = value.trim();
        if (String.isBlank(value)) return;
        if (!fmap.containsKey(fieldApi)) return;
        try { sobj.put(fieldApi, value); } catch (Exception e) {}
    }

    private static void setBooleanIfPresent(SObject sobj, Map<String, Schema.SObjectField> fmap,
                                            String fieldApi, Boolean value) {
        if (String.isBlank(fieldApi) || value == null) return;
        if (!fmap.containsKey(fieldApi)) return;
        try { sobj.put(fieldApi, value); } catch (Exception e) {}
    }

    private static String formatUtcToReadable(String isoUtc, String tzCode) {
        if (String.isBlank(isoUtc)) return null;
        try {
            String cleaned = isoUtc.trim();
            Integer dot = cleaned.indexOf('.');
            if (dot > 0) cleaned = cleaned.substring(0, dot) + (cleaned.endsWith('Z') ? 'Z' : '');
            cleaned = cleaned.replace('T', ' ');
            if (cleaned.endsWith('Z')) cleaned = cleaned.substring(0, cleaned.length() - 1);
            Datetime utc = Datetime.valueOfGmt(cleaned);
            String tz = (tzCode == null ? '' : tzCode.trim().toUpperCase());
            String iana = 'UTC', suffix = 'UTC';
            if      (tz == 'ET')                           { iana = 'America/New_York';    suffix = 'ET'; }
            else if (tz == 'CT')                           { iana = 'America/Chicago';     suffix = 'CT'; }
            else if (tz == 'MT')                           { iana = 'America/Denver';      suffix = 'MT'; }
            else if (tz == 'PT' || tz == 'PST' || tz == 'PDT') { iana = 'America/Los_Angeles'; suffix = 'PT'; }
            return utc.format('MMM d, yyyy hh:mm a', iana) + ' ' + suffix;
        } catch (Exception e) {
            return isoUtc;
        }
    }
}