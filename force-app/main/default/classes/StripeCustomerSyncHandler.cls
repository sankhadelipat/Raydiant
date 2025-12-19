public class StripeCustomerSyncHandler {
    // List of fields to monitor for changes
    private static final Set<String> MONITORED_FIELDS = new Set<String>{
        'Name',
        'Phone',
        'Bill_To_Email__c',
        'Bill_To_Contact_Phone__c',
        'BillingStreet',
        'BillingCity',
        'BillingState',
        'BillingPostalCode',
        'BillingCountry',
        'ShippingStreet',
        'ShippingCity',
        'ShippingState',
        'ShippingPostalCode',
        'ShippingCountry'
    };

    public static void syncCustomers(Map<Id, Account> oldMap, Map<Id, Account> newMap) {
        Set<Id> accountIds = new Set<Id>();

        for (Id accountId : newMap.keySet()) {
            Account newAccount = newMap.get(accountId);
            Account oldAccount = oldMap.get(accountId);

            Boolean needsSync = false;

            // Check if any monitored fields have changed
            for (String fieldName : MONITORED_FIELDS) {
                if (newAccount.get(fieldName) != oldAccount.get(fieldName)) {
                    needsSync = true;
                    break;
                }
            }

            if (needsSync) {
                accountIds.add(accountId);
            }

            if (!accountIds.isEmpty()) {
                // Enqueue the Queueable job for updating Stripe customers
                System.enqueueJob(new StripeCustomerSyncQueueable('UPDATE', accountIds));
            }
        }
    }
}