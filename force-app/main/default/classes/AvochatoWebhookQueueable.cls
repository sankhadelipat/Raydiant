/**
 * AvochatoWebhookQueueable
 *
 * Does the real work after AvochatoWebhookHandler enqueues it.
 * Handles two event types:
 *   1. message.created (direction=out) → find/create Case, add CaseComment, log Task
 *   2. ticket.status_changed (status=closed/resolved) → close the Case
 *
 * Contact resolution order (per Francisco):
 *   1. contact.salesforce_object_id — already linked in Avochato, trust it first
 *   2. Phone number lookup — fallback when SF ID is null
 *   3. Email lookup — critical for live-chat contacts who have no phone
 *   4. Create placeholder Contact — last resort
 *
 * @author  Blake Reeves (StargateCRM / Displai.ai)
 * @date    2026-04-22
 */
public class AvochatoWebhookQueueable implements Queueable {

    private String rawBody;
    private String sanitizedBody;

    public AvochatoWebhookQueueable(String rawBody, String sanitizedBody) {
        this.rawBody = rawBody;
        this.sanitizedBody = sanitizedBody;
    }

    public void execute(QueueableContext ctx) {
        String eventId = null;
        try {
            AvochatoWebhookHandler.AvochatoEvent evt =
                (AvochatoWebhookHandler.AvochatoEvent) JSON.deserialize(
                    sanitizedBody, AvochatoWebhookHandler.AvochatoEvent.class
                );
            eventId = evt.id;

            // Detect event type by payload content:
            // - Ticket Status Webhook: top-level status field present, message is null
            // - Message webhooks: message block present with direction
            // - Legacy event_type field: fallback
            // Ticket Status Webhook has top-level status field — check FIRST
            // (payload may also include a message block, so check status before message)
            if (String.isNotBlank(evt.status)) {
                handleTicketStatusChanged(evt);
            } else if (evt.message != null && String.isNotBlank(evt.message.direction)) {
                handleMessageCreated(evt);
            } else if (evt.event_type != null && evt.event_type.equalsIgnoreCase('ticket.status_changed')) {
                handleTicketStatusChanged(evt);
            }

            // Mark event as processed
            updateEventStatus(eventId, 'Processed', null);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AvochatoWebhookQueueable error: ' +
                e.getMessage() + ' | Stack: ' + e.getStackTraceString() +
                ' | Body: ' + rawBody);
            // Mark event as error
            updateEventStatus(eventId, 'Error', e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  message.created handler
    // ═══════════════════════════════════════════════════════════════
    private void handleMessageCreated(AvochatoWebhookHandler.AvochatoEvent evt) {
        AvochatoWebhookHandler.AvochatoMessage msg = evt.message;
        AvochatoWebhookHandler.AvochatoContact aCon = evt.contact;
        AvochatoWebhookHandler.AvochatoTicket ticket = evt.ticket;

        if (msg == null) return;

        // Determine the conversation key (ticket.id)
        String conversationId = (ticket != null) ? ticket.id : null;

        // Find existing open Case for this ticket
        Case existingCase = findOpenCase(conversationId);

        // Detect if this is a live-chat (web widget) vs SMS conversation
        Boolean liveChat = isLiveChat(ticket, msg);

        if (msg.direction == 'out') {
            // OUTBOUND message
            if (existingCase != null) {
                // Append to existing Case
                appendCaseComment(existingCase.Id, msg, aCon, liveChat);
                // Update owner to responding agent; create Task on first agent response
                Id agentUserId = resolveAgentUser(msg.sender_id);
                if (agentUserId != null) {
                    updateCaseOwnerAndTask(existingCase, agentUserId, msg, liveChat);
                }
            } else {
                // No Case exists — agent initiated, create one now
                // Skip automated Avochato messages (auto-responder, bot) — sender_type = "Avochato"
                // These fire seconds after inbound and cause duplicate cases
                if (msg.sender_type != null && msg.sender_type.equalsIgnoreCase('Avochato')) return;

                Contact sfContact = resolveContact(aCon, msg);
                Id accountId = sfContact.AccountId;
                Id agentUserId = resolveAgentUser(msg.sender_id);

                Case newCase = createCase(sfContact, accountId, msg, ticket, aCon, agentUserId, liveChat);
                appendCaseComment(newCase.Id, msg, aCon, liveChat);
                createTask(newCase.Id, sfContact.Id, accountId, msg, liveChat);
            }
        } else {
            // INBOUND message
            if (existingCase != null && existingCase.Avochato_Ticket_Id__c != null) {
                // Existing case we created — append comment
                appendCaseComment(existingCase.Id, msg, aCon, liveChat);
            } else if (existingCase == null) {
                // Inbound message with no case yet
                Contact sfContact = resolveContact(aCon, msg);

                // Check for a recently Solved case for this contact (within 48hrs)
                // If found — reopen it rather than creating a new case
                Case solvedCase = findSolvedCaseForContact(sfContact.Id);
                if (solvedCase != null) {
                    // Reopen — update ticket ID to new Avochato conversation and set Open
                    solvedCase.Status = 'New';
                    if (ticket != null) solvedCase.Avochato_Ticket_Id__c = ticket.id;
                    update solvedCase;
                    appendCaseComment(solvedCase.Id, msg, aCon, liveChat);
                } else {
                    // No recent Solved case — create a fresh one
                    Case newCase = createCase(sfContact, sfContact.AccountId, msg, ticket, aCon, null, liveChat);
                    appendCaseComment(newCase.Id, msg, aCon, liveChat);
                    // No task yet — agent not known until they respond
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  ticket.status_changed handler
    // ═══════════════════════════════════════════════════════════════
    private void handleTicketStatusChanged(AvochatoWebhookHandler.AvochatoEvent evt) {
        AvochatoWebhookHandler.AvochatoTicket ticket = evt.ticket;
        if (ticket == null) return;

        // Determine the status — check top-level evt.status first (Ticket Status Webhook),
        // fall back to ticket.status (legacy event_type payload)
        String ticketStatus = String.isNotBlank(evt.status) ? evt.status : ticket.status;
        if (String.isBlank(ticketStatus)) return;

        // Only act on closed (Ticket Status Webhook sends lowercase "closed")
        if (!ticketStatus.equalsIgnoreCase('closed') && !ticketStatus.equalsIgnoreCase('resolved')) {
            return;
        }

        // Find the open Case by ticket ID
        Case openCase = findOpenCase(ticket.id);
        if (openCase == null) return;

        // Set to Solved — a scheduled Flow will auto-close after 2 days of silence
        openCase.Status = 'Solved';
        update openCase;
    }

    // ═══════════════════════════════════════════════════════════════
    //  Contact resolution — SF ID first, phone fallback, create last
    // ═══════════════════════════════════════════════════════════════
    @TestVisible
    private static Contact resolveContact(
        AvochatoWebhookHandler.AvochatoContact aCon,
        AvochatoWebhookHandler.AvochatoMessage msg
    ) {
        // 1. Try salesforce_object_id from Avochato (most reliable)
        if (aCon != null && String.isNotBlank(aCon.salesforce_object_id)) {
            String sfId = aCon.salesforce_object_id;
            String objType = aCon.salesforce_object_type;

            // Only use if it's a Contact (not Lead or Account)
            if (objType == null || objType == 'Contact') {
                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName, AccountId, Phone
                    FROM Contact
                    WHERE Id = :sfId
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    return contacts[0];
                }
            }
            // If it's an Account, find the primary Contact on that Account
            if (objType == 'Account') {
                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName, AccountId, Phone
                    FROM Contact
                    WHERE AccountId = :sfId
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    return contacts[0];
                }
            }
        }

        // 2. Phone number fallback
        // Avochato sometimes sends UUID-style strings as phone (e.g. "avochato:c:...")
        // Only use phone if it looks like a real number
        String phone = (aCon != null && String.isNotBlank(aCon.phone))
            ? aCon.phone
            : (msg != null ? msg.to_phone : null);

        if (String.isNotBlank(phone) && isValidPhone(phone)) {
            String normalized = normalizePhone(phone);
            if (String.isNotBlank(normalized)) {
                String last10 = normalized.length() > 10
                    ? normalized.substring(normalized.length() - 10)
                    : normalized;

                // Also try dash-formatted pattern e.g. "612-963-7737" for last10 "6129637737"
                String dashed = last10.length() == 10
                    ? last10.substring(0,3) + '-' + last10.substring(3,6) + '-' + last10.substring(6)
                    : last10;

                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName, AccountId, Phone
                    FROM Contact
                    WHERE Phone LIKE :('%' + last10)
                       OR MobilePhone LIKE :('%' + last10)
                       OR OtherPhone LIKE :('%' + last10)
                       OR Phone LIKE :('%' + dashed)
                       OR MobilePhone LIKE :('%' + dashed)
                       OR OtherPhone LIKE :('%' + dashed)
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    return contacts[0];
                }

                // 3. Create placeholder Contact with valid phone
                Contact newCon = new Contact(
                    LastName    = (aCon != null && String.isNotBlank(aCon.name))
                                    ? aCon.name : 'Avochato Contact (' + last10 + ')',
                    Phone       = phone.left(40),
                    Email       = (aCon != null) ? aCon.email : null,
                    Description = 'Auto-created by Avochato outbound webhook. Phone: ' + phone
                );
                insert newCon;
                return newCon;
            }
        }

        // 3. Email lookup — key for live-chat contacts who come in with email but no phone
        if (aCon != null && String.isNotBlank(aCon.email)) {
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, AccountId, Phone
                FROM Contact
                WHERE Email = :aCon.email
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                return contacts[0];
            }
        }

        // Absolute fallback — create a placeholder so the Case still gets a Contact
        Contact fallback = new Contact(
            LastName    = (aCon != null && String.isNotBlank(aCon.name))
                            ? aCon.name : 'Avochato Contact (Unknown)',
            Email       = (aCon != null) ? aCon.email : null,
            Description = 'Auto-created by Avochato webhook — no phone or SF ID available.'
        );
        insert fallback;
        return fallback;
    }

    // ═══════════════════════════════════════════════════════════════
    //  Helpers
    // ═══════════════════════════════════════════════════════════════

    @TestVisible
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() == 10) {
            digits = '1' + digits;
        }
        return digits;
    }

