public class StripeInvoiceReminderScheduler implements Schedulable {
    private Integer reminderOffsetDays;

    public StripeInvoiceReminderScheduler(Integer reminderOffsetDays) {
        this.reminderOffsetDays = reminderOffsetDays;
    }

    public void execute(SchedulableContext sc) {
        Date today = Date.today();

        List<Stripe_Invoice__c> invoices;

        if (reminderOffsetDays == 7) {
            invoices = [
                SELECT Id
                FROM Stripe_Invoice__c
                WHERE Status__c = 'Open' AND Reminder_7_Day__c = :today
            ];
        } else if (reminderOffsetDays == 15) {
            invoices = [
                SELECT Id
                FROM Stripe_Invoice__c
                WHERE Status__c = 'Open' AND Reminder_15_Day__c = :today
            ];
        } else {
            return;
        }

        if (!invoices.isEmpty()) {
            Set<Id> invoiceIds = new Set<Id>();

            for (Stripe_Invoice__c inv : invoices) {
                invoiceIds.add(inv.Id);
            }

            Database.executeBatch(new StripeInvoiceAdditionalEmailBatch(invoiceIds), 10);
        }
    }

    public static void schedule7DayReminder() {
        System.schedule('Stripe Invoice 7 Day Reminder', '0 0 11 * * ? *', new StripeInvoiceReminderScheduler(7));
    }

    public static void schedule15DayReminder() {
        System.schedule('Stripe Invoice 15 Day Reminder', '0 0 11 * * ? *', new StripeInvoiceReminderScheduler(15));
    }
}