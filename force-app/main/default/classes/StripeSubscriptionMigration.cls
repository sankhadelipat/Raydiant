public class StripeSubscriptionMigration implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
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
                    Contract_Migration__c,
                    Stripe_Subscription_ID__c,
                    StartDate,
                    EndDate,
                    Stripe_Billing_Date__c,
                    CreatedDate,
                    Current_Migration_Start_Date__c,
                    Current_Migration_End_Date__c,
                    CurrencyIsoCode,
                    SBQQ__Evergreen__c,
                    ContractTerm,
                    Account.Stripe_Customer_ID__c,
                    SBQQ__Order__c,
                    SBQQ__Quote__c,
                    SBQQ__Opportunity__c,
                    AccountId
                FROM Contract
                WHERE
                    Contract_Migration__c = FALSE
                    AND Is_Migrating__c = TRUE
                    AND Stripe_Subscription_ID__c = NULL
                    AND Current_Migration_End_Date__c != NULL
                    AND Current_Migration_End_Date__c > TODAY
                    AND Current_Migration_Start_Date__c < TODAY
                ORDER BY LastModifiedDate DESC
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        try {
            Set<Id> conIds = new Set<Id>();
            Map<Id, Contract> oldToNewContractMap = new Map<Id, Contract>();
            List<SBQQ__Subscription__c> subscriptionItemsToInsert = new List<SBQQ__Subscription__c>();
            List<Contract> UpdateConatrct = new List<Contract>();
            Map<String, SBQQ__Subscription__c> priceIdToSubscriptionMap = new Map<String, SBQQ__Subscription__c>();
            for (Contract con : scope) {
                conIds.add(con.Id);
            }

            List<SBQQ__Subscription__c> allSubscriptions = [
                SELECT
                    Id,
                    SBQQ__Contract__c,
                    SBQQ__StartDate__c,
                    SBQQ__EndDate__c,
                    SBQQ__SubscriptionType__c,
                    Order_Line_Billing_Freq__c,
                    Stripe_Price_ID__c,
                    SBQQ__NetPrice__c,
                    SBQQ__Quantity__c,
                    Subscription_Term__c,
                    SBQQ__Contract__r.StartDate,
                    SBQQ__Contract__r.EndDate,
                    SBQQ__Contract__r.ContractTerm,
                    SBQQ__Product__r.Name,
                    SBQQ__Product__r.Description,
                    SBQQ__Product__r.Stripe_Product_ID__c,
                    SBQQ__BillingFrequency__c,
                    CurrencyIsoCode
                FROM SBQQ__Subscription__c
                WHERE
                    SBQQ__Contract__c IN :conIds
                    AND F52_Active__c = TRUE
                    AND SBQQ__SubscriptionType__c != NULL
                    AND SBQQ__Product__r.Stripe_Product_ID__c != NULL
                    AND Stripe_Price_ID__c != NULL
                //   AND LastModifiedDate = today
                //  AND Stripe_Subscription_Migration__c = TRUE
            ];

            Map<Id, List<SBQQ__Subscription__c>> contractSubscriptionsMap = new Map<Id, List<SBQQ__Subscription__c>>();
            for (SBQQ__Subscription__c sub : allSubscriptions) {
                if (!contractSubscriptionsMap.containsKey(sub.SBQQ__Contract__c)) {
                    contractSubscriptionsMap.put(sub.SBQQ__Contract__c, new List<SBQQ__Subscription__c>());
                }
                contractSubscriptionsMap.get(sub.SBQQ__Contract__c).add(sub);
                priceIdToSubscriptionMap.put(sub.Stripe_Price_ID__c, sub);
            }

            List<Contract> contractsToInsert = new List<Contract>();
            List<SBQQ__Subscription__c> subscriptionsToInsert = new List<SBQQ__Subscription__c>();

            System.debug('SIZE: ' + scope.size());
            for (Contract con : scope) {
                processedCount++;

                if (!contractSubscriptionsMap.containsKey(con.Id))
                    continue;

                List<SBQQ__Subscription__c> contractSubs = contractSubscriptionsMap.get(con.Id);

                // ⚙️ Determine correct start/end dates (Requirement #1)
                Date startDate = con.Current_Migration_Start_Date__c; //con.SBQQ__Evergreen__c ? con.Current_Migration_Start_Date__c : con.StartDate;
                Date endDate = con.Current_Migration_End_Date__c; // con.SBQQ__Evergreen__c ? con.Current_Migration_End_Date__c   : con.EndDate;

                List<String> bodyParts = new List<String>();
                bodyParts.add('customer=' + EncodingUtil.urlEncode(con.Account.Stripe_Customer_ID__c, 'UTF-8'));
                bodyParts.add('metadata[subscription_source]=salesforce');
                if (String.isNotBlank(con.AccountId)) {
                    bodyParts.add('metadata[salesforce_account_id]=' + EncodingUtil.urlEncode(con.AccountId, 'UTF-8'));
                }
                if (String.isNotBlank(con.SBQQ__Opportunity__c)) {
                    bodyParts.add(
                        'metadata[salesforce_opportunity_id]=' +
                        EncodingUtil.urlEncode(con.SBQQ__Opportunity__c, 'UTF-8')
                    );
                }
                if (String.isNotBlank(con.SBQQ__Quote__c)) {
                    bodyParts.add(
                        'metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(con.SBQQ__Quote__c, 'UTF-8')
                    );
                }
                if (String.isNotBlank(con.SBQQ__Order__c)) {
                    bodyParts.add(
                        'metadata[salesforce_order_id]=' + EncodingUtil.urlEncode(con.SBQQ__Order__c, 'UTF-8')
                    );
                }

                bodyParts.add('days_until_due=0');
                bodyParts.add('collection_method=send_invoice');
                //bodyParts.add('collection_method=charge_automatically');
                bodyParts.add('currency=' + con.CurrencyIsoCode);
                bodyParts.add('proration_behavior=none');
                bodyParts.add('billing_mode[type]=flexible');

                // Billing anchor date
                Date billingDate = con.Stripe_Billing_Date__c; //con.Stripe_Billing_Date__c;

                if (billingDate != null) {
                    Datetime billingAnchor = Datetime.newInstanceGMT(
                        billingDate.year(),
                        billingDate.month(),
                        billingDate.day(),
                        0,
                        0,
                        0
                    );

                    bodyParts.add('billing_cycle_anchor=' + String.valueOf(billingAnchor.getTime() / 1000));
                }

                // Backdate start & cancel date
                Long startUnix = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000;
                bodyParts.add('backdate_start_date=' + String.valueOf(startUnix));

                if (endDate != null) {
                    Long endUnix = Datetime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000;
                    bodyParts.add('cancel_at=' + String.valueOf(endUnix));
                }

                Integer idx = 0;
                for (SBQQ__Subscription__c sub : contractSubs) {
                    if (sub.Stripe_Price_ID__c != null) {
                        bodyParts.add('items[' + idx + '][price]=' + sub.Stripe_Price_ID__c);
                        bodyParts.add(
                            'items[' + idx + '][quantity]=' + String.valueOf(sub.SBQQ__Quantity__c.intValue())
                        );
                        idx++;
                    }
                }

                // Stripe Callout
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/subscriptions');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req.setBody(String.join(bodyParts, '&'));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    system.debug('payload---' + payload);
                    Map<String, Object> metadata = (Map<String, Object>) payload.get('metadata');
                    system.debug('metadata---' + metadata);
                    String subId = (String) payload.get('id');
                    system.debug('subId---' + subId);
                    String customerId = (String) payload.get('customer');
                    String invoiceId = (String) payload.get('latest_invoice');
                    String status = (String) payload.get('status');
                    Long billingCycleAnchorUnix = payload.containsKey('billing_cycle_anchor')
                        ? (Long) payload.get('billing_cycle_anchor')
                        : null;
                    Datetime billingCycleAnchor = toDateTime(billingCycleAnchorUnix);

                    Long startDateUnix = payload.containsKey('start_date') ? (Long) payload.get('start_date') : null;
                    // ⚙️ Subscriptions tagging (Requirement #3)
                    Map<String, Object> items = (Map<String, Object>) payload.get('items');
                    system.debug('items---' + items);
                    if (items != null && items.containsKey('data')) {
                        List<Object> subs = (List<Object>) items.get('data');

                        // Collect all unique product IDs from subscription items
                        Set<String> stripeProductIds = new Set<String>();
                        for (Object itemObj : subs) {
                            Map<String, Object> item = (Map<String, Object>) itemObj;
                            Map<String, Object> price = (Map<String, Object>) item.get('price');
                            String productId = (String) price.get('product');
                            stripeProductIds.add(productId);
                        }

                        // Query Product2 records based on collected product IDs
                        Map<String, Product2> stripeProductIdToProductMap = new Map<String, Product2>();
                        if (!stripeProductIds.isEmpty()) {
                            List<Product2> products = [
                                SELECT Id, Name, Stripe_Product_ID__c
                                FROM Product2
                                WHERE Stripe_Product_ID__c IN :stripeProductIds
                            ];
                            for (Product2 prod : products) {
                                stripeProductIdToProductMap.put(prod.Stripe_Product_ID__c, prod);
                            }
                        }
                        System.debug('Stripe Product ID to Product Map: ' + stripeProductIdToProductMap);
                        system.debug('subs  to insert---' + subs);

                        // ⚙️ Create Contract Record (Requirement #2)
                        // new Contract & Subscription insert if Old Contract is Evergreen
                        if (con.SBQQ__Evergreen__c == true) {
                            Contract newCon = new Contract(
                                Stripe_Subscription_ID__c = subId,
                                Stripe_Customer_ID__c = customerId,
                                Stripe_latest_Invoice_Id__c = invoiceId,
                                Stripe_Status__c = status,
                                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscriptions/' + subId,
                                Contract_Migration__c = true,
                                StartDate = startDate,
                                EndDate = endDate,
                                ContractTerm = (startDate != null &&
                                    endDate != null)
                                    ? startDate.monthsBetween(endDate)
                                    : null,
                                Stripe_Billing_Date__c = billingDate,
                                Created_From_Stripe__c = true,
                                Latest_Change_Reason__c = 'Contract Migration Done From Stripe',
                                AccountId = metadata != null && metadata.containsKey('salesforce_account_id')
                                    ? (String) metadata.get('salesforce_account_id')
                                    : con.AccountId,
                                SBQQ__Opportunity__c = metadata != null &&
                                    metadata.containsKey('salesforce_opportunity_id')
                                    ? (String) metadata.get('salesforce_opportunity_id')
                                    : con.SBQQ__Opportunity__c,
                                SBQQ__Quote__c = metadata != null && metadata.containsKey('salesforce_quote_id')
                                    ? (String) metadata.get('salesforce_quote_id')
                                    : con.SBQQ__Quote__c,
                                SBQQ__Order__c = metadata != null && metadata.containsKey('salesforce_order_id')
                                    ? (String) metadata.get('salesforce_order_id')
                                    : con.SBQQ__Order__c
                            );
                            contractsToInsert.add(newCon);

                            for (Object o : subs) {
                                Map<String, Object> item = (Map<String, Object>) o;
                                Map<String, Object> price = (Map<String, Object>) item.get('price');
                                Map<String, Object> recurring = (Map<String, Object>) price.get('recurring');
                                String priceId = (String) price.get('id');

                                String productId = (String) price.get('product');
                                String interval = recurring != null && recurring.containsKey('interval')
                                    ? (String) recurring.get('interval')
                                    : null;
                                Integer intervalCount = recurring != null && recurring.containsKey('interval_count')
                                    ? (Integer) recurring.get('interval_count')
                                    : 1;
                                System.debug('Processing Price ID: ' + priceId);
                                System.debug('Processing Product ID: ' + productId);
                                Product2 matchingProduct = stripeProductIdToProductMap.get(productId);
                                System.debug('Matching Product: ' + matchingProduct);
                                Decimal unitAmount = (price.containsKey('unit_amount_decimal'))
                                    ? Decimal.valueOf((String) price.get('unit_amount_decimal')) / 100
                                    : 0;
                                Decimal stripeMRR = unitAmount * (Integer) item.get('quantity'); // monthly value
                                Decimal stripeARR = stripeMRR * 12; // annual value
                                SBQQ__Subscription__c newSub = new SBQQ__Subscription__c(
                                    Stripe_Subscription_ID_Actual__c = subId,
                                    SBQQ__Account__c = metadata != null && metadata.containsKey('salesforce_account_id')
                                        ? (String) metadata.get('salesforce_account_id')
                                        : con.AccountId,
                                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                                    SBQQ__NetPrice__c = unitAmount,
                                    Stripe_Subscription_ID__c = (String) item.get('id'),
                                    Stripe_Price_ID__c = priceId,
                                    Stripe_Product_ID__c = (String) price.get('product'),
                                    Stripe_Monthly_Value__c = stripeMRR,
                                    Latest_Change_Reason__c = 'Subscription Migration Done From Stripe',
                                    SBQQ__Quantity__c = (Integer) (item.get('quantity') == null
                                        ? 1
                                        : item.get('quantity')),
                                    Stripe_Activate__c = (Boolean) price.get('active'),
                                    Status__c = status,
                                    Stripe_Start_Date__c = toDateTime((Long) item.get('current_period_start')).date(),
                                    Stripe_End_Date__c = toDateTime((Long) item.get('current_period_end')).date(),
                                    SBQQ__SubscriptionStartDate__c = startDate,
                                    SBQQ__SubscriptionEndDate__c = endDate,
                                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                                    SBQQ__BillingFrequency__c = getBillingFrequency(interval, intervalCount),
                                    Billing_Frequency_Override__c = getBillingFrequency(interval, intervalCount),
                                    Stripe_ARR__c = stripeARR
                                );
                                subscriptionsToInsert.add(newSub);
                            }
                        }  // if evergreen end here; update only
                        // not evergreen Renewal
                        else {
                            // Create Contract

                            Contract contract = new Contract(
                                id = con.id,
                                Stripe_Subscription_ID__c = subId,
                                Stripe_Customer_ID__c = customerId,
                                Stripe_latest_Invoice_Id__c = invoiceId,
                                Stripe_Subscription_Source__c = 'salesforce',
                                Stripe_Status__c = status,
                                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscriptions/' + subId,
                                Contract_Migration__c = true,
                                Status = 'Activated',
                                Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                                Created_From_Stripe__c = true,
                                Latest_Change_Reason__c = 'Renewable Contract Migration Done From Stripe',
                                //  Stripe_Subscription_Schedule_ID__c = scheduleId,
                                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix)
                            );
                            UpdateConatrct.add(Contract);

                            //// update Renewal Subscription
                            for (Object itemObj : subs) {
                                Map<String, Object> item = (Map<String, Object>) itemObj;
                                Map<String, Object> price = (Map<String, Object>) item.get('price');
                                Map<String, Object> recurring = (Map<String, Object>) price.get('recurring');
                                String priceId = (String) price.get('id');
                                SBQQ__Subscription__c matchingSub = priceIdToSubscriptionMap.get(priceId);
                                String productId = (String) price.get('product');
                                String interval = recurring != null && recurring.containsKey('interval')
                                    ? (String) recurring.get('interval')
                                    : null;
                                Integer intervalCount = recurring != null && recurring.containsKey('interval_count')
                                    ? (Integer) recurring.get('interval_count')
                                    : 1;
                                System.debug('Processing Price ID: ' + priceId);
                                System.debug('Processing Product ID: ' + productId);

                                Product2 matchingProduct = stripeProductIdToProductMap.get(productId);
                                System.debug('Matching Product: ' + matchingProduct);

                                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100; // Stripe amounts are in cents
                                // Calculate values directly from Stripe response
                                Decimal stripeMRR = unitAmount * (Integer) item.get('quantity'); // monthly value
                                Decimal stripeARR = stripeMRR * 12; // annual value
                                Integer contractTerm = con.ContractTerm != null ? con.ContractTerm : null;
                                // Decimal stripeTCV = contractTerm > 0 ? (stripeMRR * contractTerm) : null;
                                Decimal customerPrice = contractTerm > 0
                                    ? (unitAmount * contractTerm).setScale(2)
                                    : null;

                                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                                    Id = matchingSub.Id,
                                    SBQQ__Contract__c = con.Id,
                                    Stripe_Subscription_ID__c = (String) item.get('id'),
                                    Stripe_Price_ID__c = priceId,
                                    Stripe_Product_ID__c = productId,
                                    SBQQ__Quantity__c = (Integer) item.get('quantity'),
                                    Stripe_Interval__c = interval,
                                    Stripe_Activate__c = (Boolean) price.get('active'),
                                    Status__c = status,
                                    Stripe_Start_Date__c = toDateTime((Long) item.get('current_period_start')).date(),
                                    Stripe_End_Date__c = toDateTime((Long) item.get('current_period_end')).date(),
                                    SBQQ__SubscriptionStartDate__c = startDate,
                                    SBQQ__SubscriptionEndDate__c = endDate,
                                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                                    Latest_Change_Reason__c = 'Renewable Subscription Migration Done From Stripe',
                                    SBQQ__NetPrice__c = unitAmount,
                                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                                    // Stripe_Subscription_ID_Actual__c = subscriptionId,
                                    SBQQ__CustomerPrice__c = customerPrice,
                                    SBQQ__BillingFrequency__c = getBillingFrequency(interval, intervalCount),
                                    Billing_Frequency_Override__c = getBillingFrequency(interval, intervalCount),
                                    Stripe_Monthly_Value__c = stripeMRR,
                                    Stripe_Subscription_Term__c = contractTerm,
                                    Stripe_ARR__c = stripeARR
                                );

                                subscriptionItemsToInsert.add(sub);
                            }

                            System.debug('Subscription Items to Insert: ' + subscriptionItemsToInsert);
                            System.debug('Total Subscription Items to Insert: ' + subscriptionItemsToInsert.size());
                        }
                    }
                }

                successCount++;
            }

            // Insert Contracts
            Database.SaveResult[] conResults = Database.insert(contractsToInsert, false);
            system.debug('Contract insert---');
            // ✅ Update Status = Activated (Requirement #4)
            List<Contract> activatedContracts = new List<Contract>();
            Integer i = 0;
            Map<Id, Id> oldToNewContractIdMap = new Map<Id, Id>();
            List<Id> oldContractIds = new List<Id>(oldToNewContractMap.keySet());
            for (Database.SaveResult r : conResults) {
                // Id oldId = oldContractIds[i];

                if (r.isSuccess()) {
                    //oldToNewContractIdMap.put(oldId, contractsToInsert[i].Id);
                    // i++;
                    activatedContracts.add(new Contract(Id = r.getId(), Status = 'Activated'));
                }
            }
            if (!activatedContracts.isEmpty())
                update activatedContracts;

            // update Subscriptions
            if (!subscriptionsToInsert.isEmpty()) {
                insert subscriptionsToInsert;
                // Database.insert(subscriptionsToInsert, false);
                system.debug('Subscription insert---');
            }
            //
            if (!subscriptionItemsToInsert.isEmpty()) {
                update subscriptionItemsToInsert;
            }
            if (!UpdateConatrct.isEmpty()) {
                update UpdateConatrct;
            }
        } catch (Exception ex) {
            System.debug('Error in batch execution: ' + ex.getStackTraceString());
            errorCount++;
            errorMessages.add('Error in batch execution: ' + ex.getMessage());
            insert new Logger__c(
                Name = 'Stripe Subscription MIGRATION',
                Message__c = ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubcriptionMigartion',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Subscription'
            );
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
                System.debug(errMsg);
            }

            insert new Logger__c(
                Name = 'STRIPE SUBSCRIPTION MIGRATION ',
                Message__c = errorMessages.size() + ' errors occurred during Stripe Product Upload Batch.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubcriptionMigartion',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Subscription'
            );
        }

        StripeContractHandler batchJob = new StripeContractHandler();
        Database.executeBatch(batchJob, 90);
        System.debug('Stripe migration batch finished.');
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

        // Default fallback
        return null;
    }
    public static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer) unixTs);
    }
}