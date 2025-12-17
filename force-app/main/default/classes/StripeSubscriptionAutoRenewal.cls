public class StripeSubscriptionAutoRenewal implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Find contracts that expire tomorrow and have auto-renewal enabled and are active
        Date tomorrow = Date.today().addDays(1);

        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    AccountId,
                    Account.Stripe_Customer_ID__c,
                    Stripe_Subscription_ID__c,
                    Stripe_Subscription_Schedule_ID__c,
                    SBQQ__Quote__c,
                    EndDate,
                    StartDate,
                    ContractTerm,
                    Status,
                    CurrencyIsoCode,
                    Stripe_Billing_Date__c
                FROM Contract
                WHERE
                    EndDate = :tomorrow
                    AND Renewed_End_Date__c = NULL
                    AND Status = 'Activated'
                    AND DO_NOT_RENEW__c = FALSE
                    AND Stripe_Subscription_ID__c != NULL
                    AND Account.Stripe_Customer_ID__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        // Collect Contract Ids and related Quote Ids
        Set<Id> contractIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> quoteIds = new Set<Id>();
        for (Contract con : scope) {
            contractIds.add(con.Id);
            accountIds.add(con.AccountId);
            if (con.SBQQ__Quote__c != null)
                quoteIds.add(con.SBQQ__Quote__c);
        }
        System.debug('Processing Contracts: ' + contractIds);

        // Bulk query subscriptions related to these contracts
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

        // Bulk query quotes related to these contracts
        Map<Id, SBQQ__Quote__c> contractQuoteMap = new Map<Id, SBQQ__Quote__c>();

        List<SBQQ__Quote__c> allQuotes = [
            SELECT Id, SBQQ__PaymentTerms__c, CurrencyIsoCode
            FROM SBQQ__Quote__c
            WHERE Id IN :quoteIds
        ];

        for (SBQQ__Quote__c quote : allQuotes) {
            contractQuoteMap.put(quote.Id, quote);
        }

        Map<Id, Boolean> accountHasPaymentMethod = new Map<Id, Boolean>();

        List<AggregateResult> paymentMethods = [
            SELECT Account__c acct, COUNT(Id) cnt
            FROM Stripe_Payment_Method__c
            WHERE Account__c IN :accountIds
            GROUP BY Account__c
        ];

        for (AggregateResult pm : paymentMethods) {
            accountHasPaymentMethod.put((Id) pm.get('acct'), ((Integer) pm.get('cnt')) > 0);
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

                SBQQ__Quote__c quote = contractQuoteMap.get(contract.SBQQ__Quote__c);
                Boolean hasPaymentMethod = accountHasPaymentMethod.get(contract.AccountId) == true;

                // Calculate new start and end dates
                Date newStart = contract.EndDate; // Start immediately after expiration
                Integer daysBetween = contract.StartDate.daysBetween(contract.EndDate);
                Date newEnd = contract.ContractTerm != null
                    ? newStart.addMonths(contract.ContractTerm)
                    : newStart.addDays(daysBetween);

                // Create new subscription schedule in Stripe
                String scheduleId = createNewSchedule(
                    contract,
                    subscriptionItems,
                    quote,
                    hasPaymentMethod,
                    newStart,
                    newEnd
                );

                if (scheduleId != null) {
                    contract.Renewed_End_Date__c = newEnd;
                    contract.DO_NOT_RENEW__c = true;
                    contractsToUpdate.add(contract);
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add('Failed to create subscription schedule for Contract Id: ' + contract.Id);
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
            'Auto-renew batch completed. Processed: ' +
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

    private String createNewSchedule(
        Contract contract,
        List<SBQQ__Subscription__c> subscriptions,
        SBQQ__Quote__c quote,
        Boolean hasPaymentMethod,
        Date startDate,
        Date endDate
    ) {
        try {
            Long startUnix =
                DateTime.newInstanceGmt(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0).getTime() / 1000;
            Long endUnix =
                DateTime.newInstanceGmt(endDate.year(), endDate.month(), endDate.day(), 0, 0, 0).getTime() / 1000;
            Integer daysUntilDue = 0;

            if (quote != null) {
                if (quote.SBQQ__PaymentTerms__c != null || String.isNotBlank(quote.SBQQ__PaymentTerms__c)) {
                    if (quote.SBQQ__PaymentTerms__c == 'Prepayment') {
                        daysUntilDue = 0;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Due on receipt') {
                        daysUntilDue = 0;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Net 15') {
                        daysUntilDue = 15;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Net 30') {
                        daysUntilDue = 30;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Net 45') {
                        daysUntilDue = 45;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Net 60') {
                        daysUntilDue = 60;
                    } else if (quote.SBQQ__PaymentTerms__c == 'Net 90') {
                        daysUntilDue = 90;
                    } else {
                        daysUntilDue = 0; // Default to no due date
                    }
                }
            }

            List<String> bodyParts = new List<String>();

            // Build request body
            bodyParts.add('customer=' + EncodingUtil.urlEncode(contract.Account.Stripe_Customer_ID__c, 'UTF-8'));
            bodyParts.add('start_date=' + String.valueOf(startUnix));
            bodyParts.add('end_behavior=cancel');
            bodyParts.add('default_settings[billing_cycle_anchor]=automatic');
            System.debug('Payment method: ' + hasPaymentMethod);
            if (hasPaymentMethod)
                bodyParts.add('default_settings[collection_method]=charge_automatically');
            else
                bodyParts.add('default_settings[collection_method]=send_invoice');
            if (!hasPaymentMethod)
                bodyParts.add('default_settings[invoice_settings][days_until_due]=' + String.valueOf(daysUntilDue));
            bodyParts.add('billing_mode[type]=flexible');

            // Metadata
            // if (quote != null)
            //     bodyParts.add('metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            bodyParts.add('metadata[subscription_source]=salesforce');
            bodyParts.add('metadata[subscription_schedule]=true');
            bodyParts.add('metadata[auto_renewal]=true');

            // Phase
            bodyParts.add('phases[0][currency]=' + EncodingUtil.urlEncode(contract.CurrencyIsoCode, 'UTF-8'));
            bodyParts.add('phases[0][end_date]=' + String.valueOf(endUnix));
            bodyParts.add('phases[0][proration_behavior]=none');
            // if (quote != null)
            //     bodyParts.add('phases[0][metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            bodyParts.add('phases[0][metadata][subscription_source]=salesforce');
            bodyParts.add('phases[0][metadata][subscription_schedule]=true');
            bodyParts.add('phases[0][metadata][auto_renewal]=true');
            bodyParts.add('phases[0][metadata][renewed_from_contract]=' + EncodingUtil.urlEncode(contract.Id, 'UTF-8'));
            bodyParts.add(
                'phases[0][metadata][renewal_date]=' + EncodingUtil.urlEncode(String.valueOf(Date.today()), 'UTF-8')
            );

            // Subscription Items
            Integer index = 0;
            for (SBQQ__Subscription__c subItem : subscriptions) {
                bodyParts.add(
                    'phases[0][items][' +
                        index +
                        '][price]=' +
                        EncodingUtil.urlEncode(subItem.Stripe_Price_Id__c, 'UTF-8')
                );
                bodyParts.add(
                    'phases[0][items][' + index + '][quantity]=' + Integer.valueOf(subItem.SBQQ__Quantity__c)
                );
                index++;
            }

            String requestBody = String.join(bodyParts, '&');

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscription_schedules');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Subscription Schedule created successfully');
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) resMap.get('id');
            } else {
                System.debug(
                    'Failed to create Subscription Schedule. Status: ' +
                        res.getStatusCode() +
                        ', Body: ' +
                        res.getBody()
                );
                return null;
            }
        } catch (Exception e) {
            System.debug('Error creating empty schedule: ' + e.getMessage());
            throw e;
        }
    }
}
