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
        } else if (eventType.equals('invoice.created')) {
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
        } else if (eventType.equals('invoice.updated')) {
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

            // Check for deleted invoice line items
            Set<String> deletedLineItemIds = new Set<String>();

            if (data.containsKey('previous_attributes')) {
                Map<String, Object> previousAttributes = (Map<String, Object>) data.get('previous_attributes');

                if (previousAttributes.containsKey('lines')) {
                    Map<String, Object> previousLines = (Map<String, Object>) previousAttributes.get('lines');
                    List<Object> previousLineItems = (List<Object>) previousLines.get('data');

                    Map<String, Object> currentLines = (Map<String, Object>) stripeInvoice.get('lines');
                    List<Object> currentLineItems = (List<Object>) currentLines.get('data');

                    // Create sets for comparison
                    Set<String> currentItemIds = new Set<String>();
                    Set<String> previousItemIds = new Set<String>();

                    // Populate current item IDs
                    for (Object itemObj : currentLineItems) {
                        Map<String, Object> item = (Map<String, Object>) itemObj;
                        String itemId = (String) item.get('id');
                        currentItemIds.add(itemId);
                    }

                    // Populate previous item IDs
                    for (Object itemObj : previousLineItems) {
                        Map<String, Object> item = (Map<String, Object>) itemObj;
                        String itemId = (String) item.get('id');
                        previousItemIds.add(itemId);
                    }

                    // Find deleted item IDs (in previous but not in current)
                    deletedLineItemIds = previousItemIds.clone();
                    deletedLineItemIds.removeAll(currentItemIds);
                    System.debug('Deleted Line Item IDs: ' + deletedLineItemIds);
                }
            }

            // If there are deleted line items, handle them accordingly
            if (!deletedLineItemIds.isEmpty()) {
                List<Stripe_Capture_Deleted_Invoice_Item__e> deletedLineItemsEvents = new List<Stripe_Capture_Deleted_Invoice_Item__e>();

                for (String itemId : deletedLineItemIds) {
                    Stripe_Capture_Deleted_Invoice_Item__e deletedItemEvent = new Stripe_Capture_Deleted_Invoice_Item__e();
                    deletedItemEvent.Stripe_Invoice_ID__c = stripeInvoiceId;
                    deletedItemEvent.Deleted_Invoice_Item_ID__c = itemId;
                    deletedLineItemsEvents.add(deletedItemEvent);
                }

                Database.SaveResult[] deleteResults = EventBus.publish(deletedLineItemsEvents);
                System.debug('Deleted Line Items Publish Results: ' + deleteResults);
            }

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
                stripePayment.Payment_Capture__c = false;
                stripePayment.Invoice_Capture__c = true;
                stripePayment.Stripe_Subscription_ID__c = subscriptionId;
                stripePayment.StripeInvoiceId__c = stripeInvoiceId2;
                stripePayment.stripepaymentintent_ID__c = stripepaymentintentID;
                stripePayment.Quote_Id_From_Stripe__c = parenttQuoteId;
                stripePaymentList.add(stripePayment);
                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else {
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
                // This is for subscription creation from stripe which has been scheduled via Salesforce Quote
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Salesforce_Quote_Id__c = quoteId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Subscription_Schedule__c = subscriptionSchedule;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == 'amazon' ||
                subscriptionSource == 'self_service') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription which has been created from self-service portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Subscription_Schedule__c = false;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == null ||
                subscriptionSource != 'salesforce') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription which has been manually created from stripe dashboard
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Latest_invoiceId__c = invoiceid;
                stripePayment.Subscription_Source__c = 'stripe';
                stripePayment.Subscription_Schedule__c = false;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
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

            // Check for deleted subscription items
            Set<String> deletedItemIds = new Set<String>();

            if (data1.containsKey('previous_attributes')) {
                Map<String, Object> previousAttributes = (Map<String, Object>) data1.get('previous_attributes');

                if (previousAttributes.containsKey('items')) {
                    Map<String, Object> previousItems = (Map<String, Object>) previousAttributes.get('items');
                    List<Object> previousSubscriptionItems = (List<Object>) previousItems.get('data');

                    Map<String, Object> currentItems = (Map<String, Object>) data2.get('items');
                    List<Object> currentSubscriptionItems = (List<Object>) currentItems.get('data');

                    // Create sets for comparison
                    Set<String> currentItemIds = new Set<String>();
                    Set<String> previousItemIds = new Set<String>();

                    // Populate current item IDs
                    for (Object itemObj : currentSubscriptionItems) {
                        Map<String, Object> item = (Map<String, Object>) itemObj;
                        String itemId = (String) item.get('id');
                        currentItemIds.add(itemId);
                    }

                    // Populate previous item IDs
                    for (Object itemObj : previousSubscriptionItems) {
                        Map<String, Object> item = (Map<String, Object>) itemObj;
                        String itemId = (String) item.get('id');
                        previousItemIds.add(itemId);
                    }

                    // Find deleted item IDs (in previous but not in current)
                    deletedItemIds = previousItemIds.clone();
                    deletedItemIds.removeAll(currentItemIds);
                    System.debug('Deleted Item IDs: ' + deletedItemIds);
                }
            }

            // If there are deleted items, handle them accordingly
            if (!deletedItemIds.isEmpty()) {
                List<Stripe_Capture_Deleted_Subscription_Item__e> deletedItemsEvents = new List<Stripe_Capture_Deleted_Subscription_Item__e>();

                for (String itemId : deletedItemIds) {
                    Stripe_Capture_Deleted_Subscription_Item__e deletedItemEvent = new Stripe_Capture_Deleted_Subscription_Item__e();
                    deletedItemEvent.Stripe_Subscription_ID__c = subscriptionId;
                    deletedItemEvent.Deleted_Subscription_Item_ID__c = itemId;
                    deletedItemsEvents.add(deletedItemEvent);
                }

                Database.SaveResult[] deleteResults = EventBus.publish(deletedItemsEvents);
                System.debug('Deleted Items Publish Results: ' + deleteResults);
            }

            if (quoteId != null && subscriptionId != null) {
                // This is for subscription which has been updated & was originally created via Salesforce Quote
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Salesforce_Quote_Id__c = quoteId;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == 'amazon' ||
                subscriptionSource == 'self_service') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription which has been created from self-service portal
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Subscription_Source__c = subscriptionSource;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            } else if (
                (subscriptionSource == null ||
                subscriptionSource != 'salesforce') &&
                quoteId == null &&
                subscriptionId != null
            ) {
                // this is for subscription which has been manually created from stripe dashboard
                List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

                Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
                stripePayment.StripeSubscriptionId__c = subscriptionId;
                stripePayment.Subscription_Source__c = 'stripe';
                stripePayment.Event_Type__c = eventType;
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
        } else if (eventType.equals('customer.created') || eventType.equals('customer.updated')) {
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

            List<Stripe_Capture_Customer__e> stripeCustomerList = new List<Stripe_Capture_Customer__e>();

            Stripe_Capture_Customer__e stripeCustomer = new Stripe_Capture_Customer__e();
            stripeCustomer.StripeCustomerId__c = stripeCustomerId;
            stripeCustomer.Raydiant_Signup_Type__c = raydiantSignupType;
            stripeCustomer.Event_Type__c = eventType;
            stripeCustomerList.add(stripeCustomer);
            System.debug('stripeCustomerList--' + stripeCustomerList);

            Database.saveResult[] results = EventBus.publish(stripeCustomerList);
            system.debug('results--' + results);
        }
    }
}
