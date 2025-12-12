public class StripeInvoicePreviewBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, Stripe_Subscription_ID__c
                FROM Contract
                WHERE Stripe_Subscription_ID__c != NULL AND Next_Billing_Date__c = NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        System.debug('Scope: ' + scope);
        List<Contract> contractsToUpdate = new List<Contract>();

        for (Contract contract : scope) {
            processedCount++;
            String subscriptionId = contract.Stripe_Subscription_ID__c;

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/invoices/create_preview');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req.setBody('subscription=' + EncodingUtil.urlEncode(subscriptionId, 'UTF-8'));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getstatusCode() == 200) {
                    Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    Long nextBillingTimestamp;

                    if (preview.containsKey('next_payment_attempt') && preview.get('next_payment_attempt') != null) {
                        nextBillingTimestamp = (Long) preview.get('next_payment_attempt');
                    } else if (preview.containsKey('created') && preview.get('created') != null) {
                        nextBillingTimestamp = (Long) preview.get('created');
                    } else if (preview.containsKey('period_end') && preview.get('period_end') != null) {
                        nextBillingTimestamp = (Long) preview.get('period_end');
                    } else {
                        System.debug('No next billing date found in preview response for Contract Id: ' + contract.Id);
                        continue;
                    }

                    Date nextBillingDate = DateTime.newInstance(nextBillingTimestamp * 1000).date();
                    contract.Next_Billing_Date__c = nextBillingDate;
                    contractsToUpdate.add(contract);
                    successCount++;
                } else if (res.getstatusCode() == 404) {
                    System.debug('No upcoming invoices for subscription: ' + subscriptionId);
                    successCount++;
                } else {
                    System.debug(
                        'Error retrieving invoice preview for subscription: ' +
                            subscriptionId +
                            ' - Status Code: ' +
                            res.getstatusCode() +
                            ' - Body: ' +
                            res.getBody()
                    );
                    errorCount++;
                    errorMessages.add(
                        'Error retrieving invoice preview for subscription: ' +
                            subscriptionId +
                            ' - Status Code: ' +
                            res.getstatusCode()
                    );
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add('Error processing Contract Id: ' + contract.Id + ' - ' + e.getMessage());
                System.debug('Error processing Contract Id: ' + contract.Id + ' - ' + e.getMessage());
            }
        }

        // Update contracts
        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Batch Process Completed. Processed: ' +
                processedCount +
                ', Success: ' +
                successCount +
                ', Errors: ' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            for (String errMsg : errorMessages) {
                System.debug('Error: ' + errMsg);
            }

            Logger__c logger = new Logger__c(
                Name = '(BATCH) Stripe Invoice Preview Error',
                Message__c = errorMessages.size() + ' errors occurred during Stripe Invoice Preview Batch.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoicePreviewBatch',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Contract'
            );
        }
    }
}