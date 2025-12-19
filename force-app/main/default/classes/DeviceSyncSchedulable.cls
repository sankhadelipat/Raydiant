public without sharing class DeviceSyncSchedulable implements Schedulable {
    
    public DeviceSyncSchedulable() {

    }

    public void execute(SchedulableContext context) {
        system.debug('called Schedulable');
        System.enqueueJob(new DeviceSyncQueueable(1));
    }
}