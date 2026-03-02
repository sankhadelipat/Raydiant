public class StripeSendPaymentLinkEmailService {
    public class FlowResult {
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String message;
    }

    @InvocableMethod(
        label='Send Stripe Payment Link Email'
        description='Send payment link email to Bill To Email with additional emails in CC'
        category='Stripe'
    )
    public static List<FlowResult> sendPaymentLinkEmails(List<String> quoteIds) {
        FlowResult result = new FlowResult();
        List<FlowResult> results = new List<FlowResult>{ result };

        if (quoteIds == null || quoteIds.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No Quote ID provided';
            return results;
        }

        try {
            // Get quotes + account emails
            SBQQ__Quote__c quote = [
                SELECT
                    Id,
                    Name,
                    SBQQ__Account__c,
                    SBQQ__Account__r.Name,
                    SBQQ__Account__r.Bill_To_Email__c,
                    SBQQ__Account__r.Bill_to_Contacts__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteIds[0]
                LIMIT 1
            ];

            // Validation of emails
            String billToEmail = quote.SBQQ__Account__r.Bill_To_Email__c;
            String additionalEmails = quote.SBQQ__Account__r.Bill_to_Contacts__c;

            if (String.isBlank(billToEmail)) {
                throw new HandledException('Bill To Email is required for Customer ' + quote.SBQQ__Account__r.Name);
            }
            if (!isSingleEmailValid(billToEmail)) {
                throw new HandledException('Invalid Bill To Email for Customer ' + quote.SBQQ__Account__r.Name);
            }
            if (!isEmailListValid(additionalEmails)) {
                throw new HandledException('Invalid additional emails for Customer ' + quote.SBQQ__Account__r.Name);
            }

            // Org Wide Email (query once)
            OrgWideEmailAddress owea = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE DisplayName = 'Displai Billing'
                LIMIT 1
            ];

            // Email template
            EmailTemplate template = [
                SELECT Id
                FROM EmailTemplate
                WHERE DeveloperName = 'Stripe_Checkout_Email'
                LIMIT 1
            ];

            // Build and send emails
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

            Messaging.SingleEmailMessage mail = buildPaymentLinkEmail(
                quote,
                billToEmail,
                additionalEmails,
                template.Id,
                owea.Id
            );
            emailsToSend.add(mail);

            if (!emailsToSend.isEmpty()) {
                List<Messaging.SendEmailResult> emailResults = Messaging.sendEmail(emailsToSend);

                if (!inspectResults(emailResults)) {
                    throw new HandledException('Failed to send email');
                }
            }

            result.isSuccess = true;
            result.message = 'Payment link email sent successfully';
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
        }

        return results;
    }

    private static Messaging.SingleEmailMessage buildPaymentLinkEmail(
        SBQQ__Quote__c quote,
        String toEmail,
        String ccEmails,
        Id templateId,
        Id orgWideEmailId
    ) {
        // Render the template to get the email body and subject
        Messaging.SingleEmailMessage renderRes = Messaging.renderStoredEmailTemplate(templateId, null, quote.Id);
        String renderedSubject = renderRes.getSubject();
        String renderedBody = renderRes.getHtmlBody();

        // --- Email addresses ---
        List<String> toAddr = new List<String>{ toEmail.trim() };

        List<String> ccAddr = new List<String>();
        if (String.isNotBlank(ccEmails)) {
            for (String e : ccEmails.split(',')) {
                ccAddr.add(e.trim());
            }
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddr);
        if (!String.isBlank(ccEmails)) {
            mail.setCcAddresses(ccAddr);
        }
        mail.setSubject(renderedSubject);
        mail.setHtmlBody(renderedBody);
        mail.setOrgWideEmailAddressId(orgWideEmailId);
        mail.setWhatId(quote.SBQQ__Account__c);
        mail.setSaveAsActivity(true);

        return mail;
    }

    // ------------------------------------------------
    // VALIDATION
    // ------------------------------------------------
    private static Boolean isSingleEmailValid(String email) {
        return Pattern.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', email.trim());
    }

    private static Boolean isEmailListValid(String emailList) {
        if (String.isNotBlank(emailList)) {
            for (String e : emailList.split(',')) {
                if (!isSingleEmailValid(e.trim())) {
                    return false;
                }
            }
        }
        return true;
    }

    // ------------------------------------------------
    // INSPECT RESULTS
    // ------------------------------------------------
    private static Boolean inspectResults(Messaging.SendEmailResult[] results) {
        Boolean sendResult = true;

        for (Messaging.SendEmailResult res : results) {
            if (res.isSuccess()) {
                System.debug('Email sent successfully');
            } else {
                sendResult = false;
                System.debug('The following errors occurred: ' + res.getErrors());
            }
        }
        return sendResult;
    }
}