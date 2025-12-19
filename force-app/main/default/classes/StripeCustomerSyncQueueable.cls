public class StripeCustomerSyncQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private String operation; // 'CREATE' or 'UPDATE'
    private Set<Id> accountIds;

    public StripeCustomerSyncQueueable(String op, Set<Id> ids) {
        this.operation = op;
        this.accountIds = ids;
    }

    public void execute(QueueableContext context) {
        List<Account> accountsToUpdate = new List<Account>();

        // Fetch accounts based on provided IDs
        List<Account> accountList = [
            SELECT
                Id,
                Name,
                Phone,
                Bill_To_Email__c,
                Bill_To_Contact_Phone__c,
                Stripe_Customer_ID__c,
                Stripe_Customer_URL__c,
                Account_Record_URL__c,
                Account_Number__c,
                Raydiant_Signup_Type__c,
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
            WHERE Id IN :accountIds
            ALL ROWS
        ];

        try {
            Http http = new Http();

            for (Account acc : accountList) {
                HttpRequest req = new HttpRequest();

                if (operation == 'CREATE' && acc.Stripe_Customer_ID__c == null) {
                    req.setEndpoint('https://api.stripe.com/v1/customers');
                    req.setMethod('POST');

                    Map<String, String> params = new Map<String, String>{
                        'name' => acc.Name,
                        'business_name' => acc.Name,
                        'email' => acc.Bill_To_Email__c,
                        'phone' => acc.Phone != null ? acc.Phone : acc.Bill_To_Contact_Phone__c,
                        'metadata[ID__c]' => acc.Id,
                        'metadata[raydiant_signup_type__c]' => 'salesforce'
                    };

                    if (acc.Account_Record_URL__c != null)
                        params.put('metadata[Account_Record_URL]', acc.Account_Record_URL__c);
                    if (acc.Account_Number__c != null)
                        params.put('metadata[AccountNum__c]', acc.Account_Number__c);

                    if (
                        acc.BillingStreet != null ||
                        acc.BillingCity != null ||
                        acc.BillingState != null ||
                        acc.BillingPostalCode != null ||
                        acc.BillingCountry != null
                    ) {
                        params.put('address[line1]', acc.BillingStreet);
                        params.put('address[city]', acc.BillingCity);
                        params.put('address[state]', acc.BillingState);
                        params.put('address[postal_code]', acc.BillingPostalCode);
                        params.put('address[country]', acc.BillingCountry);
                    }

                    if (
                        acc.ShippingStreet != null &&
                        acc.ShippingCity != null &&
                        acc.ShippingState != null &&
                        acc.ShippingPostalCode != null &&
                        acc.ShippingCountry != null
                    ) {
                        params.put('shipping[name]', acc.Name);
                        params.put('shipping[address][line1]', acc.ShippingStreet);
                        params.put('shipping[address][city]', acc.ShippingCity);
                        params.put('shipping[address][state]', acc.ShippingState);
                        params.put('shipping[address][postal_code]', acc.ShippingPostalCode);
                        params.put('shipping[address][country]', acc.ShippingCountry);
                    }

                    req.setBody(encodeParams(params));
                } else if (operation == 'UPDATE' && acc.Stripe_Customer_ID__c != null) {
                    req.setEndpoint('https://api.stripe.com/v1/customers/' + acc.Stripe_Customer_ID__c);
                    req.setMethod('POST');

                    Map<String, String> params = new Map<String, String>{
                        'name' => acc.Name,
                        'business_name' => acc.Name,
                        'email' => acc.Bill_To_Email__c,
                        'phone' => acc.Phone != null ? acc.Phone : acc.Bill_To_Contact_Phone__c
                    };

                    if (acc.Account_Record_URL__c != null)
                        params.put('metadata[Account_Record_URL]', acc.Account_Record_URL__c);
                    if (acc.Account_Number__c != null)
                        params.put('metadata[AccountNum__c]', acc.Account_Number__c);
                    if (acc.Raydiant_Signup_Type__c != null)
                        params.put('metadata[raydiant_signup_type__c]', acc.Raydiant_Signup_Type__c);

                    if (
                        acc.BillingStreet != null ||
                        acc.BillingCity != null ||
                        acc.BillingState != null ||
                        acc.BillingPostalCode != null ||
                        acc.BillingCountry != null
                    ) {
                        params.put('address[line1]', acc.BillingStreet);
                        params.put('address[city]', acc.BillingCity);
                        params.put('address[state]', acc.BillingState);
                        params.put('address[postal_code]', acc.BillingPostalCode);
                        params.put('address[country]', acc.BillingCountry);
                    }

                    if (
                        acc.ShippingStreet != null &&
                        acc.ShippingCity != null &&
                        acc.ShippingState != null &&
                        acc.ShippingPostalCode != null &&
                        acc.ShippingCountry != null
                    ) {
                        params.put('shipping[name]', acc.Name);
                        params.put('shipping[address][line1]', acc.ShippingStreet);
                        params.put('shipping[address][city]', acc.ShippingCity);
                        params.put('shipping[address][state]', acc.ShippingState);
                        params.put('shipping[address][postal_code]', acc.ShippingPostalCode);
                        params.put('shipping[address][country]', acc.ShippingCountry);
                    }

                    req.setBody(encodeParams(params));
                }
                // else if (operation == 'DELETE' && acc.Stripe_Customer_ID__c != null) {
                //     req.setEndpoint('https://api.stripe.com/v1/customers/' + acc.Stripe_Customer_ID__c);
                //     req.setMethod('DELETE');
                // }

                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    // Parse response to get Stripe Customer ID
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                    if (operation == 'CREATE') {
                        stripeGC__Stripe_Account__c stripeOrgAccount = [
                            SELECT Id, Name
                            FROM stripeGC__Stripe_Account__c
                            LIMIT 1
                        ];

                        String stripeCustomerId = (String) responseMap.get('id');

                        acc.Stripe_Customer_ID__c = stripeCustomerId;
                        acc.Stripe_Customer_URL__c = 'https://dashboard.stripe.com/customers/' + stripeCustomerId;
                        acc.Stripe_Org_Account__c = stripeOrgAccount.Id;

                        accountsToUpdate.add(acc);
                    }
                } else {
                    System.debug(
                        'Error during ' +
                            operation +
                            ' for Account ' +
                            acc.Id +
                            ': ' +
                            res.getStatusCode() +
                            ' - ' +
                            res.getBody()
                    );
                    throw new CalloutException('Stripe API call failed with status ' + res.getStatusCode());
                }
            }
        } catch (Exception e) {
            System.debug('Exception occurred: ' + e.getMessage());

            Logger__c logger = new Logger__c(
                Name = 'Stripe Customer Sync Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeCustomerSyncQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Account'
            );
            insert logger;
        } finally {
            StripeTriggerHandler.enableBypass('Account');
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
            StripeTriggerHandler.disableBypass('Account');
        }
    }

    private static String encodeParams(Map<String, String> params) {
        List<String> encodedParams = new List<String>();
        for (String key : params.keySet()) {
            if (params.get(key) != null) {
                encodedParams.add(
                    EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8')
                );
            }
        }
        return String.join(encodedParams, '&');
    }
}