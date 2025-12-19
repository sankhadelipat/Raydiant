public class StripeCustomerQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    String stripeCustomerId;
    String raydiantSignupType;
    String eventType;

    public StripeCustomerQueueable(String stripeCustomerId, String raydiantSignupType, String eventType) {
        this.stripeCustomerId = stripeCustomerId;
        this.raydiantSignupType = raydiantSignupType;
        this.eventType = eventType;
    }

    public void execute(QueueableContext context) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://api.stripe.com/v1/customers/' + stripeCustomerId);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            HttpResponse res = http.send(request);

            if (res.getStatusCode() == 200) {
                Map<String, Object> customerData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                // Extract customer details from Stripe
                String stripeCustomerId = (String) customerData.get('id');
                String customerName = (String) customerData.get('name');
                String customerEmail = (String) customerData.get('email');
                String customerPhone = (String) customerData.get('phone');
                String currencyCode = (String) customerData.get('currency');
                String description = (String) customerData.get('description');
                Map<String, Object> billingAddress = (Map<String, Object>) customerData.get('address');
                Map<String, Object> shipping = (Map<String, Object>) customerData.get('shipping');
                Map<String, Object> shippingAddress = shipping != null
                    ? (Map<String, Object>) shipping.get('address')
                    : null;

                // Create Account in Salesforce
                Account acc = new Account(
                    Name = customerName != null ? customerName : 'Stripe Customer ' + stripeCustomerId,
                    Type = 'Customer',
                    Stripe_Customer_ID__c = stripeCustomerId,
                    Stripe_Customer_URL__c = 'https://dashboard.stripe.com/customers/' + stripeCustomerId,
                    Created_by_Stripe__c = raydiantSignupType == 'salesforce' ? false : true,
                    Raydiant_Signup_Type__c = raydiantSignupType,
                    Phone = customerPhone,
                    Dashboard_Email__c = customerEmail,
                    CurrencyIsoCode = currencyCode != null ? currencyCode.ToUpperCase() : 'USD',
                    Description = description,
                    BillingStreet = billingAddress != null ? (String) billingAddress.get('line1') : null,
                    BillingCity = billingAddress != null ? (String) billingAddress.get('city') : null,
                    BillingState = billingAddress != null ? (String) billingAddress.get('state') : null,
                    BillingPostalCode = billingAddress != null ? (String) billingAddress.get('postal_code') : null,
                    BillingCountry = billingAddress != null ? (String) billingAddress.get('country') : null,
                    ShippingStreet = shippingAddress != null ? (String) shippingAddress.get('line1') : null,
                    ShippingCity = shippingAddress != null ? (String) shippingAddress.get('city') : null,
                    ShippingState = shippingAddress != null ? (String) shippingAddress.get('state') : null,
                    ShippingPostalCode = shippingAddress != null ? (String) shippingAddress.get('postal_code') : null,
                    ShippingCountry = shippingAddress != null ? (String) shippingAddress.get('country') : null
                );

                StripeTriggerHandler.enableBypass('Account');
                upsert acc Stripe_Customer_ID__c;
                StripeTriggerHandler.disableBypass('Account');

                // Retrieve the Account to get additional fields
                acc = [
                    SELECT Id, blng__BillToContact__c, F52_Primary_Contact__c, Account_Record_URL__c, Account_Number__c
                    FROM Account
                    WHERE Id = :acc.Id
                ];

                Contact billToCon;

                List<Contact> accountContacts = [
                    SELECT Id
                    FROM Contact
                    WHERE Id = :acc.blng__BillToContact__c OR Id = :acc.F52_Primary_Contact__c
                    LIMIT 1
                ];

                if (!accountContacts.isEmpty()) {
                    billToCon = accountContacts[0];
                } else if (accountContacts.isEmpty() && customerEmail != null) {
                    List<Contact> contactsByEmail = [
                        SELECT Id
                        FROM Contact
                        WHERE Email = :customerEmail
                        LIMIT 1
                    ];
                    if (!contactsByEmail.isEmpty()) {
                        billToCon = contactsByEmail[0];
                    }
                }

                if (billToCon != null) {
                    // Update existing Contact in Salesforce
                    billToCon.AccountId = acc.Id;
                    // billToCon.FirstName = customerName != null ? customerName.split(' ')[0] : 'Stripe';
                    // billToCon.LastName = customerName != null &&
                    //     customerName.split(' ').size() > 1
                    //     ? customerName.substringAfter(' ')
                    //     : 'Customer ' + stripeCustomerId;
                    billToCon.Email = customerEmail;
                    billToCon.Phone = customerPhone;
                    // billToCon.MailingStreet = billingAddress != null ? (String) billingAddress.get('line1') : null;
                    // billToCon.MailingCity = billingAddress != null ? (String) billingAddress.get('city') : null;
                    // billToCon.MailingState = billingAddress != null ? (String) billingAddress.get('state') : null;
                    // billToCon.MailingPostalCode = billingAddress != null
                    //     ? (String) billingAddress.get('postal_code')
                    //     : null;
                    // billToCon.MailingCountry = billingAddress != null ? (String) billingAddress.get('country') : null;

                    update billToCon;
                    acc.blng__BillToContact__c = billToCon.Id;
                    acc.F52_Primary_Contact__c = billToCon.Id;
                } else if (billToCon == null && customerEmail != null) {
                    // Create Contact in Salesforce
                    billToCon = new Contact(
                        AccountId = acc.Id,
                        FirstName = customerName != null ? customerName.split(' ')[0] : 'Stripe',
                        LastName = customerName != null &&
                            customerName.split(' ').size() > 1
                            ? customerName.substringAfter(' ')
                            : 'Customer ' + stripeCustomerId,
                        Email = customerEmail,
                        Phone = customerPhone,
                        MailingStreet = billingAddress != null ? (String) billingAddress.get('line1') : null,
                        MailingCity = billingAddress != null ? (String) billingAddress.get('city') : null,
                        MailingState = billingAddress != null ? (String) billingAddress.get('state') : null,
                        MailingPostalCode = billingAddress != null ? (String) billingAddress.get('postal_code') : null,
                        MailingCountry = billingAddress != null ? (String) billingAddress.get('country') : null
                    );

                    insert billToCon;
                    acc.blng__BillToContact__c = billToCon.Id;
                    acc.F52_Primary_Contact__c = billToCon.Id;
                }

                // Retrieve Stripe Account record
                if (eventType == 'customer.created') {
                    stripeGC__Stripe_Account__c stripeOrgAccount = [
                        SELECT Id, Name
                        FROM stripeGC__Stripe_Account__c
                        LIMIT 1
                    ];

                    acc.Stripe_Org_Account__c = stripeOrgAccount.Id;
                }

                StripeTriggerHandler.enableBypass('Account');
                update acc;
                StripeTriggerHandler.disableBypass('Account');

                // Update Stripe metadata
                if (eventType == 'customer.created') {
                    StripeMetadataUpdater.updateStripeCustomerMetadata(
                        stripeCustomerId,
                        acc.Account_Record_URL__c,
                        acc.Id,
                        acc.Account_Number__c
                    );
                }

                /*// Flow inputs
                Map<String, Object> flowInputs = new Map<String, Object>{
                    'stripeCustomerId' => stripeCustomerId,
                    'accountRecordUrl' => acc.Account_URL__c,
                    'internalId' => acc.Id,
                    'accountNumber' => acc.Account_Number__c
                };
                System.debug('Flow Inputs: ' + flowInputs);
                
                Flow.Interview.Update_Stripe_Customer_Metadata updateStripeCustomerMetadata = new Flow.Interview.Update_Stripe_Customer_Metadata(flowInputs);
                updateStripeCustomerMetadata.start();*/
            } else {
                System.debug('Failed to retrieve customer data: ' + res.getBody());
                throw new CalloutException('Stripe callout failed: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error creating customer: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Customer Upsert Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeCustomerQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Account'
            );
            insert logger;
        }
    }
}