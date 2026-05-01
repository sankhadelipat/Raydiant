/**
 * AirtableLeadSyncWatchdog
 *
 * Runs every 4 hours via two scheduled jobs (on-the-hour offsets).
 * Reads Last_Successful_Sync__c from Airtable_Sync_Settings__c org defaults.
 * If null or older than STALE_HOURS, emails ALERT_EMAIL immediately.
 *
 * Schedule this in sandbox via Dev Console anonymous Apex:
 *   System.schedule('Airtable Watchdog 00', '0 0 0,4,8,12,16,20 * * ?', new AirtableLeadSyncWatchdog());
 *   System.schedule('Airtable Watchdog 02', '0 0 2,6,10,14,18,22 * * ?', new AirtableLeadSyncWatchdog());
 *
 * The email includes a one-liner to manually kick the sync from Dev Console.
 */
global class AirtableLeadSyncWatchdog implements Schedulable {

    private static final String  ALERT_EMAIL  = 'blake.reeves@displai.ai';
    private static final Integer STALE_HOURS  = 3; // alert if sync hasn't run in this many hours

    global void execute(SchedulableContext sc) {
        try {
            runCheck();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'WATCHDOG_EXCEPTION: ' + e.getMessage());
        }
    }

    private static void runCheck() {
        Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();

        String problem = null;

        if (cfg == null || cfg.Last_Successful_Sync__c == null) {
            problem =
                'Last_Successful_Sync__c is null.\n' +
                'The sync may never have completed successfully, or the custom setting row is missing.';
        } else {
            Long    msElapsed  = System.now().getTime() - cfg.Last_Successful_Sync__c.getTime();
            Decimal hoursSince = msElapsed / 3600000.0;

            if (hoursSince > STALE_HOURS) {
                String lastSyncStr = cfg.Last_Successful_Sync__c
                    .format('MMM d, yyyy h:mm a', 'America/Los_Angeles') + ' PT';
                problem =
                    'Last successful sync was ' + hoursSince.setScale(1) + ' hours ago (' + lastSyncStr + ').\n' +
                    'Expected interval: every 30 minutes.\n' +
                    'The Airtable Lead Sync job has stopped or is erroring silently.';
            }
        }

        if (problem != null) {
            String body =
                problem + '\n\n' +
                '--- WHAT TO DO ---\n' +
                '1. Check Salesforce Setup → Scheduled Jobs for "Airtable Lead Sync" jobs.\n' +
                '2. To manually kick the sync from Dev Console (Anonymous Apex):\n' +
                '   System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));\n' +
                '3. To force a full re-sync from scratch:\n' +
                '   Airtable_Sync_Settings__c cfg = Airtable_Sync_Settings__c.getOrgDefaults();\n' +
                '   cfg.Last_Successful_Sync__c = null; update cfg;\n' +
                '   System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));\n' +
                '\n---\n' +
                'Org: '  + UserInfo.getOrganizationName() +
                '\nWatchdog run time: ' + System.now();

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ ALERT_EMAIL });
            email.setSubject('[Displai SF] ⚠️ Airtable Lead Sync — Stale or Stopped');
            email.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

            System.debug(LoggingLevel.WARN, 'WATCHDOG_ALERT_SENT: ' + problem);
        } else {
            System.debug('WATCHDOG_OK: last sync within ' + STALE_HOURS + ' hours');
        }
    }
}