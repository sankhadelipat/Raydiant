global class UpdatePaymentMethodInfoBatchSche implements Schedulable {
 global void execute(SchedulableContext sc) {
      UpdatePaymentMethodInfoBatch b = new UpdatePaymentMethodInfoBatch(); 
      database.executebatch(b);
   }
}