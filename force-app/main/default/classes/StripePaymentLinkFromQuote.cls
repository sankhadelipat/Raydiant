public class StripePaymentLinkFromQuote {
    private static final Stripe_Details__c testPub = Stripe_Details__c.getInstance('Stripe Details');
    private static final String Secret_Key = testPub.Serect_Key__c;
    private static final String Publish_Key = testPub.Publishable_Key__c;
    private static final String sucessUrl = System.Label.SuccessUrlForPayment;
    private static final String paymentMethodConfig = System.Label.StripePaymentMethodConfig;
    private static final String signatureLabel = System.Label.StripeSignatureLabel;

    //Quote To Cash Abhi 12/08/25
    @invocableMethod(label='Stripe Payment Callout quote to cash process')
    public static void getQuoteForQuoteToCash(List<Id> quoteIds) {
        try {
            List<SBQQ__Quote__c> updateQuoteList = new List<SBQQ__Quote__c>();

            // 1. Query Quote
            SBQQ__Quote__c quoteRecord = [
                SELECT
                    Id,
                    SBQQ__NetAmount__c,
                    SBQQ__Account__c,
                    Bill_To_Contact__c,
                    SBQQ__SubscriptionTerm__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    SBQQ__Account__r.Bill_To_Email__c,
                    CurrencyIsoCode
                FROM SBQQ__Quote__c
                WHERE Id = :quoteIds
                LIMIT 1
            ];
            System.debug('quote--' + quoteRecord);
            // 2. Query Quote Lines + Product with multiple Price IDs
            List<SBQQ__QuoteLine__c> quoteLineItems = [
                SELECT
                    Id,
                    Stripe_Subscription_Type__c,
                    SBQQ__Quote__c,
                    SBQQ__Product__r.Name,
                    SBQQ__BillingType__c,
                    MRR__c,
                    Billing_Frequency_Override__c,
                    SBQQ__BillingFrequency__c,
                    Monthly_Total__c,
                    SBQQ__Quantity__c,
                    SBQQ__NetTotal__c,
                    Quantity_For_Stripe__c,
                    SBQQ__CustomerPrice__c,
                    SBQQ__Product__r.Stripe_Product_Id__c,
                    SBQQ__Product__r.Stripe_Price_ID__c,
                    SBQQ__Product__r.SBQQ__SubscriptionType__c,
                    CurrencyIsoCode
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quoteRecord.Id AND SBQQ__Product__r.Stripe_Product_Id__c != NULL
            ];

            System.debug('quoteLineItems--' + quoteLineItems);
            // prepare price id with Quote line price //
            Map<Id, String> quoteLineToPriceIdMap = new Map<Id, String>();
            Http http = new Http();
 Map<String, List<Object>> freqMap = new Map<String, List<Object>>{
                'Monthly' => new List<Object>{ 'month', 1 },
                    'Quarterly' => new List<Object>{ 'month', 3 },
                        'Annual' => new List<Object>{ 'year', 1 },
                            '2-Year' => new List<Object>{ 'year', 2 },
                                '3-Year' => new List<Object>{ 'year', 3 }
            };

            // Determine product charge type
            Boolean hasRecurringProducts = false;

            for (SBQQ__QuoteLine__c ql : quoteLineItems) {
                String priceType;
                String interval;
                Integer intervalCount;

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
                } else if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'One-time') {
                    priceType = 'one_time';
                }

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

                // Send Price request
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
                    String priceId = (String) ((Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody()))
                        .get('id');
                    quoteLineToPriceIdMap.put(ql.Id, priceId);
                } else {
                    system.debug('results--' + priceRes.getBody());
                    throw new CalloutException('Stripe callout failed: ' + priceRes.getBody());
                }
            }

            // Determine Checkout Session mode
            String checkoutMode = hasRecurringProducts ? 'subscription' : 'payment';
            // 3. Base Checkout Session body
            List<String> bodyParts = new List<String>();
            // bodyParts.add('payment_method_types[]=card');
            bodyParts.add('mode=' + checkoutMode);
            bodyParts.add('customer=' + quoteRecord.SBQQ__Account__r.Stripe_Customer_ID__c);
            // bodyParts.add('customer_email=' + quoteRecord.SBQQ__Account__r.Bill_To_Email__c);
            bodyParts.add('payment_method_configuration=' + paymentMethodConfig);
            bodyParts.add('success_url=' + sucessUrl);
            bodyParts.add('metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(quoteRecord.Id, 'UTF-8'));
            bodyParts.add('metadata[salesforce_initial_payment]=true');
            bodyParts.add('billing_address_collection=required');
            bodyParts.add('consent_collection[terms_of_service]=required');
            bodyParts.add('shipping_address_collection[allowed_countries][]=US');
            bodyParts.add('shipping_address_collection[allowed_countries][]=CA');
            //bodyParts.add('shipping_address_collection[allowed_countries][]=UK'); ask client
            bodyParts.add('shipping_address_collection[allowed_countries][]=AU');
            bodyParts.add('shipping_address_collection[allowed_countries][]=GB'); // custom metadata
            bodyParts.add('custom_fields[0][key]=signature');
            bodyParts.add('custom_fields[0][label][type]=custom');
            bodyParts.add('custom_fields[0][label][custom]=' + EncodingUtil.urlEncode(signatureLabel, 'UTF-8'));
            bodyParts.add('custom_fields[0][type]=text');
            bodyParts.add('custom_fields[0][optional]=false');
            bodyParts.add('custom_fields[0][text][maximum_length]=255');
            bodyParts.add('custom_fields[0][text][minimum_length]=1');
            if (checkoutMode == 'payment') {
                bodyParts.add(
                    'payment_intent_data[metadata][salesforce_quote_id]=' +
                    EncodingUtil.urlEncode(quoteRecord.Id, 'UTF-8')
                );
            }
            //bodyParts.add('invoice_creation[enabled]=true');
            // bodyParts.add('invoice_creation[invoice_data][metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quoteRecord.Id, 'UTF-8'));
            // bodyParts.add('invoice_creation[invoice_data][metadata][subscription_source]=salesforce');
            // bodyParts.add('subscription_data.metadata[updated_from_salesforce]=true');

            Integer index = 0;
            for (SBQQ__QuoteLine__c item : quoteLineItems) {
                String priceId = (string) quoteLineToPriceIdMap.get(item.id);
                bodyParts.add('line_items[' + index + '][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8'));
                bodyParts.add('line_items[' + index + '][quantity]=' + String.valueOf(item.Quantity_For_Stripe__c));
                index++;
            }

            // 5. Send request to Stripe
            String requestBody = String.join(bodyParts, '&');
            System.debug('requestBody--' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/checkout/sessions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + Secret_Key);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);

            Http httpChecout = new Http();
            HttpResponse res = httpChecout.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('results--' + results);
                String paymentLink = (String) results.get('url');
                String checkoutSessionID = (String) results.get('id');

                for (SBQQ__Quote__c qt : new List<SBQQ__Quote__c>{ quoteRecord }) {
                    qt.Stripe_Payment_Link__c = paymentLink;
                    qt.Stripe_Payment_Intent__c = checkoutSessionID;
                    updateQuoteList.add(qt);
                }
                update updateQuoteList;
                /// add price in quote line///
                List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
                for (Id qlId : quoteLineToPriceIdMap.keySet()) {
                    quoteLinesToUpdate.add(
                        new SBQQ__QuoteLine__c(Id = qlId, Stripe_Price_ID__c = quoteLineToPriceIdMap.get(qlId))
                    );
                }
                update quoteLinesToUpdate;
            } else {
                system.debug('results--' + res.getBody());
                throw new CalloutException('Stripe callout failed: ' + res.getBody());
            }
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Link Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentLinkFromQuote',
                Apex_Method__c = 'getQuoteForQuoteToCash',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;
        }
    }

    //Self service Sank 12/08/25 - Modified 26/08/25
    // @future(callout=true)
    public static String getQuoteForSelfService(Id quoteId) {
        try {
            List<SBQQ__Quote__c> updateQuoteList = new List<SBQQ__Quote__c>();

            // 1. Query Quote
            SBQQ__Quote__c quoteRecord = [
                SELECT
                    Id,
                    SBQQ__NetAmount__c,
                    SBQQ__Account__c,
                    Bill_To_Contact__c,
                    SBQQ__SubscriptionTerm__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    CurrencyIsoCode
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1
            ];
            System.debug('quote--' + quoteRecord);
            // 2. Query Quote Lines + Product with multiple Price IDs
            List<SBQQ__QuoteLine__c> quoteLineItems = [
                SELECT
                    Id,
                    Stripe_Subscription_Type__c,
                    SBQQ__Quote__c,
                    SBQQ__Product__r.Name,
                    SBQQ__BillingType__c,
                    MRR__c,
                    Billing_Frequency_Override__c,
                    SBQQ__BillingFrequency__c,
                    Monthly_Total__c,
                    SBQQ__Quantity__c,
                    SBQQ__NetTotal__c,
                    Quantity_For_Stripe__c,
                    SBQQ__CustomerPrice__c,
                    SBQQ__Product__r.Stripe_Product_Id__c,
                    SBQQ__Product__r.Stripe_Price_ID__c,
                    SBQQ__Product__r.SBQQ__SubscriptionType__c,
                    CurrencyIsoCode
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quoteRecord.Id AND SBQQ__Product__r.Stripe_Product_Id__c != NULL
            ];

            System.debug('quoteLineItems--' + quoteLineItems);
            // prepare price id with Quote line price //
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

            for (SBQQ__QuoteLine__c ql : quoteLineItems) {
                String priceType;
                String interval;
                Integer intervalCount;

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
                } else if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'One-time') {
                    priceType = 'one_time';
                }

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

                // Send Price request
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
                    String priceId = (String) ((Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody()))
                        .get('id');
                    quoteLineToPriceIdMap.put(ql.Id, priceId);
                } else {
                    system.debug('results--' + priceRes.getBody());
                    throw new CalloutException('Stripe callout failed: ' + priceRes.getBody());
                }
            }

            // Determine Checkout Session mode
            String checkoutMode = hasRecurringProducts ? 'subscription' : 'payment';
            // 3. Base Checkout Session body
            List<String> bodyParts = new List<String>();
            bodyParts.add('payment_method_types[]=card');
            bodyParts.add('mode=' + checkoutMode);
            bodyParts.add('customer=' + quoteRecord.SBQQ__Account__r.Stripe_Customer_ID__c);
            bodyParts.add('success_url=' + EncodingUtil.urlEncode(sucessUrl, 'UTF-8'));
            bodyParts.add('metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(quoteRecord.Id, 'UTF-8'));
            bodyParts.add('metadata[salesforce_initial_payment]=true');
            if (checkoutMode == 'payment') {
                bodyParts.add(
                    'payment_intent_data[metadata][salesforce_quote_id]=' +
                    EncodingUtil.urlEncode(quoteRecord.Id, 'UTF-8')
                );
            }
            // bodyParts.add('subscription_data.metadata[updated_from_salesforce]=true');
            //4. Add line items dynamically using Stripe Price IDs
            Integer index = 0;
            for (SBQQ__QuoteLine__c item : quoteLineItems) {
                String priceId = (string) quoteLineToPriceIdMap.get(item.id);
                bodyParts.add('line_items[' + index + '][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8'));
                bodyParts.add('line_items[' + index + '][quantity]=' + String.valueOf(item.Quantity_For_Stripe__c));
                index++;
            }

            // 5. Send request to Stripe
            String requestBody = String.join(bodyParts, '&');
            System.debug('requestBody--' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/checkout/sessions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + Secret_Key);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);

            Http httpChecout = new Http();
            HttpResponse res = httpChecout.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('results--' + results);
                String paymentLink = (String) results.get('url');
                String checkoutSessionID = (String) results.get('id');

                for (SBQQ__Quote__c qt : new List<SBQQ__Quote__c>{ quoteRecord }) {
                    qt.Stripe_Payment_Link__c = paymentLink;
                    qt.Stripe_Payment_Intent__c = checkoutSessionID;
                    updateQuoteList.add(qt);
                }
                update updateQuoteList;
                /// add price in quote line///
                List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
                for (Id qlId : quoteLineToPriceIdMap.keySet()) {
                    quoteLinesToUpdate.add(
                        new SBQQ__QuoteLine__c(Id = qlId, Stripe_Price_ID__c = quoteLineToPriceIdMap.get(qlId))
                    );
                }
                update quoteLinesToUpdate;

                return paymentLink;
            } else {
                system.debug('results--' + res.getBody());
                throw new CalloutException('Stripe callout failed: ' + res.getBody());
            }
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Link Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentLinkFromQuote',
                Apex_Method__c = 'getQuoteForSelfService',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;

            throw e;
        }
    }
}