public class StripeSubscriptionAutoRenewScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        StripeSubscriptionAutoRenewal batch = new StripeSubscriptionAutoRenewal();
        Database.executeBatch(batch, 200);
    }

    public static void scheduleJob() {
        String cronExp = '0 0 18 * * ? *'; // Every day at 6 PM
        String jobName = 'Stripe Subscription Auto Renew Scheduler';
        StripeSubscriptionAutoRenewScheduler scheduler = new StripeSubscriptionAutoRenewScheduler();
        System.schedule(jobName, cronExp, scheduler);
    }
}