    private static Case findOpenCase(String ticketId) {
        if (String.isBlank(ticketId)) return null;
        List<Case> cases = [
            SELECT Id, Subject, Status, ContactId, AccountId, OwnerId, Avochato_Ticket_Id__c
            FROM Case
            WHERE Avochato_Ticket_Id__c = :ticketId
              AND IsClosed = false
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    private static Case createCase(
        Contact con, Id accountId,
        AvochatoWebhookHandler.AvochatoMessage msg,
        AvochatoWebhookHandler.AvochatoTicket ticket,
        AvochatoWebhookHandler.AvochatoContact aCon,
        Id agentUserId,
        Boolean liveChat
    ) {
        String agentName = (msg != null && String.isNotBlank(msg.sender_id))
            ? resolveAgentName(msg.sender_id) : 'AR Staff';
        if (String.isBlank(agentName)) agentName = 'AR Staff';

        Boolean inbound = (msg != null && msg.direction == 'in');
        String caseOrigin  = liveChat ? 'Web Chat' : 'SMS';
        String caseSubject = liveChat
            ? 'Inbound Chat'
            : (inbound
                ? 'Inbound SMS'
                : ('Outbound SMS - ' + (con.LastName != null ? con.LastName : 'Unknown')));
        String caseDesc    = liveChat
            ? ('Inbound chat conversation via Avochato web widget.' +
               '\nAgent: ' + agentName +
               '\nCustomer: ' + (aCon != null && String.isNotBlank(aCon.email) ? aCon.email : '') +
               '\nAvochato Ticket: ' + (ticket != null ? ticket.id : 'N/A'))
            : (inbound
                ? ('Inbound SMS conversation from customer.' +
                   '\nPhone: ' + (aCon != null ? aCon.phone : '') +
                   '\nAvochato Ticket: ' + (ticket != null ? ticket.id : 'N/A'))
                : ('Outbound SMS conversation initiated by ' + agentName +
                   ' via Avochato.' +
                   '\nPhone: ' + (aCon != null ? aCon.phone : '') +
                   '\nAvochato Ticket: ' + (ticket != null ? ticket.id : 'N/A')));

        Case c = new Case(
            Subject     = caseSubject,
            Description = caseDesc,
            ContactId   = con.Id,
            AccountId   = accountId,
            Origin      = caseOrigin,
            Status      = 'New',
            Avochato_Ticket_Id__c       = (ticket != null) ? ticket.id : null,
            Avochato_Conversation_URL__c = (ticket != null && String.isNotBlank(ticket.uuid))
                ? 'https://www.avochato.com/accounts/raydiant/tickets/' + ticket.uuid
                : null
        );
        // Insert first — this guarantees c.Id is set (insert throws on failure)
        insert c;

        // Race condition guard — if two queueables fired simultaneously for the same ticket,
        // both may have inserted. Keep the earliest, delete ours if we're the duplicate.
        if (String.isNotBlank(c.Avochato_Ticket_Id__c)) {
            List<Case> dupes = [
                SELECT Id FROM Case
                WHERE Avochato_Ticket_Id__c = :c.Avochato_Ticket_Id__c
                  AND IsClosed = false
                  AND Id != :c.Id
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!dupes.isEmpty()) {
                // We are the duplicate — delete ourselves and return the original
                delete c;
                return [SELECT Id, ContactId, AccountId, OwnerId, Avochato_Ticket_Id__c
                        FROM Case WHERE Id = :dupes[0].Id LIMIT 1];
            }
        }

        // Now override owner explicitly — agent if known, CS queue as fallback
        // Never leave OwnerId as whatever assignment rule set (could be Displai Systems Inc)
        Id ownerId = agentUserId;
        if (ownerId == null) {
            List<Group> csQueue = [
                SELECT Id FROM Group
                WHERE Type = 'Queue' AND Name = 'Customer Service'
                LIMIT 1
            ];
            if (!csQueue.isEmpty()) ownerId = csQueue[0].Id;
        }
        if (ownerId != null) {
            c.OwnerId = ownerId;
            update c;
        }
        return c;
    }

    private static void appendCaseComment(
        Id caseId,
        AvochatoWebhookHandler.AvochatoMessage msg,
        AvochatoWebhookHandler.AvochatoContact aCon,
        Boolean liveChat
    ) {
        String senderLabel = 'Agent';
        if (msg.sender_type != null && msg.sender_type.equalsIgnoreCase('user')) {
            // Resolve agent name from SF User
            String agentName = resolveAgentName(msg.sender_id);
            senderLabel = String.isNotBlank(agentName) ? agentName : ('Agent ' + msg.sender_id);
        } else if (msg.sender_type != null && msg.sender_type.equalsIgnoreCase('contact')) {
            senderLabel = (aCon != null && String.isNotBlank(aCon.name)) ? aCon.name : 'Customer';
        } else if (msg.sender_type != null && msg.sender_type.equalsIgnoreCase('bot')) {
            senderLabel = 'Bot';
        }

        // Label direction — chat vs SMS
        String directionLabel;
        if (liveChat) {
            directionLabel = (msg.direction == 'out') ? 'Outbound Chat' : 'Inbound Chat';
        } else {
            directionLabel = (msg.direction == 'out') ? 'Outbound SMS' : 'Inbound SMS';
        }

        String timestamp = '';
        if (msg.sent_at != null) {
            timestamp = Datetime.newInstance(msg.sent_at.longValue() * 1000).format('yyyy-MM-dd HH:mm:ss z');
        } else if (msg.created_at != null) {
            timestamp = Datetime.newInstance(msg.created_at.longValue() * 1000).format('yyyy-MM-dd HH:mm:ss z');
        }

        CaseComment cc = new CaseComment(
            ParentId    = caseId,
            CommentBody = '[' + senderLabel + ' - ' + timestamp + ' - ' + directionLabel + ']\n' +
                          (String.isNotBlank(msg.message) ? msg.message : '(no body)'),
            IsPublished = false
        );
        insert cc;
    }

    private static void createTask(Id caseId, Id contactId, Id accountId,
        AvochatoWebhookHandler.AvochatoMessage msg, Boolean liveChat
    ) {
        String agentName = (msg != null) ? resolveAgentName(msg.sender_id) : null;
        Id agentUserId = (msg != null) ? resolveAgentUser(msg.sender_id) : null;
        String name = String.isNotBlank(agentName) ? agentName : 'AR staff';

        String taskSubject = liveChat ? 'Inbound Chat via Avochato' : 'Outbound SMS via Avochato';
        String taskDesc    = liveChat
            ? (name + ' responded to inbound chat conversation via Avochato web widget.' +
               '\nFirst message: ' + (msg != null ? msg.message : ''))
            : (name + ' initiated outbound SMS conversation.' +
               '\nFirst message: ' + (msg != null ? msg.message : ''));

        Task t = new Task(
            Subject      = taskSubject,
            Description  = taskDesc,
            WhatId       = caseId,
            WhoId        = contactId,
            Status       = 'Completed',
            Priority     = 'Normal',
            TaskSubtype  = 'Call',
            ActivityDate = Date.today()
        );
        if (agentUserId != null) {
            t.OwnerId = agentUserId;
        }
        insert t;
    }

    // ── Update case owner to responding agent; create Task on first response ──
    private static void updateCaseOwnerAndTask(
        Case existingCase, Id agentUserId,
        AvochatoWebhookHandler.AvochatoMessage msg,
        Boolean liveChat
    ) {
        // Update owner if the responding agent is different from current owner
        if (existingCase.OwnerId != agentUserId) {
            existingCase.OwnerId = agentUserId;
            update existingCase;
        }
        // Create Task only if none exists yet for this case (first agent response)
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :existingCase.Id LIMIT 1];
        if (tasks.isEmpty()) {
            createTask(existingCase.Id, existingCase.ContactId, existingCase.AccountId, msg, liveChat);
        }
    }

    // ── Find a Solved case for this contact modified within the last 48 hours ──
    // Used to reopen rather than create a duplicate when customer texts back
    private static Case findSolvedCaseForContact(Id contactId) {
        if (contactId == null) return null;
        Datetime cutoff = Datetime.now().addHours(-48);
        List<Case> cases = [
            SELECT Id, Status, Avochato_Ticket_Id__c, ContactId, AccountId, OwnerId
            FROM Case
            WHERE ContactId = :contactId
              AND Status = 'Solved'
              AND LastModifiedDate >= :cutoff
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    // ── Detect live-chat (web widget) vs SMS ──
    // ticket.origin = "live-chat" or "chat" for web chat; "sms" for SMS
    private static Boolean isLiveChat(
        AvochatoWebhookHandler.AvochatoTicket ticket,
        AvochatoWebhookHandler.AvochatoMessage msg
    ) {
        if (ticket != null && String.isNotBlank(ticket.origin)) {
            String orig = ticket.origin.toLowerCase();
            if (orig == 'live-chat' || orig == 'chat') return true;
        }
        return false;
    }

    // ── Validate phone number (reject UUIDs and junk) ──
    @TestVisible
    private static Boolean isValidPhone(String phone) {
        if (String.isBlank(phone)) return false;
        // Real phone numbers start with + or a digit, and are mostly digits
        // Reject anything that looks like a UUID or avochato internal ID
        if (phone.startsWith('avochato:')) return false;
        if (phone.contains('-') && phone.split('-').size() > 4) return false; // UUID pattern
        String digits = phone.replaceAll('[^0-9]', '');
        return digits.length() >= 7; // At minimum 7 digits for a real phone
    }

    // ── Resolve Avochato agent ID → SF User ──
    @TestVisible
    private static Id resolveAgentUser(String avochatoAgentId) {
        if (String.isBlank(avochatoAgentId)) return null;
        User u = getAgentUser(avochatoAgentId);
        return u != null ? u.Id : null;
    }

    @TestVisible
    private static String resolveAgentName(String avochatoAgentId) {
        if (String.isBlank(avochatoAgentId)) return null;
        User u = getAgentUser(avochatoAgentId);
        return u != null ? u.Name : null;
    }

    private static Map<String, User> agentCache = new Map<String, User>();

    private static User getAgentUser(String avochatoAgentId) {
        if (String.isBlank(avochatoAgentId)) return null;
        if (agentCache.containsKey(avochatoAgentId)) return agentCache.get(avochatoAgentId);
        List<User> users = [
            SELECT Id, Name
            FROM User
            WHERE Avochato_Agent_Id__c = :avochatoAgentId
              AND IsActive = true
            LIMIT 1
        ];
        User u = users.isEmpty() ? null : users[0];
        agentCache.put(avochatoAgentId, u);
        return u;
    }

    private static void updateEventStatus(String eventId, String status, String errorMsg) {
        if (String.isBlank(eventId)) return;
        try {
            List<Avochato_Webhook_Event__c> events = [
                SELECT Id FROM Avochato_Webhook_Event__c
                WHERE Event_Id__c = :eventId LIMIT 1
            ];
            if (!events.isEmpty()) {
                events[0].Status__c = status;
                if (String.isNotBlank(errorMsg)) {
                    events[0].Error_Message__c = errorMsg.left(32768);
                }
                update events[0];
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to update event status: ' + e.getMessage());
        }
    }
}