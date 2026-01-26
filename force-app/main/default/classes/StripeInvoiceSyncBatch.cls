public class StripeInvoiceSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, Stripe_Invoice_Id__c
                FROM Stripe_Invoice__c
                WHERE Stripe_Invoice_Id__c != NULL AND Contract__c = NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Stripe_Invoice__c> scope) {
        List<Stripe_Invoice__c> invoicesToUpdate = new List<Stripe_Invoice__c>();

        for (Stripe_Invoice__c inv : scope) {
            processedCount++;

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/invoices/' + inv.Stripe_Invoice_Id__c);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> stripeInvoice = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    Map<String, Object> parent = (Map<String, Object>) stripeInvoice.get('parent');
                    Map<String, Object> subscriptionDetails = parent != null
                        ? (Map<String, Object>) parent.get('subscription_details')
                        : null;

                    String subscriptionId = subscriptionDetails != null
                        ? (String) subscriptionDetails.get('subscription')
                        : null;

                    if (subscriptionId == null) {
                        successCount++;
                        continue;
                    }

                    List<Contract> contracts = [
                        SELECT Id
                        FROM Contract
                        WHERE Stripe_Subscription_ID__c = :subscriptionId
                        LIMIT 1
                    ];

                    if (contracts.isEmpty()) {
                        errorCount++;
                        errorMessages.add(
                            'No Contract found for subscription ' +
                                subscriptionId +
                                ' (Invoice ' +
                                inv.Stripe_Invoice_Id__c +
                                ')'
                        );
                        continue;
                    }

                    inv.Contract__c = contracts[0].Id;
                    invoicesToUpdate.add(inv);
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add(
                        'Invoice fetch failed for ' + inv.Stripe_Invoice_Id__c + ' | Status: ' + res.getStatusCode()
                    );
                }
            } catch (Exception ex) {
                errorCount++;
                errorMessages.add('Error processing invoice ' + inv.Stripe_Invoice_Id__c + ' | ' + ex.getMessage());
            }
        }

        if (!invoicesToUpdate.isEmpty()) {
            update invoicesToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Batch Process Completed. ' +
                'Processed: ' +
                processedCount +
                ', Success: ' +
                successCount +
                ', Errors: ' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            for (String errMsg : errorMessages) {
                System.debug(errMsg);
            }

            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Sync Error',
                Message__c = errorMessages.size() + ' errors occurred during Stripe Invoice Sync.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceSyncBatch',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice__c'
            );
            insert logger;
        }
    }
}