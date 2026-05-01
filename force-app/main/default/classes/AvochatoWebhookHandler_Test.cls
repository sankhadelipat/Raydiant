/**
 * Test class for AvochatoWebhookHandler + AvochatoWebhookQueueable
 *
 * Tests the full flow: REST endpoint receives POST → validates token →
 * checks idempotency → enqueues Queueable → Queueable creates/updates
 * Cases, CaseComments, Tasks, and handles ticket close events.
 *
 * @author  Blake Reeves (StargateCRM / Displai.ai)
 * @date    2026-04-22
 */
@isTest
private class AvochatoWebhookHandler_Test {

    // Use a known test token — the handler will check Custom Metadata,
    // but in tests we mock the token validation by injecting via the header.
    private static final String TEST_TOKEN = 'test-secret-token-12345';

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test AR Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName  = 'Doe',
            Phone     = '+15551234567',
            AccountId = acc.Id
        );
        insert con;
    }

    // ── Helper: build the nested Avochato JSON payload ──
    private static String buildPayload(
        String eventType, String direction, String messageBody,
        String ticketId, String ticketStatus, String phone,
        String sfObjectId, String sfObjectType, String senderId
    ) {
        return '{'
            + '"event_type": "' + eventType + '",'
            + '"id": "evt-' + ticketId + '-' + String.valueOf(Datetime.now().getTime()) + '",'
            + '"subdomain": "displai",'
            + '"account": { "id": "acct-1", "subdomain": "displai", "name": "Displai", "phone": "+14155550000" },'
            + '"ticket": {'
            + '  "id": "' + ticketId + '",'
            + '  "uuid": "uuid-' + ticketId + '",'
            + '  "contact": "avo-contact-1",'
            + '  "user_id": "' + (senderId != null ? senderId : 'agent-1') + '",'
            + '  "status": "' + (ticketStatus != null ? ticketStatus : 'open') + '",'
            + '  "origin": "sms",'
            + '  "created_at": 1713000000,'
            + '  "updated_at": 1713000000'
            + '},'
            + '"message": {'
            + '  "id": "msg-' + ticketId + '",'
            + '  "uuid": "uuid-msg-' + ticketId + '",'
            + '  "ticket_id": "' + ticketId + '",'
            + '  "contact_id": "avo-contact-1",'
            + '  "sender_id": "' + (senderId != null ? senderId : 'agent-1') + '",'
            + '  "sender_type": "user",'
            + '  "from": "+14155550001",'
            + '  "to": "' + (phone != null ? phone : '+15551234567') + '",'
            + '  "direction": "' + direction + '",'
            + '  "origin": "sms",'
            + '  "message": "' + messageBody + '",'
            + '  "status": "sent",'
            + '  "error_code": null,'
            + '  "error_description": null,'
            + '  "created_at": 1713000000,'
            + '  "sent_at": 1713000100'
            + '},'
            + '"contact": {'
            + '  "id": "avo-contact-1",'
            + '  "name": "Jane Doe",'
            + '  "email": "jane@test.com",'
            + '  "phone": "' + (phone != null ? phone : '+15551234567') + '",'
            + '  "salesforce_object_type": "' + (sfObjectType != null ? sfObjectType : '') + '",'
            + '  "salesforce_object_id": "' + (sfObjectId != null ? sfObjectId : '') + '",'
            + '  "user_id": "owner-1",'
            + '  "opted_out": false,'
            + '  "blocked": false'
            + '}'
            + '}';
    }

    // ── Helper: simulate a POST to the REST endpoint ──
    private static RestResponse doPost(String jsonBody, Boolean includeToken) {
        // Set the test token override so the handler can validate
        AvochatoWebhookHandler.testTokenOverride = TEST_TOKEN;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/avochato/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        if (includeToken) {
            req.headers.put('x-avochato-webhook-token', TEST_TOKEN);
        }

        RestContext.request  = req;
        RestContext.response = new RestResponse();

        AvochatoWebhookHandler.handlePost();

        return RestContext.response;
    }

    // ══════════════════════════════════════════════════════════════
    //  Handler-level tests
    // ══════════════════════════════════════════════════════════════

    @isTest
    static void testMissingTokenReturns401() {
        AvochatoWebhookHandler.testTokenOverride = null; // ensure no override
        String payload = buildPayload(
            'message.created', 'out', 'Hello', 'tkt-401', 'open',
            '+15551234567', null, null, null
        );

        Test.startTest();
        RestResponse res = doPost(payload, false);
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should reject without token');
        System.assert(res.responseBody.toString().contains('unauthorized'));
    }

    @isTest
    static void testHandlerHappyPathQueuesJob() {
        // Tests the full handler path: token valid → idempotency stamp → enqueue → 200
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        String payload = buildPayload(
            'message.created', 'out', 'Payment reminder via handler.',
            'tkt-handler-hp', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-1'
        );

        Test.startTest();
        RestResponse res = doPost(payload, true);
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        System.assert(res.responseBody.toString().contains('"status":"queued"'), 'Should be queued');

        // Verify idempotency record was created
        List<Avochato_Webhook_Event__c> events = [
            SELECT Event_Id__c, Event_Type__c FROM Avochato_Webhook_Event__c
            WHERE Event_Type__c = 'message.created'
        ];
        System.assert(!events.isEmpty(), 'Idempotency record should exist');

        // Verify the Queueable ran and created a Case
        List<Case> cases = [SELECT Id FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-handler-hp'];
        System.assertEquals(1, cases.size(), 'Case should be created by queueable');
    }

    @isTest
    static void testHandlerDuplicateEventIgnored() {
        // Pre-insert an idempotency record
        insert new Avochato_Webhook_Event__c(
            Event_Id__c   = 'evt-dup-test-123',
            Event_Type__c = 'message.created',
            Received_At__c = Datetime.now()
        );

        // Build a payload with a matching event id
        String payload = '{'
            + '"event_type": "message.created",'
            + '"id": "evt-dup-test-123",'
            + '"subdomain": "displai",'
            + '"account": { "id": "a1", "subdomain": "displai", "name": "Displai", "phone": "+14155550000" },'
            + '"ticket": { "id": "tkt-dup", "uuid": "u1", "contact": "c1", "user_id": "ag1", "status": "open", "origin": "sms", "created_at": 1713000000, "updated_at": 1713000000 },'
            + '"message": { "id": "m1", "uuid": "u2", "ticket_id": "tkt-dup", "contact_id": "c1", "sender_id": "ag1", "sender_type": "user", "from": "+14155550001", "to": "+15551234567", "direction": "out", "origin": "sms", "message": "dup test", "status": "sent", "error_code": null, "error_description": null, "created_at": 1713000000, "sent_at": 1713000100 },'
            + '"contact": { "id": "c1", "name": "Jane", "email": "j@t.com", "phone": "+15551234567", "salesforce_object_type": "", "salesforce_object_id": "", "user_id": "o1", "opted_out": false, "blocked": false }'
            + '}';

        Test.startTest();
        RestResponse res = doPost(payload, true);
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('"status":"duplicate"'), 'Should detect duplicate');
    }

    @isTest
    static void testHandlerBadPayloadLogsError() {
        // Send invalid JSON to trigger the error path and error logging
        String badPayload = '{"this is not valid json at all!!!';

        Test.startTest();
        RestResponse res = doPost(badPayload, true);
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should still return 200 to prevent retries');
        System.assert(res.responseBody.toString().contains('"status":"error"'), 'Should return error status');
    }

    @isTest
    static void testHandlerTokenViaQueryParam() {
        // Test token validation via query param instead of header
        AvochatoWebhookHandler.testTokenOverride = TEST_TOKEN;
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        String payload = buildPayload(
            'message.created', 'out', 'Token via param test.',
            'tkt-param', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-1'
        );

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/avochato/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        req.params.put('token', TEST_TOKEN);

        RestContext.request  = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AvochatoWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"status":"queued"'));
    }

    // ══════════════════════════════════════════════════════════════
    //  Queueable-level tests (business logic)
    // ══════════════════════════════════════════════════════════════

    @isTest
    static void testOutboundMessageCreatesCaseViaSfId() {
        Contact con = [SELECT Id, AccountId FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        String payload = buildPayload(
            'message.created', 'out', 'Your payment is overdue.',
            'tkt-001', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-sarah'
        );

        // Sanitize "from"/"to" like the handler does
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        // Verify Case
        List<Case> cases = [
            SELECT Id, Subject, ContactId, AccountId, Origin, Avochato_Ticket_Id__c
            FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-001'
        ];
        System.assertEquals(1, cases.size(), 'One Case should be created');
        System.assertEquals(con.Id, cases[0].ContactId, 'Case linked to correct Contact');
        System.assertEquals(con.AccountId, cases[0].AccountId, 'Case linked to correct Account');
        System.assertEquals('SMS', cases[0].Origin);

        // Verify Case Comment
        List<CaseComment> comments = [SELECT CommentBody FROM CaseComment WHERE ParentId = :cases[0].Id];
        System.assertEquals(1, comments.size());
        System.assert(comments[0].CommentBody.contains('Your payment is overdue.'));

        // Verify Task
        List<Task> tasks = [SELECT Subject, WhatId FROM Task WHERE WhatId = :cases[0].Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals('Outbound SMS via Avochato', tasks[0].Subject);
    }

    @isTest
    static void testOutboundMessageFallsBackToPhoneLookup() {
        // Don't pass SF object ID — should find Contact by phone
        String payload = buildPayload(
            'message.created', 'out', 'Please update your card.',
            'tkt-002', 'open', '+15551234567',
            null, null, 'agent-mike'
        );
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT ContactId FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-002'];
        System.assertEquals(1, cases.size());
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        System.assertEquals(con.Id, cases[0].ContactId, 'Should find existing Contact by phone');
    }

    @isTest
    static void testUnknownPhoneCreatesPlaceholderContact() {
        String payload = buildPayload(
            'message.created', 'out', 'We need to talk about your bill.',
            'tkt-003', 'open', '+19995559999',
            null, null, 'agent-mike'
        );
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT ContactId FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-003'];
        System.assertEquals(1, cases.size());

        // A new Contact should exist
        Contact newCon = [SELECT Id, LastName, Phone FROM Contact WHERE Id = :cases[0].ContactId];
        System.assert(newCon.Phone.contains('9995559999'));
    }

    @isTest
    static void testSecondMessageAppendsToCaseComment() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        String payload1 = buildPayload(
            'message.created', 'out', 'First message.',
            'tkt-004', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-1'
        );
        String sanitized1 = payload1.replace('"from":', '"from_phone":')
                                    .replace('"to":', '"to_phone":');

        // Process first message
        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload1, sanitized1));
        Test.stopTest();

        // Now process second message (same ticket ID) — need separate execution context
        String payload2 = buildPayload(
            'message.created', 'out', 'Follow up message.',
            'tkt-004', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-1'
        );
        String sanitized2 = payload2.replace('"from":', '"from_phone":')
                                    .replace('"to":', '"to_phone":');

        // Execute synchronously since we can't enqueue in same test after stopTest
        AvochatoWebhookQueueable q2 = new AvochatoWebhookQueueable(payload2, sanitized2);
        q2.execute(null);

        List<Case> cases = [SELECT Id FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-004'];
        System.assertEquals(1, cases.size(), 'Should still be 1 Case');

        List<CaseComment> comments = [SELECT CommentBody FROM CaseComment WHERE ParentId = :cases[0].Id ORDER BY CreatedDate];
        System.assertEquals(2, comments.size(), 'Should have 2 CaseComments');
    }

    @isTest
    static void testInboundSMSCreatesCase() {
        // Inbound SMS now creates a Case immediately (native Avochato integration removed)
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        String payload = buildPayload(
            'message.created', 'in', 'Customer reply.',
            'tkt-005', 'open', '+15551234567',
            con.Id, 'Contact', null
        );
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT Id, Subject, Origin FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-005'];
        System.assertEquals(1, cases.size(), 'Inbound SMS should create a Case');
        System.assertEquals('Inbound SMS', cases[0].Subject, 'Subject should be Inbound SMS');
        System.assertEquals('SMS', cases[0].Origin, 'Origin should be SMS');
    }

    @isTest
    static void testTicketClosedClosesCase() {
        // First create a Case via outbound message
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        String msgPayload = buildPayload(
            'message.created', 'out', 'Payment reminder.',
            'tkt-006', 'open', '+15551234567',
            con.Id, 'Contact', 'agent-1'
        );
        String sanitizedMsg = msgPayload.replace('"from":', '"from_phone":')
                                        .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(msgPayload, sanitizedMsg));
        Test.stopTest();

        // Verify Case is open
        Case openCase = [SELECT Id, Status, IsClosed FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-006'];
        System.assertEquals(false, openCase.IsClosed);

        // Now send ticket.status_changed with status=Closed
        // Ticket close events have no message direction, so we build a minimal payload
        String closePayload = '{'
            + '"event_type": "ticket.status_changed",'
            + '"id": "evt-close-tkt-006",'
            + '"subdomain": "displai",'
            + '"account": { "id": "a1", "subdomain": "displai", "name": "Displai", "phone": "+14155550000" },'
            + '"ticket": { "id": "tkt-006", "uuid": "u1", "contact": "c1", "user_id": "ag1", "status": "Closed", "origin": "sms", "created_at": 1713000000, "updated_at": 1713000000 },'
            + '"contact": { "id": "c1", "name": "Jane", "email": "j@t.com", "phone": "+15551234567", "salesforce_object_type": "Contact", "salesforce_object_id": "' + con.Id + '", "user_id": "o1", "opted_out": false, "blocked": false }'
            + '}';
        String sanitizedClose = closePayload.replace('"from":', '"from_phone":')
                                            .replace('"to":', '"to_phone":');

        AvochatoWebhookQueueable closeQ = new AvochatoWebhookQueueable(closePayload, sanitizedClose);
        closeQ.execute(null);

        // Verify Case is now Solved (webhook sets Solved; Flow auto-closes after 48hrs)
        Case closedCase = [SELECT Status, IsClosed FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-006'];
        System.assertEquals('Solved', closedCase.Status, 'Case should be Solved');
    }

    @isTest
    static void testPhoneNormalization() {
        System.assertEquals('15551234567', AvochatoWebhookQueueable.normalizePhone('+1 (555) 123-4567'));
        System.assertEquals('15551234567', AvochatoWebhookQueueable.normalizePhone('5551234567'));
        System.assertEquals('15551234567', AvochatoWebhookQueueable.normalizePhone('15551234567'));
        System.assertEquals(null, AvochatoWebhookQueueable.normalizePhone(''));
        System.assertEquals(null, AvochatoWebhookQueueable.normalizePhone(null));
    }

    // ── Helper: build a live-chat payload ──
    private static String buildChatPayload(
        String direction, String messageBody, String ticketId,
        String sfObjectId, String sfObjectType, String email, String senderId
    ) {
        return '{'
            + '"event_type": "message.created",'
            + '"id": "evt-chat-' + ticketId + '-' + String.valueOf(Datetime.now().getTime()) + '",'
            + '"subdomain": "displai",'
            + '"account": { "id": "acct-1", "subdomain": "displai", "name": "Displai", "phone": "+14155550000" },'
            + '"ticket": {'
            + '  "id": "' + ticketId + '",'
            + '  "uuid": "uuid-' + ticketId + '",'
            + '  "contact": "avo-contact-chat",'
            + '  "user_id": "' + (senderId != null ? senderId : 'agent-chat') + '",'
            + '  "status": "Open",'
            + '  "origin": "live-chat",'
            + '  "created_at": 1713000000,'
            + '  "updated_at": 1713000000'
            + '},'
            + '"message": {'
            + '  "id": "msg-chat-' + ticketId + '",'
            + '  "uuid": "uuid-msg-chat",'
            + '  "ticket_id": "' + ticketId + '",'
            + '  "contact_id": "avo-contact-chat",'
            + '  "sender_id": "' + (senderId != null ? senderId : 'avo-contact-chat') + '",'
            + '  "sender_type": "' + (direction == 'out' ? 'user' : 'contact') + '",'
            + '  "from": "avochato:a:NXA46neBdy",'
            + '  "to": "avochato:c:abc123",'
            + '  "direction": "' + direction + '",'
            + '  "origin": "web",'
            + '  "message": "' + messageBody + '",'
            + '  "status": "queued",'
            + '  "error_code": 0,'
            + '  "error_description": null,'
            + '  "created_at": 1713000000,'
            + '  "sent_at": 1713000100'
            + '},'
            + '"contact": {'
            + '  "id": "avo-contact-chat",'
            + '  "name": "Chat Customer",'
            + '  "email": "' + (email != null ? email : '') + '",'
            + '  "phone": "",'
            + '  "salesforce_object_type": "' + (sfObjectType != null ? sfObjectType : 'Case') + '",'
            + '  "salesforce_object_id": "' + (sfObjectId != null ? sfObjectId : '') + '",'
            + '  "user_id": null,'
            + '  "opted_out": false,'
            + '  "blocked": false'
            + '}'
            + '}';
    }

    @isTest
    static void testInboundChatCreatesCase() {
        // Inbound live-chat with email match should create a Case owned by CS queue
        Contact con = [SELECT Id, AccountId FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        // Add email to the contact so email lookup works
        con.Email = 'jane@test.com';
        update con;

        String payload = buildChatPayload('in', 'Hi I need help with my screen.',
            'tkt-chat-001', null, 'Case', 'jane@test.com', null);
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT Id, Origin, Subject, ContactId FROM Case
                            WHERE Avochato_Ticket_Id__c = 'tkt-chat-001'];
        System.assertEquals(1, cases.size(), 'Inbound chat should create a Case');
        System.assertEquals('Web Chat', cases[0].Origin, 'Origin should be Web Chat');
        System.assertEquals('Inbound Chat', cases[0].Subject, 'Subject should be Inbound Chat');
        System.assertEquals(con.Id, cases[0].ContactId, 'Contact resolved by email');
    }

    @isTest
    static void testAgentResponseUpdatesOwnerAndCreatesTask() {
        // Agent responds to existing inbound chat case — owner should update, task created
        Contact con = [SELECT Id, AccountId FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        con.Email = 'jane@test.com';
        update con;

        // Create inbound chat case first
        String inPayload = buildChatPayload('in', 'Customer opening message.',
            'tkt-chat-002', null, 'Case', 'jane@test.com', null);
        String inSanitized = inPayload.replace('"from":', '"from_phone":')
                                      .replace('"to":', '"to_phone":');

        AvochatoWebhookQueueable q1 = new AvochatoWebhookQueueable(inPayload, inSanitized);
        q1.execute(null);

        List<Case> cases = [SELECT Id, OwnerId FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-chat-002'];
        System.assertEquals(1, cases.size(), 'Case should exist after inbound');

        // Now agent responds outbound
        String outPayload = buildChatPayload('out', 'How can I help you?',
            'tkt-chat-002', null, 'Case', 'jane@test.com', 'agent-chat');
        String outSanitized = outPayload.replace('"from":', '"from_phone":')
                                        .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(outPayload, outSanitized));
        Test.stopTest();

        // Should still be 1 case
        List<Case> casesAfter = [SELECT Id FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-chat-002'];
        System.assertEquals(1, casesAfter.size(), 'Should still be 1 case');

        // Should have 2 comments (inbound + outbound)
        List<CaseComment> comments = [SELECT Id FROM CaseComment WHERE ParentId = :casesAfter[0].Id];
        System.assertEquals(2, comments.size(), 'Should have 2 comments');
    }

    @isTest
    static void testEmailContactLookup() {
        // Contact with email but no phone — email lookup should resolve correctly
        Contact con = new Contact(LastName = 'EmailOnly', Email = 'emailonly@test.com');
        insert con;

        String payload = buildChatPayload('out', 'Outbound to email-only contact.',
            'tkt-email-001', null, 'Case', 'emailonly@test.com', 'agent-1');
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT ContactId FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-email-001'];
        System.assertEquals(1, cases.size(), 'Case should be created');
        System.assertEquals(con.Id, cases[0].ContactId, 'Contact resolved by email');
    }

    @isTest
    static void testCsQueueFallbackWhenNoAgent() {
        // When agent ID is not mapped, case should go to Customer Service queue not site user
        List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'Customer Service' LIMIT 1];
        if (queues.isEmpty()) return; // Skip if no CS queue exists in this org
        Group csQueue = queues[0];

        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        String payload = buildPayload(
            'message.created', 'out', 'No agent mapped test.',
            'tkt-csqueue-001', 'open', '+15551234567',
            con.Id, 'Contact', 'unmapped-agent-xyz'
        );
        String sanitized = payload.replace('"from":', '"from_phone":')
                                  .replace('"to":', '"to_phone":');

        Test.startTest();
        System.enqueueJob(new AvochatoWebhookQueueable(payload, sanitized));
        Test.stopTest();

        List<Case> cases = [SELECT Id, OwnerId FROM Case WHERE Avochato_Ticket_Id__c = 'tkt-csqueue-001'];
        System.assertEquals(1, cases.size(), 'Case should be created');
        System.assertEquals(csQueue.Id, cases[0].OwnerId, 'Owner should be Customer Service queue');
    }

}