public class StripeInvoiceMigration implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();
    private List<String> stripeInvoiceIds;
    private String initialStartingAfter;
    private String lastProcessedInvoiceId;

    public StripeInvoiceMigration() {
        this.initialStartingAfter = null;
        this.stripeInvoiceIds = new List<String>();
    }

    public StripeInvoiceMigration(String startingAfter) {
        this.initialStartingAfter = startingAfter;
        this.stripeInvoiceIds = new List<String>();
    }

    public Iterable<String> start(Database.BatchableContext bc) {
        // Fetch all invoice IDs from Stripe
        this.stripeInvoiceIds = fetchAllStripeInvoiceIds(this.initialStartingAfter);
        System.debug('Found ' + stripeInvoiceIds.size() + ' invoices to process');
        return stripeInvoiceIds;
    }

    public void execute(Database.BatchableContext bc, List<String> invoiceIds) {
        List<Map<String, Object>> stripeInvoices = new List<Map<String, Object>>();

        for (String invoiceId : invoiceIds) {
            try {
                // Fetch invoice details from Stripe
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/invoices/' + invoiceId);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    stripeInvoices.add(result);
                } else {
                    errorCount++;
                    errorMessages.add('Failed invoice fetch: ' + invoiceId);
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add(e.getMessage());
            }
        }

        for (Map<String, Object> invoiceData : stripeInvoices) {
            try {
                processedCount++;
                processInvoiceData(invoiceData);
                successCount++;
            } catch (Exception e) {
                errorCount++;
                errorMessages.add(e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Stripe Invoice Migration Batch Completed. Processed: ' +
                processedCount +
                ', Success: ' +
                successCount +
                ', Errors: ' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            for (String errorMsg : errorMessages) {
                System.debug(errorMsg);
            }

            Logger__c logger = new Logger__c(
                Name = 'Stripe Invoice Migration Batch',
                Message__c = 'Processed: ' + processedCount + ', Success: ' + successCount + ', Errors: ' + errorCount,
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeInvoiceMigration',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Invoice__c'
            );
            insert logger;
        }

        // If there are more invoices to process, enqueue another batch
        if (this.lastProcessedInvoiceId != null) {
            System.debug('Enqueuing next batch starting after: ' + this.lastProcessedInvoiceId);

            StripeInvoiceMigration nextBatch = new StripeInvoiceMigration(this.lastProcessedInvoiceId);
            Database.executeBatch(nextBatch, 1);
        }
    }

    private List<String> fetchAllStripeInvoiceIds(String initialStartingAfter) {
        List<String> invoiceIds = new List<String>();
        String startingAfter = initialStartingAfter;
        Boolean hasMore = true;
        Integer maxRecords = 200; // Limit to avoid excessive data

        try {
            while (hasMore && invoiceIds.size() < maxRecords) {
                System.debug('Fetching invoices starting after: ' + startingAfter);

                HttpRequest req = new HttpRequest();
                String endpoint = 'https://api.stripe.com/v1/invoices?limit=100';
                if (startingAfter != null) {
                    endpoint += '&starting_after=' + startingAfter;
                }
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> invoices = (List<Object>) response.get('data');

                    if (invoices.isEmpty()) {
                        hasMore = false;
                    } else {
                        for (Object invoiceObj : invoices) {
                            Map<String, Object> invoice = (Map<String, Object>) invoiceObj;
                            String invoiceId = (String) invoice.get('id');
                            invoiceIds.add(invoiceId);
                            startingAfter = invoiceId; // Set for pagination
                        }
                        hasMore = (Boolean) response.get('has_more');
                    }
                } else {
                    hasMore = false;
                    errorMessages.add('Error fetching invoice list: ' + res.getStatusCode() + ' - ' + res.getStatus());
                }

                // Add small delay to avoid rate limiting
                if (hasMore) {
                    Long startTime = DateTime.now().getTime();
                    while (DateTime.now().getTime() - startTime < 1000) {
                        // Busy wait for 1s
                    }
                }
            }
            
            if (hasMore){
                this.lastProcessedInvoiceId = startingAfter;
            } else {
                this.lastProcessedInvoiceId = null;
            }

            System.debug('Fetched ' + invoiceIds.size() + ' invoice IDs from Stripe');
        } catch (Exception e) {
            errorMessages.add('Error fetching invoice IDs: ' + e.getMessage());
            System.debug('Error fetching invoice IDs: ' + e.getStackTraceString());
        }

        return invoiceIds;
    }

    private void processInvoiceData(Map<String, Object> result) {
        try {
            String stripeInvoiceId = (String) result.get('id');
            String customerId = result.containsKey('customer') ? (String) result.get('customer') : null;

            // Extract subscription and quote information from metadata
            String subscriptionId = null;
            String quoteId = null;

            // Check if "parent" exists (for newer Stripe API version)
            if (result.containsKey('parent') && result.get('parent') != null) {
                Map<String, Object> parent = (Map<String, Object>) result.get('parent');
                if (parent.containsKey('subscription_details') && parent.get('subscription_details') != null) {
                    Map<String, Object> subDetails = (Map<String, Object>) parent.get('subscription_details');
                    if (subDetails.containsKey('subscription') && subDetails.get('subscription') != null) {
                        subscriptionId = (String) subDetails.get('subscription');
                    }
                    if (subDetails.containsKey('metadata') && subDetails.get('metadata') != null) {
                        Map<String, Object> metadata = (Map<String, Object>) subDetails.get('metadata');
                        quoteId = metadata.containsKey('salesforce_quote_id')
                            ? (String) metadata.get('salesforce_quote_id')
                            : (metadata.containsKey('salesforce_Quote_id')
                                  ? (String) metadata.get('salesforce_Quote_id')
                                  : null);
                    }
                }
            }

            // Also check direct metadata (for older invoices)
            if (result.containsKey('metadata') && result.get('metadata') != null) {
                Map<String, Object> metadata = (Map<String, Object>) result.get('metadata');
                if (quoteId == null) {
                    quoteId = metadata.containsKey('salesforce_quote_id')
                        ? (String) metadata.get('salesforce_quote_id')
                        : (metadata.containsKey('salesforce_Quote_id')
                              ? (String) metadata.get('salesforce_Quote_id')
                              : null);
                }
            }

            List<Contract> contacts = new List<Contract>();
            if (subscriptionId != null) {
                contacts = [
                    SELECT Id, Stripe_Subscription_ID__c, SBQQ__Quote__c
                    FROM Contract
                    WHERE Stripe_Subscription_ID__c = :subscriptionId
                ];
            }

            List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
            if (!contacts.isEmpty()) {
                quoteList = [
                    SELECT
                        Id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :contacts[0].SBQQ__Quote__c
                ];
            } else if (quoteId != null) {
                quoteList = [
                    SELECT
                        Id,
                        SBQQ__NetAmount__c,
                        SBQQ__Account__c,
                        Is_Stripe_Payment_Done__c,
                        Bill_To_Contact__c,
                        Stripe_Payment_Intent__c,
                        SBQQ__Account__r.blng__BillToContact__c
                    FROM SBQQ__Quote__c
                    WHERE Id = :quoteId
                ];
            }

            // Fetch Account based on Customer ID
            List<Account> accts = [
                SELECT Id, Name, blng__BillToContact__c
                FROM Account
                WHERE Stripe_Customer_ID__c = :customerId
            ];
            System.debug('accts--' + accts);

            // Extract date fields
            Long effectiveAt = result.containsKey('effective_at') ? (Long) result.get('effective_at') : null;
            Long periodStart = result.containsKey('period_start') ? (Long) result.get('period_start') : null;
            Long periodEnd = result.containsKey('period_end') ? (Long) result.get('period_end') : null;
            Long webhooksDeliveredAt = result.containsKey('webhooks_delivered_at')
                ? (Long) result.get('webhooks_delivered_at')
                : null;
            Long dueDate = result.containsKey('due_date') ? (Long) result.get('due_date') : null;
            Long finalizesAt = result.containsKey('automatically_finalizes_at')
                ? (Long) result.get('automatically_finalizes_at')
                : null;
            String currencyCode = (String) result.get('currency');
            String status = (String) result.get('status');
            Decimal prePaymentCreditAmount = result.containsKey('pre_payment_credit_notes_amount')
                ? (Decimal) result.get('pre_payment_credit_notes_amount') / 100
                : 0;
            Decimal postPaymentCreditAmount = result.containsKey('post_payment_credit_notes_amount')
                ? (Decimal) result.get('post_payment_credit_notes_amount') / 100
                : 0;
            String invoiceStatus;
            Id accountId;
            Id billToContactId;

            if (prePaymentCreditAmount + postPaymentCreditAmount > 0) {
                invoiceStatus = 'Credited';
            } else {
                if (status == 'open') {
                    invoiceStatus = 'Open';
                } else if (status == 'paid') {
                    invoiceStatus = 'Paid';
                } else if (status == 'void') {
                    invoiceStatus = 'Void';
                } else if (status == 'uncollectible') {
                    invoiceStatus = 'Uncollectible';
                } else {
                    invoiceStatus = status != null ? status.capitalize() : 'Open';
                }
            }

            if (!accts.isEmpty()) {
                accountId = accts[0].Id;
                billToContactId = accts[0].blng__BillToContact__c;
            } else if (!quoteList.isEmpty()) {
                accountId = quoteList[0].SBQQ__Account__c;
                billToContactId = quoteList[0].Bill_To_Contact__c != null
                    ? quoteList[0].Bill_To_Contact__c
                    : quoteList[0].SBQQ__Account__r.blng__BillToContact__c;
            } else {
                throw new DmlException('No Account found: ' + customerId);
            }
            System.debug('accountId--' + accountId);

            // Create/Update Stripe Invoice record
            Stripe_Invoice__c invoice = new Stripe_Invoice__c();
            invoice.Total_Amount__c = result.containsKey('total') ? ((Decimal) result.get('total')) / 100 : 0;
            invoice.Total_Amount_with_Tax__c = result.containsKey('total_excluding_tax')
                ? ((Decimal) result.get('total_excluding_tax')) / 100
                : 0;
            invoice.Subtotal__c = result.containsKey('subtotal') ? ((Decimal) result.get('subtotal')) / 100 : 0;
            invoice.Amount_Paid__c = result.containsKey('amount_paid')
                ? ((Decimal) result.get('amount_paid')) / 100
                : 0;
            invoice.Amount_Due__c = result.containsKey('amount_due') ? ((Decimal) result.get('amount_due')) / 100 : 0;
            invoice.Amount_Remaining__c = result.containsKey('amount_remaining')
                ? ((Decimal) result.get('amount_remaining')) / 100
                : 0;
            invoice.Amount_Credited__c = prePaymentCreditAmount + postPaymentCreditAmount;
            invoice.Tax_Rate__c = result.containsKey('tax') && result.get('tax') != null
                ? (Decimal) result.get('tax')
                : 0;
            invoice.Due_Date__c = duedate != null ? Date.valueOf(toDateTime(dueDate)) : date.valueof(toDateTime(effectiveAt));
            invoice.Automatically_Finalizes_At__c = toDateTime(finalizesAt);
            invoice.Billing_Reason__c = (String) result.get('billing_reason');
            invoice.CurrencyIsoCode = currencyCode != null ? currencyCode.toUpperCase() : 'USD';
            invoice.Quote_CPQ__c = quoteList.isEmpty() ? null : quoteList[0].Id;
            invoice.Account__c = accountId;
            invoice.Bill_to_Contact__c = billToContactId;
            invoice.Is_Payment_Done__c = status == 'paid' ? true : false;
            invoice.Stripe_Invoice_Id__c = stripeInvoiceId;
            invoice.Invoice_Date__c = effectiveAt != null ? date.valueof(toDateTime(effectiveAt)) : null;
            invoice.Invoice_PDF_URL__c = (String) result.get('invoice_pdf');
            invoice.Invoice_URL__c = (String) result.get('hosted_invoice_url');
            invoice.Name = result.get('number') != null ? (String) result.get('number') : 'SI-DRAFT';
            invoice.Stripe_Invoice_Number__c = (String) result.get('number');
            invoice.Stripe_Invoice_Period_End__c = toDateTime(periodEnd);
            invoice.Stripe_Invoice_Period_Start__c = toDateTime(periodStart);
            invoice.Status__c = invoiceStatus;
            invoice.Webhook_Delivered_At__c = toDateTime(webhooksDeliveredAt);

            // Upsert the invoice
            upsert invoice Stripe_Invoice_Id__c;

            // Process line items
            processInvoiceLineItems(result, invoice.Id);
        } catch (Exception e) {
            throw new InvoiceProcessingException('Error processing invoice data: ' + e.getMessage(), e);
        }
    }

    private void processInvoiceLineItems(Map<String, Object> result, Id invoiceId) {
        try {
            Map<String, Object> lines = (Map<String, Object>) result.get('lines');
            if (lines != null && lines.containsKey('data')) {
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
                    line.Stripe_Invoice__c = invoiceId;
                    line.Stripe_Invoice_line_Item_Id__c = (String) lineItem.get('id');
                    line.Quantity__c = quantity;
                    line.Product_Name__c = (String) lineItem.get('description');

                    // Period handling
                    if (lineItem.containsKey('period')) {
                        Map<String, Object> period = (Map<String, Object>) lineItem.get('period');
                        Long lineStartDate = (Long) period.get('start');
                        Long lineEndDate = (Long) period.get('end');
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
                    upsert lineItems Stripe_Invoice_line_Item_Id__c;
                }
            }
        } catch (Exception e) {
            throw new InvoiceProcessingException('Error processing line items: ' + e.getMessage(), e);
        }
    }

    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstance(unixTs * 1000);
    }

    // Custom exception class for better error handling
    public class InvoiceProcessingException extends Exception {
    }

    /**
     * Run this batch class from Execute Anonymous Window:
     * StripeInvoiceMigration batch = new StripeInvoiceMigration();
     * Database.executeBatch(batch, 1);
     *
     * Always run this batch one chunk at a time to avoid hitting uncommited work pending.
     */
}