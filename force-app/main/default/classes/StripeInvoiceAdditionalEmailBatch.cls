public class StripeInvoiceAdditionalEmailBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private Set<Id> invoiceIds;
    private Integer processed = 0;
    private Integer success = 0;
    private Integer error = 0;
    private List<String> errorMessages = new List<String>();

    public StripeInvoiceAdditionalEmailBatch(Set<Id> invoiceIds) {
        this.invoiceIds = invoiceIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, Name, Status__c, Stripe_Invoice_Id__c, Invoice_PDF_URL__c, Account__r.Bill_to_Contacts__c
                FROM Stripe_Invoice__c
                WHERE Id IN :invoiceIds AND Status__c = 'Open'
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Stripe_Invoice__c> scope) {
        // Get org wide email address
        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Displai Billing'
            LIMIT 1
        ];

        // Get email template
        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'Stripe_Invoice_Email'
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Stripe_Invoice__c inv : scope) {
            processed++;

            try {
                String emailList = inv.Account__r.Bill_to_Contacts__c;

                if (!isEmailListValid(emailList)) {
                    error++;
                    errorMessages.add('Invalid additional emails for Invoice ' + inv.Name);
                    continue;
                }

                Messaging.SingleEmailMessage mail = buildInvoiceEmail(inv, emailList, template.Id, owea.Id);

                emailsToSend.add(mail);
            } catch (Exception e) {
                error++;
                errorMessages.add(e.getMessage());
            }
        }

        // Send bulk email
        if (!emailsToSend.isEmpty()) {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend);

            for (Messaging.SendEmailResult result : results) {
                if (result.isSuccess()) {
                    success++;
                } else {
                    error++;
                    errorMessages.add(result.getErrors()[0].getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Batch Process Summary:\n' +
                'Total Invoices Processed: ' +
                processed +
                '\n' +
                'Successful Updates: ' +
                success +
                '\n' +
                'Errors: ' +
                error +
                '\n'
        );

        if (!errorMessages.isEmpty()) {
            for (String errMsg : errorMessages) {
                System.debug('Error: ' + errMsg);
            }

            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Additional Email Sent Failed',
                Message__c = 'Processed=' + processed + ', Success=' + success + ', Errors=' + error,
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceAdditionalEmailBatch',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice__c'
            );
            insert logger;
        }
    }

    // -------------------------
    // Helpers
    // -------------------------
    public static Messaging.SingleEmailMessage buildInvoiceEmail(
        Stripe_Invoice__c inv,
        String emailList,
        Id templateId,
        Id oweaId
    ) {
        // Fetch PDF
        HttpRequest pdfReq = new HttpRequest();
        pdfReq.setEndpoint(inv.Invoice_PDF_URL__c);
        pdfReq.setMethod('GET');
        pdfReq.setTimeout(60000);

        HttpResponse pdfRes = new Http().send(pdfReq);

        if (pdfRes.getStatusCode() >= 300 && pdfRes.getStatusCode() < 400) {
            String redirectUrl = pdfRes.getHeader('Location');

            if (String.isNotBlank(redirectUrl)) {
                HttpRequest redirectReq = new HttpRequest();
                redirectReq.setEndpoint(redirectUrl);
                redirectReq.setMethod('GET');
                redirectReq.setTimeout(60000);

                pdfRes = new Http().send(redirectReq);
            } else {
                throw new CalloutException('Invoice PDF download failed for Invoice ' + inv.Name);
            }
        }

        if (pdfRes.getStatusCode() != 200) {
            throw new CalloutException('Invoice PDF download failed for Invoice ' + inv.Name);
        }

        // Attachment
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Invoice-' + inv.Name + '.pdf');
        attachment.setBody(pdfRes.getBodyAsBlob());
        attachment.setContentType('application/pdf');

        // Render the template
        Messaging.SingleEmailMessage renderRes = Messaging.renderStoredEmailTemplate(templateId, null, inv.Id);
        String renderedSubject = renderRes.getSubject();
        String renderedBody = renderRes.getHtmlBody();

        List<String> toAddresses = new List<String>();
        for (String e : emailList.split(',')) {
            toAddresses.add(e.trim());
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(toAddresses);
        mail.setSubject(renderedSubject);
        mail.setHtmlBody(renderedBody);
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        mail.setOrgWideEmailAddressId(oweaId);
        mail.setWhatId(inv.Account__c);
        mail.setSaveAsActivity(true);

        return mail;
    }

    private static Boolean isEmailListValid(String emailList) {
        if (String.isBlank(emailList)) {
            return false;
        }

        List<String> emails = emailList.split(',');
        for (String email : emails) {
            if (!Pattern.matches('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$', email.trim())) {
                return false;
            }
        }
        return true;
    }
}