public without sharing class DeviceSyncAsset {
    
    @InvocableMethod(label='Sync Asset License Details' description='Sync the License details for the asset for given MAC Address')
    public static void syncDeviceLicenses(List<String> deviceIds){
        
        //This is called from Asset Page Layout Quick action, size should be = 1.
        if ( deviceIds != null && deviceIds.size() == 1 ) {
            System.enqueueJob(new DeviceSyncQueueable(deviceIds));
        }
    }
    
}