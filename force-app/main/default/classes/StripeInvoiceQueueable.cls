public class StripeInvoiceQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String secretKey = stripeDetails.Serect_Key__c;

    String invoiceId;
    string subcritionId;
    string QuoteID;
    Boolean PaymentCaptured;
    Boolean InvoiceCaptured;

    public StripeInvoiceQueueable(
        String invoiceId,
        string subcritionId,
        string quoteid,
        boolean PaymentCaptured,
        boolean InvoiceCaptured
    ) {
        this.invoiceId = invoiceId;
        this.subcritionId = subcritionId;
        this.Quoteid = quoteid;
        this.PaymentCaptured = PaymentCaptured;
        this.InvoiceCaptured = InvoiceCaptured;
    }

    public void execute(QueueableContext context) {
        try {
            List<Contract> contr = new List<Contract>();
            if (subcritionId != null) {
                contr = [
                    SELECT id, Stripe_Subscription_ID__c, SBQQ__Quote__c
                    FROM Contract
                    WHERE Stripe_Subscription_ID__c = :subcritionId
                ];
            }

            SBQQ__Quote__c quoteList = new SBQQ__Quote__c();
            // 2nd Invoice Paid From stripe subscription
            if (!contr.isEmpty()) {
                quoteList = [
                    SELECT
                        id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE id = :contr[0].SBQQ__Quote__c
                    LIMIT 1
                ];
                system.debug('quoteList==' + quoteList);
                // Q2I initial invoice paid
            } else if (InvoiceCaptured) {
                quoteList = [
                    SELECT
                        id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :quoteid
                    LIMIT 1
                ];
                system.debug('quoteList==' + quoteList);
                // 1st Transaction  initial payment Q2C
            } else {
                quoteList = [
                    SELECT
                        id,
                        SBQQ__Account__c,
                        Bill_To_Contact__c,
                        Billing_Frequency_Override__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE id = :Quoteid
                ];
                system.debug('quoteList==' + quoteList);
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId + '?expand[]=payments');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(secretKey + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            HttpResponse res = new Http().send(req);

            List<Stripe_Invoice__c> InsertInvoice = new List<Stripe_Invoice__c>();

            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String paymentIntentId;

                // Check if "payments" exists
                if (result.containsKey('payments') && result.get('payments') != null) {
                    Map<String, Object> payments = (Map<String, Object>) result.get('payments');

                    if (payments.containsKey('data') && payments.get('data') != null) {
                        List<Object> paymentData = (List<Object>) payments.get('data');

                        if (!paymentData.isEmpty()) {
                            Map<String, Object> firstPayment = (Map<String, Object>) paymentData[0];

                            if (firstPayment.containsKey('payment') && firstPayment.get('payment') != null) {
                                Map<String, Object> paymentDetails = (Map<String, Object>) firstPayment.get('payment');

                                if (
                                    paymentDetails.containsKey('payment_intent') &&
                                    paymentDetails.get('payment_intent') != null
                                ) {
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

                System.debug('Captured Subscription ID: ' + subscriptionId);
                system.debug('result---' + result);
                Stripe_Invoice__c invoice = new Stripe_Invoice__c();
                long effectivedate = (long) result.get('effective_at');
                long stratDate = (long) result.get('period_start');
                long endDate = (long) result.get('period_end');
                long webhoodDelivered = (long) result.get('webhooks_delivered_at');
                long dueDate = (long) result.get('due_date');
                Long finalizesAt = (Long) result.get('automatically_finalizes_at');
                String currencyCode = (String) result.get('currency');

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
                invoice.Tax_Rate__c = result.containsKey('tax') && result.get('tax') != null
                    ? (Decimal) result.get('tax')
                    : 0;
                invoice.Due_Date__c = toDateTime(dueDate);
                invoice.Automatically_Finalizes_At__c = toDateTime(finalizesAt);
                invoice.Billing_Reason__c = (String) result.get('billing_reason');
                invoice.CurrencyIsoCode = currencyCode.toUpperCase();
                invoice.Quote_CPQ__c = quoteList.id;
                invoice.Account__c = quoteList.SBQQ__Account__c;
                invoice.Bill_to_Contact__c = quoteList.SBQQ__Account__r.blng__BillToContact__c;
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
                    // line.Billing_Frequency_Override__c = quoteList.Billing_Frequency_Override__c;

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
                    // call payment class to store Transaction payment intent object from stripe
                    System.enqueueJob(
                        new StripePaymentIntentQueueable(
                            invoiceID,
                            paymentIntentId,
                            subcritionId,
                            QuoteID,
                            PaymentCaptured,
                            InvoiceCaptured
                        )
                    );
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