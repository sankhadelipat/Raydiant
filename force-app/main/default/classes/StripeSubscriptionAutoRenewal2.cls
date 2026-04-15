public class StripeSubscriptionAutoRenewal2 implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Find contracts that is going to expire within 30 days and have auto-renewal enabled and are active
        Date today = Date.today();
        Date thirtyDaysFromToday = Date.today().addDays(30);

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    AccountId,
                    Account.Stripe_Customer_ID__c,
                    Stripe_Subscription_ID__c,
                    Stripe_Subscription_Schedule_ID__c,
                    Renewed_Schedule_ID__c,
                    Renewed_Start_Date__c,
                    Renewed_End_Date__c,
                    Backup_Renewed_Start_Date__c,
                    Backup_Renewed_End_Date__c,
                    EndDate,
                    StartDate,
                    ContractTerm,
                    Status,
                    CurrencyIsoCode,
                    Stripe_Billing_Date__c
                FROM Contract
                WHERE
                    EndDate >= :today
                    AND EndDate <= :thirtyDaysFromToday
                    AND Status = 'Activated'
                    AND DO_NOT_RENEW__c = FALSE
                    AND Renewal_Scheduled__c = FALSE
                    AND Stripe_Subscription_ID__c != NULL
                    AND Account.Stripe_Customer_ID__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract con : scope) {
            contractIds.add(con.Id);
        }
        System.debug('Processing Contracts: ' + contractIds);

        Map<Id, List<SBQQ__Subscription__c>> contractSubscriptionsMap = new Map<Id, List<SBQQ__Subscription__c>>();

        List<SBQQ__Subscription__c> allSubscriptions = [
            SELECT Id, SBQQ__Contract__c, SBQQ__Quantity__c, Stripe_Price_Id__c
            FROM SBQQ__Subscription__c
            WHERE SBQQ__Contract__c IN :contractIds AND F52_Active__c = TRUE AND Stripe_Price_Id__c != NULL
        ];

        for (SBQQ__Subscription__c sub : allSubscriptions) {
            if (!contractSubscriptionsMap.containsKey(sub.SBQQ__Contract__c)) {
                contractSubscriptionsMap.put(sub.SBQQ__Contract__c, new List<SBQQ__Subscription__c>());
            }
            contractSubscriptionsMap.get(sub.SBQQ__Contract__c).add(sub);
        }

        List<Contract> contractsToUpdate = new List<Contract>();

        for (Contract contract : scope) {
            try {
                processedCount++;

                List<SBQQ__Subscription__c> subscriptionItems = contractSubscriptionsMap.get(contract.Id);

                if (subscriptionItems == null || subscriptionItems.isEmpty()) {
                    errorCount++;
                    errorMessages.add('No active subscriptions found for Contract Id: ' + contract.Id);
                    continue;
                }

                String subscriptionScheduleId;

                // Calculate new start and end dates
                Date newStart = contract.EndDate; // Start immediately after expiration
                Integer daysBetween = contract.Backup_Renewed_Start_Date__c != null &&
                    contract.Backup_Renewed_End_Date__c != null
                    ? contract.Backup_Renewed_Start_Date__c.daysBetween(contract.Backup_Renewed_End_Date__c)
                    : contract.Renewed_Start_Date__c != null &&
                          contract.Renewed_End_Date__c != null
                          ? contract.Renewed_Start_Date__c.daysBetween(contract.Renewed_End_Date__c)
                          : contract.StartDate.daysBetween(contract.EndDate);
                Date newEnd = newStart.addDays(daysBetween);

                // Check if contract already has a schedule ID
                if (String.isNotBlank(contract.Stripe_Subscription_Schedule_ID__c)) {
                    // Update existing schedule
                    subscriptionScheduleId = updateExistingSchedule(
                        contract.Stripe_Subscription_Schedule_ID__c,
                        contract,
                        subscriptionItems,
                        newStart,
                        newEnd
                    );
                } else {
                    // Create new schedule
                    subscriptionScheduleId = createNewSchedule(contract);

                    if (String.isNotBlank(subscriptionScheduleId)) {
                        subscriptionScheduleId = updateExistingSchedule(
                            subscriptionScheduleId,
                            contract,
                            subscriptionItems,
                            newStart,
                            newEnd
                        );
                    }
                }

                if (String.isNotBlank(subscriptionScheduleId)) {
                    Contract updatedContract = new Contract(
                        Id = contract.Id,
                        Backup_Renewed_Start_Date__c = null,
                        Backup_Renewed_End_Date__c = null,
                        Renewed_Start_Date__c = newStart,
                        Renewed_End_Date__c = newEnd,
                        Renewed_Schedule_ID__c = subscriptionScheduleId,
                        Latest_Change_Reason__c = 'Auto-renewed: ' + DateTime.now().format()
                    );

                    contractsToUpdate.add(updatedContract);
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add('Failed to create or update schedule for Contract Id: ' + contract.Id);
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add('Error processing Contract Id: ' + contract.Id + '. Error: ' + e.getMessage());
            }
        }

        if (!contractsToUpdate.isEmpty()) {
            try {
                update contractsToUpdate;
            } catch (DmlException dmle) {
                errorMessages.add('Error updating Contracts: ' + dmle.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Subscription Schedule Batch Completed. Processed: ' +
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
                Name = 'Subscription Auto-Renewal Batch',
                Message__c = 'Processed: ' + processedCount + ', Success: ' + successCount + ', Errors: ' + errorCount,
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionAutoRenewal',
                Apex_Method__c = 'execute'
            );
            insert logger;
        }
    }

    private String createNewSchedule(Contract contract) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscription_schedules');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('from_subscription=' + contract.Stripe_Subscription_ID__c);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String scheduleId = (String) payload.get('id');
                return scheduleId;
            } else {
                System.debug('Failed to create empty schedule: ' + res.getStatusCode() + ' - ' + res.getBody());
                throw new CalloutException('Failed to create empty schedule: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error creating empty schedule: ' + e.getMessage());
            throw e;
        }
    }

    private String updateExistingSchedule(
        String subscriptionScheduleId,
        Contract contract,
        List<SBQQ__Subscription__c> subscriptionItems,
        Date startDate,
        Date endDate
    ) {
        try {
            // First get current schedule to get ALL existing phases exactly as they are
            HttpRequest getReq = new HttpRequest();
            getReq.setEndpoint('https://api.stripe.com/v1/subscription_schedules/' + subscriptionScheduleId);
            getReq.setMethod('GET');
            getReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse getRes = http.send(getReq);

            if (getRes.getStatusCode() != 200) {
                System.debug('Failed to get existing schedule: ' + getRes.getBody());
                throw new CalloutException('Failed to get existing schedule: ' + getRes.getBody());
            }

            // Calculate phase dates
            Long phaseStart = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000;
            Long phaseEnd = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000;

            Map<String, Object> existingSchedule = (Map<String, Object>) JSON.deserializeUntyped(getRes.getBody());
            List<Object> existingPhases = (List<Object>) existingSchedule.get('phases');

            // Prepare update - include ALL existing phases exactly as they are from Stripe
            List<String> bodyParts = new List<String>();

            // Copy ALL existing phases exactly as they are
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
                    bodyParts.add('phases[' + i + '][proration_behavior]=' + (String) phase.get('proration_behavior'));
                }

                // Copy billing_cycle_anchor if exists
                if (phase.containsKey('billing_cycle_anchor') && phase.get('billing_cycle_anchor') != null) {
                    bodyParts.add(
                        'phases[' + i + '][billing_cycle_anchor]=' + (String) phase.get('billing_cycle_anchor')
                    );
                }
            }

            // Now add new phase at the end with new dates and items
            Integer newPhaseIndex = existingPhases.size();
            // bodyParts.add('phases[' + newPhaseIndex + '][start_date]=' + phaseStart);
            bodyParts.add('phases[' + newPhaseIndex + '][end_date]=' + phaseEnd);
            bodyParts.add('phases[' + newPhaseIndex + '][proration_behavior]=none');
            bodyParts.add('phases[' + newPhaseIndex + '][billing_cycle_anchor]=automatic');

            // Add items to the new phase
            Integer itemIndex = 0;
            for (SBQQ__Subscription__c item : subscriptionItems) {
                bodyParts.add(
                    'phases[' + newPhaseIndex + '][items][' + itemIndex + '][price]=' + item.Stripe_Price_Id__c
                );
                bodyParts.add(
                    'phases[' +
                        newPhaseIndex +
                        '][items][' +
                        itemIndex +
                        '][quantity]=' +
                        Integer.valueOf(item.SBQQ__Quantity__c)
                );
                itemIndex++;
            }

            // Update metadata
            Map<String, Object> existingMetadata = existingSchedule.containsKey('metadata')
                ? (Map<String, Object>) existingSchedule.get('metadata')
                : new Map<String, Object>();

            bodyParts.add('metadata[auto_renewal]=true');
            bodyParts.add('metadata[salesforce_contract_id]=' + contract.Id);
            bodyParts.add('metadata[renewal_date]=' + String.valueOf(Date.today()));
            bodyParts.add(
                'metadata[renewal_count]=' +
                (existingMetadata.containsKey('renewal_count')
                    ? String.valueOf(Integer.valueOf(existingMetadata.get('renewal_count')) + 1)
                    : '1')
            );

            HttpRequest updateReq = new HttpRequest();
            updateReq.setEndpoint('https://api.stripe.com/v1/subscription_schedules/' + subscriptionScheduleId);
            updateReq.setMethod('POST');
            updateReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            updateReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            updateReq.setBody(String.join(bodyParts, '&'));

            HttpResponse updateRes = http.send(updateReq);

            if (updateRes.getStatusCode() == 200) {
                return subscriptionScheduleId;
            } else {
                System.debug('Failed to update existing schedule: ' + updateRes.getBody());
                throw new CalloutException('Failed to update existing schedule: ' + updateRes.getBody());
            }
        } catch (Exception e) {
            System.debug('Error updating existing schedule with phase: ' + e.getMessage());
            throw e;
        }
    }
}