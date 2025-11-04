public class StripeSubscriptionSync {

    public class EventInput {
        @InvocableVariable(required=true)
        public Id stripeEventId;

        @InvocableVariable(required=true)
        public Id accountId;
    }

    @InvocableMethod(label='Sync Stripe Subscriptions to Salesforce')
    public static void sync(List<EventInput> inputs) {
        for (EventInput input : inputs) {
            try {
                stripeGC__Stripe_Event__c event = [
                    SELECT Id, stripeGC__Request_Body__c, stripeGC__Stripe_Event_Id__c
                    FROM stripeGC__Stripe_Event__c
                    WHERE Id = :input.stripeEventId
                    LIMIT 1
                ];

                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(event.stripeGC__Request_Body__c);
                if (payload == null || !payload.containsKey('data')) continue;

                Map<String, Object> data = (Map<String, Object>) payload.get('data');
                Map<String, Object> subscription = (Map<String, Object>) data.get('object');
                if (subscription == null || subscription.get('id') == null) continue;

                String subscriptionId = (String) subscription.get('id');
                String status = (String) subscription.get('status');
                Map<String, Object> metadata = (Map<String, Object>) subscription.get('metadata');
                Map<String, Object> itemsWrapper = (Map<String, Object>) subscription.get('items');

                List<Object> items = new List<Object>();
                if (itemsWrapper != null && itemsWrapper.containsKey('data')) {
                    items = (List<Object>) itemsWrapper.get('data');
                }

                Id accountId = input.accountId;

                if (metadata != null && metadata.containsKey('Salesforce_Account_Id')) {
                    String metadataAccountId = (String) metadata.get('Salesforce_Account_Id');
                    if (!String.isBlank(metadataAccountId)) {
                        accountId = metadataAccountId;
                    }
                }

                List<SBQQ__Subscription__c> recordsToInsert = new List<SBQQ__Subscription__c>();

                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;

                    Integer quantity = item.containsKey('quantity') ? (Integer) item.get('quantity') : null;
                    Map<String, Object> price = item.containsKey('price') ? (Map<String, Object>) item.get('price') : null;
                    String priceId = price != null ? (String) price.get('id') : null;
                    Integer unitAmount = price != null ? (Integer) price.get('unit_amount') : null;

                    Long cps = item.containsKey('current_period_start') ? (Long) item.get('current_period_start') : null;
                    Long cpe = item.containsKey('current_period_end') ? (Long) item.get('current_period_end') : null;

                    Id productId = findProductId(priceId);
                    System.debug('--- Subscription Item ---');
                    System.debug('Quantity: ' + quantity);
                    System.debug('Price ID: ' + priceId);
                    System.debug('Unit Amount: ' + unitAmount);
                    System.debug('Product ID: ' + productId);

                    if (productId == null) {
                        System.debug('Skipping item because product lookup failed.');
                        continue;
                    }

                    SBQQ__Subscription__c s = new SBQQ__Subscription__c();
                    s.Stripe_Subscription_ID__c = subscriptionId;
                    s.Stripe_Status__c = status;
                    s.Stripe_Interval__c = 'month';
                    s.SBQQ__Quantity__c = quantity;
                    s.SBQQ__CustomerPrice__c = unitAmount != null ? Decimal.valueOf(unitAmount).setScale(2) / 100 : null;
                    s.SBQQ__Product__c = productId;
                    s.Stripe_Event__c = event.Id;
                    s.Created_From_Stripe__c = true;
                    s.SBQQ__Account__c = accountId;

                    s.SBQQ__SegmentStartDate__c = toDateTime(cps) != null ? toDateTime(cps).date() : null;
                    s.SBQQ__SegmentEndDate__c = toDateTime(cpe) != null ? toDateTime(cpe).date() : null;

                    Long startDate = subscription.containsKey('start_date') ? (Long) subscription.get('start_date') : null;
                    Long cancelAt = subscription.containsKey('cancel_at') ? (Long) subscription.get('cancel_at') : null;
                    Long canceledAt = subscription.containsKey('canceled_at') ? (Long) subscription.get('canceled_at') : null;

                    s.SBQQ__SubscriptionStartDate__c = toDateTime(startDate) != null ? toDateTime(startDate).date() : null;
                    s.SBQQ__SubscriptionEndDate__c = toDateTime(cancelAt) != null ? toDateTime(cancelAt).date() : null;
                    s.SBQQ__TerminatedDate__c = toDateTime(canceledAt) != null ? toDateTime(canceledAt).date() : null;

                    recordsToInsert.add(s);
                }

                if (!recordsToInsert.isEmpty()) {
                    insert recordsToInsert;
                    System.debug('Inserted ' + recordsToInsert.size() + ' SBQQ__Subscription__c records');
                } else {
                    System.debug('No subscription records to insert');
                }
            } catch (Exception e) {
                System.debug('Error in StripeSubscriptionSync: ' + e.getMessage());
            }
        }
    }

    private static Id findProductId(String stripePriceId) {
        if (String.isBlank(stripePriceId)) return null;
        List<Product2> products = [
            SELECT Id FROM Product2
            WHERE Stripe_Price_ID__c = :stripePriceId
            LIMIT 1
        ];
        return products.isEmpty() ? null : products[0].Id;
    }

    private static Datetime toDateTime(Long unixTs) {
        if (unixTs == null) return null;
        return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds((Integer)unixTs);
    }
}