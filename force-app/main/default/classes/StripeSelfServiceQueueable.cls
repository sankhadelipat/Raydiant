public class StripeSelfServiceQueueable implements Queueable, Database.AllowsCallouts {
    String responseBody;

    public StripeSelfServiceQueueable(String responseBody) {
        this.responseBody = responseBody;
    }

    public void execute(QueueableContext context) {
        StripeSubscriptionScheduler.createSubscriptionWithoutQuote(responseBody);
    }
}
