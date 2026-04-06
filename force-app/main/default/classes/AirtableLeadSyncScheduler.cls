/**
 * AirtableLeadSyncScheduler
 * Runs on a CRON schedule and enqueues the queueable.
 */
global class AirtableLeadSyncScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new AirtableLeadSyncQueueable(null, false, null));
    }
}