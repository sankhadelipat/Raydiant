/**
 * Quote To Cash || Subscription
 * Updates Stripe Subscription after first payment is done via Checkout Session
 * Quote To Cash - Collection Method => charge_automatically
 */
public class StripeCheckoutHandler implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private final String quoteId;
    private final String subscriptionId;

    public StripeCheckoutHandler(String quoteId, String subscriptionId) {
        this.quoteId = quoteId;
        this.subscriptionId = subscriptionId;
    }

    public void execute(QueueableContext context) {
        try {
            List<SBQQ__Quote__c> quoteList = [
                SELECT
                    Id,
                    SBQQ__StartDate__c,
                    SBQQ__Account__c,
                    Stripe_Customer_ID__c,
                    SBQQ__EndDate__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    Billing_Frequency_Override__c,
                    SBQQ__SubscriptionTerm__c,
                    CurrencyIsoCode
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1
            ];
            if (quoteList.isEmpty())
                return;

            SBQQ__Quote__c quote = quoteList[0];
            List<SBQQ__QuoteLine__c> quoteLines = [
                SELECT
                    Quantity_For_Stripe__c,
                    MRR__c,
                    SBQQ__Product__r.Name,
                    Billing_Frequency_Override__c,
                    CurrencyIsoCode
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quote.Id AND Stripe_Subscription_Type__c != 'One-time'
            ];

            // Prepare subscription body
            List<String> bodyParts = new List<String>();

            Date startDate = quote.SBQQ__StartDate__c;
            Datetime dt = Datetime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            Long unixTimestamp = dt.getTime() / 1000;
            System.debug('Unix Timestamp: ' + unixTimestamp);

            Date EndDate = startDate.addMonths(INTEGER.VALUEOF(quote.SBQQ__SubscriptionTerm__c)).addDays(-1);
            System.debug('EndDate--' + EndDate);
            Datetime EndDatedt = Datetime.newInstance(EndDate.year(), EndDate.month(), EndDate.day(), 0, 0, 0);
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
            Date dateOfNextSemiAnnual = Date.newInstance(
                startDate.addMonths(6).year(),
                startDate.addMonths(6).month(),
                startDate.addMonths(6).day()
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
                String freq = quote.Billing_Frequency_Override__c.toLowerCase();
                if (freq == 'Monthly') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNextMonth.year(),
                        dateOfNextMonth.month(),
                        dateOfNextMonth.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == 'Quarterly') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNextQuarter.year(),
                        dateOfNextQuarter.month(),
                        dateOfNextQuarter.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == 'Semiannual') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNextSemiAnnual.year(),
                        dateOfNextSemiAnnual.month(),
                        dateOfNextSemiAnnual.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == 'Annual') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNextYear.year(),
                        dateOfNextYear.month(),
                        dateOfNextYear.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == '2-Year') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNext2Year.year(),
                        dateOfNext2Year.month(),
                        dateOfNext2Year.day(),
                        0,
                        0,
                        0
                    );
                } else if (freq == '3-Year') {
                    billingAnchor = Datetime.newInstance(
                        dateOfNext3Year.year(),
                        dateOfNext3Year.month(),
                        dateOfNext3Year.day(),
                        0,
                        0,
                        0
                    );
                } else {
                    // Default to monthly
                    billingAnchor = Datetime.newInstance(
                        dateOfNextMonth.year(),
                        dateOfNextMonth.month(),
                        dateOfNextMonth.day(),
                        0,
                        0,
                        0
                    );
                }
            }

            // bodyParts.add('collection_method=charge_automatically');
            bodyParts.add('proration_behavior=always_invoice');
            bodyParts.add('cancel_at=' + String.valueOf(EndDateunixTimestamp));
            // bodyParts.add('billing_mode[type]=flexible');
            // bodyParts.add('backdate_start_date=' + String.valueOf(unixTimestamp));
            // bodyParts.add('billing_cycle_anchor=' + String.valueOf(billingAnchor.getTime() / 1000));

            String encodedBody = String.join(bodyParts, '&');

            HttpRequest subReq = new HttpRequest();
            subReq.setEndpoint('https://api.stripe.com/v1/subscriptions/' + subscriptionId);
            subReq.setMethod('POST');
            subReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            subReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            subReq.setBody(encodedBody);
            Http http = new Http();
            HttpResponse subRes = http.send(subReq);
            if (subRes.getStatusCode() == 200) {
                Map<String, Object> subResponse = (Map<String, Object>) JSON.deserializeUntyped(subRes.getBody());

                String subscriptionId = (String) subResponse.get('id');
                String invoiceId = (String) subResponse.get('latest_invoice');
                System.debug('Created Stripe Subscription ID: ' + subscriptionId);
                System.debug('Latest Invoice ID: ' + invoiceId);
            } else {
                System.debug('Stripe Subscription Error: ' + subRes.getBody());
                throw new CalloutException('Stripe Subscription Error: ' + subRes.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in StripeCheckoutHandler: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Checkout Handler Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeCheckoutHandler',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Contract'
            );
            insert logger;
        }
    }
}