public class StripeSubscriptionItemMigration implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
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
                    AccountId,
                    SBQQ__Opportunity__c,
                    SBQQ__Quote__c,
                    SBQQ__Order__c,
                    StartDate,
                    Account.Stripe_Customer_ID__c,
                    Current_Migration_Start_Date__c,
                    Current_Migration_End_Date__c,
                    Stripe_Billing_Date__c,
                    CreatedDate
                FROM Contract
                WHERE Contract_Migration__c = TRUE AND Stripe_Subscription_ID__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        List<SBQQ__Subscription__c> subscriptionsToUpsert = new List<SBQQ__Subscription__c>();
        List<Contract> contractsToUpdate = new List<Contract>();

        for (Contract contract : scope) {
            try {
                processedCount++;

                // Fetch subscription details from Stripe
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + contract.Stripe_Subscription_ID__c);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> subscriptionData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    // Update contract with latest Stripe data
                    Contract updatedContract = updateContractFromStripe(contract, subscriptionData);
                    if (updatedContract != null) {
                        contractsToUpdate.add(updatedContract);
                    }

                    // Process subscription items
                    List<SBQQ__Subscription__c> subscriptionItems = processSubscriptionItems(
                        subscriptionData,
                        contract.Id,
                        contract.AccountId
                    );
                    subscriptionsToUpsert.addAll(subscriptionItems);

                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add(
                        'Error fetching subscription ' +
                            contract.Stripe_Subscription_ID__c +
                            ': ' +
                            res.getStatusCode() +
                            ' - ' +
                            res.getStatus()
                    );
                }
            } catch (Exception ex) {
                errorCount++;
                errorMessages.add('Error processing contract ' + contract.Id + ': ' + ex.getMessage());
                System.debug('Error: ' + ex.getStackTraceString());
            }
        }

        // Perform upserts
        if (!contractsToUpdate.isEmpty()) {
            update contractsToUpdate;
        }

        if (!subscriptionsToUpsert.isEmpty()) {
            upsert subscriptionsToUpsert Stripe_Subscription_ID__c;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Stripe Subscription Sync Batch Completed. Processed: ' +
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
                Name = 'Stripe Subscription Item Migration Batch',
                Message__c = 'Processed: ' + processedCount + ', Success: ' + successCount + ', Errors: ' + errorCount,
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionItemMigration',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    private Contract updateContractFromStripe(Contract con, Map<String, Object> payload) {
        try {
            system.debug('payload---' + payload);
            Map<String, Object> metadata = (Map<String, Object>) payload.get('metadata');
            system.debug('metadata---' + metadata);
            String subId = (String) payload.get('id');
            system.debug('subId---' + subId);
            String customerId = (String) payload.get('customer');
            String invoiceId = (String) payload.get('latest_invoice');
            String status = (String) payload.get('status');
            // Extract date fields as Long
            Long billingCycleAnchorUnix = payload.containsKey('billing_cycle_anchor')
                ? (Long) payload.get('billing_cycle_anchor')
                : null;
            Long startDateUnix = payload.containsKey('start_date') ? (Long) payload.get('start_date') : null;
            Long cancelAtUnix = payload.containsKey('cancel_at') ? (Long) payload.get('cancel_at') : null;
            Long currentPeriodStartUnix = payload.containsKey('current_period_start')
                ? (Long) payload.get('current_period_start')
                : null;
            Long currentPeriodEndUnix = payload.containsKey('current_period_end')
                ? (Long) payload.get('current_period_end')
                : null;

            Date billingCycleAnchor = date.valueof(toDateTime(billingCycleAnchorUnix));
            Date startDate = date.valueof(toDateTime(startDateUnix));
            Date cancelAt = date.valueof(toDateTime(cancelAtUnix));
            Datetime currentPeriodStart = toDateTime(currentPeriodStartUnix);
            Datetime currentPeriodEnd = toDateTime(currentPeriodEndUnix);

            Contract updatedContract = new Contract(
                Id = con.Id,
                Stripe_Subscription_ID__c = subId,
                Stripe_Customer_ID__c = customerId,
                Stripe_latest_Invoice_Id__c = invoiceId,
                Stripe_Status__c = status,
                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscriptions/' + subId,
                Status = 'Activated',
                Contract_Migration__c = true,
                StartDate = startDate,
                EndDate = cancelAt,
                ContractTerm = (startDate != null && cancelAt != null) ? startDate.monthsBetween(cancelAt) : null,
                Stripe_Billing_Date__c = billingCycleAnchor,
                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix),
                Created_From_Stripe__c = true,
                Latest_Change_Reason__c = con.StartDate == null
                    ? 'Contract Migration Done From Stripe'
                    : 'Renewable Contract Migration Done From Stripe'
                // AccountId = metadata != null && metadata.containsKey('salesforce_account_id')
                //     ? (String) metadata.get('salesforce_account_id')
                //     : con.AccountId,
                // SBQQ__Opportunity__c = metadata != null && metadata.containsKey('salesforce_opportunity_id')
                //     ? (String) metadata.get('salesforce_opportunity_id')
                //     : con.SBQQ__Opportunity__c,
                // SBQQ__Quote__c = metadata != null && metadata.containsKey('salesforce_quote_id')
                //     ? (String) metadata.get('salesforce_quote_id')
                //     : con.SBQQ__Quote__c,
                // SBQQ__Order__c = metadata != null && metadata.containsKey('salesforce_order_id')
                //     ? (String) metadata.get('salesforce_order_id')
                //     : con.SBQQ__Order__c
            );

            return updatedContract;
        } catch (Exception ex) {
            errorMessages.add('Error updating contract ' + contract.Id + ': ' + ex.getMessage());
            return null;
        }
    }

    private List<SBQQ__Subscription__c> processSubscriptionItems(
        Map<String, Object> subscriptionData,
        Id contractId,
        Id accountId
    ) {
        List<SBQQ__Subscription__c> subscriptionItems = new List<SBQQ__Subscription__c>();

        try {
            Map<String, Object> items = (Map<String, Object>) subscriptionData.get('items');
            if (items != null && items.containsKey('data')) {
                List<Object> itemsData = (List<Object>) items.get('data');

                // Collect product IDs for query
                Set<String> productIds = new Set<String>();
                for (Object itemObj : itemsData) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    Map<String, Object> price = (Map<String, Object>) item.get('price');
                    if (price != null && price.containsKey('product')) {
                        productIds.add((String) price.get('product'));
                    }
                }

                // Query products
                Map<String, Product2> productMap = new Map<String, Product2>();
                if (!productIds.isEmpty()) {
                    for (Product2 prod : [
                        SELECT Id, Stripe_Product_ID__c
                        FROM Product2
                        WHERE Stripe_Product_ID__c IN :productIds
                    ]) {
                        productMap.put(prod.Stripe_Product_ID__c, prod);
                    }
                }

                // Process each subscription item
                for (Object itemObj : itemsData) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    Map<String, Object> price = (Map<String, Object>) item.get('price');

                    if (price != null) {
                        SBQQ__Subscription__c subscription = createSubscriptionFromStripeItem(
                            item,
                            price,
                            contractId,
                            accountId,
                            productMap,
                            subscriptionData
                        );

                        if (subscription != null) {
                            subscriptionItems.add(subscription);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            errorMessages.add(
                'Error processing subscription items for contract ' + contractId + ': ' + ex.getMessage()
            );
        }

        return subscriptionItems;
    }

    private SBQQ__Subscription__c createSubscriptionFromStripeItem(
        Map<String, Object> item,
        Map<String, Object> price,
        Id contractId,
        Id accountId,
        Map<String, Product2> productMap,
        Map<String, Object> subscriptionData
    ) {
        try {
            String subId = (String) subscriptionData.get('id');
            String stripeSubscriptionItemId = (String) item.get('id');
            String priceId = (String) price.get('id');
            String productId = (String) price.get('product');

            Map<String, Object> recurring = (Map<String, Object>) price.get('recurring');
            String interval = recurring != null ? (String) recurring.get('interval') : null;
            Integer intervalCount = recurring != null ? (Integer) recurring.get('interval_count') : 1;

            Long billingCycleAnchorUnix = subscriptionData.containsKey('billing_cycle_anchor')
                ? (Long) subscriptionData.get('billing_cycle_anchor')
                : null;
            Long startDateUnix = subscriptionData.containsKey('start_date')
                ? (Long) subscriptionData.get('start_date')
                : null;
            Long cancelAtUnix = subscriptionData.containsKey('cancel_at')
                ? (Long) subscriptionData.get('cancel_at')
                : null;
            Long currentPeriodStartUnix = subscriptionData.containsKey('current_period_start')
                ? (Long) subscriptionData.get('current_period_start')
                : null;
            Long currentPeriodEndUnix = subscriptionData.containsKey('current_period_end')
                ? (Long) subscriptionData.get('current_period_end')
                : null;

            Date billingCycleAnchor = date.valueof(toDateTime(billingCycleAnchorUnix));
            Date startDate = date.valueof(toDateTime(startDateUnix));
            Date cancelAt = date.valueof(toDateTime(cancelAtUnix));
            Datetime currentPeriodStart = toDateTime(currentPeriodStartUnix);
            Datetime currentPeriodEnd = toDateTime(currentPeriodEndUnix);

            Decimal unitAmount = price.containsKey('unit_amount_decimal')
                ? Decimal.valueOf((String) price.get('unit_amount_decimal')) / 100
                : 0;
            Integer quantity = item.containsKey('quantity') ? (Integer) item.get('quantity') : 1;
            Decimal stripeMRR = unitAmount * quantity;
            Decimal stripeARR = stripeMRR * 12;
            Integer contractTerm = (startDate != null && cancelAt != null) ? startDate.monthsBetween(cancelAt) : null;
            Decimal customerPrice = contractTerm > 0 ? (unitAmount * contractTerm).setScale(2) : null;

            Product2 matchingProduct = productMap.get(productId);

            SBQQ__Subscription__c subscription = new SBQQ__Subscription__c(
                Stripe_Subscription_ID_Actual__c = subId,
                Stripe_Subscription_ID__c = stripeSubscriptionItemId,
                SBQQ__Contract__c = contractId,
                SBQQ__Account__c = accountId,
                Stripe_Price_ID__c = priceId,
                Stripe_Product_ID__c = productId,
                SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                SBQQ__Quantity__c = quantity,
                SBQQ__NetPrice__c = unitAmount,
                Stripe_Monthly_Value__c = stripeMRR,
                Latest_Change_Reason__c = 'Subscription Migration Done From Stripe',
                Stripe_Start_Date__c = toDateTime((Long) item.get('current_period_start')).date(),
                Stripe_End_Date__c = toDateTime((Long) item.get('current_period_end')).date(),
                SBQQ__SubscriptionStartDate__c = startDate,
                SBQQ__SubscriptionEndDate__c = cancelAt,
                Stripe_Billing_Date__c = billingCycleAnchor,
                Stripe_Subscription_Term__c = contractTerm,
                Stripe_ARR__c = stripeARR,
                SBQQ__CustomerPrice__c = customerPrice,
                Stripe_Interval__c = interval,
                Stripe_Activate__c = (Boolean) price.get('active'),
                Created_From_Stripe__c = true,
                Status__c = (String) subscriptionData.get('status'),
                SBQQ__BillingFrequency__c = getBillingFrequency(interval, intervalCount),
                Billing_Frequency_Override__c = getBillingFrequency(interval, intervalCount)
            );

            return subscription;
        } catch (Exception ex) {
            errorMessages.add('Error creating subscription item: ' + ex.getMessage());
            return null;
        }
    }

    // Helper method to get billing frequency from Stripe interval and interval count
    public static String getBillingFrequency(String interval, Integer intervalCount) {
        if (interval == 'month') {
            if (intervalCount == 1) {
                return 'Monthly';
            } else if (intervalCount == 3) {
                return 'Quarterly';
            }
        } else if (interval == 'year') {
            if (intervalCount == 1) {
                return 'Annual';
            } else if (intervalCount == 2) {
                return '2-Year';
            } else if (intervalCount == 3) {
                return '3-Year';
            }
        }
        return null;
    }

    public static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer) unixTs);
    }
}