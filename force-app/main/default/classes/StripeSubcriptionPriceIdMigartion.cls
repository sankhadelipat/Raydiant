public class StripeSubcriptionPriceIdMigartion implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT
                    SBQQ__SubscriptionType__c,
                    Id,
                    SBQQ__StartDate__c,
                    SBQQ__EndDate__c,
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
                    CurrencyIsoCode,
                    SBQQ__Contract__c,
                    Next_Billing_Date__c,
                    Stripe_Subscription_Migration__c
                FROM SBQQ__Subscription__c
                WHERE
                    F52_Active__c = TRUE
                    AND SBQQ__Product__r.Stripe_Product_ID__c != NULL
                    AND SBQQ__Contract__r.Is_Migrating__c = TRUE
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> scope) {
        List<SBQQ__Subscription__c> subsToUpdate = new List<SBQQ__Subscription__c>();

        Map<String, List<Object>> freqMap = new Map<String, List<Object>>{
            'Monthly' => new List<Object>{ 'month', 1 },
            'Quarterly' => new List<Object>{ 'month', 3 },
            'Annual' => new List<Object>{ 'year', 1 },
            '2-Year' => new List<Object>{ 'year', 2 },
            '3-Year' => new List<Object>{ 'year', 3 }
        };

        try {
            for (SBQQ__Subscription__c sub : scope) {
                String freq = (sub.Order_Line_Billing_Freq__c != null) ? sub.Order_Line_Billing_Freq__c : 'Monthly';

                List<Object> freqData = freqMap.containsKey(freq) ? freqMap.get(freq) : freqMap.get('Monthly');
                String interval = (String) freqData[0];
                Integer intervalCount = (Integer) freqData[1];

                Decimal unitPrice = (sub.SBQQ__NetPrice__c != null &&
                    sub.SBQQ__NetPrice__c != 0)
                    ? sub.SBQQ__NetPrice__c
                    : 0;

                // Convert to cents
                Decimal multiplier = (interval == 'month' &&
                    intervalCount == 3)
                    ? 3
                    : (interval == 'year') ? (12 * intervalCount) : 1;

                Decimal unitAmount = unitPrice.setScale(2) * multiplier * 100; // need to chc

                // Build Price request
                List<String> bodyParts = new List<String>{
                    'billing_scheme=per_unit',
                    'currency=' + sub.CurrencyIsoCode,
                    'product=' + sub.SBQQ__Product__r.Stripe_Product_ID__c,
                    'unit_amount_decimal=' + unitAmount,
                    'recurring[interval]=' + interval,
                    'recurring[interval_count]=' + intervalCount
                };

                Http http = new Http();
                HttpRequest priceReq = new HttpRequest();
                priceReq.setEndpoint('https://api.stripe.com/v1/prices');
                priceReq.setMethod('POST');
                priceReq.setHeader(
                    'Authorization',
                    'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                );
                priceReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                priceReq.setBody(String.join(bodyParts, '&'));

                HttpResponse priceRes = http.send(priceReq);

                if (priceRes.getStatusCode() == 200) {
                    Map<String, Object> priceResponse = (Map<String, Object>) JSON.deserializeUntyped(
                        priceRes.getBody()
                    );
                    String priceId = (String) priceResponse.get('id');
                    sub.Stripe_Price_ID__c = priceId;
                    // sub.Stripe_Subscription_Migration__c = false;
                    subsToUpdate.add(sub);
                } else {
                    System.debug(
                        'Stripe Price creation failed for Sub Id: ' + sub.Id + ' Response: ' + priceRes.getBody()
                    );
                }
            }

            if (!subsToUpdate.isEmpty()) {
                update subsToUpdate;
            }
        } catch (Exception ex) {
            System.debug('Error in batch execution: ' + ex.getMessage());
            insert new Logger__c(
                Name = 'Stripe Subscription Update Error',
                Message__c = ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeSubcriptionPriceIdMigartion',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Subscription'
            );
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Stripe Subscription Price ID Migration completed.');
        // Next phase batch can be called here if required
    }
}