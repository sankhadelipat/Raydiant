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
        for (Stripe_Invoice__c inv : scope) {
            processed++;

            try {
                String emailList = inv.Account__r.Bill_to_Contacts__c;

                if (!isEmailListValid(emailList)) {
                    error++;
                    errorMessages.add('Invalid additional emails for Invoice ' + inv.Name);
                    continue;
                }

                Messaging.SingleEmailMessage mail = buildInvoiceEmail(inv, emailList);

                List<Messaging.SendEmailResult> results = Messaging.sendEmail(
                    new List<Messaging.SingleEmailMessage>{ mail }
                );

                if (inspectResults(results)) {
                    success++;
                } else {
                    error++;
                    errorMessages.add('Failed to send additional email for Invoice ' + inv.Name);
                }
            } catch (Exception e) {
                error++;
                errorMessages.add(e.getMessage());
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

    public static Messaging.SingleEmailMessage buildInvoiceEmail(Stripe_Invoice__c inv, String emailList) {
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

        List<String> toAddresses = new List<String>();

        for (String e : emailList.split(',')) {
            toAddresses.add(e.trim());
        }

        OrgWideEmailAddress owea = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE DisplayName = 'Displai Billing'
            LIMIT 1
        ];

        // Email body
        String payUrl =
            'https://raydiant.my.salesforce-sites.com/services/apexrest/stripe/invoice/pay?iid=' +
            inv.Stripe_Invoice_Id__c;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(toAddresses);
        mail.setSubject('New invoice from Displai #' + inv.Name);
        mail.setHtmlBody(
            '<p>Hello,</p>' +
                '<p>Please find your invoice attached.</p>' +
                '<p>' +
                '<a href="' +
                payUrl +
                '" style="padding:10px 15px;background:#635bff;color:#fff;text-decoration:none;">' +
                'View & Pay Invoice</a>' +
                '</p>' +
                '<p>Thank you.</p>'
        );
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        mail.setOrgWideEmailAddressId(owea.Id);

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