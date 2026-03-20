public class StripeScheduleQueueable implements Queueable, Database.AllowsCallouts {
    String responseBody;
    String quoteId;

    public StripeScheduleQueueable(String responseBody, String quoteId) {
        this.responseBody = responseBody;
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context) {
        if (quoteId != null) {
            createScheduleWithQuote(responseBody, quoteId);
        } else {
            createScheduleWithoutQuote(responseBody);
        }
    }

    private static void createScheduleWithQuote(String responseBody, String quoteId) {
        try {
            List<SBQQ__Quote__c> quoteList = [
                SELECT
                    Id,
                    SBQQ__StartDate__c,
                    SBQQ__ExpirationDate__c,
                    Expiration_Date__c,
                    SBQQ__EndDate__c,
                    SBQQ__Account__c,
                    Bill_To_Contact__c,
                    SBQQ__SubscriptionTerm__c,
                    SBQQ__Account__r.blng__BillToContact__c,
                    SBQQ__Opportunity2__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1
            ];

            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT
                    Quantity_For_Stripe__c,
                    SBQQ__NetTotal__c,
                    SBQQ__Product__c,
                    MRR__c,
                    Monthly_Total__c,
                    Stripe_Price_ID__c,
                    SBQQ__SubscriptionType__c,
                    SBQQ__SubscriptionTerm__c,
                    Billing_Frequency_Override__c,
                    Annual_Total__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quoteList[0].Id AND Stripe_Subscription_Type__c != 'One-time'
                LIMIT 20
            ];

            system.debug('--quoteItems-' + quoteLines);

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            system.debug('--payload--' + payload);

            String scheduleId = (String) payload.get('id');
            String customerId = (String) payload.get('customer');
            String status = (String) payload.get('status');
            Long createdUnix = payload.containsKey('created') ? (Long) payload.get('created') : null;

            // Phase 0 = scheduled subscription
            Map<String, Object> phase = (Map<String, Object>) ((List<Object>) payload.get('phases'))[0];

            Long startDateUnix = phase.containsKey('start_date') ? (Long) phase.get('start_date') : null;
            Long endDateUnix = phase.containsKey('end_date') ? (Long) phase.get('end_date') : null;
            Long billingCycleAnchorUnix = phase.containsKey('billing_cycle_anchor')
                ? (Long) phase.get('billing_cycle_anchor')
                : null;
            Date startDate = date.valueof(toDateTime(startDateUnix));
            Date endDate = date.valueof(toDateTime(endDateUnix));
            Datetime billingCycleAnchor = toDateTime(billingCycleAnchorUnix);
            System.debug('Start Date: ' + startDate);
            System.debug('End Date: ' + endDate);

            Map<String, Object> defaultSettings = payload.containsKey('default_settings')
                ? (Map<String, Object>) payload.get('default_settings')
                : null;
            System.debug('Default Settings: ' + defaultSettings);

            String collectionMethod = defaultSettings != null && defaultSettings.containsKey('collection_method')
                ? (String) defaultSettings.get('collection_method')
                : null;

            Map<String, Object> phaseMetadata = phase != null &&
                phase.containsKey('metadata') &&
                phase.get('metadata') != null
                ? (Map<String, Object>) phase.get('metadata')
                : null;
            String subscriptionSource = phaseMetadata != null && phaseMetadata.containsKey('subscription_source')
                ? String.valueOf(phaseMetadata.get('subscription_source'))
                : null;
            Boolean isRenewalSubscription = phaseMetadata != null && phaseMetadata.containsKey('auto_renewal')
                ? Boolean.valueOf((String) phaseMetadata.get('auto_renewal'))
                : false;
            String renewedFromContract = phaseMetadata != null && phaseMetadata.containsKey('renewed_from_contract')
                ? String.valueOf(phaseMetadata.get('renewed_from_contract'))
                : null;

            List<Object> subscriptionItems = (List<Object>) phase.get('items');
            System.debug('Subscription Items: ' + subscriptionItems);
            System.debug('Total subscription items: ' + subscriptionItems.size());

            String latestChangeReason;

            if (isRenewalSubscription) {
                latestChangeReason = 'Auto Renewal Subscription Scheduled';
            } else {
                latestChangeReason = 'Subscription Scheduled From Salesforce Quote';
            }

            // Upsert Contract
            Contract contract = new Contract(
                AccountId = quoteList[0].SBQQ__Account__c,
                SBQQ__Quote__c = quoteId,
                SBQQ__Opportunity__c = quoteList[0].SBQQ__Opportunity2__c,
                Stripe_Customer_ID__c = customerId,
                Stripe_Subscription_Schedule_ID__c = scheduleId,
                Stripe_Subscription_Source__c = subscriptionSource,
                Stripe_Status__c = status,
                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscription_schedules/' + scheduleId,
                Collection_Method__c = collectionMethod,
                StartDate = startDate,
                Status = 'Pending',
                ContractTerm = calculateContractTerm(startDate, endDate),
                Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                CustomerSignedId = quoteList[0].SBQQ__Account__r.blng__BillToContact__c,
                Created_From_Stripe__c = subscriptionSource != 'salesforce' ? true : false,
                Latest_Change_Reason__c = latestChangeReason,
                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix)
            );

            if (endDate != null) {
                contract.EndDate = endDate;
            }
            if (isRenewalSubscription) {
                contract.Renewed_From_Contract__c = renewedFromContract;
            }

            upsert contract Stripe_Subscription_Schedule_ID__c;

            // Insert Subscription Items
            List<SBQQ__Subscription__c> subscriptionItemsToInsert = new List<SBQQ__Subscription__c>();
            Map<String, SBQQ__QuoteLine__c> priceIdToQuoteLineMap = new Map<String, SBQQ__QuoteLine__c>();

            for (SBQQ__QuoteLine__c ql : quoteLines) {
                priceIdToQuoteLineMap.put(ql.Stripe_Price_ID__c, ql);
            }
            System.debug('Price ID to Quote Line Map: ' + priceIdToQuoteLineMap);
            System.debug('Total Quote Line Maps: ' + priceIdToQuoteLineMap.size());

            // Collect all unique product IDs from subscription items
            Set<String> stripeProductIds = new Set<String>();
            for (Object itemObj : subscriptionItems) {
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

            for (Object itemObj : subscriptionItems) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                Map<String, Object> price = (Map<String, Object>) item.get('price');
                Map<String, Object> recurring = (Map<String, Object>) price.get('recurring');
                String priceId = (String) price.get('id');
                System.debug('Processing Price ID: ' + priceId);
                String productId = (String) price.get('product');
                String interval = recurring != null && recurring.containsKey('interval')
                    ? (String) recurring.get('interval')
                    : null;
                Integer intervalCount = recurring != null && recurring.containsKey('interval_count')
                    ? (Integer) recurring.get('interval_count')
                    : 1;
                System.debug('Processing Price ID: ' + priceId);
                System.debug('Processing Product ID: ' + productId);

                Integer quantity = (Integer) item.get('quantity');
                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100;
                Decimal monthlyAmount = calculateMonthlyAmount(unitAmount, interval, intervalCount);

                // Calculate values directly from Stripe response
                Decimal stripeMRR = monthlyAmount * quantity; // monthly value
                Decimal stripeARR = stripeMRR * 12; // annual value
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : 0;
                Decimal customerPrice = contractTerm > 0 ? (stripeMRR * contractTerm) : null;

                Product2 matchingProduct = stripeProductIdToProductMap.get(productId);
                System.debug('Matching Product: ' + matchingProduct);

                SBQQ__QuoteLine__c matchingQuoteLine = priceIdToQuoteLineMap.get(priceId);
                System.debug('Matching Quote Line: ' + matchingQuoteLine);

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = quoteList[0].SBQQ__Account__c,
                    Stripe_Price_ID__c = priceId,
                    Stripe_Product_ID__c = productId,
                    SBQQ__Quantity__c = quantity,
                    Stripe_Interval__c = interval,
                    Stripe_Activate__c = (Boolean) price.get('active'),
                    Status__c = status,
                    Stripe_Start_Date__c = startDate,
                    Stripe_End_Date__c = endDate,
                    SBQQ__SubscriptionStartDate__c = startDate,
                    SBQQ__SubscriptionEndDate__c = endDate,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = monthlyAmount,
                    SBQQ__ListPrice__c = unitAmount,
                    SBQQ__CustomerPrice__c = customerPrice,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                    SBQQ__BillingFrequency__c = getBillingFrequency(interval, intervalCount),
                    Billing_Frequency_Override__c = getBillingFrequency(interval, intervalCount),
                    Stripe_Monthly_Value__c = stripeMRR,
                    Stripe_Subscription_Term__c = contractTerm,
                    Stripe_ARR__c = stripeARR
                );

                // Only set quote line–related fields if matchingQuoteLine exists
                if (matchingQuoteLine != null) {
                    sub.SBQQ__QuoteLine__c = matchingQuoteLine.Id;
                }
                subscriptionItemsToInsert.add(sub);
            }

            System.debug('Subscription Items to Insert: ' + subscriptionItemsToInsert);
            System.debug('Total Subscription Items to Insert: ' + subscriptionItemsToInsert.size());

            if (!subscriptionItemsToInsert.isEmpty()) {
                insert subscriptionItemsToInsert;
                System.debug('Inserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');

                System.enqueueJob(
                    new StripeInvoicePreview(scheduleId, StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE)
                );
            } else {
                System.debug('No subscription records to insert');
                return;
            }
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Schedule Creation Error With Quote',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeScheduleQueueable',
                Apex_Method__c = 'createScheduleWithQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    private static void createScheduleWithoutQuote(String responseBody) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            system.debug('--payload--' + payload);

            String scheduleId = (String) payload.get('id');
            String customerId = (String) payload.get('customer');
            String status = (String) payload.get('status');
            Long createdUnix = payload.containsKey('created') ? (Long) payload.get('created') : null;

            // Phase 0 = scheduled subscription
            Map<String, Object> phase = (Map<String, Object>) ((List<Object>) payload.get('phases'))[0];

            Long startDateUnix = phase.containsKey('start_date') ? (Long) phase.get('start_date') : null;
            Long endDateUnix = phase.containsKey('end_date') ? (Long) phase.get('end_date') : null;
            Long billingCycleAnchorUnix = phase.containsKey('billing_cycle_anchor')
                ? (Long) phase.get('billing_cycle_anchor')
                : null;
            Date startDate = date.valueof(toDateTime(startDateUnix));
            Date endDate = date.valueof(toDateTime(endDateUnix));
            Datetime billingCycleAnchor = toDateTime(billingCycleAnchorUnix);
            System.debug('Start Date: ' + startDate);
            System.debug('End Date: ' + endDate);

            Map<String, Object> defaultSettings = payload.containsKey('default_settings')
                ? (Map<String, Object>) payload.get('default_settings')
                : null;
            System.debug('Default Settings: ' + defaultSettings);

            String collectionMethod = defaultSettings != null && defaultSettings.containsKey('collection_method')
                ? (String) defaultSettings.get('collection_method')
                : null;

            Map<String, Object> phaseMetadata = phase != null &&
                phase.containsKey('metadata') &&
                phase.get('metadata') != null
                ? (Map<String, Object>) phase.get('metadata')
                : null;
            String subscriptionSource = phaseMetadata != null && phaseMetadata.containsKey('subscription_source')
                ? String.valueOf(phaseMetadata.get('subscription_source'))
                : null;
            Boolean isRenewalSubscription = phaseMetadata != null && phaseMetadata.containsKey('auto_renewal')
                ? Boolean.valueOf((String) phaseMetadata.get('auto_renewal'))
                : false;
            String renewedFromContract = phaseMetadata != null && phaseMetadata.containsKey('renewed_from_contract')
                ? String.valueOf(phaseMetadata.get('renewed_from_contract'))
                : null;

            List<Object> subscriptionItems = (List<Object>) phase.get('items');
            System.debug('Subscription Items: ' + subscriptionItems);
            System.debug('Total subscription items: ' + subscriptionItems.size());

            String latestChangeReason;

            if (isRenewalSubscription) {
                latestChangeReason = 'Auto Renewal Subscription Scheduled';
            } else {
                latestChangeReason = 'Subscription Scheduled From Stripe Manually';
            }

            // Fetch Account based on Customer ID
            List<Account> accts = [
                SELECT Id, Name, blng__BillToContact__c
                FROM Account
                WHERE Stripe_Customer_ID__c = :customerId
            ];
            System.debug('accts--' + accts);

            Id accountId = accts.size() > 0 ? accts[0].Id : null;
            System.debug('Account ID: ' + accountId);
            if (accountId == null) {
                throw new DmlException('No Account found with Stripe Customer ID: ' + customerId);
            }

            // Upsert Contract
            Contract contract = new Contract(
                AccountId = accountId,
                Stripe_Customer_ID__c = customerId,
                Stripe_Subscription_Schedule_ID__c = scheduleId,
                Stripe_Subscription_Source__c = subscriptionSource,
                Stripe_Status__c = status,
                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscription_schedules/' + scheduleId,
                Collection_Method__c = collectionMethod,
                StartDate = startDate,
                Status = 'Pending',
                ContractTerm = calculateContractTerm(startDate, endDate),
                Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                CustomerSignedId = accts.size() > 0 ? accts[0].blng__BillToContact__c : null,
                Created_From_Stripe__c = subscriptionSource != 'salesforce' ? true : false,
                Latest_Change_Reason__c = latestChangeReason,
                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix)
            );

            if (endDate != null) {
                contract.EndDate = endDate;
            }
            if (isRenewalSubscription) {
                contract.Renewed_From_Contract__c = renewedFromContract;
            }

            upsert contract Stripe_Subscription_Schedule_ID__c;

            // Insert Subscription Items
            List<SBQQ__Subscription__c> subscriptionItemsToInsert = new List<SBQQ__Subscription__c>();
            // Collect all unique product IDs from subscription items
            Set<String> stripeProductIds = new Set<String>();
            for (Object itemObj : subscriptionItems) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                Map<String, Object> price = (Map<String, Object>) item.get('price');
                String productId = (String) price.get('product');
                stripeProductIds.add(productId);
            }

            // Query Product2 records based on collected product IDs
            Map<String, Product2> stripeProductIdToProductMap = new Map<String, Product2>();
            if (!stripeProductIds.isEmpty()) {
                List<Product2> products = [
                    SELECT Id, Name, Stripe_Product_ID__c, IsActive
                    FROM Product2
                    WHERE Stripe_Product_ID__c IN :stripeProductIds
                ];
                for (Product2 product : products) {
                    stripeProductIdToProductMap.put(product.Stripe_Product_ID__c, product);
                }
            }
            System.debug('Stripe Product ID to Product Map: ' + stripeProductIdToProductMap);

            for (Object itemObj : subscriptionItems) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
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

                Integer quantity = (Integer) item.get('quantity');
                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100;
                Decimal monthlyAmount = calculateMonthlyAmount(unitAmount, interval, intervalCount);

                // Calculate values directly from Stripe response
                Decimal stripeMRR = monthlyAmount * quantity; // monthly value
                Decimal stripeARR = stripeMRR * 12; // annual value
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : 0;
                Decimal customerPrice = contractTerm > 0 ? (stripeMRR * contractTerm) : null;

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = accountId,
                    Stripe_Price_ID__c = priceId,
                    Stripe_Product_ID__c = productId,
                    SBQQ__Quantity__c = quantity,
                    Stripe_Interval__c = interval,
                    Stripe_Activate__c = (Boolean) price.get('active'),
                    Status__c = status,
                    Stripe_Start_Date__c = startDate,
                    Stripe_End_Date__c = endDate,
                    SBQQ__SubscriptionStartDate__c = startDate,
                    SBQQ__SubscriptionEndDate__c = endDate,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = monthlyAmount,
                    SBQQ__ListPrice__c = unitAmount,
                    SBQQ__CustomerPrice__c = customerPrice,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
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

            if (!subscriptionItemsToInsert.isEmpty()) {
                insert subscriptionItemsToInsert;
                System.debug('Inserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');

                System.enqueueJob(
                    new StripeInvoicePreview(scheduleId, StripeInvoicePreview.PreviewType.SUBSCRIPTION_SCHEDULE)
                );
            } else {
                System.debug('No subscription records to insert');
                return;
            }
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Schedule Creation Error Without Quote',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeScheduleQueueable',
                Apex_Method__c = 'createScheduleWithoutQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstance(unixTs * 1000);
    }

    private static Integer calculateContractTerm(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            return null;
        }

        Integer monthsBetween = startDate.monthsBetween(endDate);
        return monthsBetween > 0 ? monthsBetween : null;
    }

    // Helper method to get billing frequency from Stripe interval and interval count
    public static String getBillingFrequency(String interval, Integer intervalCount) {
        if (interval == 'month') {
            if (intervalCount == 1) {
                return 'Monthly';
            } else if (intervalCount == 3) {
                return 'Quarterly';
            } else if (intervalCount == 6) {
                return 'Semiannual';
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

    private static Decimal calculateMonthlyAmount(Decimal unitAmount, String interval, Integer intervalCount) {
        if (interval == 'month') {
            return unitAmount / intervalCount;
        } else if (interval == 'year') {
            return unitAmount / (12 * intervalCount);
        }

        // Default fallback
        return unitAmount;
    }
}