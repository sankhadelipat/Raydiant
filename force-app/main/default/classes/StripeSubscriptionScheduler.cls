public class StripeSubscriptionScheduler {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    //label ='Quote Accepted Quote to invoice' & Quote Start Date= FUTURE Date)
    // Quote To Invoice - Collection Method=> Send_invoice///
    public static void createStripeSchedule(list<Id> quoteId) {
        try {
            List<SBQQ__Quote__c> quoteList = [
                SELECT
                    Id,
                    SBQQ__StartDate__c,
                    SBQQ__EndDate__c,
                    SBQQ__Account__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    Bill_To_Contact__c,
                    Billing_Frequency_Override__c,
                    SBQQ__SubscriptionTerm__c,
                    CurrencyIsoCode,
                    SBQQ__PaymentTerms__c
                FROM SBQQ__Quote__c
                WHERE id IN :quoteId
                LIMIT 1
            ];
            if (quoteList.isEmpty())
                return;

            SBQQ__Quote__c quote = quoteList[0];
            List<id> quoteIds = new List<Id>();
            quoteIds.add(quote.Id);
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT
                    Quantity_For_Stripe__c,
                    SBQQ__NetTotal__c,
                    MRR__c,
                    SBQQ__Product__r.Stripe_Product_ID__c,
                    SBQQ__Product__r.SBQQ__SubscriptionType__c,
                    SBQQ__Product__r.Name,
                    Billing_Frequency_Override__c,
                    CurrencyIsoCode
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quote.Id AND Stripe_Subscription_Type__c != 'One-time'
                LIMIT 20
            ];
            system.debug('--quoteItems-' + quoteLines);

            Map<Id, String> quoteLineToPriceIdMap = new Map<Id, String>();
            Http http = new Http();

            // Map for frequency to interval + count
            Map<String, List<Object>> freqMap = new Map<String, List<Object>>{
                'Monthly' => new List<Object>{ 'month', 1 },
                'Quarterly' => new List<Object>{ 'month', 3 },
                'Annual' => new List<Object>{ 'year', 1 },
                '2-Year' => new List<Object>{ 'year', 2 },
                '3-Year' => new List<Object>{ 'year', 3 }
            };

            // Determine product charge type
            Boolean hasRecurringProducts = false;

            //  Create Price in Stripe for each Quote Lines
            for (SBQQ__QuoteLine__c ql : quoteLines) {
                String priceType;
                String interval;
                Integer intervalCount;

                String productId = ql.SBQQ__Product__r.Stripe_Product_Id__c;
                if (String.isBlank(productId))
                    continue;

                // Determine price type & interval
                if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'Renewable') {
                    priceType = 'recurring';
                    hasRecurringProducts = true;

                    String freq = (ql.Billing_Frequency_Override__c != null
                        ? ql.Billing_Frequency_Override__c
                        : 'Monthly');

                    List<Object> freqData = freqMap.containsKey(freq) ? freqMap.get(freq) : freqMap.get('Monthly');

                    interval = (String) freqData[0];
                    intervalCount = (Integer) freqData[1];
                }

                // else if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'One-time') {
                //     priceType = 'one_time';
                // }

                // Calculate unit price safely
                Decimal qty = (ql.Quantity_For_Stripe__c != null &&
                    ql.Quantity_For_Stripe__c != 0)
                    ? ql.Quantity_For_Stripe__c
                    : 1;
                Decimal unitPrice = (ql.MRR__c != null &&
                    ql.MRR__c != 0)
                    ? ql.MRR__c / qty
                    : ql.SBQQ__NetTotal__c / qty;

                // Calculate unitAmount in cents
                Decimal multiplier = 1;
                if (priceType == 'recurring') {
                    multiplier = (interval == 'month' &&
                        intervalCount == 3)
                        ? 3
                        : (interval == 'year') ? (12 * intervalCount) : 1; // monthly default
                }
                Decimal unitAmount = (unitPrice != null ? unitPrice.setScale(2) * multiplier * 100 : 0);
                System.debug('unitAmount--' + unitAmount);

                // Build Price API body
                List<String> bodyParts = new List<String>{
                    'billing_scheme=per_unit',
                    'currency=' + ql.CurrencyIsoCode,
                    'product=' + ql.SBQQ__Product__r.Stripe_Product_Id__c,
                    'unit_amount_decimal=' + unitAmount
                };

                // Add recurring details only if recurring
                if (priceType == 'recurring') {
                    bodyParts.add('recurring[interval]=' + interval);
                    bodyParts.add('recurring[interval_count]=' + intervalCount);
                }

                String priceBody = String.join(bodyParts, '&');

                HttpRequest priceReq = new HttpRequest();
                priceReq.setEndpoint('https://api.stripe.com/v1/prices');
                priceReq.setMethod('POST');
                priceReq.setHeader(
                    'Authorization',
                    'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                );
                priceReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                priceReq.setBody(priceBody);

                HttpResponse priceRes = http.send(priceReq);
                if (priceRes.getStatusCode() == 200) {
                    Map<String, Object> priceResult = (Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody());
                    String priceId = (String) priceResult.get('id');
                    quoteLineToPriceIdMap.put(ql.Id, priceId);
                } else {
                    System.debug('Price creation failed: ' + priceRes.getBody());
                }
            }

            // dynamic request body for Subscription Schedule
            List<String> bodyParts = new List<String>();

            Date StartDate = quote.SBQQ__StartDate__c;
            Datetime dt = Datetime.newInstanceGMT(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            Long unixTimestamp = dt.getTime() / 1000;
            System.debug('Unix Timestamp: ' + unixTimestamp);

            Date EndDate = startDate.addMonths(INTEGER.VALUEOF(quote.SBQQ__SubscriptionTerm__c)).addDays(-1);
            Datetime EndDatedt = Datetime.newInstanceGMT(EndDate.year(), EndDate.month(), EndDate.day(), 0, 0, 0);
            Long EndDateunixTimestamp = EndDatedt.getTime() / 1000;
            System.debug('Unix Timestamp: ' + EndDateunixTimestamp);

            Date dateOfNextMonth = Date.newInstance(
                startDate.addMonths(1).year(),
                startDate.addMonths(1).month(),
                startDate.addMonths(1).day()
            );
            Date dateOfNextQuarter = Date.newInstance(
                startDate.addMonths(3).year(),
                startDate.addMonths(3).month(),
                startDate.addMonths(3).day()
            );
            Date dateOfNextYear = Date.newInstance(
                startDate.addYears(1).year(),
                startDate.addYears(1).month(),
                startDate.addYears(1).day()
            );
            Date dateOfNext2Year = Date.newInstance(
                startDate.addYears(2).year(),
                startDate.addYears(2).month(),
                startDate.addYears(2).day()
            );
            Date dateOfNext3Year = Date.newInstance(
                startDate.addYears(3).year(),
                startDate.addYears(3).month(),
                startDate.addYears(3).day()
            );

            // Set billing anchor based on billing frequency
            Datetime billingAnchor;
            if (quote.Billing_Frequency_Override__c != null) {
                String freq = quote.Billing_Frequency_Override__c;
                if (freq == 'Monthly') {
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNextMonth.year(),
                        dateOfNextMonth.month(),
                        dateOfNextMonth.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == 'Quarterly') {
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNextQuarter.year(),
                        dateOfNextQuarter.month(),
                        dateOfNextQuarter.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == 'Annual') {
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNextYear.year(),
                        dateOfNextYear.month(),
                        dateOfNextYear.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == '2-Year') {
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNext2Year.year(),
                        dateOfNext2Year.month(),
                        dateOfNext2Year.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == '3-Year') {
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNext3Year.year(),
                        dateOfNext3Year.month(),
                        dateOfNext3Year.day(),
                        0,
                        0,
                        0
                    );
                } else {
                    // Default to monthly
                    billingAnchor = Datetime.newInstanceGMT(
                        dateOfNextMonth.year(),
                        dateOfNextMonth.month(),
                        dateOfNextMonth.day(),
                        0,
                        0,
                        0
                    );
                }
            }

            Integer daysUntilDue;

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
            } else {
                daysUntilDue = 0; // Default to no due date if payment terms are not set
            }

            bodyParts.add('customer=' + EncodingUtil.urlEncode(quote.SBQQ__Account__r.Stripe_Customer_ID__c, 'UTF-8'));
            // bodyParts.add('start_date=1757071713');
            bodyParts.add('start_date=' + String.valueOf(unixTimestamp));
            bodyParts.add('end_behavior=cancel');
            bodyParts.add('default_settings[billing_cycle_anchor]=automatic');
            bodyParts.add('default_settings[collection_method]=send_invoice');
            bodyParts.add('default_settings[invoice_settings][days_until_due]=' + String.valueOf(daysUntilDue));
            bodyParts.add('metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            bodyParts.add('metadata[subscription_schedule]=true');
            bodyParts.add('metadata[subscription_source]=salesforce');
            bodyParts.add('billing_mode[type]=flexible');

            // Phase settings
            bodyParts.add('phases[0][currency]=' + quote.CurrencyIsoCode);
            bodyParts.add('phases[0][end_date]=' + String.valueOf(EndDateunixTimestamp));
            bodyParts.add('phases[0][proration_behavior]=always_invoice');
            bodyParts.add('phases[0][metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            bodyParts.add('phases[0][metadata][subscription_source]=salesforce');
            bodyParts.add('phases[0][metadata][subscription_schedule]=true');

            // Dynamic items
            // Integer i = 0;
            Integer j = 0;
            for (SBQQ__QuoteLine__c ql : quoteLines) {
                String priceId = quoteLineToPriceIdMap.get(ql.Id);
                if (String.isBlank(priceId))
                    continue;

                // if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'One-time') {
                //     bodyParts.add(
                //         'phases[0][add_invoice_items][' + i + '][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8')
                //     );
                //     bodyParts.add(
                //         'phases[0][add_invoice_items][' + i + '][quantity]=' + String.valueOf(ql.Quantity_For_Stripe__c)
                //     );
                //     i++;
                //     system.debug('One _ Time');
                // } else

                if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'Renewable') {
                    bodyParts.add('phases[0][items][' + j + '][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8'));
                    bodyParts.add('phases[0][items][' + j + '][quantity]=' + String.valueOf(ql.Quantity_For_Stripe__c));
                    j++;
                }
            }

            // Final encoded body
            String encodedBody = String.join(bodyParts, '&');
            System.debug('Encoded Stripe Request Body: ' + encodedBody);

            // Send Subscription Schedule Callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscription_schedules');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(encodedBody);

            HttpResponse res = http.send(req);
            if (res.getstatusCode() == 200) {
                Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                String subscriptionId = (String) subResponse.get('id');
                System.debug('Created Stripe Subscription ID: ' + subscriptionId);

                List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
                for (Id qlId : quoteLineToPriceIdMap.keySet()) {
                    quoteLinesToUpdate.add(
                        new SBQQ__QuoteLine__c(Id = qlId, Stripe_Price_ID__c = quoteLineToPriceIdMap.get(qlId))
                    );
                }
                update quoteLinesToUpdate;
            } else {
                System.debug('Stripe Subscription Schedule Error: ' + res.getBody());
                throw new CalloutException('Stripe Subscription Schedule Error: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in createStripeSchedule: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Schedule Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'createStripeSchedule',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;
        }
    }

    // It is Used for both Create & Update Subscription
    public static void createSubscriptionWithQuote(String responseBody, String quoteId) {
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
            Map<String, Object> metadata = (Map<String, Object>) payload.get('metadata');
            system.debug('--metadata--' + metadata);
            String subscriptionSource = metadata != null &&
                metadata.containsKey('subscription_source') &&
                metadata.get('subscription_source') != null
                ? String.valueOf(metadata.get('subscription_source'))
                : null;
            Boolean subscriptionSchedule = metadata.get('subscription_schedule') != null
                ? Boolean.valueOf((String) metadata.get('subscription_schedule'))
                : false;
            Boolean isRenewalSubscription = metadata.get('auto_renewal') != null
                ? Boolean.valueOf((String) metadata.get('auto_renewal'))
                : false;
            Map<String, Object> items = (Map<String, Object>) payload.get('items');
            List<Object> subscriptionItems = (List<Object>) items.get('data');
            System.debug('Subscription Items: ' + subscriptionItems);
            System.debug('Total subscription items: ' + subscriptionItems.size());

            // Extract basic fields from payload
            String scheduleId = (String) (payload.containsKey('schedule') ? payload.get('schedule') : null);
            System.debug('Extracted Schedule Id: ' + scheduleId);
            String subscriptionId = (String) payload.get('id');
            String customerId = (String) payload.get('customer');
            String latestInvoice = (String) payload.get('latest_invoice');
            String status = (String) payload.get('status');

            // Extract date fields as Long
            Long billingCycleAnchorUnix = payload.containsKey('billing_cycle_anchor')
                ? (Long) payload.get('billing_cycle_anchor')
                : null;
            Long cancelAtUnix = payload.containsKey('cancel_at') ? (Long) payload.get('cancel_at') : null;
            Long canceledAtUnix = payload.containsKey('canceled_at') ? (Long) payload.get('canceled_at') : null;
            Long createdUnix = payload.containsKey('created') ? (Long) payload.get('created') : null;
            Long currentPeriodStartUnix = payload.containsKey('current_period_start')
                ? (Long) payload.get('current_period_start')
                : null;
            Long currentPeriodEndUnix = payload.containsKey('current_period_end')
                ? (Long) payload.get('current_period_end')
                : null;
            Long startDateUnix = payload.containsKey('start_date') ? (Long) payload.get('start_date') : null;

            // Log extracted values
            System.debug('Subscription ID: ' + subscriptionId);
            System.debug('Customer ID: ' + customerId);
            System.debug('Latest Invoice: ' + latestInvoice);
            System.debug('Status: ' + status);

            Datetime billingCycleAnchor = toDateTime(billingCycleAnchorUnix);
            Date cancelAt = date.valueof(toDateTime(cancelAtUnix));
            Datetime canceledAt = toDateTime(canceledAtUnix);
            Datetime created = toDateTime(createdUnix);
            Datetime currentPeriodStart = toDateTime(currentPeriodStartUnix);
            Datetime currentPeriodEnd = toDateTime(currentPeriodEndUnix);
            Date startDate = date.valueof(toDateTime(startDateUnix));
            datetime subStartDate = toDateTime(startDateUnix);
            System.debug('Billing Cycle Anchor: ' + billingCycleAnchor);
            System.debug('Cancel At: ' + cancelAt);
            System.debug('Canceled At: ' + canceledAt);
            System.debug('Created: ' + created);
            System.debug('Current Period Start: ' + currentPeriodStart);
            System.debug('Current Period End: ' + currentPeriodEnd);
            System.debug('Start Date: ' + startDate);

            String latestChangeReason;

            if (isRenewalSubscription) {
                latestChangeReason = 'Auto Renewal Subscription Creaeted';
            } else {
                latestChangeReason = 'Subscription Created From Salesforce';
            }

            // Create Contract
            Contract contract = new Contract(
                AccountId = quoteList[0].SBQQ__Account__c,
                SBQQ__Quote__c = quoteId,
                SBQQ__Opportunity__c = quoteList[0].SBQQ__Opportunity2__c,
                Stripe_Subscription_ID__c = subscriptionId,
                Stripe_Customer_ID__c = customerId,
                Stripe_latest_Invoice_Id__c = latestInvoice,
                Stripe_Subscription_Source__c = subscriptionSource,
                Stripe_Status__c = status,
                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscriptions/' + subscriptionId,
                StartDate = startDate,
                ContractTerm = calculateContractTerm(startDate, cancelAt),
                Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                CustomerSignedId = quoteList[0].SBQQ__Account__r.blng__BillToContact__c,
                Created_From_Stripe__c = subscriptionSource != 'salesforce' ? true : false,
                Latest_Change_Reason__c = latestChangeReason,
                Stripe_Subscription_Schedule_ID__c = scheduleId,
                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix)
            );

            if (cancelAt != null) {
                contract.EndDate = cancelAt;
            }

            upsert contract Stripe_Subscription_ID__c;

            // Create Subscription Items
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

                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100; // Stripe amounts are in cents

                // Calculate values directly from Stripe response
                Decimal stripeMRR = unitAmount * (Integer) item.get('quantity'); // monthly value
                Decimal stripeARR = stripeMRR * 12; // annual value
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : 0;
                Decimal stripeTCV = contractTerm > 0 ? (stripeMRR * contractTerm) : null;
                Decimal customerPrice = contractTerm > 0 ? (unitAmount * contractTerm).setScale(2) : null;

                Product2 matchingProduct = stripeProductIdToProductMap.get(productId);
                System.debug('Matching Product: ' + matchingProduct);

                SBQQ__QuoteLine__c matchingQuoteLine = priceIdToQuoteLineMap.get(priceId);
                System.debug('Matching Quote Line: ' + matchingQuoteLine);

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = quoteList[0].SBQQ__Account__c,
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
                    SBQQ__SubscriptionEndDate__c = cancelAt,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = unitAmount,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                    SBQQ__CustomerPrice__c = customerPrice,
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
                upsert subscriptionItemsToInsert SBQQ__Subscription__c.Stripe_Subscription_ID__c;
                System.debug('Upserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');

                List<Contract> contractsToUpdate = new List<Contract>();
                Contract conToUpdate = new Contract(Id = contract.Id, Status = 'Activated');
                contractsToUpdate.add(conToUpdate);
                update contractsToUpdate;

                System.enqueueJob(new StripeInvoicePreview(subscriptionId));
            } else {
                System.debug('No subscription records to insert');
                return;
            }
        } catch (exception ex) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Upsert Error',
                Message__c = ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'createSubscriptionWithQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    // Create Subscription when Subscription is created manually from Stripe Portal
    public static void createSubscriptionWithoutQuote(String responseBody) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            system.debug('--payload--' + payload);
            Map<String, Object> metadata = (Map<String, Object>) payload.get('metadata');
            system.debug('--metadata--' + metadata);
            String subscriptionSource = metadata != null &&
                metadata.containsKey('subscription_source') &&
                metadata.get('subscription_source') != null
                ? String.valueOf(metadata.get('subscription_source'))
                : null;
            Boolean subscriptionSchedule = metadata.get('subscription_schedule') != null
                ? Boolean.valueOf((String) metadata.get('subscription_schedule'))
                : false;
            Boolean isRenewalSubscription = metadata.get('auto_renewal') != null
                ? Boolean.valueOf((String) metadata.get('auto_renewal'))
                : false;
            Map<String, Object> items = (Map<String, Object>) payload.get('items');
            List<Object> subscriptionItems = (List<Object>) items.get('data');
            System.debug('Subscription Items: ' + subscriptionItems);
            System.debug('Total subscription items: ' + subscriptionItems.size());

            // Extract basic fields from payload
            String scheduleId = (String) (payload.containsKey('schedule') ? payload.get('schedule') : null);
            System.debug('Extracted Schedule Id: ' + scheduleId);
            String subscriptionId = (String) payload.get('id');
            String customerId = (String) payload.get('customer');
            String latestInvoice = (String) payload.get('latest_invoice');
            String status = (String) payload.get('status');

            // Extract date fields as Long
            Long billingCycleAnchorUnix = payload.containsKey('billing_cycle_anchor')
                ? (Long) payload.get('billing_cycle_anchor')
                : null;
            Long cancelAtUnix = payload.containsKey('cancel_at') ? (Long) payload.get('cancel_at') : null;
            Long trialEndUnix = payload.containsKey('trial_end') ? (Long) payload.get('trial_end') : null;
            Long canceledAtUnix = payload.containsKey('canceled_at') ? (Long) payload.get('canceled_at') : null;
            Long createdUnix = payload.containsKey('created') ? (Long) payload.get('created') : null;
            Long currentPeriodStartUnix = payload.containsKey('current_period_start')
                ? (Long) payload.get('current_period_start')
                : null;
            Long currentPeriodEndUnix = payload.containsKey('current_period_end')
                ? (Long) payload.get('current_period_end')
                : null;
            Long startDateUnix = payload.containsKey('start_date') ? (Long) payload.get('start_date') : null;

            // Log extracted values
            System.debug('Subscription ID: ' + subscriptionId);
            System.debug('Customer ID: ' + customerId);
            System.debug('Latest Invoice: ' + latestInvoice);
            System.debug('Status: ' + status);

            Datetime billingCycleAnchor = toDateTime(billingCycleAnchorUnix);
            Date cancelAt = cancelAtUnix != null
                ? date.valueof(toDateTime(cancelAtUnix))
                : date.valueOf(toDateTime(trialEndUnix));
            Datetime canceledAt = toDateTime(canceledAtUnix);
            Datetime created = toDateTime(createdUnix);
            Datetime currentPeriodStart = toDateTime(currentPeriodStartUnix);
            Datetime currentPeriodEnd = toDateTime(currentPeriodEndUnix);
            Date startDate = date.valueof(toDateTime(startDateUnix));
            datetime subStartDate = toDateTime(startDateUnix);
            System.debug('Billing Cycle Anchor: ' + billingCycleAnchor);
            System.debug('Cancel At: ' + cancelAt);
            System.debug('Canceled At: ' + canceledAt);
            System.debug('Created: ' + created);
            System.debug('Current Period Start: ' + currentPeriodStart);
            System.debug('Current Period End: ' + currentPeriodEnd);
            System.debug('Start Date: ' + startDate);

            String latestChangeReason;

            if (subscriptionSource == 'salesforce') {
                if (isRenewalSubscription)
                    latestChangeReason = 'Contract Renewed From Salesforce';
                else
                    latestChangeReason = 'Contract Created From Salesforce';
            } else if (subscriptionSource == 'self_service' || subscriptionSource == 'amazon') {
                latestChangeReason = 'Contract Created From Stripe Self-Service Portal';
            } else if (subscriptionSource == null) {
                latestChangeReason = 'Contract Created From Stripe Manually';
            } else {
                latestChangeReason = 'Contract Created From Stripe';
            }
            System.debug('Latest Change Reason: ' + latestChangeReason);

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

            // Create Contract
            Contract contract = new Contract(
                AccountId = accountId,
                Stripe_Subscription_ID__c = subscriptionId,
                Stripe_Customer_ID__c = customerId,
                Stripe_latest_Invoice_Id__c = latestInvoice,
                Stripe_Subscription_Source__c = subscriptionSource != null ? subscriptionSource : 'stripe',
                Stripe_Status__c = status,
                Stripe_Subscription_URL__c = 'https://dashboard.stripe.com/subscriptions/' + subscriptionId,
                StartDate = startDate,
                ContractTerm = calculateContractTerm(startDate, cancelAt),
                // SBQQ__Evergreen__c = calculateContractTerm(startDate, cancelAt) > 0 ? false : true,
                Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                CustomerSignedId = accts.size() > 0 ? accts[0].blng__BillToContact__c : null,
                Created_From_Stripe__c = subscriptionSource != 'salesforce' ? true : false,
                Latest_Change_Reason__c = latestChangeReason,
                Stripe_Subscription_Schedule_ID__c = scheduleId,
                Stripe_Subscription_Start_Date__c = String.valueOf(startDateUnix)
            );

            if (cancelAt != null) {
                contract.EndDate = cancelAt;
            }

            upsert contract Stripe_Subscription_ID__c;

            // Create Subscription Items
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
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : null;
                Decimal stripeTCV = contractTerm > 0 ? (stripeMRR * contractTerm) : null;
                Decimal customerPrice = contractTerm > 0 ? (unitAmount * contractTerm).setScale(2) : null;

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = accountId,
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
                    SBQQ__SubscriptionEndDate__c = cancelAt,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = unitAmount,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
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

            if (!subscriptionItemsToInsert.isEmpty()) {
                upsert subscriptionItemsToInsert SBQQ__Subscription__c.Stripe_Subscription_ID__c;
                System.debug('Upserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');

                List<Contract> contractsToUpdate = new List<Contract>();
                Contract conToUpdate = new Contract(Id = contract.Id, Status = 'Activated');
                contractsToUpdate.add(conToUpdate);
                update contractsToUpdate;

                System.enqueueJob(new StripeInvoicePreview(subscriptionId));
            } else {
                System.debug('No subscription records to insert');
                return;
            }
        } catch (exception ex) {
            Logger__c logger = new Logger__c(
                Name = 'Subscription Creation Error Without Quote',
                Message__c = ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'createSubscriptionWithoutQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    public static void createScheduleWithQuote(String responseBody, String quoteId) {
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

                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100; // Stripe amounts are in cents

                // Calculate values directly from Stripe response
                Decimal stripeMRR = unitAmount * (Integer) item.get('quantity'); // monthly value
                Decimal stripeARR = stripeMRR * 12; // annual value
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : 0;
                Decimal stripeTCV = contractTerm > 0 ? (stripeMRR * contractTerm) : null;
                Decimal customerPrice = contractTerm > 0 ? (unitAmount * contractTerm).setScale(2) : null;

                Product2 matchingProduct = stripeProductIdToProductMap.get(productId);
                System.debug('Matching Product: ' + matchingProduct);

                SBQQ__QuoteLine__c matchingQuoteLine = priceIdToQuoteLineMap.get(priceId);
                System.debug('Matching Quote Line: ' + matchingQuoteLine);

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = quoteList[0].SBQQ__Account__c,
                    Stripe_Price_ID__c = priceId,
                    Stripe_Product_ID__c = productId,
                    SBQQ__Quantity__c = (Integer) item.get('quantity'),
                    Stripe_Interval__c = interval,
                    Stripe_Activate__c = (Boolean) price.get('active'),
                    Status__c = status,
                    Stripe_Start_Date__c = startDate,
                    Stripe_End_Date__c = endDate,
                    SBQQ__SubscriptionStartDate__c = startDate,
                    SBQQ__SubscriptionEndDate__c = endDate,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = unitAmount,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
                    SBQQ__CustomerPrice__c = customerPrice,
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
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'createScheduleWithQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    public static void createScheduleWithoutQuote(String responseBody) {
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

                Decimal unitAmount = ((Decimal) price.get('unit_amount')) / 100; // Stripe amounts are in cents

                // Calculate values directly from Stripe response
                Decimal stripeMRR = unitAmount * (Integer) item.get('quantity'); // monthly value
                Decimal stripeARR = stripeMRR * 12; // annual value
                Integer contractTerm = contract.ContractTerm != null ? contract.ContractTerm : 0;
                Decimal stripeTCV = contractTerm > 0 ? (stripeMRR * contractTerm) : null;
                Decimal customerPrice = contractTerm > 0 ? (unitAmount * contractTerm).setScale(2) : null;

                SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                    SBQQ__Contract__c = contract.Id,
                    SBQQ__Account__c = accountId,
                    Stripe_Price_ID__c = priceId,
                    Stripe_Product_ID__c = productId,
                    SBQQ__Quantity__c = (Integer) item.get('quantity'),
                    Stripe_Interval__c = interval,
                    Stripe_Activate__c = (Boolean) price.get('active'),
                    Status__c = status,
                    Stripe_Start_Date__c = startDate,
                    Stripe_End_Date__c = endDate,
                    SBQQ__SubscriptionStartDate__c = startDate,
                    SBQQ__SubscriptionEndDate__c = endDate,
                    Stripe_Billing_Date__c = date.valueof(billingCycleAnchor),
                    Latest_Change_Reason__c = latestChangeReason,
                    SBQQ__NetPrice__c = unitAmount,
                    SBQQ__Product__c = matchingProduct != null ? matchingProduct.Id : null,
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

            if (!subscriptionItemsToInsert.isEmpty()) {
                insert subscriptionItemsToInsert;
                System.debug('Inserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');
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
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'createScheduleWithoutQuote',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    // Canceled From Stripe
    @future(callout=true)
    public static void deleteSubscription(String subscriptionId) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + subscriptionId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            HttpResponse res = http.send(req);

            if (res.getstatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('Stripe Subscription Response: ' + responseBody);
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                system.debug('--payload-' + payload);
                Map<String, Object> items = (Map<String, Object>) payload.get('items');
                List<Object> subscriptionItems = (List<Object>) items.get('data');
                System.debug('Subscription Items: ' + subscriptionItems);
                System.debug('Total subscription items: ' + subscriptionItems.size());

                // Extract basic fields from payload
                String status = (String) payload.get('status');
                System.debug('Status: ' + status);

                List<Contract> contracts = [
                    SELECT Id, Stripe_Subscription_ID__c
                    FROM Contract
                    WHERE Stripe_Subscription_ID__c = :subscriptionId
                ];

                if (contracts.isEmpty()) {
                    System.debug('No Contract found for Subscription ID: ' + subscriptionId);
                    return;
                }

                // Update and cancel the Contract
                Contract updatedContract = new Contract(
                    Id = contracts[0].Id,
                    Stripe_Status__c = status,
                    Status = 'canceled',
                    Latest_Change_Reason__c = 'Subscription Canceled'
                );

                update updatedContract;
                System.debug('Updated Contract: ' + updatedContract);

                // Cancel Subscription Items
                List<SBQQ__Subscription__c> subscriptionItemsToInsert = new List<SBQQ__Subscription__c>();

                for (Object itemObj : subscriptionItems) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    Map<String, Object> price = (Map<String, Object>) item.get('price');

                    SBQQ__Subscription__c sub = new SBQQ__Subscription__c(
                        SBQQ__Contract__c = updatedContract.Id,
                        Stripe_Subscription_ID__c = (String) item.get('id'),
                        Stripe_Activate__c = (Boolean) price.get('active'),
                        Status__c = status,
                        Canceled_From_Stripe__c = true,
                        Latest_Change_Reason__c = 'Subcription Item Delete From Stripe'
                    );

                    subscriptionItemsToInsert.add(sub);
                }

                System.debug('Subscription Items to Insert: ' + subscriptionItemsToInsert);
                System.debug('Total Subscription Items to Insert: ' + subscriptionItemsToInsert.size());

                if (!subscriptionItemsToInsert.isEmpty()) {
                    upsert subscriptionItemsToInsert SBQQ__Subscription__c.Stripe_Subscription_ID__c;
                    System.debug('Upserted ' + subscriptionItemsToInsert.size() + ' SBQQ__Subscription__c records');
                }
            } else {
                System.debug('Stripe Subscription Retrieval Error: ' + res.getBody());
                throw new CalloutException('Stripe Subscription Retrieval Error: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in deleteSubscription: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Deletion Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'deleteSubscription',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }

    public static void deleteSchedule(String scheduleId) {
        try {
            List<Contract> pendingContracts = [
                SELECT Id
                FROM Contract
                WHERE Stripe_Subscription_Schedule_ID__c = :scheduleId AND Status = 'Pending'
            ];

            if (!pendingContracts.isEmpty()) {
                delete pendingContracts;
                System.debug('Deleted pending contracts for Stripe Schedule: ' + scheduleId);
            } else {
                System.debug('No pending contracts found for Stripe Schedule: ' + scheduleId);
            }
        } catch (Exception e) {
            System.debug('Error deleting pending contracts for schedule ' + scheduleId + ': ' + e.getMessage());

            insert new Logger__c(
                Name = 'Stripe Schedule Deletion Error',
                Message__c = e.getMessage(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler',
                Apex_Method__c = 'deleteSchedule',
                Object_Name__c = 'Contract'
            );
        }
    }

    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer) unixTs);
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
}