@RestResource(urlMapping='/stripe/web-hook')
global without sharing class StripeWebHook {
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBody = req.requestBody.toString();
        Map<String, Object> event = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

        system.debug('event--' + event);
        String eventType = (String) event.get('type');
        system.debug('event Type--' + eventType);
        // quote to cash With Subscrition
        if (eventType.equals('checkout.session.completed')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            system.debug('data--' + data);

            Map<String, Object> sessionObj = (Map<String, Object>) data.get('object');
            system.debug('sessionObj--' + sessionObj);
            // Extract values from the session object
            String checkoutSessionId = (String) sessionObj.get('id');
            String invoiceId = (String) sessionObj.get('invoice');
            String subscriptionId = (String) sessionObj.get('subscription');

            // Metadata is nested
            Map<String, Object> metadata = (Map<String, Object>) sessionObj.get('metadata');
            String quoteId = metadata != null ? (String) metadata.get('salesforce_quote_id') : null;

            System.debug('Checkout Session Id: ' + checkoutSessionId);
            System.debug('Invoice Id: ' + invoiceId);
            System.debug('Subscription Id: ' + subscriptionId);
            System.debug('Quote Id from Metadata: ' + quoteId);

            // Example — publish platform event or save to custom object
            List<Stripe_Capture_Payment__e> stripePaymentList = new List<Stripe_Capture_Payment__e>();
            Stripe_Capture_Payment__e stripePayment = new Stripe_Capture_Payment__e();
            stripePayment.Payment_Capture__c = true;
            stripePayment.Invoice_Capture__c = false;
            stripePayment.CheckoutSessionId__c = checkoutSessionId;
            stripePayment.StripeInvoiceId__c = invoiceId;
            stripePayment.Stripe_Subscription_ID__c = subscriptionId;
            stripePayment.Quote_Id_From_Stripe__c = quoteId;
            stripePaymentList.add(stripePayment);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            System.debug('Publish results: ' + results);
        } else if (eventType.equals('invoice.created') || eventType.equals('invoice.updated')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            system.debug('data--' + data);
            Map<String, Object> stripeInvoice = (Map<String, Object>) data.get('object');
            Map<String, Object> parent = (Map<String, Object>) stripeInvoice.get('parent');
            Map<String, Object> subscriptionDetails = parent != null
                ? (Map<String, Object>) parent.get('subscription_details')
                : null;
            String subscriptionId = subscriptionDetails != null
                ? (String) subscriptionDetails.get('subscription')
                : null;
            Map<String, Object> metadata = (Map<String, Object>) stripeInvoice.get('metadata');
            String parentQuoteId = metadata.get('salesforce_quote_id') != null
                ? (String) metadata.get('salesforce_quote_id')
                : null;
            Map<String, Object> parentMetadata = subscriptionDetails != null
                ? (Map<String, Object>) subscriptionDetails.get('metadata')
                : null;
            if (parentQuoteId == null) {
                parentQuoteId = parentMetadata != null
                    ? (String) (parentMetadata.get('salesforce_quote_id') != null
                          ? parentMetadata.get('salesforce_quote_id')
                          : parentMetadata.get('salesforce_Quote_id'))
                    : null;
            }
            String stripeInvoiceId = (String) stripeInvoice.get('id');
            system.debug('invoice----' + stripeInvoiceId);

            List<Stripe_Capture_Invoice__e> stripeInvoiceList = new List<Stripe_Capture_Invoice__e>();

            Stripe_Capture_Invoice__e stripeInv = new Stripe_Capture_Invoice__e();
            stripeInv.Stripe_Subscription_ID__c = subscriptionId;
            stripeInv.Stripe_Invoice_ID__c = stripeInvoiceId;
            stripeInv.Quote_ID_From_Stripe__c = parentQuoteId;
            stripeInvoiceList.add(stripeInv);

            Database.SaveResult[] results = EventBus.publish(stripeInvoiceList);
            system.debug('results--' + results);
        } else if (eventType.equals('invoice.paid')) {
            Map<String, Object> data1 = (Map<String, Object>) event.get('data');
            system.debug('data1--' + data1);
            Map<String, Object> stripeInvoice = (Map<String, Object>) data1.get('object');
            Map<String, Object> parent = (Map<String, Object>) stripeInvoice.get('parent');
            Map<String, Object> subscriptionDetails = parent != null
                ? (Map<String, Object>) parent.get('subscription_details')
                : null;
            String subscriptionId = subscriptionDetails != null
                ? (String) subscriptionDetails.get('subscription')
                : null;
            Map<String, Object> metadata = (Map<String, Object>) stripeInvoice.get('metadata');
            string stripeInvoiceId2 = (String) stripeInvoice.get('id');
            system.debug('invoice----' + stripeInvoiceId2);
            String billingReason = (String) stripeInvoice.get('billing_reason');
            system.debug('invoice billingReason----' + billingReason);
            string stripepaymentintentID = (String) stripeInvoice.get('payment_intent');
            Boolean isInitialPayment = metadata.get('salesforce_initial_payment') != null
                ? Boolean.valueOf((String) metadata.get('salesforce_initial_payment'))
                : false;
            String parenttQuoteId = metadata.get('salesforce_quote_id') != null
                ? (String) metadata.get('salesforce_quote_id')
                : null;
            Boolean quoteAccepted = metadata.get('salesforce_quote_accepted') != null
                ? Boolean.valueOf((String) metadata.get('salesforce_quote_accepted'))
                : false;
            Map<String, Object> parentMetadata = subscriptionDetails != null
                ? (Map<String, Object>) subscriptionDetails.get('metadata')
                : null;
            if (parenttQuoteId == null) {
                parenttQuoteId = parentMetadata != null
                    ? (String) (parentMetadata.get('salesforce_quote_id') != null
                          ? parentMetadata.get('salesforce_quote_id')
                          : parentMetadata.get('salesforce_Quote_id'))
                    : null;
            }

            System.debug('parenttQuoteId--' + parenttQuoteId);
            System.debug('Stripe Subscription ID: ' + subscriptionId);

            // for 1st transaction billingReason = 'subscription_create'
            // Quote to Cash with Subscription
            if (billingReason != 'subscription_create') {
                List<Stripe_Capture_Payment__e> stripePaymentList = new List<Stripe_Capture_Payment__e>();

                Stripe_Capture_Payment__e stripePayment = new Stripe_Capture_Payment__e();
                stripePayment.Payment_Capture__c = false;
                stripePayment.Invoice_Capture__c = true;
                stripePayment.Stripe_Subscription_ID__c = subscriptionId;
                stripePayment.StripeInvoiceId__c = stripeInvoiceId2;
                stripePayment.stripepaymentintent_ID__c = stripepaymentintentID;
                stripePayment.Quote_Id_From_Stripe__c = parenttQuoteId;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            }
            // for 2nd transaction  get subscription id  use that on contract
            // When Invoice Paid from 2nd Time payment for subscription
            // Quote to Invoice
            else if (!string.isBlank(parenttQuoteId) && quoteAccepted) {
                List<Stripe_Capture_Payment__e> stripePaymentList = new List<Stripe_Capture_Payment__e>();

                Stripe_Capture_Payment__e stripePayment = new Stripe_Capture_Payment__e();
                Stripe_Capture_Payment__e stripePaymentinv = new Stripe_Capture_Payment__e();
                stripePaymentinv.Payment_Capture__c = false;
                stripePaymentinv.Invoice_Capture__c = true;
                stripePaymentinv.Stripe_Subscription_ID__c = subscriptionId;
                stripePaymentinv.StripeInvoiceId__c = stripeInvoiceId2;
                stripePaymentinv.stripepaymentintent_ID__c = stripepaymentintentID;
                stripePaymentinv.Quote_Id_From_Stripe__c = parenttQuoteId;
                stripePaymentList.add(stripePaymentinv);
                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('customer.subscription.created')) {
            Map<String, Object> outerMap = (Map<String, Object>) event.get('data');
            Map<String, Object> subscriptionObj = (Map<String, Object>) outerMap.get('object');

            String subscriptionId = (String) subscriptionObj.get('id');
            String invoiceid = (String) subscriptionObj.get('latest_invoice');
            String customerId = (String) subscriptionObj.get('customer');

            // Capture Metadata -> salesforce_quote_id
            Map<String, Object> metadata = (Map<String, Object>) subscriptionObj.get('metadata');
            String quoteId = (String) metadata.get('salesforce_quote_id');
            String subscriptionSource = metadata != null &&
                metadata.containsKey('subscription_source') &&
                metadata.get('subscription_source') != null
                ? String.valueOf(metadata.get('subscription_source'))
                : null;
            Boolean subscriptionSchedule = metadata.get('subscription_schedule') != null
                ? Boolean.valueOf((String) metadata.get('subscription_schedule'))
                : false;

            // Debug
            System.debug('Subscription Id: ' + subscriptionId);
            System.debug('Invoice Id: ' + invoiceId);
            System.debug('Quote Id: ' + quoteId);

            if (subscriptionSchedule == true && quoteId != null && subscriptionId != null) {
                //fire  StripeWebhookSubscriptionConsumer  event & call this StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe
                // it will upsert new Contarct & Subscription . For Invoice creation call another QueableClass StripeInvoiceScheduler.5/09

                // Publish subscription event then Event called  StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe
                // method then this  StripeSubscriptionScheduler.createStripeSubscription. For Invoice creation StripeInviceSchedular Queueable class
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Salesforce_Quote_Id__c = quoteId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Subscription_Schedule__c = subscriptionSchedule;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                //turned offdue to subscription Migration
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == 'amazon' ||
                subscriptionSource == 'self_service') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription creation from self-service portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Subscription_Schedule__c = false;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                // turned offdue to subscription Migration
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == null ||
                subscriptionSource != 'salesforce') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription maqnually created from stripe portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = 'stripe';
                stripePayment.Subscription_Schedule__c = false;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                // turned offdue to subscription Migration
                system.debug('results--' + results);
            }
        } else if (eventType.equals('customer.subscription.updated')) {
            Map<String, Object> data1 = (Map<String, Object>) event.get('data');
            system.debug(' data1 -- ' + data1);
            Map<String, Object> data2 = (Map<String, Object>) data1.get('object');
            System.debug('data2 -- ' + JSON.serializePretty(data2));
            String responseBody = JSON.serialize(data2);
            system.debug('response body -- ' + responseBody);
            String subscriptionId = (String) data2.get('id');
            Map<String, Object> metadata = (Map<String, Object>) data2.get('metadata');
            system.debug('metadata -- ' + metadata);
            String quoteId = (String) metadata.get('salesforce_quote_id');
            system.debug('quoteIdStr -- ' + quoteId);
            String manualUpdateFromSF = (metadata != null &&
                metadata.containsKey('last_updated_from_Salesforce') &&
                metadata.get('last_updated_from_Salesforce') != null)
                ? String.valueOf(metadata.get('last_updated_from_Salesforce'))
                : null;
            String subscriptionSource = metadata != null &&
                metadata.containsKey('subscription_source') &&
                metadata.get('subscription_source') != null
                ? String.valueOf(metadata.get('subscription_source'))
                : null;

            System.debug('manualUpdateFromSF -- ' + manualUpdateFromSF);
            System.debug('subscriptionSource -- ' + subscriptionSource);

            // Check if the id is matching with the previous_attributes & the current items
            // if (data1.containsKey('previous_attributes')) {
            //     Map<String, Object> previousAttributes = (Map<String, Object>) data1.get('previous_attributes');

            //     if (previousAttributes.containsKey('items')) {
            //         Map<String, Object> previousItems = (Map<String, Object>) previousAttributes.get('items');
            //         List<Object> previousSubscriptionItems = (List<Object>) previousItems.get('data');

            //         Map<String, Object> items = (Map<String, Object>) data2.get('items');
            //         List<Object> subscriptionItems = (List<Object>) items.get('data');

            //         // Create sets for comparison
            //         Set<String> currentItemIds = new Set<String>();
            //         Set<String> previousItemIds = new Set<String>();

            //         // Populate current item IDs
            //         for (Object itemObj : subscriptionItems) {
            //             Map<String, Object> item = (Map<String, Object>) itemObj;
            //             String itemId = (String) item.get('id');
            //             currentItemIds.add(itemId);
            //         }

            //         // Populate previous item IDs
            //         for (Object itemObj : previousSubscriptionItems) {
            //             Map<String, Object> item = (Map<String, Object>) itemObj;
            //             String itemId = (String) item.get('id');
            //             previousItemIds.add(itemId);
            //         }

            //         // Check if all item IDs match
            //         System.debug('Current item IDs: ' + currentItemIds);
            //         System.debug('Previous item IDs' + previousItemIds);
            //         if (!currentItemIds.equals(previousItemIds)) {
            //             System.debug(
            //                 'Item ID mismatch detected: Current=' + currentItemIds + ', Previous=' + previousItemIds
            //             );
            //             return;
            //         }

            //         System.debug('All item IDs match between current and previous items');
            //     }
            // }

            if (quoteId != null && subscriptionId != null) {
                // Publish subscription event then Event called  StripeSubscriptionScheduler2.getUpdatedSubcriptionfromStrpe
                // method then this  StripeSubscriptionScheduler.createStripeSubscription
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Salesforce_Quote_Id__c = quoteId;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == 'amazon' ||
                subscriptionSource == 'self_service') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription creation from self-service portal or stripe portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == null ||
                subscriptionSource != 'salesforce') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription maqnually created from stripe portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Subscription_Source__c = 'stripe';
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('customer.subscription.deleted')) {
            Map<String, Object> deletedata1 = (Map<String, Object>) event.get('data');
            system.debug(' deletedata1 -- ' + deletedata1);
            Map<String, Object> deletedata2 = (Map<String, Object>) deletedata1.get('object');
            String subscriptionId = (String) deletedata2.get('id');

            List<Stripe_Capture_Subscription_Deletion__e> stripeSubList = new List<Stripe_Capture_Subscription_Deletion__e>();

            Stripe_Capture_Subscription_Deletion__e stripeSub = new Stripe_Capture_Subscription_Deletion__e();
            stripeSub.StripeSubscriptionId__c = subscriptionId;
            stripeSubList.add(stripeSub);

            Database.SaveResult[] results = EventBus.publish(stripeSubList);
            system.debug('results--' + results);
        } else if (eventType.equals('payment_intent.payment_failed')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> paymentIntent = (Map<String, Object>) data.get('object');
            Map<String, Object> metadata = (Map<String, Object>) paymentIntent.get('metadata');
            system.debug('paymentIntent--' + paymentIntent);

            String stripePaymentIntentId = (String) paymentIntent.get('id');
            String quoteId = (String) metadata.get('salesforce_quote_id');
            String customerId = (String) paymentIntent.get('customer');

            List<Stripe_Capture_Transaction__e> stripePaymentList = new List<Stripe_Capture_Transaction__e>();

            Stripe_Capture_Transaction__e stripePayment = new Stripe_Capture_Transaction__e();
            stripePayment.StripePaymentIntentId__c = stripePaymentIntentId;
            stripePayment.QuoteId__c = quoteId;
            stripePayment.CustomerId__c = customerId;
            stripePaymentList.add(stripePayment);
            System.debug('stripePaymentList--' + stripePaymentList);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            system.debug('results--' + results);
        } else if (eventType.equals('invoice.payment_failed')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> failedstripeInvoice = (Map<String, Object>) data.get('object');
            system.debug('failedstripeInvoice--' + failedstripeInvoice);

            String failedstripeInvoiceId = (String) failedstripeInvoice.get('id');
            String failedsubscriptionId = (String) failedstripeInvoice.get('subscription');
            String paymentIntentId = (String) failedstripeInvoice.get('payment_intent');
            System.debug('failedsubscriptionId--' + failedsubscriptionId);

            List<Stripe_Capture_Payment__e> stripePaymentList = new List<Stripe_Capture_Payment__e>();

            Stripe_Capture_Payment__e stripePayment = new Stripe_Capture_Payment__e();
            stripePayment.CheckoutSessionId__c = failedsubscriptionId;
            stripePayment.StripeInvoiceId__c = failedstripeInvoiceId;
            stripePayment.stripepaymentintent_ID__c = paymentIntentId;
            stripePaymentList.add(stripePayment);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            System.debug('results--' + results);
        } else if (eventType.equals('customer.created')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> customer = (Map<String, Object>) data.get('object');
            Map<String, Object> metadata = (Map<String, Object>) customer.get('metadata');
            system.debug('customer--' + customer);

            String stripeCustomerId = (String) customer.get('id');
            String raydiantSignupType = metadata != null &&
                metadata.containsKey('raydiant_signup_type__c') &&
                metadata.get('raydiant_signup_type__c') != null
                ? String.valueOf(metadata.get('raydiant_signup_type__c'))
                : null;

            if (raydiantSignupType == 'amazon' || raydiantSignupType == 'self_service') {
                List<Stripe_Capture_Customer__e> stripeCustomerList = new List<Stripe_Capture_Customer__e>();

                Stripe_Capture_Customer__e stripeCustomer = new Stripe_Capture_Customer__e();
                stripeCustomer.StripeCustomerId__c = stripeCustomerId;
                stripeCustomer.Raydiant_Signup_Type__c = raydiantSignupType;
                stripeCustomerList.add(stripeCustomer);
                System.debug('stripeCustomerList--' + stripeCustomerList);

                Database.saveResult[] results = EventBus.publish(stripeCustomerList);
                system.debug('results--' + results);
            }
        }
    }
}
