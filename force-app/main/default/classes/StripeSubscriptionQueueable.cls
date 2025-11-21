public class StripeSubscriptionQueueable implements Queueable, Database.AllowsCallouts {
    String responseBody;

    public StripeSubscriptionQueueable(String responseBody) {
        this.responseBody = responseBody;
    }

    public void execute(QueueableContext context) {
        StripeSubscriptionScheduler.createManualSubscrition(responseBody);
    }
}
