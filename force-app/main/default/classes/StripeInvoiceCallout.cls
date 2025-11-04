public class StripeInvoiceCallout implements Queueable, Database.AllowsCallouts {
    String invoiceId;
    string quoteId;
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;
    //@InvocableMethod(label ='Quote To Invoiec: Invoice Created when Quote Accepted')
    public StripeInvoiceCallout(String invoiceId, string quoteId) {
        this.invoiceId = invoiceId;
        this.quoteId = quoteId;
    }
    public void execute(QueueableContext context) {
        //(String quoteId, String invoiceid)
        try {
            List<SBQQ__Quote__c> quoteList = [
                SELECT
                    Id,
                    SBQQ__NetAmount__c,
                    SBQQ__StartDate__c,
                    SBQQ__Account__c,
                    Bill_To_Contact__c,
                    SBQQ__SubscriptionTerm__c,
                    SBQQ__Account__r.Stripe_Customer_ID__c,
                    SBQQ__PaymentTerms__c,
                    CurrencyIsoCode,
                    Billing_Frequency_Override__c,
                    SBQQ__Account__r.blng__BillToContact__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1
            ];

            List<SBQQ__QuoteLine__c> quoteLineItems = [
                SELECT
                    Id,
                    SBQQ__Product__r.Name,
                    SBQQ__Quantity__c,
                    SBQQ__NetTotal__c,
                    SBQQ__CustomerPrice__c,
                    SBQQ__Product__r.Stripe_Product_Id__c,
                    Stripe_Price_ID__c,
                    Quantity_For_Stripe__c,
                    CurrencyIsoCode,
                    Billing_Frequency_Override__c,
                    MRR__c,
                    SBQQ__Product__r.SBQQ__SubscriptionType__c
                FROM SBQQ__QuoteLine__c
                WHERE
                    SBQQ__Quote__c = :quoteList[0].Id
                    AND SBQQ__Product__r.Stripe_Product_Id__c != NULL
                    AND Stripe_Subscription_Type__c = 'One-time'
            ];
            system.debug('quoteLineItems--' + quoteLineItems);
            // Flag if we found any One-time quote lines
            Boolean hasOneTimeLines = !quoteLineItems.isEmpty();

            // prepare price id with Quote line price //
            if (hasOneTimeLines) {
                Map<Id, String> quoteLineToPriceIdMap = new Map<Id, String>();
                Http http = new Http();

                Map<String, List<Object>> freqMap = new Map<String, List<Object>>{
                    'Monthly' => new List<Object>{ 'month', 1 },
                    'Quarterly' => new List<Object>{ 'month', 3 },
                    'Annual' => new List<Object>{ 'year', 1 },
                    '2-Year' => new List<Object>{ 'year', 2 },
                    '3-Year' => new List<Object>{ 'year', 3 }
                };

                // Determine product charge type
                Boolean hasRecurringProducts = false;

                for (SBQQ__QuoteLine__c ql : quoteLineItems) {
                    String priceType;
                    String interval;
                    Integer intervalCount;

                    // Determine price type & interval
                    if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'Renewable') {
                        priceType = 'recurring';
                        hasRecurringProducts = true;

                        String freq = (ql.Billing_Frequency_Override__c != null
                            ? ql.Billing_Frequency_Override__c
                            : 'Monthly');

                        List<Object> freqData = freqMap.containsKey(freq) ? freqMap.get(freq) : freqMap.get('Monthly');

                        interval = (String) freqData[0];
                        intervalCount = (Integer) freqData[1];
                    } else if (ql.SBQQ__Product__r.SBQQ__SubscriptionType__c == 'One-time') {
                        priceType = 'one_time';
                    }

                    // Calculate unit price safely
                    Decimal qty = (ql.Quantity_For_Stripe__c != null &&
                        ql.Quantity_For_Stripe__c != 0)
                        ? ql.Quantity_For_Stripe__c
                        : 1;
                    Decimal unitPrice = (ql.MRR__c != null &&
                        ql.MRR__c != 0)
                        ? ql.MRR__c / qty
                        : ql.SBQQ__NetTotal__c / qty;

                    // Calculate unitAmount in cents
                    Decimal multiplier = 1;
                    if (priceType == 'recurring') {
                        multiplier = (interval == 'month' &&
                            intervalCount == 3)
                            ? 3
                            : (interval == 'year') ? (12 * intervalCount) : 1; // monthly default
                    }
                    Decimal unitAmount = (unitPrice != null ? unitPrice.setScale(2) * multiplier * 100 : 0);

                    System.debug('unitAmount--' + unitAmount);

                    // Build Price API body
                    List<String> bodyParts = new List<String>{
                        'billing_scheme=per_unit',
                        'currency=' + ql.CurrencyIsoCode,
                        'product=' + ql.SBQQ__Product__r.Stripe_Product_Id__c,
                        'unit_amount_decimal=' + unitAmount
                    };

                    // Add recurring details only if recurring
                    if (priceType == 'recurring') {
                        bodyParts.add('recurring[interval]=' + interval);
                        bodyParts.add('recurring[interval_count]=' + intervalCount);
                    }

                    String priceBody = String.join(bodyParts, '&');

                    // Send Price request
                    HttpRequest priceReq = new HttpRequest();
                    priceReq.setEndpoint('https://api.stripe.com/v1/prices');
                    priceReq.setMethod('POST');
                    priceReq.setHeader(
                        'Authorization',
                        'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                    );
                    priceReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                    priceReq.setBody(priceBody);
                    HttpResponse priceRes = http.send(priceReq);

                    if (priceRes.getStatusCode() == 200) {
                        String priceId = (String) ((Map<String, Object>) JSON.deserializeUntyped(priceRes.getBody()))
                            .get('id');
                        quoteLineToPriceIdMap.put(ql.Id, priceId);
                    }
                }
                ////////////add lines////////////////////////
                List<String> parts = new List<String>();
                Integer i = 0;

                for (SBQQ__QuoteLine__c item : quoteLineItems) {
                    String priceId = quoteLineToPriceIdMap.get(item.Id);

                    parts.add('lines[' + i + '][pricing][price]=' + EncodingUtil.urlEncode(priceId, 'UTF-8'));
                    parts.add(
                        'lines[' +
                            i +
                            '][quantity]=' +
                            EncodingUtil.urlEncode(
                                String.valueOf(item.Quantity_For_Stripe__c != null ? item.Quantity_For_Stripe__c : 1),
                                'UTF-8'
                            )
                    );

                    if (!String.isBlank(item.SBQQ__Product__r.Name)) {
                        parts.add(
                            'lines[' +
                                i +
                                '][description]=' +
                                EncodingUtil.urlEncode(item.SBQQ__Product__r.Name, 'UTF-8')
                        );
                    }

                    i++;
                }

                String endpoint = 'https://api.stripe.com/v1/invoices/' + invoiceId + '/add_lines';

                HttpRequest req2 = new HttpRequest();
                req2.setEndpoint(endpoint);
                req2.setMethod('POST');
                req2.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req2.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req2.setBody(String.join(parts, '&'));

                Http http5 = new Http();
                HttpResponse res3 = http5.send(req2);
                System.debug('Stripe response: ' + res3.getBody());
                if (res3.getStatusCode() == 200) {
                    System.debug('Stripe Invoice Add Lines: ' + res3.getBody());
                } else {
                    System.debug('Stripe Invoice Error: ' + res3.getBody());
                    throw new CalloutException('Stripe callout failed: ' + res3.getBody());
                }
            }
            // invoice update ///

            Integer dueOffsetDays = 0;
            String terms = quoteList[0].SBQQ__PaymentTerms__c != null
                ? quoteList[0].SBQQ__PaymentTerms__c.toLowerCase()
                : '';
            system.debug('terms--' + terms);
            String extractedTerm = terms.replaceAll('\\D+', '');
            system.debug('extractedTerm--' + extractedTerm);

            switch on extractedTerm {
                when '15' {
                    dueOffsetDays = 15;
                }
                when '30' {
                    dueOffsetDays = 30;
                }
                when '45' {
                    dueOffsetDays = 45;
                }
                when '60' {
                    dueOffsetDays = 60;
                }
                when '90' {
                    dueOffsetDays = 90;
                }
                when else {
                    dueOffsetDays = 0;
                }
            }
            // Get the Salesforce user's timezone
            TimeZone tz = UserInfo.getTimeZone();
            System.debug('Display name: ' + tz.getDisplayName());
            System.debug('ID: ' + tz.getID());

            Date startDate = quoteList[0].SBQQ__StartDate__c;
            system.debug('dueOffsetDays--' + dueOffsetDays);
            Date dueDate = startDate.addDays(dueOffsetDays);
            Long unixStartDate;
            Long unixDueDate;

            if (startDate != null) {
                // Create datetime at midnight in user's local time
                Datetime userLocalStart = Datetime.newInstanceGMT(
                    startDate.year(),
                    startDate.month(),
                    startDate.day(),
                    0,
                    0,
                    0
                );
                // Convert that datetime to UTC by subtracting the user's offset
                // Datetime utcStart = userLocalStart.addSeconds(-tz.getOffset(userLocalStart) / 1000);
                unixStartDate = userLocalStart.getTime() / 1000;
            }

            if (dueDate != null) {
                Datetime userLocalDue = Datetime.newInstanceGMT(
                    dueDate.year(),
                    dueDate.month(),
                    dueDate.day(),
                    0,
                    0,
                    0
                );
                // Datetime utcDue = userLocalDue.addSeconds(-tz.getOffset(userLocalDue) / 1000);
                unixDueDate = userLocalDue.getTime() / 1000;
            }

            System.debug('unixStartDate (user TZ adjusted): ' + unixStartDate);
            System.debug('unixDueDate (user TZ adjusted): ' + unixDueDate);
            // Long unixStartDate = startDate != null ? Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000 : null;
            //  Long unixDueDate = dueDate != null ? Datetime.newInstance(dueDate, Time.newInstance(0, 0, 0, 0)).getTime() / 1000 : null;

            List<String> bodyParts = new List<String>();
            // bodyParts.add('customer=' + EncodingUtil.urlEncode(quoteList[0].SBQQ__Account__r.Stripe_Customer_ID__c, 'UTF-8'));
            //  bodyParts.add('collection_method=send_invoice');
            //  bodyParts.add('currency=' + quoteList[0].CurrencyIsoCode);
            // bodyParts.add('payment_settings[payment_method_types][0]=card');
            // bodyParts.add('payment_settings[payment_method_types][1]=ach_debit');
            // bodyParts.add('payment_settings[payment_method_types][2]=klarna');
            bodyParts.add('metadata[salesforce_quote_id]=' + quoteList[0].Id);
            bodyParts.add('metadata[salesforce_quote_accepted]=true');

            if (unixStartDate != null) {
                bodyParts.add('effective_at=' + String.valueOf(unixStartDate));
            }
            if (dueOffsetDays != 0) {
                bodyParts.add('due_date=' + String.valueOf(unixDueDate));
            }

            String encodedBody = String.join(bodyParts, '&');
            system.debug('encodedBody--' + encodedBody);
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceid);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(encodedBody);

            Http http3 = new Http();
            HttpResponse res = http3.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('Invoice updated Successfully: ' + responseMap);

                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String paymentIntentId = (String) result.get('payment_intent');

                // Get Subscription ID
                String subscriptionId = (String) result.get('subscription');

                System.debug('Payment Intent ID: ' + paymentIntentId);
                System.debug('Subscription ID: ' + subscriptionId);
                system.debug('result---' + result);
                List<Stripe_Invoice__c> updateStripeInvoice = new List<Stripe_Invoice__c>();
                long effectivedate = (long) result.get('effective_at');
                long stratDate = (long) result.get('period_start');
                long endDate = (long) result.get('period_end');
                long webhoodDelivered = (long) result.get('webhooks_delivered_at');
                long dueDate2 = (long) result.get('due_date');
                Long finalizesAt = (Long) result.get('automatically_finalizes_at');
                String currencyCode = (String) result.get('currency');

                Stripe_Invoice__c invoice = new Stripe_Invoice__c();

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
                invoice.Due_Date__c = toDateTime(dueDate2);
                invoice.Automatically_Finalizes_At__c = toDateTime(finalizesAt);
                invoice.Billing_Reason__c = (String) result.get('billing_reason');
                invoice.CurrencyIsoCode = currencyCode.toUpperCase();
                invoice.Quote_CPQ__c = quoteList[0].id;
                invoice.Account__c = quoteList[0].SBQQ__Account__c;
                invoice.Bill_to_Contact__c = quoteList[0].SBQQ__Account__r.blng__BillToContact__c; //quoteList[0].Bill_To_Contact__c;
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
                updateStripeInvoice.add(invoice);
                upsert updateStripeInvoice Stripe_Invoice_Id__c;
                string getinvoiceID;
                // Now IDs are available in the same list
                for (Stripe_Invoice__c inv : updateStripeInvoice) {
                    getinvoiceID = inv.id;
                    System.debug('Salesforce Id: ' + getinvoiceID);
                    System.debug('External Stripe Invoice Id: ' + inv.Stripe_Invoice_Id__c);
                }
                // Proceed to Invoice Line Items

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
                    line.Stripe_Invoice__c = getinvoiceID;
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
                }
            } else {
                System.debug('Stripe Invoice Error: ' + res.getBody());
                throw new CalloutException('Stripe callout failed: ' + res.getBody());
            }
            // }
        } catch (Exception e) {
            System.debug('Error during invoice creation: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceCallout',
                Apex_Method__c = 'invoiceGeneration',
                Object_Name__c = 'Stripe_Invoice__c',
                User_Email__c = UserInfo.getUserEmail()
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