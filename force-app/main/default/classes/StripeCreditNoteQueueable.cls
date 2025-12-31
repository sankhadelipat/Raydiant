public class StripeCreditNoteQueueable implements Queueable, Database.AllowsCallouts {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    private String creditNoteId;
    private String stripeInvoiceId;

    public StripeCreditNoteQueueable(String creditNoteId, String stripeInvoiceId) {
        this.creditNoteId = creditNoteId;
        this.stripeInvoiceId = stripeInvoiceId;
    }

    public void execute(QueueableContext context) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/credit_notes/' + creditNoteId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> cnData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('Credit Note Data: ' + cnData);

                Map<String, Object> lines = (Map<String, Object>) cnData.get('lines');
                List<Object> lineData = (List<Object>) lines.get('data');
                String customerId = (String) cnData.get('customer');

                // Extract relevant fields
                String reason = cnData.get('reason') != null ? String.valueOf(cnData.get('reason')) : 'other';
                Long effectiveAtUnix = (Long) cnData.get('effective_at');
                Long voidedAtUnix = cnData.get('voided_at') != null ? (Long) cnData.get('voided_at') : null;
                Date effectiveDate = effectiveAtUnix != null ? toDateTime(effectiveAtUnix).date() : null;
                Date voidedDate = voidedAtUnix != null ? toDateTime(voidedAtUnix).date() : null;
                Decimal totalAmount = cnData.get('total') != null ? (Decimal) cnData.get('total') / 100 : 0;
                Decimal subtotal = cnData.get('subtotal') != null ? (Decimal) cnData.get('subtotal') / 100 : 0;
                Decimal outOfBandAmount = cnData.get('out_of_band_amount') != null
                    ? (Decimal) cnData.get('out_of_band_amount') / 100
                    : 0;
                Decimal postPaymentAmount = cnData.get('post_payment_amount') != null
                    ? (Decimal) cnData.get('post_payment_amount') / 100
                    : 0;
                Decimal prePaymentAmount = cnData.get('pre_payment_amount') != null
                    ? (Decimal) cnData.get('pre_payment_amount') / 100
                    : 0;
                Id accountId;
                Id invoiceId;

                // Fetch Customer
                List<Account> customers = [
                    SELECT Id, Name
                    FROM Account
                    WHERE Stripe_Customer_ID__c = :customerId
                ];
                System.debug('Fetched Customers: ' + customers);

                if (!customers.isEmpty()) {
                    accountId = customers[0].Id;
                } else {
                    System.debug('Customer not found for ID: ' + customerId);
                    throw new DmlException('Customer not found for ID: ' + customerId);
                }

                // Fetch Invoice
                List<Stripe_Invoice__c> invoices = [
                    SELECT Id, Status__c
                    FROM Stripe_Invoice__c
                    WHERE Stripe_Invoice_ID__c = :stripeInvoiceId
                ];
                System.debug('Fetched Invoices: ' + invoices);

                if (!invoices.isEmpty()) {
                    invoiceId = invoices[0].Id;
                } else {
                    System.debug('Invoice not found for ID: ' + stripeInvoiceId);
                    throw new DmlException('Invoice not found for ID: ' + stripeInvoiceId);
                }

                // Create or Update Credit Note Record
                Stripe_Credit_Note__c creditNote = new Stripe_Credit_Note__c();
                creditNote.Name = (String) cnData.get('number');
                creditNote.Stripe_Credit_Note_ID__c = creditNoteId;
                creditNote.Memo__c = (String) cnData.get('memo');
                creditNote.Type__c = (String) cnData.get('type');
                creditNote.PDF_URL__c = (String) cnData.get('pdf');
                creditNote.Status__c = (String) cnData.get('status');
                creditNote.Reason__c = reason;
                creditNote.Account__c = accountId;
                creditNote.Stripe_Invoice__c = invoiceId;
                creditNote.Subtotal__c = subtotal;
                creditNote.Total_Amount__c = totalAmount;
                creditNote.Post_Payment_Amount__c = postPaymentAmount;
                creditNote.Pre_Payment_Amount__c = prePaymentAmount;
                creditNote.Out_of_band_Amount__c = outOfBandAmount;
                creditNote.Effective_Date__c = effectiveDate;
                creditNote.Voided_At__c = voidedDate;

                upsert creditNote Stripe_Credit_Note_ID__c;

                Id creditNoteRecordId = creditNote.Id;
                System.debug('Credit Note processed successfully: ' + creditNote);

                // Create Line Items
                List<Stripe_Credit_Note_Line_Item__c> lineItemsToInsert = new List<Stripe_Credit_Note_Line_Item__c>();

                // Collect all invoice line items
                Set<String> invoiceLineItemIds = new Set<String>();
                for (Object lineObj : lineData) {
                    Map<String, Object> lineMap = (Map<String, Object>) lineObj;
                    String invoiceLineItemId = (String) lineMap.get('invoice_line_item');
                    if (invoiceLineItemId != null) {
                        invoiceLineItemIds.add(invoiceLineItemId);
                    }
                }

                // Fetch all related invoice line items in one query
                Map<String, Stripe_Invoice_Line_Item__c> invoiceLineItemMap = new Map<String, Stripe_Invoice_Line_Item__c>();
                if (!invoiceLineItemIds.isEmpty()) {
                    for (Stripe_Invoice_Line_Item__c ili : [
                        SELECT Id, Stripe_Invoice_Line_Item_ID__c, Name
                        FROM Stripe_Invoice_Line_Item__c
                        WHERE Stripe_Invoice_Line_Item_ID__c IN :invoiceLineItemIds
                    ]) {
                        invoiceLineItemMap.put(ili.Stripe_Invoice_Line_Item_ID__c, ili);
                    }
                }
                System.debug('Fetched Invoice Line Items: ' + invoiceLineItemMap);

                // Create credit note line items
                for (Object item : lineData) {
                    Map<String, Object> lineItem = (Map<String, Object>) item;

                    String creditNoteLineItemId = (String) lineItem.get('id');
                    String invoiceLineItemId = (String) lineItem.get('invoice_line_item');
                    Decimal amount = lineItem.get('amount') != null ? (Decimal) lineItem.get('amount') / 100 : 0;
                    Decimal unitAmount = lineItem.get('unit_amount') != null
                        ? (Decimal) lineItem.get('unit_amount') / 100
                        : 0;
                    Integer quantity = lineItem.get('quantity') != null ? (Integer) lineItem.get('quantity') : 0;
                    Stripe_Invoice_Line_Item__c relatedInvoiceLineItem = invoiceLineItemMap.get(invoiceLineItemId);

                    Stripe_Credit_Note_Line_Item__c cnLineItem = new Stripe_Credit_Note_Line_Item__c();
                    cnLineItem.Name = relatedInvoiceLineItem != null
                        ? relatedInvoiceLineItem.Name
                        : 'CN-LI-' + creditNoteLineItemId;
                    cnLineItem.Stripe_Credit_Note__c = creditNoteRecordId;
                    cnLineItem.Stripe_Invoice_Line_Item__c = relatedInvoiceLineItem != null
                        ? relatedInvoiceLineItem.Id
                        : null;
                    cnLineItem.Stripe_Credit_Note_Line_Item_ID__c = creditNoteLineItemId;
                    cnLineItem.Description__c = (String) lineItem.get('description');
                    cnLineItem.Quantity__c = quantity;
                    cnLineItem.Amount__c = amount;
                    cnLineItem.Unit_Amount__c = unitAmount;

                    lineItemsToInsert.add(cnLineItem);
                }

                if (!lineItemsToInsert.isEmpty()) {
                    upsert lineItemsToInsert Stripe_Credit_Note_Line_Item_ID__c;
                    System.debug('Upserted Credit Note Line Items: ' + lineItemsToInsert);
                }
            } else {
                System.debug('Failed to retrieve credit note: ' + res.getBody());
                throw new CalloutException('Failed to retrieve credit note: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error processing credit note: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Credit Note Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeCreditNoteQueueable',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Credit_Note__c'
            );
            insert logger;
        }
    }

    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null)
            return null;
        return Datetime.newInstance(unixTs * 1000);
    }
}