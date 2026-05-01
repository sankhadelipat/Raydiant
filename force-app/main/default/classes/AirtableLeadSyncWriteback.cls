/**
 * AirtableLeadSyncWriteback — Chained Queueable for SFDC Lead ID write-back
 *
 * WHY THIS EXISTS:
 *   Salesforce prohibits callouts after DML in the same transaction.
 *   The main AirtableLeadSyncQueueable does GET (callout) → DML (insert/update),
 *   so it cannot PATCH Airtable in the same execution. This class runs as a
 *   chained Queueable — enqueued by the main sync AFTER DML — so the PATCH
 *   callouts happen in a fresh transaction with no pending DML.
 *
 * USAGE (called automatically by AirtableLeadSyncQueueable):
 *   System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
 */
public with sharing class AirtableLeadSyncWriteback implements Queueable, Database.AllowsCallouts {

    // Must match the main sync class constants
    private static final String  BASE_ID           = 'appYMsTqt5BPSDf5z';
    private static final String  TABLE_ID          = 'tblxFmAekGMYnuRR6';
    private static final String  NC_CALLOUT_PREFIX = 'callout:Outbound_Airtable';
    private static final String  AT_SFDC_LEAD_ID   = 'SFDC Lead ID';
    private static final String  ALERT_EMAIL       = 'blake.reeves@displai.ai';

    private Map<String, String> airtableIdToLeadId;

    public AirtableLeadSyncWriteback(Map<String, String> airtableIdToLeadId) {
        this.airtableIdToLeadId = airtableIdToLeadId;
    }

    public void execute(QueueableContext qc) {
        if (airtableIdToLeadId == null || airtableIdToLeadId.isEmpty()) return;

        List<String> atIds          = new List<String>(airtableIdToLeadId.keySet());
        Integer      batchSize      = 10; // Airtable max per PATCH request
        List<String> writebackErrors = new List<String>();
        Integer      successCount    = 0;

        for (Integer i = 0; i < atIds.size(); i += batchSize) {
            List<Object> recordList = new List<Object>();
            Integer batchEnd = Math.min(i + batchSize, atIds.size());

            for (Integer j = i; j < batchEnd; j++) {
                String atId = atIds[j];
                recordList.add(new Map<String, Object>{
                    'id'     => atId,
                    'fields' => new Map<String, Object>{ AT_SFDC_LEAD_ID => airtableIdToLeadId.get(atId) }
                });
            }

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(NC_CALLOUT_PREFIX + '/v0/' + BASE_ID + '/' + TABLE_ID);
                req.setMethod('PATCH');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(new Map<String, Object>{ 'records' => recordList }));
                req.setTimeout(120000);

                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                    writebackErrors.add('Batch ' + (i/batchSize + 1) + ': HTTP ' +
                        res.getStatusCode() + ' - ' + res.getBody());
                } else {
                    successCount += recordList.size();
                }
            } catch (Exception e) {
                writebackErrors.add('Batch ' + (i/batchSize + 1) + ': EXCEPTION - ' + e.getMessage());
            }
        }

        System.debug('AIRTABLE_WRITEBACK_COMPLETE success=' + successCount +
                     ' errors=' + writebackErrors.size() +
                     ' total=' + atIds.size());

        if (!writebackErrors.isEmpty()) {
            sendErrorEmail(
                'Airtable Lead Sync - ' + writebackErrors.size() + ' Write-Back Error(s)',
                'Failed to PATCH SF Lead IDs back to Airtable.\n\n' +
                'Successful: ' + successCount + ' records\n' +
                'Failed batches: ' + writebackErrors.size() + '\n' +
                'Total attempted: ' + atIds.size() + ' records\n\n' +
                String.join(writebackErrors, '\n\n')
            );
        }
    }

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
}