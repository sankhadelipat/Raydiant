@RestResource(urlMapping='/stripe/webhook')
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

        if (eventType.equals('checkout.session.completed')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            system.debug('data--' + data);
            Map<String, Object> sessionObj = (Map<String, Object>) data.get('object');
            system.debug('sessionObj--' + sessionObj);

            // Extract values from the session object
            String checkoutSessionId = (String) sessionObj.get('id');
            String invoiceId = (String) sessionObj.get('invoice');
            String subscriptionId = (String) sessionObj.get('subscription');

            // Capture Metadata -> salesforce_quote_id
            Map<String, Object> metadata = (Map<String, Object>) sessionObj.get('metadata');
            String quoteId = metadata != null ? (String) metadata.get('salesforce_quote_id') : null;

            System.debug('checkoutSessionId--' + checkoutSessionId);
            System.debug('invoiceId--' + invoiceId);
            System.debug('subscriptionId--' + subscriptionId);
            System.debug('quoteId--' + quoteId);

            List<Stripe_Capture_Payment__e> stripePaymentList = new List<Stripe_Capture_Payment__e>();

            Stripe_Capture_Payment__e stripePayment = new Stripe_Capture_Payment__e();
            stripePayment.CheckoutSessionId__c = checkoutSessionId;
            stripePayment.StripeInvoiceId__c = invoiceId;
            stripePayment.StripeSubscriptionId__c = subscriptionId;
            stripePayment.SalesforceQuoteId__c = quoteId;
            stripePaymentList.add(stripePayment);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            System.debug('Publish results: ' + results);
        } else if (
            eventType.equals('invoice.created') ||
            eventType.equals('invoice.finalized') ||
            eventType.equals('invoice.paid') ||
            eventType.equals('invoice.marked_uncollectible') ||
            eventType.equals('invoice.voided')
        ) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            system.debug('data--' + data);
            Map<String, Object> stripeInvoice = (Map<String, Object>) data.get('object');

            String stripeInvoiceId = (String) stripeInvoice.get('id');
            String status = (String) stripeInvoice.get('status');
            system.debug('invoice----' + stripeInvoiceId);

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

            if (status != 'draft') {
                List<Stripe_Capture_Invoice__e> stripeInvoiceList = new List<Stripe_Capture_Invoice__e>();

                Stripe_Capture_Invoice__e stripeInv = new Stripe_Capture_Invoice__e();
                stripeInv.Stripe_Subscription_ID__c = subscriptionId;
                stripeInv.Stripe_Invoice_ID__c = stripeInvoiceId;
                stripeInv.Quote_ID_From_Stripe__c = parentQuoteId;
                stripeInv.Event_Type__c = eventType;
                stripeInvoiceList.add(stripeInv);

                Database.SaveResult[] results = EventBus.publish(stripeInvoiceList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('invoice.updated')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            system.debug('data--' + data);
            Map<String, Object> stripeInvoice = (Map<String, Object>) data.get('object');

            String stripeInvoiceId = (String) stripeInvoice.get('id');
            String status = (String) stripeInvoice.get('status');
            system.debug('invoice----' + stripeInvoiceId);

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

            if (status != 'draft') {
                List<Stripe_Capture_Invoice__e> stripeInvoiceList = new List<Stripe_Capture_Invoice__e>();

                Stripe_Capture_Invoice__e stripeInv = new Stripe_Capture_Invoice__e();
                stripeInv.Stripe_Subscription_ID__c = subscriptionId;
                stripeInv.Stripe_Invoice_ID__c = stripeInvoiceId;
                stripeInv.Quote_ID_From_Stripe__c = parentQuoteId;
                stripeInv.Event_Type__c = eventType;
                stripeInvoiceList.add(stripeInv);

                Database.SaveResult[] results = EventBus.publish(stripeInvoiceList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('customer.subscription.created')) {
            Map<String, Object> outerMap = (Map<String, Object>) event.get('data');
            Map<String, Object> subscriptionObj = (Map<String, Object>) outerMap.get('object');

            String subscriptionId = (String) subscriptionObj.get('id');
            String invoiceid = (String) subscriptionObj.get('latest_invoice');

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
            Boolean isRenewalSubscription = metadata.get('auto_renewal') != null
                ? Boolean.valueOf((String) metadata.get('auto_renewal'))
                : false;

            // Debug
            System.debug('Subscription Id: ' + subscriptionId);
            System.debug('Invoice Id: ' + invoiceId);
            System.debug('Quote Id: ' + quoteId);

            List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

            Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
            stripePayment.StripeSubscriptionId__c = subscriptionId;
            stripePayment.Salesforce_Quote_Id__c = quoteId;
            stripePayment.Latest_invoiceId__c = invoiceid;
            stripePayment.Subscription_Source__c = subscriptionSource;
            stripePayment.Subscription_Schedule__c = subscriptionSchedule;
            stripePayment.Renewal_Subscription__c = isRenewalSubscription;
            stripePayment.Event_Type__c = eventType;
            stripePaymentList.add(stripePayment);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            system.debug('results--' + results);
        } else if (eventType.equals('customer.subscription.updated')) {
            Map<String, Object> outerMap = (Map<String, Object>) event.get('data');
            Map<String, Object> subscriptionObj = (Map<String, Object>) outerMap.get('object');

            String subscriptionId = (String) subscriptionObj.get('id');

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
            Boolean isRenewalSubscription = metadata.get('auto_renewal') != null
                ? Boolean.valueOf((String) metadata.get('auto_renewal'))
                : false;

            System.debug('subscription Source: ' + subscriptionSource);
            System.debug('Quote Id: ' + quoteId);

            // Check for deleted subscription items
            Set<String> deletedItemIds = new Set<String>();

            if (outerMap.containsKey('previous_attributes')) {
                Map<String, Object> previousAttributes = (Map<String, Object>) outerMap.get('previous_attributes');

                if (previousAttributes.containsKey('items')) {
                    Map<String, Object> previousItems = (Map<String, Object>) previousAttributes.get('items');
                    List<Object> previousSubscriptionItems = (List<Object>) previousItems.get('data');

                    Map<String, Object> currentItems = (Map<String, Object>) subscriptionObj.get('items');
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

            List<Stripe_Capture_Subscription__e> stripePaymentList = new List<Stripe_Capture_Subscription__e>();

            Stripe_Capture_Subscription__e stripePayment = new Stripe_Capture_Subscription__e();
            stripePayment.StripeSubscriptionId__c = subscriptionId;
            stripePayment.Salesforce_Quote_Id__c = quoteId;
            stripePayment.Subscription_Source__c = subscriptionSource;
            stripePayment.Subscription_Schedule__c = subscriptionSchedule;
            stripePayment.Renewal_Subscription__c = isRenewalSubscription;
            stripePayment.Event_Type__c = eventType;
            stripePaymentList.add(stripePayment);

            Database.SaveResult[] results = EventBus.publish(stripePaymentList);
            system.debug('results--' + results);
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
        } else if (eventType.equals('subscription_schedule.created')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> subscriptionScheduleObj = (Map<String, Object>) data.get('object');

            String subscriptionScheduleId = (String) subscriptionScheduleObj.get('id');
            String subId = (String) subscriptionScheduleObj.get('subscription');

            // Capture Metadata -> salesforce_quote_id
            Map<String, Object> metadata = (Map<String, Object>) subscriptionScheduleObj.get('metadata');
            String quoteId = (String) metadata.get('salesforce_quote_id');
            String subscriptionSource = metadata != null &&
                metadata.containsKey('subscription_source') &&
                metadata.get('subscription_source') != null
                ? String.valueOf(metadata.get('subscription_source'))
                : null;
            Boolean subscriptionSchedule = metadata.get('subscription_schedule') != null
                ? Boolean.valueOf((String) metadata.get('subscription_schedule'))
                : false;
            Boolean isRenewalSubscription = metadata.get('is_renewal_subscription') != null
                ? Boolean.valueOf((String) metadata.get('is_renewal_subscription'))
                : false;

            // Debug
            System.debug('Subscription Schedule Id: ' + subscriptionScheduleId);
            System.debug('Quote Id: ' + quoteId);

            if (subId == null) {
                List<Stripe_Capture_Subscription_Schedule__e> stripeSubScheduleList = new List<Stripe_Capture_Subscription_Schedule__e>();

                Stripe_Capture_Subscription_Schedule__e stripeSubSchedule = new Stripe_Capture_Subscription_Schedule__e();
                stripeSubSchedule.StripeSubscriptionScheduleId__c = subscriptionScheduleId;
                stripeSubSchedule.Salesforce_Quote_Id__c = quoteId;
                stripeSubSchedule.Subscription_Source__c = subscriptionSource;
                stripeSubSchedule.Renewal_Subscription__c = isRenewalSubscription;
                stripeSubSchedule.Event_Type__c = eventType;
                stripeSubScheduleList.add(stripeSubSchedule);

                Database.SaveResult[] results = EventBus.publish(stripeSubScheduleList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('subscription_schedule.canceled')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> subscriptionScheduleObj = (Map<String, Object>) data.get('object');

            String subscriptionScheduleId = (String) subscriptionScheduleObj.get('id');
            String subId = (String) subscriptionScheduleObj.get('subscription');

            // Capture Metadata -> salesforce_quote_id
            Map<String, Object> metadata = (Map<String, Object>) subscriptionScheduleObj.get('metadata');
            Boolean subscriptionSchedule = metadata.get('subscription_schedule') != null
                ? Boolean.valueOf((String) metadata.get('subscription_schedule'))
                : false;
            Boolean isRenewalSubscription = metadata.get('is_renewal_subscription') != null
                ? Boolean.valueOf((String) metadata.get('is_renewal_subscription'))
                : false;

            // Debug
            System.debug('Subscription Schedule Id: ' + subscriptionScheduleId);

            if (subId == null) {
                List<Stripe_Capture_Schedule_Deletion__e> stripeSubScheduleDelList = new List<Stripe_Capture_Schedule_Deletion__e>();

                Stripe_Capture_Schedule_Deletion__e stripeSubScheduleDel = new Stripe_Capture_Schedule_Deletion__e();
                stripeSubScheduleDel.StripeSubscriptionScheduleId__c = subscriptionScheduleId;
                stripeSubScheduleDelList.add(stripeSubScheduleDel);

                Database.SaveResult[] results = EventBus.publish(stripeSubScheduleDelList);
                system.debug('results--' + results);
            }
        } else if (
            eventType.equals('payment_intent.succeeded') ||
            eventType.equals('payment_intent.payment_failed') ||
            eventType.equals('payment_intent.canceled')
        ) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> paymentIntent = (Map<String, Object>) data.get('object');
            system.debug('paymentIntent--' + paymentIntent);

            String paymentIntentId = (String) paymentIntent.get('id');
            String customerId = (String) paymentIntent.get('customer');
            Map<String, Object> metadata = (Map<String, Object>) paymentIntent.get('metadata');
            String quoteId = metadata != null ? (String) metadata.get('salesforce_quote_id') : null;

            if (customerId != null) {
                List<Stripe_Capture_Transaction__e> stripePaymentList = new List<Stripe_Capture_Transaction__e>();

                Stripe_Capture_Transaction__e stripePayment = new Stripe_Capture_Transaction__e();
                stripePayment.Stripe_Payment_Intent_ID__c = paymentIntentId;
                stripePayment.Stripe_Customer_ID__c = customerId;
                stripePayment.Salesforce_Quote_Id__c = quoteId;
                stripePayment.Event_Type__c = eventType;
                stripePaymentList.add(stripePayment);
                System.debug('stripePaymentList--' + stripePaymentList);

                Database.SaveResult[] results = EventBus.publish(stripePaymentList);
                system.debug('results--' + results);
            }
        } else if (eventType.equals('invoice.payment_succeeded')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> invoice = (Map<String, Object>) data.get('object');
            System.debug('invoice--' + invoice);

            String invoiceId = (String) invoice.get('id');
            String customerId = (String) invoice.get('customer');
            Map<String, Object> parent = (Map<String, Object>) invoice.get('parent');
            Map<String, Object> subscriptionDetails = parent != null
                ? (Map<String, Object>) parent.get('subscription_details')
                : null;
            String subscriptionId = subscriptionDetails != null
                ? (String) subscriptionDetails.get('subscription')
                : null;

            List<Stripe_Capture_Intent__e> stripeIntentList = new List<Stripe_Capture_Intent__e>();
            Stripe_Capture_Intent__e stripeIntent = new Stripe_Capture_Intent__e();
            stripeIntent.Stripe_Invoice_ID__c = invoiceId;
            stripeIntentList.add(stripeIntent);

            Database.SaveResult[] results1 = EventBus.publish(stripeIntentList);
            System.debug('results--' + results1);

            if (subscriptionId != null) {
                List<Stripe_Capture_Subscription_Promotion__e> stripeInvoicePromotionList = new List<Stripe_Capture_Subscription_Promotion__e>();

                Stripe_Capture_Subscription_Promotion__e stripeInvoicePromotion = new Stripe_Capture_Subscription_Promotion__e();
                stripeInvoicePromotion.Stripe_Customer_ID__c = customerId;
                stripeInvoicePromotion.Stripe_Subscription_ID__c = subscriptionId;
                stripeInvoicePromotionList.add(stripeInvoicePromotion);
                System.debug('stripeInvoicePromotionList--' + stripeInvoicePromotionList);

                Database.SaveResult[] results2 = EventBus.publish(stripeInvoicePromotionList);
                System.debug('results--' + results2);
            }
        } else if (eventType.equals('invoice.payment_failed')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> stripeInvoice = (Map<String, Object>) data.get('object');
            System.debug('stripeInvoice--' + stripeInvoice);

            String stripeInvoiceId = (String) stripeInvoice.get('id');

            List<Stripe_Capture_Intent__e> stripeIntentList = new List<Stripe_Capture_Intent__e>();
            Stripe_Capture_Intent__e stripeIntent = new Stripe_Capture_Intent__e();
            stripeIntent.Stripe_Invoice_ID__c = stripeInvoiceId;
            stripeIntentList.add(stripeIntent);

            Database.SaveResult[] results = EventBus.publish(stripeIntentList);
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
        } else if (eventType.equals('payment_method.attached')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> paymentMethod = (Map<String, Object>) data.get('object');
            system.debug('paymentMethod--' + paymentMethod);

            String stripePaymentMethodId = (String) paymentMethod.get('id');
            String customerId = (String) paymentMethod.get('customer');

            List<Stripe_Capture_Payment_Method__e> stripePaymentMethodList = new List<Stripe_Capture_Payment_Method__e>();

            Stripe_Capture_Payment_Method__e stripePaymentMethod = new Stripe_Capture_Payment_Method__e();
            stripePaymentMethod.StripePaymentMethodId__c = stripePaymentMethodId;
            stripePaymentMethod.CustomerId__c = customerId;
            stripePaymentMethodList.add(stripePaymentMethod);
            System.debug('stripePaymentMethodList--' + stripePaymentMethodList);

            Database.saveResult[] results = EventBus.publish(stripePaymentMethodList);
            system.debug('results--' + results);
        } else if (eventType.equals('credit_note.created') || eventType.equals('credit_note.voided')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> creditNote = (Map<String, Object>) data.get('object');
            system.debug('creditNote--' + creditNote);

            String stripeCreditNoteId = (String) creditNote.get('id');
            String stripeInvoiceId = (String) creditNote.get('invoice');
            String customerId = (String) creditNote.get('customer');

            List<Stripe_Capture_Credit_Note__e> stripeCreditNoteList = new List<Stripe_Capture_Credit_Note__e>();

            Stripe_Capture_Credit_Note__e stripeCreditNote = new Stripe_Capture_Credit_Note__e();
            stripeCreditNote.StripeCreditNoteId__c = stripeCreditNoteId;
            stripeCreditNote.StripeInvoiceId__c = stripeInvoiceId;
            stripeCreditNote.CustomerId__c = customerId;
            stripeCreditNoteList.add(stripeCreditNote);
            System.debug('stripeCreditNoteList--' + stripeCreditNoteList);

            Database.saveResult[] results = EventBus.publish(stripeCreditNoteList);
            system.debug('results--' + results);
        } else if (eventType.equals('charge.refunded')) {
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            Map<String, Object> chargeObj = (Map<String, Object>) data.get('object');

            String chargeId = (String) chargeObj.get('id');
            String paymentIntentId = (String) chargeObj.get('payment_intent');
            Decimal amountRefunded = chargeObj.get('amount_refunded') != null
                ? (Decimal) chargeObj.get('amount_refunded') / 100
                : 0;
            System.debug('paymentIntentId--' + paymentIntentId);
            System.debug('amountRefunded--' + amountRefunded);

            if (String.isNotBlank(paymentIntentId)) {
                List<Stripe_Capture_Refund__e> stripeRefundList = new List<Stripe_Capture_Refund__e>();
                Stripe_Capture_Refund__e stripeRefund = new Stripe_Capture_Refund__e();
                stripeRefund.StripeChargeId__c = chargeId;
                stripeRefund.StripePaymentIntentId__c = paymentIntentId;
                stripeRefund.RefundedAmount__c = amountRefunded;
                stripeRefundList.add(stripeRefund);

                Database.SaveResult[] results = EventBus.publish(stripeRefundList);
                system.debug('results--' + results);
            }
        }
    }
}