public class StripeSubscriptionItemPriceIdMigration implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Stripe_Subscription_ID__c,
                    Stripe_Price_ID__c,
                    SBQQ__Quantity__c,
                    SBQQ__Contract__r.Stripe_Subscription_ID__c
                FROM SBQQ__Subscription__c
                WHERE
                    F52_Active__c = TRUE
                    AND Stripe_Subscription_ID__c != NULL
                    AND Stripe_Price_ID__c != NULL
                    AND SBQQ__Contract__r.Stripe_Subscription_ID__c != NULL
                    AND SBQQ__Contract__r.Contract_Migration__c = TRUE
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> scope) {
        for (SBQQ__Subscription__c sub : scope) {
            try {
                processedCount++;

                // Update the subscription item in Stripe
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscription_items/' + sub.Stripe_Subscription_ID__c);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                // Build request body
                List<String> bodyParts = new List<String>();
                bodyParts.add('price=' + EncodingUtil.urlEncode(sub.Stripe_Price_ID__c, 'UTF-8'));
                bodyParts.add('quantity=' + String.valueOf(sub.SBQQ__Quantity__c.intValue()));

                req.setBody(String.join(bodyParts, '&'));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    // Successfully updated Stripe subscription item
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add(
                        'Error updating subscription item ' +
                            sub.Stripe_Subscription_ID__c +
                            ': ' +
                            res.getStatusCode() +
                            ' - ' +
                            res.getStatus() +
                            ' - ' +
                            res.getBody()
                    );
                    System.debug('Error updating subscription item: ' + res.getBody());
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add('Error processing subscription ' + sub.Id + ': ' + e.getMessage());
                System.debug('Error processing subscription: ' + e.getStackTraceString());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Stripe Subscription Item Update Batch Completed. Processed: ' +
                processedCount +
                ', Success: ' +
                successCount +
                ', Errors: ' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Item Update Batch',
                Message__c = 'Processed: ' + processedCount + ', Success: ' + successCount + ', Errors: ' + errorCount,
                StackTrace__c = String.join(errorMessages, '\n'),
                Status__c = 'Success',
                Apex_Class__c = 'StripeSubscriptionItemPriceIdMigration',
                Apex_Method__c = 'finish',
                Object_Name__c = 'SBQQ__Subscription__c'
            );
            insert logger;
        }
    }
}