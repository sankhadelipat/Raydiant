public class StripeRenewalCancellationService implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private List<Id> contractIds;

    public StripeRenewalCancellationService(List<Id> contractIds) {
        this.contractIds = contractIds;
    }

    public void execute(QueueableContext context) {
        List<Contract> contractsToUpdate = new List<Contract>();
        Http http = new Http();

        for (Contract con : [
            SELECT
                Id,
                Renewed_Schedule_ID__c,
                Renewed_Start_Date__c,
                Renewed_End_Date__c,
                Backup_Renewed_Start_Date__c,
                Backup_Renewed_End_Date__c
            FROM Contract
            WHERE Id IN :contractIds AND Renewed_Schedule_ID__c != NULL
        ]) {
            try {
                // First get current schedule to get ALL existing phases exactly as they are
                HttpRequest getReq = new HttpRequest();
                getReq.setEndpoint('https://api.stripe.com/v1/subscription_schedules/' + con.Renewed_Schedule_ID__c);
                getReq.setMethod('GET');
                getReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

                HttpResponse getRes = http.send(getReq);

                if (getRes.getStatusCode() != 200) {
                    System.debug('Failed to get existing schedule: ' + getRes.getBody());
                    throw new CalloutException('Failed to get existing schedule: ' + getRes.getBody());
                }

                Map<String, Object> existingSchedule = (Map<String, Object>) JSON.deserializeUntyped(getRes.getBody());
                List<Object> existingPhases = (List<Object>) existingSchedule.get('phases');

                // Now delete the latest phase
                existingPhases.remove(existingPhases.size() - 1);

                // Recreate the schedule with the remaining phases
                List<String> bodyParts = new List<String>();

                // Copy all existing phases except the last one
                for (Integer i = 0; i < existingPhases.size(); i++) {
                    Map<String, Object> phase = (Map<String, Object>) existingPhases[i];

                    // Copy duration if exists
                    if (phase.containsKey('duration') && phase.get('duration') != null) {
                        Map<String, Object> duration = (Map<String, Object>) phase.get('duration');
                        bodyParts.add('phases[' + i + '][duration][interval]=' + (String) duration.get('interval'));
                        bodyParts.add('phases[' + i + '][duration][interval_count]=' + duration.get('interval_count'));
                    }

                    // Copy start_date if exists
                    if (phase.containsKey('start_date') && phase.get('start_date') != null) {
                        bodyParts.add('phases[' + i + '][start_date]=' + phase.get('start_date'));
                    }

                    // Copy end_date if exists
                    if (phase.containsKey('end_date') && phase.get('end_date') != null) {
                        bodyParts.add('phases[' + i + '][end_date]=' + phase.get('end_date'));
                    }

                    // Copy items exactly as they are
                    if (phase.containsKey('items')) {
                        List<Object> items = (List<Object>) phase.get('items');
                        for (Integer j = 0; j < items.size(); j++) {
                            Map<String, Object> item = (Map<String, Object>) items[j];
                            bodyParts.add('phases[' + i + '][items][' + j + '][price]=' + (String) item.get('price'));
                            bodyParts.add('phases[' + i + '][items][' + j + '][quantity]=' + item.get('quantity'));
                        }
                    }

                    // Copy proration_behavior if exists
                    if (phase.containsKey('proration_behavior') && phase.get('proration_behavior') != null) {
                        bodyParts.add(
                            'phases[' + i + '][proration_behavior]=' + (String) phase.get('proration_behavior')
                        );
                    }

                    // Copy billing_cycle_anchor if exists
                    if (phase.containsKey('billing_cycle_anchor') && phase.get('billing_cycle_anchor') != null) {
                        bodyParts.add(
                            'phases[' + i + '][billing_cycle_anchor]=' + (String) phase.get('billing_cycle_anchor')
                        );
                    }
                }

                // Update metadata
                Map<String, Object> existingMetadata = existingSchedule.containsKey('metadata')
                    ? (Map<String, Object>) existingSchedule.get('metadata')
                    : new Map<String, Object>();

                bodyParts.add('metadata[auto_renewal]=false');
                bodyParts.add(
                    'metadata[renewal_count]=' +
                    (existingMetadata.containsKey('renewal_count')
                        ? String.valueOf(Integer.valueOf(existingMetadata.get('renewal_count')) - 1)
                        : '0')
                );

                HttpRequest updateReq = new HttpRequest();
                updateReq.setEndpoint('https://api.stripe.com/v1/subscription_schedules/' + con.Renewed_Schedule_ID__c);
                updateReq.setMethod('POST');
                updateReq.setHeader(
                    'Authorization',
                    'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                );
                updateReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                updateReq.setBody(String.join(bodyParts, '&'));

                HttpResponse updateRes = http.send(updateReq);

                if (updateRes.getStatusCode() == 200) {
                    // Clear the renewal schedule ID from the contract
                    con.Renewed_Schedule_ID__c = null;
                    con.Backup_Renewed_Start_Date__c = con.Renewed_Start_Date__c;
                    con.Backup_Renewed_End_Date__c = con.Renewed_End_Date__c;
                    con.Renewed_Start_Date__c = null;
                    con.Renewed_End_Date__c = null;
                    contractsToUpdate.add(con);
                } else {
                    System.debug('Failed to update existing schedule: ' + updateRes.getBody());
                    throw new CalloutException('Failed to update existing schedule: ' + updateRes.getBody());
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