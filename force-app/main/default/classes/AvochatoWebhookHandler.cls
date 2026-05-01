/**
 * AvochatoWebhookHandler
 *
 * Thin REST endpoint that receives webhook POSTs from Avochato.
 * Validates the shared-secret token, then enqueues an AvochatoWebhookQueueable
 * to do the real work. Returns 200 immediately so Avochato doesn't retry.
 *
 * Francisco's advice: Avochato retries aggressively on non-2xx, and Apex REST
 * on a Site has governor limits. So we enqueue and bail — no DML in this class.
 *
 * Supported events:
 *   message.created  → create/update Case + CaseComment + Task
 *   ticket.status_changed (status=closed/resolved) → close Case
 *
 * Security: Shared-secret token via ?token= query param or
 *           x-avochato-webhook-token header. Token stored in Custom Metadata
 *           (Avochato_Webhook_Setting__mdt.Webhook_Token__c).
 *
 * @author  Blake Reeves (StargateCRM / Displai.ai)
 * @date    2026-04-22
 */
@RestResource(urlMapping='/avochato/webhook/*')
global without sharing class AvochatoWebhookHandler {

    // ── Payload inner classes matching Avochato's nested JSON ──

    global class AvochatoEvent {
        public String event_type;      // May not be present — Avochato doesn't always send this
        public String id;              // top-level event/ticket id — idempotency key
        public Decimal at_time;        // top-level timestamp (renamed from "at" which is reserved)
        public String status;          // Ticket Status Webhook: current status (new/open/closed/pending)
        public String old_status;      // Ticket Status Webhook: previous status
        public String subdomain;
        public AvochatoAccount account;
        public AvochatoTicket ticket;
        public AvochatoMessage message;
        public AvochatoContact contact;
    }

    global class AvochatoAccount {
        public String id;
        public String subdomain;
        public String name;
        public String phone;
    }

    global class AvochatoTicket {
        public String id;              // conversation key
        public String uuid;
        public String contact;         // contact id in Avochato
        public String user_id;         // assigned agent id
        public String status;          // Open|Closed|Resolved etc. (capitalized)
        public String origin;          // sms|chat|email|Avochato
        public Decimal created_at;     // Unix epoch seconds (decimal)
        public Decimal updated_at;
    }

    global class AvochatoMessage {
        public String id;
        public String uuid;
        public String ticket_id;
        public String contact_id;
        public String sender_id;
        public String sender_type;     // User|Contact|Bot (capitalized)
        public String from_phone;      // "from" is reserved in Apex, handled in deserialize
        public String to_phone;        // "to" is reserved in Apex, handled in deserialize
        public String direction;       // "out" or "in"
        public String origin;          // web|sms|chat|email
        public String message;         // body text
        public String status;          // queued|sent|delivered|failed
        public Decimal error_code;     // numeric (0, not null)
        public String error_description;
        public Decimal created_at;     // Unix epoch seconds (decimal)
        public Decimal sent_at;
        public String event_id;        // Avochato event_id on the message
        public String element_id;
        public String element_type;
    }

    global class AvochatoContact {
        public String id;
        public String name;
        public String email;
        public String phone;
        public String salesforce_object_type;  // Contact|Lead|Account
        public String salesforce_object_id;    // 003... — use this FIRST
        public String user_id;
        public Boolean opted_out;
        public Boolean blocked;
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // ── Token validation ──
        if (!validateToken(req)) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf('{"status":"unauthorized"}');
            return;
        }

        String requestBody = req.requestBody.toString();

        try {
            // Avochato uses "from", "to", and "at" which are reserved words in Apex.
            // Replace them before deserializing.
            String sanitized = requestBody.replace('"from":', '"from_phone":')
                                          .replace('"to":', '"to_phone":')
                                          .replace('"at":', '"at_time":');

            AvochatoEvent evt = (AvochatoEvent) JSON.deserialize(sanitized, AvochatoEvent.class);

            // ── Idempotency key ──
            // Message events: use top-level id (the message/element id)
            // Ticket Status events: use ticket.id + '_' + status (ticket id repeats across status changes)
            String idempotencyKey = evt.id;
            // Ticket Status Webhook payloads always have top-level status + old_status
            // Message payloads never have top-level status — safe to use as the signal
            Boolean isTicketStatusEvent = String.isNotBlank(evt.status);
            if (isTicketStatusEvent && evt.ticket != null) {
                idempotencyKey = evt.ticket.id + '_' + evt.status;
            }

            // ── Idempotency check: skip if we already processed this event ──
            if (String.isNotBlank(idempotencyKey)) {
                List<Avochato_Webhook_Event__c> existing = [
                    SELECT Id FROM Avochato_Webhook_Event__c
                    WHERE Event_Id__c = :idempotencyKey LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"status":"duplicate","event_id":"' + idempotencyKey + '"}');
                    return;
                }
                // Stamp the event immediately so retries during queueable execution are caught
                insert new Avochato_Webhook_Event__c(
                    Event_Id__c    = idempotencyKey,
                    Event_Type__c  = isTicketStatusEvent ? 'ticket.status_changed' : evt.event_type,
                    Received_At__c = Datetime.now(),
                    Status__c      = 'Queued',
                    Payload__c     = requestBody.left(131072)
                );
            }

            // ── Enqueue the work and return 200 fast ──
            System.enqueueJob(new AvochatoWebhookQueueable(requestBody, sanitized));

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"queued","event_id":"' + evt.id + '"}');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AvochatoWebhookHandler error: ' +
                e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            // Try to log the error on the event record if it exists
            try {
                if (String.isNotBlank(req.requestBody.toString())) {
                    // Best-effort error logging
                    insert new Avochato_Webhook_Event__c(
                        Event_Id__c     = 'ERR-' + Datetime.now().getTime(),
                        Event_Type__c   = 'error',
                        Received_At__c  = Datetime.now(),
                        Status__c       = 'Error',
                        Payload__c      = req.requestBody.toString().left(131072),
                        Error_Message__c = (e.getMessage() + '\n' + e.getStackTraceString()).left(32768)
                    );
                }
            } catch (Exception logEx) {
                System.debug(LoggingLevel.ERROR, 'Failed to log error event: ' + logEx.getMessage());
            }
            // Still return 200 to prevent Avochato from retrying a bad payload forever
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"error","message":"' +
                e.getMessage().escapeJava() + '"}');
        }
    }

    // ── Token validation ──
    @TestVisible
    private static Boolean validateToken(RestRequest req) {
        // Get token from query param or header
        String token = req.params.get('token');
        if (String.isBlank(token)) {
            token = req.headers.get('x-avochato-webhook-token');
        }
        if (String.isBlank(token)) {
            return false;
        }

        // Compare against stored token in Custom Metadata
        // TODO: Create Avochato_Webhook_Setting__mdt with field Webhook_Token__c
        // For now, fall back to a Custom Label or hardcoded test value
        String expectedToken = getStoredToken();
        return String.isNotBlank(expectedToken) && token == expectedToken;
    }

    // Test bypass — allows tests to inject a token without Custom Metadata
    @TestVisible
    private static String testTokenOverride = null;

    @TestVisible
    private static String getStoredToken() {
        if (Test.isRunningTest() && testTokenOverride != null) {
            return testTokenOverride;
        }
        try {
            List<Avochato_Webhook_Setting__mdt> settings = [
                SELECT Webhook_Token__c
                FROM Avochato_Webhook_Setting__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            if (!settings.isEmpty()) {
                return settings[0].Webhook_Token__c;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not read Avochato webhook token from Custom Metadata: ' + e.getMessage());
        }
        return null;
    }
}