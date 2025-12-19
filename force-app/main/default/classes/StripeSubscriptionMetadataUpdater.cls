public class StripeSubscriptionMetadataUpdater implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String stripeSubscriptionId;
    String subscriptionSource;

    public StripeSubscriptionMetadataUpdater(String stripeSubscriptionId, String subscriptionSource) {
        this.stripeSubscriptionId = stripeSubscriptionId;
        this.subscriptionSource = subscriptionSource;
    }

    public void execute(QueueableContext context) {
        try {
            // Fetch the Contract associated with the Stripe Subscription ID
            List<Contract> contracts = [
                SELECT Id, Contract_Record_URL__c, ContractNumber
                FROM Contract
                WHERE Stripe_Subscription_ID__c = :stripeSubscriptionId
                LIMIT 1
            ];

            if (!contracts.isEmpty()) {
                Contract contract = contracts[0];

                // Prepare metadata
                Map<String, Object> metadata = new Map<String, Object>{
                    'subscription_source' => subscriptionSource,
                    'Contract_ID' => contract.Id,
                    'Contract_Number' => contract.ContractNumber,
                    'Contract_Record_URL' => contract.Contract_Record_URL__c
                };

                // Make the HTTP request
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + stripeSubscriptionId);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                List<String> bodyParams = new List<String>();
                for (String key : metadata.keySet()) {
                    bodyParams.add(
                        'metadata[' + key + ']=' + EncodingUtil.urlEncode(String.valueOf(metadata.get(key)), 'UTF-8')
                    );
                }
                req.setBody(String.join(bodyParams, '&'));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    // Metadata update successful
                    System.debug('Metadata updated successfully for Stripe Subscription ID: ' + stripeSubscriptionId);
                } else {
                    // Handle error response
                    System.debug(
                        'Failed to update metadata for Stripe Subscription ID: ' +
                            stripeSubscriptionId +
                            '. Response: ' +
                            res.getBody()
                    );
                    throw new CalloutException('Failed to update metadata. Status Code: ' + res.getStatusCode());
                }
            }
        } catch (Exception e) {
            System.debug('Error updating metadata for Stripe Subscription ID: ' + stripeSubscriptionId);
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Metadata Updating Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionMetadataUpdater',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Contract'
            );
        }
    }
}