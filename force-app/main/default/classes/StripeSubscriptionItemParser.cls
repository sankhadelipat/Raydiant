public with sharing class StripeSubscriptionItemParser {

    public class SubscriptionItemWrapper {
        @InvocableVariable(label='Stripe Product ID')
        public String productId;

        @InvocableVariable(label='Stripe Price ID')
        public String priceId;

        @InvocableVariable(label='Quantity')
        public Decimal quantity;

        @InvocableVariable(label='Stripe Subscription ID')
        public String subscriptionId;
    }

    @InvocableMethod(label='Parse Stripe Subscription Items from Event')
    public static List<SubscriptionItemWrapper> parseItems(List<Id> eventIds) {
        List<SubscriptionItemWrapper> results = new List<SubscriptionItemWrapper>();

        for (Id eventId : eventIds) {
            // Step 1: Fetch event + raw JSON
            stripeGC__Stripe_Event__c evt = [
                SELECT stripeGC__Request_Body__c 
                FROM stripeGC__Stripe_Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];

            if (String.isNotBlank(evt.stripeGC__Request_Body__c)) {
                try {
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(evt.stripeGC__Request_Body__c);
                    Map<String, Object> subscription = (Map<String, Object>) body.get('data');
                    Map<String, Object> objectData = (Map<String, Object>) subscription.get('object');
                    String subId = String.valueOf(objectData.get('id'));

                    Map<String, Object> itemsWrapper = (Map<String, Object>) objectData.get('items');
                    List<Object> items = (List<Object>) itemsWrapper.get('data');

                    for (Object o : items) {
                        Map<String, Object> item = (Map<String, Object>) o;
                        Decimal qty = (item.containsKey('quantity')) ? Decimal.valueOf(String.valueOf(item.get('quantity'))) : null;

                        Map<String, Object> price = (Map<String, Object>) item.get('price');
                        String priceId = String.valueOf(price.get('id'));

                        Object productRaw = price.get('product');
                        String productId;
                        if (productRaw instanceof String) {
                            productId = (String) productRaw;
                        } else if (productRaw instanceof Map<String, Object>) {
                            productId = String.valueOf(((Map<String, Object>)productRaw).get('id'));
                        } else {
                            productId = null;
                        }

                        SubscriptionItemWrapper wrapper = new SubscriptionItemWrapper();
                        wrapper.productId = productId;
                        wrapper.priceId = priceId;
                        wrapper.quantity = qty;
                        wrapper.subscriptionId = subId;
                        results.add(wrapper);
                    }

                } catch (Exception ex) {
                    System.debug('❌ JSON Parse Error: ' + ex.getMessage());
                }
            }
        }

        return results;
    }
}