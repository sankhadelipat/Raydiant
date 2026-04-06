/**
 * AirtableLeadSyncQueueable (FULL REPLACEMENT - WITH 422 OFFSET SELF-HEAL)
 *
 * What this does:
 * - Pulls records from Airtable via Named Credential: Outbound_Airtable
 * - Upserts Leads by Airtable_Record_ID__c ONLY:
 *     - If Airtable_Record_ID__c found -> UPDATE
 *     - If not found -> INSERT
 * - Airtable checkbox-ish fields that arrive as:
 *     true/false, 1/0, "checked"/"" -> stored as TEXT "1"/"0" in Salesforce
 *     (Booked / Attended / Canceled / No Showed / Not ICP)
 * - Last_OBS_Update__c is stamped EVERY time this Apex touches the record
 *   (insert OR update in this run)
 *
 * REQUIRED SETUP (already in your org):
 * - Named Credential: Outbound_Airtable (URL=https://api.airtable.com)
 * - Hierarchy Custom Setting: Airtable_Sync_Settings__c (Org Defaults row)
 *     PageSize__c (Number), Offset__c (Text)
 * - Lead field: Airtable_Record_ID__c (Text; ideally Unique)
 */
public with sharing class AirtableLeadSyncQueueable implements Queueable, Database.AllowsCallouts {

    // =========================
    // ======= EDIT HERE =======
    // =========================
    private static final String BASE_ID  = 'appYMsTqt5BPSDf5z';
    private static final String TABLE_ID = 'tblxFmAekGMYnuRR6';

    // MUST be literal
    private static final String NC_CALLOUT_PREFIX = 'callout:Outbound_Airtable';

    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final Integer MAX_PAGE_SIZE = 100;

    // Airtable fields (exact)
    private static final String AT_INITIAL_DATE           = 'Initial Date';
    private static final String AT_STATUS                 = 'Status';
    private static final String AT_LAST_MODIFIED_DT       = 'Last Modified by Date & Time';
    private static final String AT_COMPANY_NAME           = 'Company Name';
    private static final String AT_INDUSTRY               = 'Industry';
    private static final String AT_INITIAL_REPLY          = 'Initial Reply';
    private static final String AT_NOTES                  = 'Notes';
    private static final String AT_COLD_CALL_SUMMARY      = 'Cold Call Summary';
    private static final String AT_MEETING_DATE           = 'Meeting Date';
    private static final String AT_MEETING_TIMEZONE       = 'Meeting Timezone';
    private static final String AT_BOOKED                 = 'Booked';
    private static final String AT_ATTENDED               = 'Attended';
    private static final String AT_CANCELED               = 'Canceled';
    private static final String AT_NO_SHOWED              = 'No Showed';
    private static final String AT_NOT_ICP                = 'Not ICP';     // NEW
    private static final String AT_DO_NOT_CALL            = 'Do Not Call';
    private static final String AT_SENDER_EMAIL           = 'Sender Email';
    private static final String AT_LOCATION               = 'Location';
    private static final String AT_COMPANY_URL            = 'Company URL';
    private static final String AT_PROSPECT_FIRST_NAME    = 'Prospect First Name';
    private static final String AT_PROSPECT_LAST_NAME     = 'Prospect Last Name';
    private static final String AT_PROSPECT_TITLE         = 'Prospect Title';
    private static final String AT_PROSPECT_EMAIL         = 'Prospect Email';
    private static final String AT_LINKEDIN_PROFILE       = 'Linkedin Profile';
    private static final String AT_CAMPAIGN_NAME          = 'Campaign Name';
    private static final String AT_BETTERCONTACT_NUMBER   = 'BetterContact Number';
    private static final String AT_SOURCE                 = 'Source';
    private static final String AT_DOMAIN                 = 'Domain';

    // SF field API names (your mapping)
    private static final String SF_OUTBOUND_INITIAL_DATE  = 'Outbound_Initial_Date__c';              // STRING in your org
    private static final String SF_OUTBOUND_STATUS        = 'Outbound_Solutions_Status__c';
    private static final String SF_OUTBOUND_MEETING_DATE  = 'Outbound_Meeting_Date__c';              // STRING in your org (we store formatted)
    private static final String SF_OUTBOUND_MEETING_TZ    = 'Outbound_Meeting_Timezone__c';

    // These are TEXT in your org (store "1"/"0")
    private static final String SF_OUTBOUND_BOOKED        = 'Outbound_Booked__c';
    private static final String SF_OUTBOUND_ATTENDED      = 'Outbound_Attended__c';
    private static final String SF_OUTBOUND_CANCELED      = 'Outbound_Canceled__c';
    private static final String SF_OUTBOUND_NO_SHOWED     = 'Outbound_No_Showed__c';
    private static final String SF_NOT_ICP                = 'Not_ICP__c'; // NEW

    private static final String SF_OUTBOUND_DNC           = 'Outbound_DNC__c'; // checkbox in your org
    private static final String SF_OUTBOUND_SENDER_EMAIL  = 'Outbound_Sender_Email__c';
    private static final String SF_LINKEDIN_URL           = 'LinkedIn_Contact_Profile_URL__c';
    private static final String SF_OUTBOUND_CAMPAIGN      = 'Outbound_Campaign__c';
    private static final String SF_OUTBOUND_SOURCE        = 'Outbound_Source__c';
    private static final String SF_OUTBOUND_INITIAL_REPLY = 'Outbound_Initial_Reply__c';
    private static final String SF_OUTBOUND_NOTES         = 'Outbound_Notes__c';
    private static final String SF_LEAD_DOMAIN            = 'Lead_Domain__c';
    private static final String SF_OUTBOUND_COLD_SUMMARY  = 'Outbound_Cold_Call_Summary__c';

    // Optional (may not exist in your org)
    private static final String SF_OUTBOUND_LAST_MODIFIED = 'Outbound_Last_Modified__c';

    // Hard-coded defaults (set on INSERT OR if empty)
    private static final String DEFAULT_OWNER_ID      = '00511000007n36Z'; // NOTE: often sandbox-only; code falls back if invalid
    private static final String DEFAULT_STATUS_VALUE  = 'Assigned';
    private static final String DEFAULT_SOURCE_VALUE  = 'Outbound Solutions';

    // Hard-coded SF fields (existence-checked)
    private static final String SF_ASSIGNED_DT      = 'Assigned__c';           // DateTime
    private static final String SF_LAST_OBS_UPDATE  = 'Last_OBS_Update__c';    // DateTime  <-- IMPORTANT: updated EVERY run now
    private static final String SF_LEAD_ASSIGNED    = 'Lead_Assigned__c';      // Checkbox
    private static final String SF_SOURCE_DETAIL    = 'Lead_Source_Detail__c'; // Text
    // =========================
    // ====== END EDIT HERE ====
    // =========================

    private final Integer overridePageSize;

    public AirtableLeadSyncQueueable(Integer overridePageSize, Boolean unused1, String unused2) {
        this.overridePageSize = overridePageSize;
    }

    public void execute(QueueableContext qc) {
        try {
            runInternal();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AIRTABLE_SYNC_FATAL: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());
        }
    }

    private void runInternal() {
        Map<String, Schema.SObjectField> leadFieldMap = Lead.SObjectType.getDescribe().fields.getMap();
        Datetime nowDt = System.now();

        // Validate the default owner id (sandbox/prod safe). If invalid, fall back to running user.
        Boolean defaultOwnerIsValid = false;
        try { defaultOwnerIsValid = ![SELECT Id FROM User WHERE Id = :DEFAULT_OWNER_ID LIMIT 1].isEmpty(); }
        catch (Exception e) { defaultOwnerIsValid = false; }
        System.debug('DEFAULT_OWNER_VALID=' + defaultOwnerIsValid);

        // Load org defaults (Hierarchy Custom Setting)
        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Airtable_Sync_Settings__c();
            cfg.SetupOwnerId = UserInfo.getOrganizationId();
            cfg.PageSize__c = DEFAULT_PAGE_SIZE;
            cfg.Offset__c = null;
            insert cfg;
        }

        Integer pageSize = (overridePageSize != null && overridePageSize > 0)
            ? overridePageSize
            : (cfg.PageSize__c == null ? DEFAULT_PAGE_SIZE : Integer.valueOf(cfg.PageSize__c));

        if (pageSize > MAX_PAGE_SIZE) pageSize = MAX_PAGE_SIZE;
        if (pageSize <= 0) pageSize = DEFAULT_PAGE_SIZE;

        // Build endpoint
        String endpoint = NC_CALLOUT_PREFIX + '/v0/' + BASE_ID + '/' + TABLE_ID;

        List<String> qs = new List<String>();
        qs.add('pageSize=' + pageSize);
        qs.add('cellFormat=json');

        if (!String.isBlank(cfg.Offset__c)) {
            qs.add('offset=' + EncodingUtil.urlEncode(cfg.Offset__c, 'UTF-8'));
        }

        endpoint += '?' + String.join(qs, '&');
        System.debug('AIRTABLE_ENDPOINT=' + endpoint);

        // Call Airtable
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = (new Http()).send(req);
        System.debug('AIRTABLE_STATUS=' + res.getStatus() + ' code=' + res.getStatusCode());

        // ✅ INSERTION: Airtable expired iterator self-heal (prevents integration from "silently dying")
        if (res.getStatusCode() == 422 && res.getBody() != null &&
            res.getBody().contains('LIST_RECORDS_ITERATOR_NOT_AVAILABLE')) {

            System.debug(LoggingLevel.ERROR, 'AIRTABLE_OFFSET_EXPIRED — clearing Offset__c');

            cfg.Offset__c = null;
            update cfg;

            // Stop this run. Next scheduled run will restart from page 1.
            return;
        }

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug(LoggingLevel.ERROR, 'AIRTABLE_BODY=' + res.getBody());
            return;
        }

        // Parse
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) parsed.get('records');
        String nextOffset = (String) parsed.get('offset');

        System.debug('AIRTABLE_RECORDS_COUNT=' + (records == null ? 0 : records.size()));
        System.debug('AIRTABLE_NEXT_OFFSET=' + nextOffset);

        if (records == null || records.isEmpty()) {
            cfg.Offset__c = nextOffset;
            update cfg;
            return;
        }

        // Collect Airtable IDs
        Set<String> airtableIds = new Set<String>();
        for (Object o : records) {
            Map<String, Object> rec = (Map<String, Object>) o;
            String recId = (String) rec.get('id');
            if (!String.isBlank(recId)) airtableIds.add(recId);
        }
        if (airtableIds.isEmpty()) {
            cfg.Offset__c = nextOffset;
            update cfg;
            return;
        }

        // Query existing leads ONLY by Airtable ID (per your rules)
        // Include hard-coded fields so we can check "if empty"
        List<Lead> existingLeads = [
            SELECT Id, Airtable_Record_ID__c, OwnerId, Status, LeadSource,
                   Assigned__c, Last_OBS_Update__c, Lead_Assigned__c, Lead_Source_Detail__c
            FROM Lead
            WHERE Airtable_Record_ID__c IN :airtableIds
        ];
        Map<String, Lead> leadByAirtableId = new Map<String, Lead>();
        for (Lead l : existingLeads) leadByAirtableId.put(l.Airtable_Record_ID__c, l);

        List<Lead> toInsert = new List<Lead>();
        List<Lead> toUpdate = new List<Lead>();

        for (Object o : records) {
            Map<String, Object> rec = (Map<String, Object>) o;
            String recId = (String) rec.get('id');
            if (String.isBlank(recId)) continue;

            Map<String, Object> f = (Map<String, Object>) rec.get('fields');
            if (f == null) f = new Map<String, Object>();

            Lead existing = leadByAirtableId.get(recId);
            Boolean isInsert = (existing == null);

            Lead l = isInsert ? new Lead() : existing;
            SObject ls = (SObject) l;

            l.Airtable_Record_ID__c = recId;

            // --- Date fields (store strings; meeting date is formatted using timezone)
            String initDate = getStr(f, AT_INITIAL_DATE);
            if (!String.isBlank(initDate) && leadFieldMap.containsKey(SF_OUTBOUND_INITIAL_DATE)) {
                ls.put(SF_OUTBOUND_INITIAL_DATE, initDate.trim());
            }

            String rawMeetingIso = getStr(f, AT_MEETING_DATE);
            String mtz = getStr(f, AT_MEETING_TIMEZONE);
            if (!String.isBlank(rawMeetingIso) && leadFieldMap.containsKey(SF_OUTBOUND_MEETING_DATE)) {
                String formatted = formatUtcToAirtableTimezoneReadable(rawMeetingIso.trim(), mtz);
                ls.put(SF_OUTBOUND_MEETING_DATE, formatted);
            }

            // Store the timezone field itself too (if present)
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_MEETING_TZ, mtz);

            // Optional: last modified -> store raw string if you have a field for it
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_LAST_MODIFIED, getStr(f, AT_LAST_MODIFIED_DT));

            // --- Core Lead fields
            setStringIfPresent(ls, leadFieldMap, 'Company',   getStr(f, AT_COMPANY_NAME));
            setStringIfPresent(ls, leadFieldMap, 'Industry',  getStr(f, AT_INDUSTRY));
            setStringIfPresent(ls, leadFieldMap, 'FirstName', getStr(f, AT_PROSPECT_FIRST_NAME));
            setStringIfPresent(ls, leadFieldMap, 'LastName',  getStr(f, AT_PROSPECT_LAST_NAME));
            setStringIfPresent(ls, leadFieldMap, 'Title',     getStr(f, AT_PROSPECT_TITLE));
            setStringIfPresent(ls, leadFieldMap, 'Email',     getStr(f, AT_PROSPECT_EMAIL));
            setStringIfPresent(ls, leadFieldMap, 'Phone',     getStr(f, AT_BETTERCONTACT_NUMBER));
            setStringIfPresent(ls, leadFieldMap, 'Website',   getStr(f, AT_COMPANY_URL));
            setStringIfPresent(ls, leadFieldMap, 'City',      getStr(f, AT_LOCATION));

            // --- Custom fields
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_STATUS,        getStr(f, AT_STATUS));

            // TEXT flags "1"/"0"
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_BOOKED,    getFlag01(f, AT_BOOKED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_ATTENDED,  getFlag01(f, AT_ATTENDED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_CANCELED,  getFlag01(f, AT_CANCELED));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_NO_SHOWED, getFlag01(f, AT_NO_SHOWED));
            setStringIfPresent(ls, leadFieldMap, SF_NOT_ICP,            getFlag01(f, AT_NOT_ICP)); // NEW

            // Boolean field (checkbox)
            setBooleanIfPresent(ls, leadFieldMap, SF_OUTBOUND_DNC, getBool(f, AT_DO_NOT_CALL));

            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_SENDER_EMAIL,  getStr(f, AT_SENDER_EMAIL));
            setStringIfPresent(ls, leadFieldMap, SF_LINKEDIN_URL,           getStr(f, AT_LINKEDIN_PROFILE));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_CAMPAIGN,      getStr(f, AT_CAMPAIGN_NAME));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_SOURCE,        getStr(f, AT_SOURCE));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_INITIAL_REPLY, getStr(f, AT_INITIAL_REPLY));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_NOTES,         getStr(f, AT_NOTES));
            setStringIfPresent(ls, leadFieldMap, SF_LEAD_DOMAIN,            getStr(f, AT_DOMAIN));
            setStringIfPresent(ls, leadFieldMap, SF_OUTBOUND_COLD_SUMMARY,  getStr(f, AT_COLD_CALL_SUMMARY));

            // Ensure required fields for insert
            if (isInsert) {
                if (String.isBlank((String)ls.get('LastName'))) ls.put('LastName', 'Unknown');
                if (String.isBlank((String)ls.get('Company')))  ls.put('Company',  'Unknown');
            }

            // --- Hard-coded defaults: INSERT OR if empty
            if (leadFieldMap.containsKey(SF_ASSIGNED_DT) && (isInsert || ls.get(SF_ASSIGNED_DT) == null)) {
                ls.put(SF_ASSIGNED_DT, nowDt);
            }

            // IMPORTANT CHANGE: update every time this Apex touches the record
            if (leadFieldMap.containsKey(SF_LAST_OBS_UPDATE)) {
                ls.put(SF_LAST_OBS_UPDATE, nowDt);
            }

            if (leadFieldMap.containsKey(SF_LEAD_ASSIGNED) && (isInsert || ls.get(SF_LEAD_ASSIGNED) == null)) {
                ls.put(SF_LEAD_ASSIGNED, true);
            }
            if (leadFieldMap.containsKey(SF_SOURCE_DETAIL) && (isInsert || String.isBlank((String)ls.get(SF_SOURCE_DETAIL)))) {
                ls.put(SF_SOURCE_DETAIL, DEFAULT_SOURCE_VALUE);
            }
            if (isInsert || String.isBlank((String)ls.get('LeadSource'))) {
                ls.put('LeadSource', DEFAULT_SOURCE_VALUE);
            }
            if (isInsert || String.isBlank((String)ls.get('Status'))) {
                ls.put('Status', DEFAULT_STATUS_VALUE);
            }
            if ((isInsert || String.isBlank((String)ls.get('OwnerId'))) && defaultOwnerIsValid) {
                ls.put('OwnerId', DEFAULT_OWNER_ID);
            }

            if (isInsert) toInsert.add(l);
            else toUpdate.add(l);
        }

        if (!toInsert.isEmpty()) Database.insert(toInsert, false);
        if (!toUpdate.isEmpty()) Database.update(toUpdate, false);

        cfg.Offset__c = nextOffset;
        update cfg;
    }

    // =========================
    // ======= HELPERS =========
    // =========================

    private static String getStr(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        Object v = fields.get(key);
        if (v == null) return null;
        if (v instanceof String) return (String) v;
        String s = String.valueOf(v);
        return String.isBlank(s) ? null : s;
    }

    /**
     * Boolean parser used for SF boolean fields (e.g., Outbound_DNC__c).
     * Recognizes "checked"/"unchecked" too.
     */
    private static Boolean getBool(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        Object v = fields.get(key);
        if (v == null) return null;

        if (v instanceof Boolean) return (Boolean) v;

        if (v instanceof String) {
            String s = ((String) v).trim().toLowerCase();
            if (s == 'true' || s == 'yes' || s == '1' || s == 'checked' || s == 't' || s == 'y') return true;
            if (s == 'false' || s == 'no' || s == '0' || s == 'unchecked' || s == 'f' || s == 'n' || s == '') return false;
        }

        if (v instanceof Integer) return ((Integer) v) != 0;
        if (v instanceof Long) return ((Long) v) != 0;
        if (v instanceof Decimal) return ((Decimal) v) != 0;

        return null;
    }

    /**
     * Airtable checkbox-ish -> TEXT flag "1"/"0" (for your TEXT fields).
     * Returns null if the key isn't present / unknown (so we won't overwrite).
     */
    private static String getFlag01(Map<String, Object> fields, String key) {
        if (fields == null || String.isBlank(key)) return null;
        if (!fields.containsKey(key)) return null;

        Object v = fields.get(key);
        if (v == null) return '0';

        if (v instanceof Boolean) return ((Boolean) v) ? '1' : '0';
        if (v instanceof Integer) return ((Integer) v) != 0 ? '1' : '0';
        if (v instanceof Long)    return ((Long) v) != 0 ? '1' : '0';
        if (v instanceof Decimal) return ((Decimal) v) != 0 ? '1' : '0';

        String s = String.valueOf(v).trim().toLowerCase();
        if (s == 'checked' || s == 'true' || s == 'yes' || s == 'y' || s == '1' || s == 't') return '1';
        if (s == '' || s == 'false' || s == 'no' || s == 'n' || s == '0' || s == 'f' || s == 'unchecked') return '0';

        // Unknown: do not overwrite
        return null;
    }

    private static void setStringIfPresent(SObject sobj, Map<String, Schema.SObjectField> fmap, String fieldApi, String value) {
        if (String.isBlank(fieldApi) || value == null) return;
        value = value.trim();
        if (String.isBlank(value)) return;
        if (!fmap.containsKey(fieldApi)) return;
        try { sobj.put(fieldApi, value); } catch (Exception e) { }
    }

    private static void setBooleanIfPresent(SObject sobj, Map<String, Schema.SObjectField> fmap, String fieldApi, Boolean value) {
        if (String.isBlank(fieldApi) || value == null) return;
        if (!fmap.containsKey(fieldApi)) return;
        try { sobj.put(fieldApi, value); } catch (Exception e) { }
    }

    /**
     * Converts UTC ISO string like "2025-12-01T16:00:00.000Z"
     * into a readable string formatted in the Airtable timezone code (ET/CT/MT/PT).
     *
     * Output example: "Dec 1, 2025 11:00 AM ET"
     *
     * If tz is blank/unknown, returns raw iso string.
     */
    private static String formatUtcToAirtableTimezoneReadable(String isoUtc, String tzCode) {
        if (String.isBlank(isoUtc)) return null;

        try {
            String cleaned = isoUtc.trim();

            // Handle milliseconds
            Integer dot = cleaned.indexOf('.');
            if (dot > 0) {
                Boolean hasZ = cleaned.endsWith('Z');
                cleaned = cleaned.substring(0, dot) + (hasZ ? 'Z' : '');
            }

            // Datetime.valueOfGmt wants "yyyy-MM-dd HH:mm:ss"
            cleaned = cleaned.replace('T', ' ');
            if (cleaned.endsWith('Z')) cleaned = cleaned.substring(0, cleaned.length() - 1);

            Datetime utc = Datetime.valueOfGmt(cleaned);

            String tz = (tzCode == null ? '' : tzCode.trim().toUpperCase());
            String iana = 'UTC';
            String suffix = 'UTC';

            if (tz == 'ET') { iana = 'America/New_York';    suffix = 'ET'; }
            else if (tz == 'CT') { iana = 'America/Chicago';  suffix = 'CT'; }
            else if (tz == 'MT') { iana = 'America/Denver';   suffix = 'MT'; }
            else if (tz == 'PT' || tz == 'PST' || tz == 'PDT') { iana = 'America/Los_Angeles'; suffix = 'PT'; }

            return utc.format('MMM d, yyyy hh:mm a', iana) + ' ' + suffix;
        } catch (Exception e) {
            System.debug('TZ_FORMAT_FAIL iso=' + isoUtc + ' tz=' + tzCode + ' err=' + e.getMessage());
            return isoUtc;
        }
    }
}