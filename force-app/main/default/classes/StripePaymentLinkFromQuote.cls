public class StripePaymentLinkFromQuote {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private static final String sucessUrl = System.Label.SuccessUrlForPayment;
    private static final String paymentMethodConfig = System.Label.StripePaymentMethodConfig;
    private static final String signatureLabel = System.Label.StripeSignatureLabel;

    public class FlowResult {
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String message;
    }

    @invocableMethod(
        label='Generate Stripe Payment Link from Quote'
        description='Generates a Stripe Payment Link for the given Quote ID'
        category='Stripe'
    )
    public static List<FlowResult> generatePaymentLinkFromQuote(List<Id> quoteIds) {
        List<FlowResult> flowResults = new List<FlowResult>();
        FlowResult flowRes = new FlowResult();
        flowResults.add(flowRes);

        if (quoteIds == null || quoteIds.isEmpty()) {
            flowRes.isSuccess = false;
            flowRes.message = 'No Quote ID provided.';
            return flowResults;
        }

        try {
            List<SBQQ__Quote__c> updateQuoteList = new List<SBQQ__Quote__c>();

            // Get Quote Record
            SBQQ__Quote__c quote = [
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
                WHERE Id = :quoteIds[0]
                LIMIT 1
            ];
            System.debug('quote--' + quote);

            // Get Quote Line Items
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
                WHERE SBQQ__Quote__c = :quote.Id AND SBQQ__Product__r.Stripe_Product_Id__c != NULL
            ];
            System.debug('quoteLineItems--' + quoteLineItems);

            // Prepare to create Prices in Stripe
            Map<Id, String> quoteLineToPriceIdMap = new Map<Id, String>();

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

                Http http = new Http();
                HttpResponse priceRes = http.send(priceReq);

                if (priceRes.getStatusCode() == 200) {
                    String priceId = (String) ((Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody()))
                        .get('id');
                    quoteLineToPriceIdMap.put(ql.Id, priceId);
                } else {
                    system.debug('results--' + priceRes.getBody());
                    throw new CalloutException('Stripe Price creation failed: ' + priceRes.getBody());
                }
            }

            // Determine Checkout Session mode
            String checkoutMode = hasRecurringProducts ? 'subscription' : 'payment';

            // Build Checkout Session API body
            List<String> bodyParts = new List<String>();
            bodyParts.add('mode=' + checkoutMode);
            bodyParts.add('customer=' + quote.SBQQ__Account__r.Stripe_Customer_ID__c);
            bodyParts.add('payment_method_configuration=' + paymentMethodConfig);
            bodyParts.add('success_url=' + sucessUrl);
            bodyParts.add('billing_address_collection=required');
            bodyParts.add('consent_collection[terms_of_service]=required');
            bodyParts.add('shipping_address_collection[allowed_countries][]=US');
            bodyParts.add('shipping_address_collection[allowed_countries][]=CA');
            //bodyParts.add('shipping_address_collection[allowed_countries][]=UK'); ask client
            bodyParts.add('shipping_address_collection[allowed_countries][]=AU');
            bodyParts.add('shipping_address_collection[allowed_countries][]=GB');
            // metadata
            bodyParts.add('metadata[salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            bodyParts.add('metadata[salesforce_initial_payment]=true');
            // custom fields
            bodyParts.add('custom_fields[0][key]=signature');
            bodyParts.add('custom_fields[0][label][type]=custom');
            bodyParts.add('custom_fields[0][label][custom]=' + EncodingUtil.urlEncode(signatureLabel, 'UTF-8'));
            bodyParts.add('custom_fields[0][type]=text');
            bodyParts.add('custom_fields[0][optional]=false');
            bodyParts.add('custom_fields[0][text][maximum_length]=255');
            bodyParts.add('custom_fields[0][text][minimum_length]=1');

            if (checkoutMode == 'subscription') {
                bodyParts.add(
                    'subscription_data[metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8')
                );
                bodyParts.add('subscription_data[metadata][subscription_source]=salesforce');
                bodyParts.add('subscription_data[metadata][updated_from_salesforce]=true');
            }

            if (checkoutMode == 'payment') {
                bodyParts.add(
                    'payment_intent_data[metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8')
                );
                bodyParts.add('payment_intent_data[setup_future_usage]=off_session');
            }
            //bodyParts.add('invoice_creation[enabled]=true');
            // bodyParts.add('invoice_creation[invoice_data][metadata][salesforce_quote_id]=' + EncodingUtil.urlEncode(quote.Id, 'UTF-8'));
            // bodyParts.add('invoice_creation[invoice_data][metadata][subscription_source]=salesforce');

            Integer index = 0;
            for (SBQQ__QuoteLine__c item : quoteLineItems) {
                String priceId = (string) quoteLineToPriceIdMap.get(item.id);
                bodyParts.add('line_items[' + index + '][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8'));
                bodyParts.add('line_items[' + index + '][quantity]=' + String.valueOf(item.Quantity_For_Stripe__c));
                index++;
            }

            // Join body parts
            String requestBody = String.join(bodyParts, '&');
            System.debug('requestBody--' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/checkout/sessions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);

            Http httpChecout = new Http();
            HttpResponse res = httpChecout.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('results--' + results);
                String paymentLink = (String) results.get('url');
                String checkoutSessionID = (String) results.get('id');

                for (SBQQ__Quote__c qt : new List<SBQQ__Quote__c>{ quote }) {
                    qt.Stripe_Payment_Link__c = paymentLink;
                    qt.Stripe_Payment_Intent__c = checkoutSessionID;
                    updateQuoteList.add(qt);
                }
                update updateQuoteList;

                // Update Quote Lines with Stripe Price IDs
                List<SBQQ__QuoteLine__c> quoteLinesToUpdate = new List<SBQQ__QuoteLine__c>();
                for (Id qlId : quoteLineToPriceIdMap.keySet()) {
                    quoteLinesToUpdate.add(
                        new SBQQ__QuoteLine__c(Id = qlId, Stripe_Price_ID__c = quoteLineToPriceIdMap.get(qlId))
                    );
                }
                update quoteLinesToUpdate;

                flowRes.isSuccess = true;
                flowRes.message = 'Payment link generated successfully';
                return flowResults;
            } else {
                system.debug('results--' + res.getBody());
                throw new CalloutException('Stripe Checkout Session creation failed: ' + res.getBody());
            }
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Link Generate Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripePaymentLinkFromQuote',
                Apex_Method__c = 'generatePaymentLinkFromQuote',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;

            flowRes.isSuccess = false;
            flowRes.message = e.getMessage();
            return flowResults;
        }
    }
}