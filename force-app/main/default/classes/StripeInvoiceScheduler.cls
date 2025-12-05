public class StripeInvoiceScheduler implements Queueable, Database.AllowsCallouts {
    String invoiceId;
    String subcritionId;
    String quoteid;
    Boolean SubscriptionSchedule;

    public StripeInvoiceScheduler(String invoiceId, string subcritionId, string quoteid, boolean SubscriptionSchedule) {
        this.invoiceId = invoiceId;
        this.subcritionId = subcritionId;
        this.quoteid = quoteid;
        this.SubscriptionSchedule = SubscriptionSchedule;
    }

    public void execute(QueueableContext context) {
        try {
            List<SBQQ__Quote__c> quoteList = [
                SELECT
                    id,
                    SBQQ__Account__c,
                    Bill_To_Contact__c,
                    Billing_Frequency_Override__c,
                    SBQQ__Account__r.blng__BillToContact__c
                FROM SBQQ__Quote__c
                WHERE id = :quoteid
            ];
            system.debug('quoteList==' + quoteList);

            Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
            String secretKey = stripeDetails.Serect_Key__c;

            HttpRequest req = new HttpRequest();
            //  req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId + '?expand[]=payments');
            req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId);
            req.setMethod('POST'); // make it GET
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(secretKey + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            HttpResponse res = new Http().send(req);

            List<Stripe_Invoice__c> InsertInvoice = new List<Stripe_Invoice__c>();

            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String paymentIntentId;

                // Check if "payments" exists
                /*if (result.containsKey('payments') && result.get('payments') != null) {
                    Map<String, Object> payments = (Map<String, Object>) result.get('payments');
                    
                    if (payments.containsKey('data') && payments.get('data') != null) {
                        List<Object> paymentData = (List<Object>) payments.get('data');
                        
                        if (!paymentData.isEmpty()) {
                            Map<String, Object> firstPayment = (Map<String, Object>) paymentData[0];
                            
                            if (firstPayment.containsKey('payment') && firstPayment.get('payment') != null) {
                                Map<String, Object> paymentDetails = (Map<String, Object>) firstPayment.get('payment');
                                
                                if (paymentDetails.containsKey('payment_intent') && paymentDetails.get('payment_intent') != null) {
                                    paymentIntentId = (String) paymentDetails.get('payment_intent');
                                }
                            }
                        }
                    }
                }
                
                System.debug('Captured PaymentIntent ID: ' + paymentIntentId);
                
                // // Initialize variable
                String subscriptionId;
                
                // Check if "parent" exists
                if (result.containsKey('parent') && result.get('parent') != null) {
                    Map<String, Object> parent = (Map<String, Object>) result.get('parent');
                    
                    if (parent.containsKey('subscription_details') && parent.get('subscription_details') != null) {
                        Map<String, Object> subDetails = (Map<String, Object>) parent.get('subscription_details');
                        
                        if (subDetails.containsKey('subscription') && subDetails.get('subscription') != null) {
                            subscriptionId = (String) subDetails.get('subscription');
                        }
                    }
                }
                
                System.debug('Captured Subscription ID: ' + subscriptionId);*/
                system.debug('result---' + result);
                Stripe_Invoice__c invoice = new Stripe_Invoice__c();
                long effectivedate = (long) result.get('effective_at');
                long stratDate = (long) result.get('period_start');
                long endDate = (long) result.get('period_end');
                long webhoodDelivered = (long) result.get('webhooks_delivered_at');
                long dueDate = (long) result.get('due_date');
                Long finalizesAt = (Long) result.get('automatically_finalizes_at');
                String currencyCode = (String) result.get('currency');
                String customerId = (String) result.get('customer');

                List<Account> accts = [
                    SELECT Id, Name, blng__BillToContact__c
                    FROM Account
                    WHERE Stripe_Customer_ID__c = :customerId
                ];
                System.debug('accts--' + accts);

                invoice.Total_Amount__c = result.containsKey('total') ? (Decimal) result.get('total') / 100 : 0;
                invoice.Total_Amount_with_Tax__c = result.containsKey('total_excluding_tax')
                    ? (Decimal) result.get('total_excluding_tax') / 100
                    : 0;
                invoice.Subtotal__c = result.containsKey('subtotal') ? (Decimal) result.get('subtotal') / 100 : 0;
                invoice.Amount_Paid__c = result.containsKey('amount_paid')
                    ? (Decimal) result.get('amount_paid') / 100
                    : 0;
                invoice.Amount_Due__c = result.containsKey('amount_due') ? (Decimal) result.get('amount_due') / 100 : 0;
                invoice.Amount_Remaining__c = result.containsKey('amount_remaining')
                    ? (Decimal) result.get('amount_remaining') / 100
                    : 0;
                invoice.Amount_Credited__c = result.containsKey('pre_payment_credit_notes_amount')
                    ? (Decimal) result.get('pre_payment_credit_notes_amount') / 100
                    : 0;
                invoice.Tax_Rate__c = result.containsKey('tax') && result.get('tax') != null
                    ? (Decimal) result.get('tax')
                    : 0;
                invoice.Due_Date__c = toDateTime(dueDate);
                invoice.Automatically_Finalizes_At__c = toDateTime(finalizesAt);
                invoice.Billing_Reason__c = (String) result.get('billing_reason');
                invoice.CurrencyIsoCode = currencyCode.toUpperCase();
                invoice.Quote_CPQ__c = quoteList.size() > 0 ? quoteList[0].Id : null;
                invoice.Account__c = quoteList.size() > 0
                    ? quoteList[0].SBQQ__Account__c
                    : (accts.size() > 0 ? accts[0].Id : null);
                invoice.Bill_to_Contact__c = quoteList.size() > 0
                    ? quoteList[0].SBQQ__Account__r.blng__BillToContact__c
                    : (accts.size() > 0 ? accts[0].blng__BillToContact__c : null);
                invoice.Is_Payment_Done__c = result.containsKey('paid') ? (Boolean) result.get('paid') : false;
                invoice.Stripe_Invoice_Id__c = invoiceId;
                invoice.Invoice_Date__c = date.valueof(toDateTime(effectivedate));
                invoice.Invoice_PDF_URL__c = (String) result.get('invoice_pdf');
                invoice.Invoice_URL__c = (String) result.get('hosted_invoice_url');
                invoice.Name = result.get('number') != null ? (String) result.get('number') : 'SI-DRAFT';
                invoice.Stripe_Invoice_Period_End__c = toDateTime(endDate);
                invoice.Stripe_Invoice_Period_Start__c = toDateTime(stratDate);
                invoice.Payment_Status__c = (String) result.get('status');
                invoice.Webhook_Delivered_At__c = toDateTime(webhoodDelivered);

                upsert invoice Stripe_Invoice_Id__c;
                //InsertInvoice.add(invoice);
                Id invoiceID = invoice.Id;
                system.debug('invoiceID--' + invoiceID);
                // insert InsertInvoice;
                // Proceed to Invoice Line Items
                // Get line items
                Map<String, Object> lines = (Map<String, Object>) result.get('lines');
                List<Object> lineData = (List<Object>) lines.get('data');

                List<Stripe_Invoice_Line_Item__c> lineItems = new List<Stripe_Invoice_Line_Item__c>();

                for (Object item : lineData) {
                    Map<String, Object> lineItem = (Map<String, Object>) item;
                    Decimal amount = lineItem.containsKey('amount') && lineItem.get('amount') != null
                        ? Decimal.valueOf((Integer) lineItem.get('amount')) / 100
                        : 0;
                    Integer quantity = lineItem.containsKey('quantity') && lineItem.get('quantity') != null
                        ? Integer.valueOf(lineItem.get('quantity'))
                        : 0;
                    Decimal unitPrice = (amount != 0 && quantity != 0) ? (amount / quantity) : 0;

                    Stripe_Invoice_Line_Item__c line = new Stripe_Invoice_Line_Item__c();
                    line.Stripe_Invoice__c = invoiceID;
                    line.Stripe_Invoice_line_Item_Id__c = (String) lineItem.get('id');
                    line.Quantity__c = quantity;
                    // line.Amount__c = toDecimal(lineItem.get('amount'));
                    line.Product_Name__c = (String) lineItem.get('description');
                    // line.Billing_Frequency_Override__c = quoteList.size() > 0 ? quoteList[0].Billing_Frequency_Override__c : null;

                    // Period handling
                    if (lineItem.containsKey('period')) {
                        Map<String, Object> period = (Map<String, Object>) lineItem.get('period');
                        long lineStartDate = (long) period.get('start');
                        long lineEndDate = (long) period.get('end');
                        line.Start_Date__c = toDateTime(lineStartDate);
                        line.End_Date__c = toDateTime(lineEndDate);
                    }

                    if (lineItem.containsKey('price')) {
                        Map<String, Object> price = (Map<String, Object>) lineItem.get('price');
                        line.Unit_Price__c = price.containsKey('unit_amount_decimal') &&
                            price.get('unit_amount_decimal') != null
                            ? Decimal.valueOf((String) price.get('unit_amount_decimal')) / 100
                            : unitPrice;
                        line.Charge_Type__c = price.containsKey('type') ? (String) price.get('type') : null;
                    }

                    line.Total_Amount_with_Tax__c = lineItem.containsKey('unit_amount_excluding_tax') &&
                        lineItem.get('unit_amount_excluding_tax') != null
                        ? Decimal.valueOf((String) lineItem.get('unit_amount_excluding_tax')) / 100
                        : null;

                    lineItems.add(line);
                }

                if (!lineItems.isEmpty()) {
                    //insert lineItems;
                    //  upsert lineItems Stripe_Invoice_line_Item_Id__c;
                    upsert lineItems Stripe_Invoice_line_Item_Id__c;
                }
            } else {
                System.debug('Invoice fetch failed: ' + res.getBody());
                Logger__c logger = new Logger__c(
                    Name = 'Stripe Invoice Queueable Error',
                    Message__c = 'Failed to fetch invoice from Stripe: ' + res.getBody(),
                    StackTrace__c = '',
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeInvoiceQueueable',
                    Apex_Method__c = 'execute',
                    Object_Name__c = 'Stripe_Invoice__c'
                    //  User_Email__c = UserInfo.getUserEmail()
                );
                insert logger;
            }
        } catch (exception ex) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Queueable Error',
                Message__c = 'Failed to fetch invoice from Stripe: ' + ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice__c'
                // User_Email__c = UserInfo.getUserEmail()
            );
            insert logger;
        }
    }
    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer) unixTs);
    }

    private static Decimal toDecimal(Object centsValue) {
        if (centsValue == null)
            return 0;
        return ((Decimal) centsValue) / 100;
    }
}
