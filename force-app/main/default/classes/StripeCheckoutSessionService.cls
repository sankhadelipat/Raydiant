public class StripeCheckoutSessionService implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private String sessionId;

    public StripeCheckoutSessionService(String sessionId) {
        this.sessionId = sessionId;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/checkout/sessions/' + sessionId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Deserialize the JSON response
                Map<String, Object> sessionObj = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('sessionObj: ' + json.serializePretty(sessionObj));

                String checkoutSessionId = (String) sessionObj.get('id');
                String customerId = (String) sessionObj.get('customer');

                // 1. Get Customer & Quote
                Account account;
                SBQQ__Quote__c quote;

                List<Account> accounts = [
                    SELECT
                        Id,
                        Stripe_Customer_ID__c,
                        BillingStreet,
                        BillingCity,
                        BillingState,
                        BillingPostalCode,
                        BillingCountry,
                        ShippingStreet,
                        ShippingCity,
                        ShippingState,
                        ShippingPostalCode,
                        ShippingCountry
                    FROM Account
                    WHERE Stripe_Customer_ID__c = :customerId
                ];

                if (accounts.isEmpty()) {
                    throw new HandledException('Customer not found for Stripe Customer ID: ' + customerId);
                } else {
                    account = accounts[0];
                }

                List<SBQQ__Quote__c> quotes = [
                    SELECT
                        Id,
                        Stripe_Checkout_Session_ID__c,
                        Shipping_Street__c,
                        SBQQ__BillingStreet__c,
                        SBQQ__BillingCity__c,
                        SBQQ__BillingState__c,
                        SBQQ__BillingPostalCode__c,
                        SBQQ__BillingCountry__c,
                        SBQQ__ShippingStreet__c,
                        SBQQ__ShippingCity__c,
                        SBQQ__ShippingState__c,
                        SBQQ__ShippingPostalCode__c,
                        SBQQ__ShippingCountry__c
                    FROM SBQQ__Quote__c
                    WHERE Stripe_Checkout_Session_ID__c = :checkoutSessionId
                ];

                if (quotes.isEmpty()) {
                    throw new HandledException('Quote not found for Stripe Checkout Session ID: ' + checkoutSessionId);
                } else {
                    quote = quotes[0];
                }

                // 2. Extract Billing Address from customer_details
                Map<String, Object> billingAddress = new Map<String, Object>();
                Map<String, Object> customerDetails = (Map<String, Object>) sessionObj.get('customer_details');

                if (customerDetails != null) {
                    Map<String, Object> address = (Map<String, Object>) customerDetails.get('address');
                    if (address != null) {
                        billingAddress.put('line1', address.get('line1'));
                        billingAddress.put('line2', address.get('line2'));
                        billingAddress.put('city', address.get('city'));
                        billingAddress.put('state', address.get('state'));
                        billingAddress.put('postal_code', address.get('postal_code'));
                        billingAddress.put('country', address.get('country'));
                    }
                }

                // 3. Extract Shipping Address from collected_information
                Map<String, Object> shippingAddress = new Map<String, Object>();
                Map<String, Object> collectedInfo = (Map<String, Object>) sessionObj.get('collected_information');

                if (collectedInfo != null) {
                    Map<String, Object> shippingDetails = (Map<String, Object>) collectedInfo.get('shipping_details');
                    if (shippingDetails != null) {
                        Map<String, Object> address = (Map<String, Object>) shippingDetails.get('address');
                        if (address != null) {
                            shippingAddress.put('line1', address.get('line1'));
                            shippingAddress.put('line2', address.get('line2'));
                            shippingAddress.put('city', address.get('city'));
                            shippingAddress.put('state', address.get('state'));
                            shippingAddress.put('postal_code', address.get('postal_code'));
                            shippingAddress.put('country', address.get('country'));
                        }
                    }
                }

                // Print the extracted values for verification
                System.debug('Billing Address: ' + billingAddress);
                System.debug('Shipping Address: ' + shippingAddress);

                // 4. Update Account record
                account.BillingStreet = (String) billingAddress.get('line1');
                account.BillingCity = (String) billingAddress.get('city');
                account.BillingState = (String) billingAddress.get('state');
                account.BillingPostalCode = (String) billingAddress.get('postal_code');
                account.BillingCountry = (String) billingAddress.get('country');

                account.ShippingStreet = (String) shippingAddress.get('line1');
                account.ShippingCity = (String) shippingAddress.get('city');
                account.ShippingState = (String) shippingAddress.get('state');
                account.ShippingPostalCode = (String) shippingAddress.get('postal_code');
                account.ShippingCountry = (String) shippingAddress.get('country');

                // 5. Update Quote record
                quote.SBQQ__BillingStreet__c = (String) billingAddress.get('line1');
                quote.SBQQ__BillingCity__c = (String) billingAddress.get('city');
                quote.SBQQ__BillingState__c = (String) billingAddress.get('state');
                quote.SBQQ__BillingPostalCode__c = (String) billingAddress.get('postal_code');
                quote.SBQQ__BillingCountry__c = (String) billingAddress.get('country');

                quote.Shipping_Street__c = (String) shippingAddress.get('line1');
                quote.SBQQ__ShippingStreet__c = (String) shippingAddress.get('line1');
                quote.SBQQ__ShippingCity__c = (String) shippingAddress.get('city');
                quote.SBQQ__ShippingState__c = (String) shippingAddress.get('state');
                quote.SBQQ__ShippingPostalCode__c = (String) shippingAddress.get('postal_code');
                quote.SBQQ__ShippingCountry__c = (String) shippingAddress.get('country');

                update account;
                update quote;

                // update new List<SObject>{ account, quote };
            } else {
                System.debug('Stripe error: ' + res.getStatus() + ' - ' + res.getBody());
                throw new CalloutException('Failed to fetch session. Status: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('Error in StripeCheckoutSessionService: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Checkout Session Service Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'error',
                Apex_Class__c = 'StripeCheckoutSessionService',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Account'
            );
            insert logger;
        }
    }
}