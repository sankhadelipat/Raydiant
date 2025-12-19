public class CompleteOrderItemsBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Integer totalOrdersProcessed = 0;
    private Integer totalOrderItemsUpdated = 0;
    private Integer totalBatchesProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, SBQQ__Order__c
                FROM Contract
                WHERE Contract_Migration__c = TRUE AND Stripe_Subscription_ID__c != NULL AND SBQQ__Order__c != NULL
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Contract> scope) {
        totalBatchesProcessed++;

        // Collect Order Ids from current batch
        Set<Id> orderIds = new Set<Id>();
        for (Contract c : scope) {
            orderIds.add(c.SBQQ__Order__c);
        }

        System.debug('Batch ' + totalBatchesProcessed + ' - Processing ' + orderIds.size() + ' orders');
        totalOrdersProcessed += orderIds.size();

        if (!orderIds.isEmpty()) {
            // Query Order Line Items that need updating
            List<OrderItem> linesToUpdate = [
                SELECT Id, blng__InvoiceRunProcessingStatus__c, OrderId
                FROM OrderItem
                WHERE OrderId IN :orderIds AND blng__InvoiceRunProcessingStatus__c != 'Completed'
            ];

            System.debug(
                'Batch ' + totalBatchesProcessed + ' - Found ' + linesToUpdate.size() + ' order lines to update'
            );

            // Update the status to Completed
            for (OrderItem item : linesToUpdate) {
                item.blng__InvoiceRunProcessingStatus__c = 'Completed';
            }

            if (!linesToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(linesToUpdate, false);

                // Count successful updates
                Integer successfulUpdates = 0;
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        successfulUpdates++;
                    } else {
                        System.debug('Error updating order item: ' + sr.getErrors()[0].getMessage());
                    }
                }

                totalOrderItemsUpdated += successfulUpdates;
                System.debug(
                    'Batch ' + totalBatchesProcessed + ' - Successfully updated ' + successfulUpdates + ' order lines'
                );
            } else {
                System.debug('Batch ' + totalBatchesProcessed + ' - No order lines needed updating');
            }
        } else {
            System.debug('Batch ' + totalBatchesProcessed + ' - No eligible orders found in this batch');
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('=== Batch Completion Summary ===');
        System.debug('Total batches processed: ' + totalBatchesProcessed);
        System.debug('Total orders processed: ' + totalOrdersProcessed);
        System.debug('Total order items updated: ' + totalOrderItemsUpdated);

        // Optional: Send notification or create log record
        Logger__c logger = new Logger__c(
            Name = 'Complete Order Items Batch - ' + System.today(),
            Message__c = 'Successfully processed ' +
                totalOrdersProcessed +
                ' orders and updated ' +
                totalOrderItemsUpdated +
                ' order items',
            Status__c = 'Success',
            Apex_Class__c = 'CompleteOrderItemsBatch',
            Apex_Method__c = 'finish'
        );
        insert logger;
    }
}