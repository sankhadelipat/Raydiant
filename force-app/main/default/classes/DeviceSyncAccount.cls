public without sharing class DeviceSyncAccount {
    
    @InvocableMethod(label='Sync Device Licenses of given Account' description='Sync the License details for all the assets for given Account')
    public static void syncAccountDeviceLicenses(List<Id> accountIds){
        
        //This is called from Account Page Layout Quick action, size should be = 1.
        if ( accountIds != null && accountIds.size() == 1 ) {
            DeviceSyncUtility.syncDevices(accountIds);
        }
    }
    
}