public class StripeRenewalCancellationService implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private List<Id> contractIds;

    public StripeRenewalCancellationService(List<Id> contractIds) {
        this.contractIds = contractIds;
    }

    public void execute(QueueableContext context) {
        List<Contract> contractsToUpdate = new List<Contract>();

        for (Contract con : [
            SELECT Id, Renewed_Schedule_ID__c
            FROM Contract
            WHERE Id IN :contractIds AND Renewed_Schedule_ID__c != NULL
        ]) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(
                    'https://api.stripe.com/v1/subscription_schedules/' + con.Renewed_Schedule_ID__c + '/cancel'
                );
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    con.Renewed_Schedule_ID__c = null;
                    contractsToUpdate.add(con);
                } else {
                    System.debug('Failed to delete schedule ' + con.Renewed_Schedule_ID__c + ' : ' + res.getBody());
                    throw new CalloutException(
                        'Failed to delete schedule ' + con.Renewed_Schedule_ID__c + ' : ' + res.getBody()
                    );
                }
            } catch (Exception e) {
                System.debug('Error deleting schedule for Contract ' + con.Id + ' : ' + e.getMessage());

                Logger__c logger = new Logger__c(
                    Name = 'Stripe Renewal Cancellation Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeRenewalCancellationService',
                    Apex_Method__c = 'execute',
                    Object_Name__c = 'Contract'
                );
                insert logger;
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }
    }
}