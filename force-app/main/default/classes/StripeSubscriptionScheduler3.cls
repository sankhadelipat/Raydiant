public class StripeSubscriptionScheduler3 {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    // -------- FLOW INPUT --------
    public class FlowInput {
        @InvocableVariable(required=true)
        public Id quoteId;
    }

    // -------- FLOW OUTPUT --------
    public class FlowResult {
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String message;
    }

    /**
     * Amends existing Stripe subscription based on CPQ Amendment Quote. It handles both subscription updates, new subscription items addition & existing subscription removal. The method is designed to be called from an invocable context, allowing it to be easily integrated into CPQ amendment processes.
     */
    @InvocableMethod(
        label='Amend Stripe Subscription'
        description='Updates existing Stripe subscription using CPQ Amendment Quote'
        category='Stripe'
    )
    public static List<FlowResult> amendStripeSubscription(List<FlowInput> inputs) {
        FlowResult result = new FlowResult();
        List<FlowResult> results = new List<FlowResult>{ result };

        if (inputs == null || inputs.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No quote Ids provided';
            return results;
        }

        try {
            SBQQ__Quote__c quote = [
                SELECT
                    Id,
                    SBQQ__MasterContract__c,
                    SBQQ__StartDate__c,
                    SBQQ__Account__c,
                    Stripe_Customer_ID__c,
                    SBQQ__EndDate__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    Billing_Frequency_Override__c,
                    SBQQ__SubscriptionTerm__c,
                    SBQQ__PaymentTerms__c,
                    CurrencyIsoCode
                FROM SBQQ__Quote__c
                WHERE Id = :inputs[0].quoteId
                LIMIT 1
            ];

            if (quote.SBQQ__MasterContract__c == null) {
                throw new HandledException('No Master Contract found for Amendment Quote');
            }

            Contract con = [
                SELECT Id, Status, Stripe_Subscription_ID__c
                FROM Contract
                WHERE Id = :quote.SBQQ__MasterContract__c
                LIMIT 1
            ];

            if (String.isBlank(con.Stripe_Subscription_ID__c)) {
                throw new HandledException('Missing Stripe Subscription ID on Contract');
            }
            if (con.Status != 'Activated') {
                throw new HandledException('Contract must be Active to amend subscription');
            }

            // Get all subscriptions related to the contract
            List<SBQQ__Subscription__c> allSubs = [
                SELECT Id, Stripe_Subscription_ID__c
                FROM SBQQ__Subscription__c
                WHERE SBQQ__Contract__c = :con.Id AND Stripe_Subscription_ID__c != NULL
            ];

            if (allSubs.isEmpty()) {
                throw new HandledException('No Stripe Subscriptions found for Contract');
            }

            // Get Amendment Quote Lines With upgraded subscription
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT
                    Id,
                    MRR__c,
                    Quantity_For_Stripe__c,
                    SBQQ__EffectiveQuantity__c,
                    SBQQ__UpgradedSubscription__c,
                    SBQQ__NetTotal__c,
                    SBQQ__Product__r.Name,
                    Billing_Frequency_Override__c,
                    CurrencyIsoCode,
                    SBQQ__Product__r.Stripe_Product_Id__c,
                    SBQQ__Product__r.SBQQ__SubscriptionType__c
                FROM SBQQ__QuoteLine__c
                WHERE
                    SBQQ__Quote__c = :quote.Id
                    AND Stripe_Subscription_Type__c != 'One-time'
                    AND SBQQ__Product__r.Stripe_Product_Id__c != NULL
            ];

            // Fetch actual subscriptions
            Set<Id> subIds = new Set<Id>();
            Set<Id> usedSubs = new Set<Id>();
            for (SBQQ__QuoteLine__c ql : quoteLines) {
                subIds.add(ql.SBQQ__UpgradedSubscription__c);
            }

            Map<Id, SBQQ__Subscription__c> subMap = new Map<Id, SBQQ__Subscription__c>(
                [
                    SELECT Id, Stripe_Subscription_ID__c
                    FROM SBQQ__Subscription__c
                    WHERE Id IN :subIds
                ]
            );

            // Prepare price id with quote line price
            Map<Id, String> quoteLineToPriceIdMap = new Map<Id, String>();
            Http http = new Http();

            // Build Stripe request
            List<String> bodyParts = new List<String>();
            Integer index = 0;

            for (SBQQ__QuoteLine__c ql : quoteLines) {
                Integer qty = (ql.Quantity_For_Stripe__c != null) ? Integer.valueOf(ql.Quantity_For_Stripe__c) : 1;

                String priceId = createStripePrice(ql);
                quoteLineToPriceIdMap.put(ql.Id, priceId);

                // CASE 1: EXISTING SUBSCRIPTION → UPDATE
                if (ql.SBQQ__UpgradedSubscription__c != null) {
                    SBQQ__Subscription__c sub = subMap.get(ql.SBQQ__UpgradedSubscription__c);

                    if (sub == null || String.isBlank(sub.Stripe_Subscription_ID__c)) {
                        System.debug('Skipping line due to missing subscription item id');
                        continue;
                    }
                    usedSubs.add(sub.Id);

                    bodyParts.add(
                        'items[' + index + '][id]=' + EncodingUtil.urlEncode(sub.Stripe_Subscription_ID__c, 'UTF-8')
                    );
                    bodyParts.add('items[' + index + '][quantity]=' + qty);
                    bodyParts.add('items[' + index + '][price]=' + priceId);
                }
                // CASE 2: NEW PRODUCT → ADD ITEM
                else {
                    bodyParts.add('items[' + index + '][quantity]=' + qty);
                    bodyParts.add('items[' + index + '][price]=' + priceId);
                }

                index++;
            }

            // Handle removed subscriptions
            for (SBQQ__Subscription__c sub : allSubs) {
                // If NOT used → DELETE from subscription
                if (!usedSubs.contains(sub.Id)) {
                    bodyParts.add(
                        'items[' + index + '][id]=' + EncodingUtil.urlEncode(sub.Stripe_Subscription_ID__c, 'UTF-8')
                    );
                    bodyParts.add('items[' + index + '][deleted]=true');
                    index++;
                }
            }

            // Enable proration
            bodyParts.add('proration_behavior=always_invoice');

            String body = String.join(bodyParts, '&');

            // Call Stripe
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/subscriptions/' + con.Stripe_Subscription_ID__c);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Stripe subscription updated successfully');
                Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                String subscriptionId = (String) subResponse.get('id');
                String invoiceId = (String) subResponse.get('latest_invoice');
                System.debug('Created Stripe Subscription ID: ' + subscriptionId);
                System.debug('Latest Invoice ID: ' + invoiceId);

                // StripeInvoiceCallout2.invoiceGeneration(new List<Id>{ quote.Id }, true);

                System.debug('Quote Lines and Price IDs:' + JSON.serializePretty(quoteLineToPriceIdMap));
                List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
                for (Id qlId : quoteLineToPriceIdMap.keySet()) {
                    quoteLinesToUpdate.add(
                        new SBQQ__QuoteLine__c(Id = qlId, Stripe_Price_ID__c = quoteLineToPriceIdMap.get(qlId))
                    );
                }
                update quoteLinesToUpdate;

                System.enqueueJob(new StripeInvoiceCallout(invoiceId, quote.Id));

                result.isSuccess = true;
                result.message = 'Stripe Subscription Updated Successfully';
                return results;
            } else {
                throw new CalloutException('Stripe Update Failed: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in amendStripeSubscription: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Subscription Amendment Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubscriptionScheduler3',
                Apex_Method__c = 'amendStripeSubscription',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;

            result.isSuccess = false;
            result.message = e.getMessage();
            return results;
        }
    }

    private static String createStripePrice(SBQQ__QuoteLine__c ql) {
        Http http = new Http();

        Map<String, List<Object>> freqMap = new Map<String, List<Object>>{
            'Monthly' => new List<Object>{ 'month', 1 },
            'Quarterly' => new List<Object>{ 'month', 3 },
            'Semiannual' => new List<Object>{ 'month', 6 },
            'Annual' => new List<Object>{ 'year', 1 },
            '2-Year' => new List<Object>{ 'year', 2 },
            '3-Year' => new List<Object>{ 'year', 3 }
        };

        String priceType;
        String interval;
        Integer intervalCount;

        if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'Renewable') {
            priceType = 'recurring';

            String freq = (ql.Billing_Frequency_Override__c != null) ? ql.Billing_Frequency_Override__c : 'Monthly';

            List<Object> freqData = freqMap.containsKey(freq) ? freqMap.get(freq) : freqMap.get('Monthly');

            interval = (String) freqData[0];
            intervalCount = (Integer) freqData[1];
        } else {
            priceType = 'one_time';
        }

        Decimal qty = (ql.Quantity_For_Stripe__c != null &&
            ql.Quantity_For_Stripe__c != 0)
            ? ql.Quantity_For_Stripe__c
            : 1;

        Decimal effectiveQty = (ql.SBQQ__EffectiveQuantity__c != null &&
            ql.SBQQ__EffectiveQuantity__c != 0)
            ? ql.SBQQ__EffectiveQuantity__c
            : qty;

        Decimal unitPrice = (ql.MRR__c != null &&
            ql.MRR__c != 0)
            ? ql.MRR__c / effectiveQty
            : ql.SBQQ__NetTotal__c / effectiveQty;

        Decimal multiplier = 1;
        if (priceType == 'recurring') {
            multiplier = (interval == 'month' &&
                intervalCount == 3)
                ? 3
                : (interval == 'year') ? (12 * intervalCount) : 1;
        }

        Decimal unitAmount = (unitPrice != null ? unitPrice.setScale(2) * multiplier * 100 : 0);

        List<String> bodyParts = new List<String>{
            'billing_scheme=per_unit',
            'currency=' + ql.CurrencyIsoCode,
            'product=' + ql.SBQQ__Product__r.Stripe_Product_Id__c,
            'unit_amount_decimal=' + unitAmount
        };

        if (priceType == 'recurring') {
            bodyParts.add('recurring[interval]=' + interval);
            bodyParts.add('recurring[interval_count]=' + intervalCount);
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.stripe.com/v1/prices');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(String.join(bodyParts, '&'));

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            String priceId = (String) ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('id');
            System.debug('Created Stripe Price: ' + priceId);
            return priceId;
        }

        throw new CalloutException('Price creation failed: ' + res.getBody());
    }
}