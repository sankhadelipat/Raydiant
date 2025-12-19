public class StripeDeleteSubscriptionItemsQueueable implements Queueable {
    private String stripeSubscriptionId;
    private List<String> deletedItemIds;

    public StripeDeleteSubscriptionItemsQueueable(String stripeSubscriptionId, List<String> deletedItemIds) {
        this.stripeSubscriptionId = stripeSubscriptionId;
        this.deletedItemIds = deletedItemIds;
    }

    public void execute(QueueableContext context) {
        System.debug('Processing deletion for subscription: ' + stripeSubscriptionId);
        System.debug('Items to delete: ' + deletedItemIds);

        // Find the parent contract
        List<Contract> parentContracts = [
            SELECT Id, Stripe_Subscription_ID__c
            FROM Contract
            WHERE Stripe_Subscription_ID__c = :stripeSubscriptionId
        ];

        if (parentContracts.isEmpty()) {
            System.debug('No parent contract found for Stripe subscription: ' + stripeSubscriptionId);
            return;
        }

        Id contractId = parentContracts[0].Id;

        // Find and deactivate the child subscription items
        List<SBQQ__Subscription__c> subscriptionsToDelete = [
            SELECT Id, Stripe_Subscription_ID__c, SBQQ__Contract__c
            FROM SBQQ__Subscription__c
            WHERE Stripe_Subscription_ID__c IN :deletedItemIds AND SBQQ__Contract__c = :contractId
        ];

        System.debug('Found ' + subscriptionsToDelete.size() + ' subscription items to deactivate');

        if (!subscriptionsToDelete.isEmpty()) {
            delete subscriptionsToDelete;
            System.debug(
                'Successfully deleted ' +
                    subscriptionsToDelete.size() +
                    ' subscription items for contract: ' +
                    contractId
            );

            // Log the deletion
            Logger__c logger = new Logger__c(
                Name = 'Subscription Items Deleted - ' + System.now(),
                Message__c = 'Deleted ' +
                    subscriptionsToDelete.size() +
                    ' subscription items from contract ' +
                    contractId +
                    '. Stripe IDs: ' +
                    String.join(deletedItemIds, ', '),
                Status__c = 'success',
                Apex_Class__c = 'StripeDeleteSubscriptionItemsQueueable',
                Apex_Method__c = 'execute'
            );
            insert logger;
        }
    }
}