public class StripeSendAdditionalEmailService {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    // -------- FLOW INPUT --------
    public class FlowInput {
        @InvocableVariable(required=true)
        public List<Stripe_Invoice__c> invoices;
    }

    // -------- FLOW OUTPUT --------
    public class FlowResult {
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String message;
    }

    // -------- INVOCABLE METHOD --------
    @InvocableMethod(
        label='Send Stripe Invoice Email'
        description='Send invoice email to Bill To Email with additional emails in CC'
        category='Stripe'
    )
    public static List<FlowResult> sendInvoiceEmails(List<FlowInput> inputs) {
        FlowResult result = new FlowResult();
        List<FlowResult> results = new List<FlowResult>{ result };

        if (inputs == null || inputs.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No invoices provided';
            return results;
        }

        try {
            // Collect invoice ids
            Set<Id> invoiceIds = new Set<Id>();
            for (Stripe_Invoice__c inv : inputs[0].invoices) {
                invoiceIds.add(inv.Id);
            }

            // Query invoices + account emails
            List<Stripe_Invoice__c> invoices = [
                SELECT
                    Id,
                    Name,
                    Stripe_Invoice_Id__c,
                    Invoice_PDF_URL__c,
                    Account__c,
                    Account__r.Name,
                    Account__r.Bill_To_Email__c,
                    Account__r.Bill_to_Contacts__c
                FROM Stripe_Invoice__c
                WHERE Id IN :invoiceIds
            ];

            // Validation of emails (assumes all invoices belong to same customer)
            String billToEmail = invoices[0].Account__r.Bill_To_Email__c;
            String additionalEmails = invoices[0].Account__r.Bill_to_Contacts__c;

            if (String.isBlank(billToEmail)) {
                throw new HandledException('Bill To Email is required for Customer ' + invoices[0].Account__r.Name);
            }
            if (!isSingleEmailValid(billToEmail)) {
                throw new HandledException('Invalid Bill To Email for Customer ' + invoices[0].Account__r.Name);
            }
            if (!isEmailListValid(additionalEmails)) {
                throw new HandledException(
                    'Invalid Additional Bill To Emails for Customer ' + invoices[0].Account__r.Name
                );
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
                WHERE DeveloperName = 'Stripe_Invoice_Email'
                LIMIT 1
            ];

            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

            for (Stripe_Invoice__c inv : invoices) {
                Messaging.SingleEmailMessage mail = buildInvoiceEmail(
                    inv,
                    billToEmail,
                    additionalEmails,
                    template.Id,
                    owea.Id
                );
                emailsToSend.add(mail);
            }

            if (!emailsToSend.isEmpty()) {
                List<Messaging.SendEmailResult> mailRes = Messaging.sendEmail(emailsToSend);

                if (!inspectResults(mailRes)) {
                    throw new HandledException('Failed to send emails');
                }
            }

            result.isSuccess = true;
            result.message = 'Emails sent successfully';
            return results;
        } catch (Exception ex) {
            result.isSuccess = false;
            result.message = ex.getMessage();
            return results;
        }
    }

    // ------------------------------------------------
    // EMAIL BUILDER
    // ------------------------------------------------
    private static Messaging.SingleEmailMessage buildInvoiceEmail(
        Stripe_Invoice__c inv,
        String toEmail,
        String ccEmails,
        Id templateId,
        Id oweaId
    ) {
        // --- Fetch invoice from Stripe ---
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.stripe.com/v1/invoices/' + inv.Stripe_Invoice_Id__c);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Stripe invoice fetch failed');
        }

        Map<String, Object> invoice = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String pdfUrl = (String) invoice.get('invoice_pdf');

        if (String.isBlank(pdfUrl)) {
            throw new CalloutException('Invoice PDF not available');
        }

        // --- Fetch PDF ---
        HttpRequest pdfReq = new HttpRequest();
        pdfReq.setEndpoint(pdfUrl);
        pdfReq.setMethod('GET');
        pdfReq.setTimeout(60000);

        HttpResponse pdfRes = new Http().send(pdfReq);

        // Follow redirect if needed
        if (pdfRes.getStatusCode() >= 300 && pdfRes.getStatusCode() < 400) {
            String redirectUrl = pdfRes.getHeader('Location');
            if (String.isBlank(redirectUrl)) {
                throw new CalloutException('Invoice PDF redirect missing');
            }
            HttpRequest r = new HttpRequest();
            r.setEndpoint(redirectUrl);
            r.setMethod('GET');
            r.setTimeout(60000);
            pdfRes = new Http().send(r);
        }

        if (pdfRes.getStatusCode() != 200) {
            throw new CalloutException('Invoice PDF download failed');
        }

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Invoice-' + inv.Name + '.pdf');
        attachment.setBody(pdfRes.getBodyAsBlob());
        attachment.setContentType('application/pdf');

        // Render the template
        Messaging.SingleEmailMessage renderRes = Messaging.renderStoredEmailTemplate(templateId, null, inv.Id);
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

        // --- Pay URL (Force.com redirect) ---
        String payUrl =
            URL.getOrgDomainUrl().toExternalForm() +
            '/services/apexrest/stripe/invoice/pay?iid=' +
            inv.Stripe_Invoice_Id__c;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(toAddr);
        if (!ccAddr.isEmpty())
            mail.setCcAddresses(ccAddr);
        mail.setSubject(renderedSubject);
        mail.setHtmlBody(renderedBody);
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        mail.setOrgWideEmailAddressId(oweaId);
        mail.setWhatId(inv.Account__c);
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