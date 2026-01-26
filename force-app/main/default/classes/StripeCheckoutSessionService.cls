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

                // 1. Extract Billing Address from customer_details
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

                // 2. Extract Shipping Address from collected_information
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

                // 3. Extract Consent Accepted
                Boolean consentAccepted = false;
                String termsofservice;
                Map<String, Object> consent = (Map<String, Object>) sessionObj.get('consent');
                if (consent != null && consent.get('terms_of_service') == 'accepted') {
                    termsofservice = (string) consent.get('terms_of_service');
                    consentAccepted = true;
                }

                // 4. Extract Signature from custom_fields
                String signature = null;
                List<Object> customFields = (List<Object>) sessionObj.get('custom_fields');
                if (customFields != null) {
                    for (Object fieldObj : customFields) {
                        Map<String, Object> field = (Map<String, Object>) fieldObj;
                        if (field.get('key') == 'signature') {
                            Map<String, Object> text = (Map<String, Object>) field.get('text');
                            if (text != null) {
                                signature = (String) text.get('value');
                            }
                            break;
                        }
                    }
                }
                // Print the extracted values for verification
                System.debug('Billing Address: ' + billingAddress);
                System.debug('Shipping Address: ' + shippingAddress);
                System.debug('Consent Accepted: ' + consentAccepted);
                System.debug('Signature: ' + signature);

                // 5. Extract Customer ID
                String customerId = (String) sessionObj.get('customer');
                System.debug('Customer ID: ' + customerId);
                List<Account> upsertaccList = new List<Account>();
                List<Account> accList = [
                    SELECT
                        id,
                        Stripe_Customer_ID__c,
                        BillingStreet,
                        BillingCity,
                        BillingState,
                        BillingPostalCode,
                        BillingCountry,
                        BillingLatitude,
                        BillingLongitude,
                        BillingGeocodeAccuracy,
                        BillingAddress,
                        ShippingStreet,
                        ShippingCity,
                        ShippingState,
                        ShippingPostalCode,
                        ShippingCountry,
                        ShippingLatitude,
                        ShippingLongitude,
                        ShippingGeocodeAccuracy,
                        ShippingAddress
                    FROM Account
                    WHERE Stripe_Customer_ID__c = :customerId
                ];
                for (Account Acc : accList) {
                    acc.BillingStreet = (String) billingAddress.get('line1');
                    acc.BillingCity = (String) billingAddress.get('city');
                    acc.BillingState = (String) billingAddress.get('state');
                    acc.BillingPostalCode = (String) billingAddress.get('postalCode');
                    acc.BillingCountry = (String) billingAddress.get('country');

                    acc.ShippingStreet = (String) shippingAddress.get('line1');
                    acc.ShippingCity = (String) shippingAddress.get('city');
                    acc.ShippingState = (String) shippingAddress.get('state');
                    acc.ShippingPostalCode = (String) shippingAddress.get('postalCode');
                    acc.ShippingCountry = (String) shippingAddress.get('country');

                    acc.Stripe_Consent_Accepted__c = termsofservice;
                    acc.Stripe_Signature__c = signature;
                    upsertaccList.Add(acc);
                }
                upsert upsertaccList Account.Stripe_Customer_ID__c;
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