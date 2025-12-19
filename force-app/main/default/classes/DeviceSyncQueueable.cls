public without sharing class DeviceSyncQueueable implements Queueable, Database.AllowsCallouts {
    
    public Integer pageNumber;
    public List<String> deviceIds = new List<String>();
    public Id accountId;
    public String syncMode;

    public DeviceSyncQueueable(Integer currentPage) {
        this.pageNumber = currentPage;
        this.syncMode = DeviceSyncUtility.SYNC_MODE_NIGHTLY;
    }

    public DeviceSyncQueueable(List<String> deviceIdList) {
        if ( deviceIdList != null && deviceIdList.size() > 0 ) {
            this.deviceIds.addAll(deviceIdList);
            this.syncMode = DeviceSyncUtility.SYNC_MODE_RESYNC;
        }
    }

    public DeviceSyncQueueable(List<String> deviceIdList, Id accountIdVar) {
        if ( deviceIdList != null && deviceIdList.size() > 0 ) {
            this.deviceIds.addAll(deviceIdList);
            this.accountId = accountIdVar;
            this.syncMode = DeviceSyncUtility.SYNC_MODE_RESYNC;
        }
    }

    public void execute(QueueableContext context) {
        system.debug('called queueable');
        
        if ( syncMode == DeviceSyncUtility.SYNC_MODE_NIGHTLY && pageNumber > 0 ) {
            DeviceSyncUtility.syncDevices(pageNumber);
        } else if ( syncMode == DeviceSyncUtility.SYNC_MODE_RESYNC && deviceIds.size() > 0 ) {
            if ( accountId == null ) {
                DeviceSyncUtility.syncDevices(deviceIds);
            } else {
                DeviceSyncUtility.syncDevices(deviceIds,accountId);
            }            
        }        
    }
}