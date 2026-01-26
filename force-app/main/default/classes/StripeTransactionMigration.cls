public class StripeTransactionMigration implements Database.Batchable<Integer>, Database.AllowsCallouts, Database.Stateful {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    // Stripe pagination state
    private String startingAfter;
    private Boolean hasMore = true;

    // Metrics
    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();

    // Constructor
    public StripeTransactionMigration() {
        this.startingAfter = null;
        this.hasMore = true;
    }

    public StripeTransactionMigration(String startingAfter) {
        this.startingAfter = startingAfter;
        this.hasMore = true;
    }

    public Iterable<Integer> start(Database.BatchableContext bc) {
        // Dummy iterable — execution controlled by Stripe pagination
        return new List<Integer>{ 1 };
    }

    public void execute(Database.BatchableContext bc, List<Integer> scope) {
        if (!hasMore) {
            return;
        }

        List<Stripe_Payment_Transaction__c> transactions = new List<Stripe_Payment_Transaction__c>();

        try {
            String endpoint = 'https://api.stripe.com/v1/payment_intents?expand[]=data.latest_charge&limit=40';

            if (startingAfter != null) {
                endpoint += '&starting_after=' + startingAfter;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                throw new CalloutException('Stripe PaymentIntent list failed: ' + res.getBody());
            }

            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> intents = (List<Object>) response.get('data');
            hasMore = (Boolean) response.get('has_more');

            for (Object obj : intents) {
                processedCount++;

                Map<String, Object> intent = (Map<String, Object>) obj;

                try {
                    String intentId = (String) intent.get('id');
                    startingAfter = intentId;

                    String status = (String) intent.get('status');
                    String customerId = (String) intent.get('customer');
                    String paymentMethodId = (String) intent.get('payment_method');
                    String currencyCode = (String) intent.get('currency');
                    Long createdTs = (Long) intent.get('created');
                    Decimal amount = (Decimal) intent.get('amount') / 100;
                    Decimal amountPaid = (Decimal) intent.get('amount_received') / 100;

                    Map<String, Object> lastPaymentError = (Map<String, Object>) intent.get('last_payment_error');
                    System.debug('lastPaymentError--' + lastPaymentError);
                    String errorMessage = lastPaymentError != null ? (String) lastPaymentError.get('message') : null;
                    String errorCode = lastPaymentError != null ? (String) lastPaymentError.get('code') : null;
                    String declineCode = lastPaymentError != null
                        ? (String) lastPaymentError.get('decline_code')
                        : null;

                    Map<String, Object> chargeData = (Map<String, Object>) intent.get('latest_charge');
                    System.debug('chargeData--' + chargeData);
                    String latestChargeId = chargeData != null ? (String) chargeData.get('id') : null;
                    String reciptUrl = chargeData != null ? (String) chargeData.get('receipt_url') : null;

                    String finalStatus;
                    if (status == 'succeeded') {
                        finalStatus = 'Succeeded';
                    } else if (status == 'canceled') {
                        finalStatus = 'Canceled';
                    } else {
                        finalStatus = 'Failed';
                    }

                    List<Account> accts = [
                        SELECT Id
                        FROM Account
                        WHERE Stripe_Customer_ID__c = :customerId
                        LIMIT 1
                    ];
                    if (!accts.isEmpty()) {
                        System.debug('accountId--' + accts[0].Id);
                    } else {
                        System.debug('No Account found for Customer ID: ' + customerId);
                        successCount++;
                        continue;
                    }

                    Stripe_Payment_Transaction__c pt = new Stripe_Payment_Transaction__c();

                    pt.Stripe_PaymentIntent_ID__c = intentId;
                    pt.Amount__c = amount;
                    pt.Amount_Paid__c = amountPaid;
                    pt.CurrencyIsoCode = currencyCode != null ? currencyCode.toUpperCase() : null;
                    pt.Stripe_Transaction_Status__c = status;
                    pt.Status__c = finalStatus;
                    pt.Payment_Date__c = createdTs != null
                        ? Date.valueOf(Datetime.newInstance(createdTs * 1000))
                        : null;
                    pt.Account__c = accts[0].Id;

                    if (chargeData != null) {
                        pt.Stripe_Charge_ID__c = latestChargeId;
                        pt.Receipt_URL__c = reciptUrl;
                    }

                    if (lastPaymentError != null) {
                        pt.Error_Message__c = errorMessage;
                        pt.Error_Code__c = errorCode;
                        pt.Decline_Code__c = declineCode;
                    }

                    // Payment Method linking
                    if (paymentMethodId != null) {
                        List<Stripe_Payment_Method__c> paymentMethods = [
                            SELECT Id
                            FROM Stripe_Payment_Method__c
                            WHERE Stripe_Payment_Method_ID__c = :paymentMethodId
                            LIMIT 1
                        ];
                        if (!paymentMethods.isEmpty()) {
                            pt.Stripe_Payment_Method__c = paymentMethods[0].Id;
                        }
                    }

                    transactions.add(pt);
                    successCount++;
                } catch (Exception innerEx) {
                    errorCount++;
                    errorMessages.add('Intent parse failed: ' + innerEx.getMessage());
                }
            }

            if (!transactions.isEmpty()) {
                upsert transactions Stripe_PaymentIntent_ID__c;
            }
        } catch (Exception ex) {
            errorCount++;
            errorMessages.add(ex.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'Stripe PaymentIntent Migration Complete | ' +
                'Processed=' +
                processedCount +
                ', Success=' +
                successCount +
                ', Errors=' +
                errorCount
        );

        if (!errorMessages.isEmpty()) {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Transaction Migration Error',
                Message__c = errorMessages.size() + ' errors occurred during Stripe Transaction migration.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeTransactionMigration',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Payment_Transaction__c'
            );
            insert logger;
        } else {
            Logger__c logger = new Logger__c(
                Name = 'Stripe Transaction Migration Complete Upto: ' + startingAfter,
                Message__c = 'Stripe Transaction migration completed successfully. Processed: ' +
                    processedCount +
                    ', Success: ' +
                    successCount +
                    ', Errors: ' +
                    errorCount,
                StackTrace__c = '',
                Status__c = 'Success',
                Apex_Class__c = 'StripeTransactionMigration',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Stripe_Payment_Transaction__c'
            );
            insert logger;
        }

        // Chain next batch if more data is available
        if (hasMore && startingAfter != null) {
            StripeTransactionMigration nextBatch = new StripeTransactionMigration(startingAfter);
            Database.executeBatch(nextBatch, 1);
        }
    }

    /**
     * Run this batch class from Execute Anonymous Window:
     * StripeTransactionMigration batch = new StripeTransactionMigration();
     * Database.executeBatch(batch, 1);
     *
     * Always run this batch one chunk at a time to avoid SOQL limit.
     */
}