public class AccountBUCScheduler implements Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new AccountBUCBatchJob(), 200);
    }
}