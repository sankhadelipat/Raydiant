public without sharing class StripeCheckoutController {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;
    private static final String PUB_KEY = stripeDetails.Publishable_Key__c;

    public static String sessionId { get; private set; }
    public static String status { get; private set; }
    public static String publishableKey { get; private set; }
    public static String clientSecret { get; set; }
    public static String ipAddress { get; private set; }
    public static String userAgent { get; private set; }
    public static QuoteDTO quoteData { get; private set; }
    public static List<QuoteLineDTO> quoteLinesData { get; private set; }
    public static String interval { get; private set; }
    public static Integer recurringItemCount { get; private set; }
    public static Decimal recurringAmount { get; private set; }
    public static Integer oneTimeItemCount { get; private set; }
    public static Decimal oneTimeAmount { get; private set; }
    public static String subscriptionHeadline { get; private set; }

    public class QuoteDTO {
        public Id id { get; private set; }
        public String quoteNumber { get; private set; }
        public Date startDate { get; private set; }
        public Date expiryDate { get; private set; }
        public Decimal mrr { get; private set; }
        public Decimal subscriptionMrr { get; private set; }
        public Decimal netAmount { get; private set; }
        public Id accountId { get; private set; }
        public Id billToContactId { get; private set; }
        public Decimal subscriptionTerm { get; private set; }
        public String billingFrequencyOverride { get; private set; }
        public String accountStripeCustomerId { get; private set; }
        public String accountBillToEmail { get; private set; }
        public String salesRepName { get; private set; }
        public String CurrencyIsoCode { get; private set; }

        public QuoteDTO(SBQQ__Quote__c quote) {
            id = quote.Id;
            quoteNumber = quote.Name;
            startDate = quote.SBQQ__StartDate__c;
            expiryDate = quote.SBQQ__ExpirationDate__c;

            mrr = quote.MRR__c;
            subscriptionMrr = quote.Subscription_MRR__c;
            netAmount = quote.SBQQ__NetAmount__c;
            accountId = quote.SBQQ__Account__c;
            billToContactId = quote.Bill_To_Contact__c;
            subscriptionTerm = quote.SBQQ__SubscriptionTerm__c;
            billingFrequencyOverride = quote.Billing_Frequency_Override__c;
            accountStripeCustomerId = quote.SBQQ__Account__r.Stripe_Customer_ID__c;
            accountBillToEmail = quote.SBQQ__Account__r.Bill_To_Email__c;
            salesRepName = quote.Owner.Name;
            CurrencyIsoCode = quote.CurrencyIsoCode;
        }
    }

    public class QuoteLineDTO {
        public Id id { get; private set; }
        public String stripeSubscriptionType { get; private set; }
        public Id quoteId { get; private set; }
        public String productName { get; private set; }
        public String productDescription { get; private set; }
        public String billingType { get; private set; }
        public Decimal mrr { get; private set; }
        public String billingFrequencyOverride { get; private set; }
        public String billingFrequency { get; private set; }
        public String chargeType { get; private set; }
        public Decimal monthlyTotal { get; private set; }
        public Decimal quantity { get; private set; }
        public Decimal listPrice { get; private set; }
        public Decimal netTotal { get; private set; }
        public Decimal stripeQuantity { get; private set; }
        public Decimal customerPrice { get; private set; }
        public String stripeProductId { get; private set; }
        public String stripePriceId { get; private set; }
        public String productSubscriptionType { get; private set; }
        public String CurrencyIsoCode { get; private set; }

        public QuoteLineDTO(SBQQ__QuoteLine__c quoteLine) {
            id = quoteLine.Id;
            stripeSubscriptionType = quoteLine.Stripe_Subscription_Type__c;
            quoteId = quoteLine.SBQQ__Quote__c;
            productName = quoteLine.SBQQ__ProductName__c;
            productDescription = quoteLine.SBQQ__Description__c;
            billingType = quoteLine.SBQQ__BillingType__c;
            mrr = quoteLine.MRR__c;
            billingFrequencyOverride = quoteLine.Billing_Frequency_Override__c;
            billingFrequency = quoteLine.SBQQ__BillingFrequency__c;
            chargeType = quoteLine.SBQQ__ChargeType__c;
            monthlyTotal = quoteLine.Monthly_Total__c;
            quantity = quoteLine.SBQQ__Quantity__c;
            listPrice = quoteLine.SBQQ__ListPrice__c;
            netTotal = quoteLine.SBQQ__NetTotal__c;
            stripeQuantity = quoteLine.Quantity_For_Stripe__c;
            customerPrice = quoteLine.SBQQ__CustomerPrice__c;
            stripeProductId = quoteLine.SBQQ__Product__r.Stripe_Product_Id__c;
            stripePriceId = quoteLine.SBQQ__Product__r.Stripe_Price_ID__c;
            productSubscriptionType = quoteLine.SBQQ__Product__r.SBQQ__SubscriptionType__c;
            CurrencyIsoCode = quoteLine.CurrencyIsoCode;
        }
    }

    public StripeCheckoutController() {
        // Initialize publishable key
        publishableKey = PUB_KEY;
        ipAddress = ApexPages.currentPage().getHeaders().get('X-Salesforce-SIP') ??
            ApexPages.currentPage().getHeaders().get('X-Forwarded-For');
        userAgent = ApexPages.currentPage().getHeaders().get('User-Agent');
        sessionId = ApexPages.currentPage().getParameters().get('session');
        clientSecret = ApexPages.currentPage().getParameters().get('client');

        if (sessionId == null && clientSecret == null) {
            throw new IllegalArgumentException('Session is required');
        }

        status = getCheckoutSessionStatus(sessionId);
        loadQuoteData();
    }

    private void loadQuoteData() {
        SBQQ__Quote__c quote = [
            SELECT
                Id,
                Name,
                SBQQ__StartDate__c,
                SBQQ__ExpirationDate__c,
                MRR__c,
                Subscription_MRR__c,
                SBQQ__NetAmount__c,
                SBQQ__Account__c,
                Bill_To_Contact__c,
                SBQQ__SubscriptionTerm__c,
                Billing_Frequency_Override__c,
                SBQQ__Account__r.Stripe_Customer_ID__c,
                SBQQ__Account__r.Bill_To_Email__c,
                Owner.Name,
                CurrencyIsoCode
            FROM SBQQ__Quote__c
            WHERE Stripe_Checkout_Session_ID__c = :sessionId
            LIMIT 1
        ];
        System.debug('quote--' + quote);

        quoteData = new QuoteDTO(quote);
        System.debug('quoteData--' + quoteData);

        List<SBQQ__QuoteLine__c> quoteLineItems = [
            SELECT
                Id,
                Stripe_Subscription_Type__c,
                SBQQ__Quote__c,
                SBQQ__ProductName__c,
                SBQQ__Description__c,
                SBQQ__BillingType__c,
                MRR__c,
                Billing_Frequency_Override__c,
                SBQQ__BillingFrequency__c,
                SBQQ__ChargeType__c,
                Monthly_Total__c,
                SBQQ__Quantity__c,
                SBQQ__ListPrice__c,
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

        recurringItemCount = 0;
        oneTimeItemCount = 0;
        recurringAmount = 0;
        oneTimeAmount = 0;
        quoteLinesData = new List<QuoteLineDTO>();

        for (SBQQ__QuoteLine__c ql : quoteLineItems) {
            if (ql.SBQQ__ChargeType__c == 'Recurring') {
                recurringItemCount++;
                recurringAmount += ql.MRR__c != null ? ql.MRR__c : 0;
            } else {
                oneTimeItemCount++;
                oneTimeAmount += ql.SBQQ__NetTotal__c != null ? ql.SBQQ__NetTotal__c : 0;
            }
            quoteLinesData.add(new QuoteLineDTO(ql));
        }

        List<String> recurringProductNames = new List<String>();

        for (SBQQ__QuoteLine__c ql : quoteLineItems) {
            if (ql.SBQQ__ChargeType__c == 'Recurring') {
                recurringProductNames.add(ql.SBQQ__ProductName__c);
            }
        }

        if (!recurringProductNames.isEmpty()) {
            if (recurringProductNames.size() == 1) {
                subscriptionHeadline = 'Subscribe to ' + recurringProductNames[0];
            } else {
                subscriptionHeadline =
                    'Subscribe to ' +
                    recurringProductNames[0] +
                    ' + ' +
                    String.valueOf(recurringProductNames.size() - 1) +
                    ' more';
            }
        } else {
            subscriptionHeadline = 'Complete your purchase';
        }

        switch on quote.Billing_Frequency_Override__c {
            when null {
                interval = null;
            }
            when 'Monthly' {
                interval = 'month';
            }
            when 'Quarterly' {
                interval = 'quarter';
            }
            when 'Annual' {
                interval = 'year';
            }
            when else {
                interval = quote.Billing_Frequency_Override__c != null
                    ? quote.Billing_Frequency_Override__c.toLowerCase()
                    : 'month';
            }
        }
    }

    private String getCheckoutSessionStatus(String sessionId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.stripe.com/v1/checkout/sessions/' + sessionId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) body.get('status');
        } else {
            return 'expired';
        }
    }

    @RemoteAction
    public static void handleCheckoutCompletion(String quoteId, String signature, String ipAddress, String userAgent) {
        try {
            System.debug('Signature: ' + signature);
            System.debug('IP Address: ' + ipAddress);
            System.debug('User Agent: ' + userAgent);

            // Update Quote with signature and metadata
            SBQQ__Quote__c qt = new SBQQ__Quote__c(
                Id = quoteId,
                Digital_Signature__c = signature,
                Signature_Timestamp__c = Datetime.now(),
                Signature_IP_Address__c = ipAddress,
                Signature_User_Agent__c = userAgent
            );

            update qt;
        } catch (Exception e) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Checkout Completion Handling Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeCheckoutController',
                Apex_Method__c = 'handleCheckoutCompletion',
                Object_Name__c = 'SBQQ__Quote__c'
            );
            insert logger;
        }
    }
}
