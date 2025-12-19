public without sharing class DeviceSyncUtility {
    
    private static Id accountVarId;
    private static Id assetVarId;
    
    public static final String DEVICE_SYNC_ENDPOINT_NAME = 'Device-Report';
    public static final String SYNC_MODE_NIGHTLY = 'Nightly';
    public static final String SYNC_MODE_RESYNC = 'Resync';

    public static final String DEVICE_SYNC_HEADER_KEY = 'Mira-APIKey';
    public static final String DEVICE_SYNC_PAGE_SIZE_KEY = 'page_size';
    public static final String DEVICE_SYNC_PAGE_NUMBER_KEY = 'page';
    public static final String DEVICE_SYNC_BY_DEVICE_ID_KEY = 'devices';

    public static final Integer DEVICE_SYNC_PAGE_SIZE = 200;        //Minimum = 1, Maximum = 1000
    
    public static final String DEVICE_NOT_FOUND_SALESFORCE_MESSAGE = 'Device not found in Salesforce.';
    public static final String DEVICE_NOT_FOUND_EXTERNAL_MESSAGE = 'Device not found in external system.';
    public static final String DEVICE_SYNC_SUCCESSFUL_MESSAGE = 'Device synced successfully.';
    public static final String DEVICE_SYNC_UNSUCCESSFUL_MESSAGE = 'Device synced failed.';

    public static string apiAction;
    public static API_Log__c log;
    public static String deviceSyncInstance { get {
        
        if ( String.isBlank(deviceSyncInstance) ) {
            if ( GeneralUtility.isProdEnvironment ) {
                deviceSyncInstance = 'Production';
            } else {
                deviceSyncInstance = 'Staging';
            }
        }
        
        return deviceSyncInstance;
    } set; }


    /** Methods Begin Here */

    public static void syncDevices(Integer pageNumber) {
        apiAction = 'Nightly Sync Job';
        syncDevices(pageNumber, null);
    }

    public static void syncDevices(List<String> deviceIds) {
        apiAction = 'Device Sync';
        Boolean deviceSyncError = false;
        String deviceSyncErrorMessage;

        //Here Device Id size should be = 1.
        if ( deviceIds != null && deviceIds.size() == 1 ) {

            deviceIds = convertDeviceToLowerCase(deviceIds);

            List<Asset> assetRecord = [SELECT Id FROM Asset WHERE F_52_MACAddress__c =: deviceIds[0]];
            if ( assetRecord.size() == 1 ) {
                assetVarId = assetRecord[0].Id;
                syncDevices(null, deviceIds);
            } else {
                deviceSyncError = true;
                deviceSyncErrorMessage = 'No Asset / Multiple assets exists against given MAC ID: ' + String.join(deviceIds, ',');
            }
        } else {
            deviceSyncError = true;
            deviceSyncErrorMessage = 'Found No Device Id / Found Multiple Device IDs when expecting one: '+ String.join(deviceIds, ',');
        }
        if ( deviceSyncError ) {
            try {
                API_Log__c logRecord = new APILogUtility(null, apiAction, 'DeviceSyncUtility').apiLogRecord;
                logRecord.Callout_Processing_Result__c = deviceSyncErrorMessage;
                logRecord.Has_Errors__c = true;
                logRecord.Direction__c = 'Outbound';
                insert logRecord;
            } catch (Exception ex) {
                API_Log__c backupLog = new API_Log__c();
                backupLog.Tag__c = 'HTTP Callout LOG ERROR BACKUP';
                backupLog.Class_Name__c = 'DeviceSyncUtility';
                backupLog.Action__c = apiAction;
                backupLog.Errors__c = 'line ' + ex.getLineNumber() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString();
                backupLog.Has_Errors__c = true;
                backupLog.Direction__c = 'Outbound';
                insert backupLog;
            }
        }        
    }

    public static void syncDevices(List<String> deviceIds, Id accountId) {
        apiAction = 'Account Device Sync';
        accountVarId = accountId;
        if ( deviceIds != null && deviceIds.size()> 0 ) {
            deviceIds = convertDeviceToLowerCase(deviceIds);
        }        
        syncDevices(null, deviceIds);
    }

    private static void syncDevices(Integer pageNumber, List<String> deviceIds) {
        log = new APILogUtility(null, apiAction, 'DeviceSyncUtility').apiLogRecord;   
        Boolean hasError = false;   
        String endpoint; 
        String method;
        Map<String,String> headers = new Map<String,String>();
        Map<String,String> params = new Map<String,String>();
        HTTPRequest request;
        HTTPResponse response;
        List<Exception> exceptionList = new List<Exception>();
        List<String> deviceIdsToSend = new List<String>();

        try {
            //1. Fetch Endpoint Property. 
            Endpoint_Properties__c deviceSyncProperty = HTTPCalloutUtility.fetchEndpointProperty(DEVICE_SYNC_ENDPOINT_NAME,deviceSyncInstance);
            if ( deviceSyncProperty == null ) {
                throw new HttpCalloutException('No Endpoint found for Device-Sync');
            }

            //2. Get Endpoint.
            endpoint = deviceSyncProperty.Endpoint_URL__c;

            //3. Request Method
            method = 'GET';

            //4. Form Headers
            headers = fetchDeviceSyncHeaders(deviceSyncProperty);

            //5. Form Params
                //First, chunk deviceIds to size of DEVICE_SYNC_PAGE_SIZE.
            if ( deviceIds != null && deviceIds.size() > 0 ) {
                if ( deviceIds.size() > DEVICE_SYNC_PAGE_SIZE ) {
                    deviceIdsToSend = chunkDeviceBatch(deviceIds);
                    deviceIds = remainingDeviceBatches(deviceIds);
                } else {
                    deviceIdsToSend.addAll(deviceIds);
                    deviceIds = new List<String>();
                } 
            }
            params = fetchDeviceSyncParams(pageNumber,deviceIdsToSend);

            //6. Create Request
            request = HTTPCalloutUtility.newRequest(endpoint, method, null, null, headers, params);

            //7. Send Request
            response = HTTPCalloutUtility.sendRequest(request);

            //8. Parse Result
            List<DeviceSyncCalloutResponse> deviceSyncResponses = (List<DeviceSyncCalloutResponse>)JSON.deserialize(response.getBody(), List<DeviceSyncCalloutResponse>.class);

            //9. Process Device Sync
            processDeviceSync(deviceSyncResponses,deviceIdsToSend);            

            if ( pageNumber != null && pageNumber > 0 ) {
                if ( deviceSyncResponses != null && deviceSyncResponses.size() > 0 ) {
                    pageNumber++;
                } else {
                    pageNumber = -1;
                }   
            }
            

        } catch (Exception ex) {
            hasError = true;
            System.debug('Error during Sync Device callout Process: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            exceptionList.add(ex);

        } finally {
            try {
                Set<String> headerToMask = new Set<String>{DEVICE_SYNC_HEADER_KEY};
                for ( String headerVar : headerToMask ) {
                    if ( headers.containsKey(headerVar) ) {
                        String valueToMask = headers.get(headerVar);
                        if ( String.isNotBlank(valueToMask) ) {
                            headers.put(headerVar,'x'.repeat(valueToMask.length()));
                        }
                    }
                }
                log = APILogUtility.populateApiLogRequest(log, endpoint, method, null, null, headers, params);
                log.Response_Status_Code__c = response?.getStatusCode();
                log.Response_Body__c = response?.getBody()?.left(APILogUtility.MAX_LEN_REQUEST_BODY);
                log.Response_Length__c = log.Response_Body__c?.length();
                log.Account__c = accountVarId;
                log.Asset__c = assetVarId;
                log.Direction__c = 'Outbound';

                APILogUtility tempLogUtility = new APILogUtility(log);
                tempLogUtility.addErrors(exceptionList);

                if ( tempLogUtility.hasErrors() ) {
                    String msgBody = 'Error for ' + apiAction + '. Processing will be stopped.' + '\n------------------\n' + log.Errors__c;
                    tempLogUtility.notifyDefault(apiAction + ' Errors', msgBody);
                }

                tempLogUtility.commitLog();
            } catch (Exception e) {
                hasError = true;
                system.debug('Error inserting log--- ' + e.getMessage());
                
                API_Log__c backupLog = new API_Log__c();
                backupLog.Tag__c = 'HTTP Callout LOG ERROR BACKUP';
                backupLog.Class_Name__c = 'DeviceSyncUtility';
                backupLog.Direction__c = 'Outbound';
                backupLog.Action__c = apiAction;
                backupLog.Errors__c = 'line ' + e.getLineNumber() + ': ' + e.getMessage() + '\n' + e.getStackTraceString();
                backupLog.Has_Errors__c = true;
                insert backupLog;

            } finally {
                if ( hasError == false && !Test.isRunningTest() ) {
                    if ( pageNumber != null && pageNumber > 0) {
                        System.enqueueJob(new DeviceSyncQueueable(pageNumber));
                    } else if ( deviceIds != null && deviceIds.size() > 0 ) {
                        System.enqueueJob(new DeviceSyncQueueable(deviceIds));
                    }
                }
            }
        }
    }

    //This currently handles only 1 account. Class DeviceSyncAccount checks for size = 1.
    public static void syncDevices(List<Id> accountIds) {
        
        apiAction = 'Account Device Sync';
        List<String> deviceIds = new List<String>();
        if ( accountIds != null && accountIds.size() == 1 ) {
            for ( Asset assetVar : [SELECT Id, F_52_MACAddress__c FROM Asset WHERE AccountId IN : accountIds AND F_52_MACAddress__c != ''] ) {
                deviceIds.add(assetVar.F_52_MACAddress__c);
            }
        }

        if ( deviceIds.size() > 0 ) {
            System.enqueueJob(new DeviceSyncQueueable(deviceIds, accountIds[0]));
        } else {
            try {
                API_Log__c logRecord = new APILogUtility(null, apiAction, 'DeviceSyncUtility').apiLogRecord;
                logRecord.Account__c = accountIds[0];
                logRecord.Callout_Processing_Result__c = 'No Asset exists against given account';
                logRecord.Has_Errors__c = true;
                logRecord.Direction__c = 'Outbound';
                insert logRecord;
            } catch (Exception ex) {
                API_Log__c backupLog = new API_Log__c();
                backupLog.Tag__c = 'HTTP Callout LOG ERROR BACKUP';
                backupLog.Class_Name__c = 'DeviceSyncUtility';
                backupLog.Direction__c = 'Outbound';
                backupLog.Action__c = apiAction;
                backupLog.Errors__c = 'line ' + ex.getLineNumber() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString();
                backupLog.Has_Errors__c = true;
                insert backupLog;
            }
        }
    }

    private static Map<String,String> fetchDeviceSyncHeaders(Endpoint_Properties__c deviceSyncProperty) {
        Map<String,String> headers = new Map<String,String>();
        headers.put('Content-Type',deviceSyncProperty.Content_Type__c);
        headers.put(DEVICE_SYNC_HEADER_KEY,deviceSyncProperty.Custom_Header_Key__c);
        return headers;
    }

    private static Map<String,String> fetchDeviceSyncParams(Integer pageNumber, List<String> deviceIds) {
        Map<String,String> params = new Map<String,String>();
        if ( pageNumber != null && pageNumber > 0 ) {
            params.put(DEVICE_SYNC_PAGE_NUMBER_KEY,String.valueOf(pageNumber));
            params.put(DEVICE_SYNC_PAGE_SIZE_KEY,String.valueOf(DEVICE_SYNC_PAGE_SIZE));
        } else if ( deviceIds.size() > 0 ) {
            params.put(DEVICE_SYNC_BY_DEVICE_ID_KEY,String.join(deviceIds, ','));
        }
        return params;
    }

    private static List<String> convertDeviceToLowerCase(List<String> deviceIds) {
        for ( Integer i = 0; i < deviceIds.size(); i++ ) {
            deviceIds[i] = deviceIds[i].toLowerCase();
        }
        return deviceIds;
    }

    private static List<String> chunkDeviceBatch(List<String> deviceIds) {
        List<String> chunkedDevices = new List<String>();
        Integer count = 0;
        for(String device : deviceIds){
            count++;
            chunkedDevices.add(device);
            if ( count == DEVICE_SYNC_PAGE_SIZE ) {
                break;
            }
        }
        return chunkedDevices;
    }

    private static List<String> remainingDeviceBatches(List<String> deviceIds) {
        List<String> remainingDevices = new List<String>();
        for(Integer count = DEVICE_SYNC_PAGE_SIZE; count < deviceIds.size(); count ++ ){
            remainingDevices.add(deviceIds[count]);
        }
        return remainingDevices;
    }

    private static void processDeviceSync(List<DeviceSyncCalloutResponse> deviceSyncResponses, List<String> deviceIdsToSync) {
        Set<String> devices = new Set<String>();
        List<Asset> assetList = new List<Asset>();
        List<DeviceSyncCalloutResult> syncResultList = new List<DeviceSyncCalloutResult>();
        Map<String,Asset> assetMapByDeviceId = new Map<String,Asset>();

        for ( DeviceSyncCalloutResponse deviceSyncVar : deviceSyncResponses ) {
            devices.add(deviceSyncVar.id);
        }

        assetList = [SELECT Id, F_52_MACAddress__c, Last_Heartbeat_At__c, Registered_At__c
                     FROM Asset WHERE F_52_MACAddress__c IN : devices];

        for ( Asset assetVar : assetList ) {
            assetMapByDeviceId.put(assetVar.F_52_MACAddress__c.toLowerCase(), assetVar);
        }
        
        syncResultList = processDeviceFoundForBatch(assetMapByDeviceId, deviceSyncResponses, deviceIdsToSync);
        log.Callout_Processing_Result__c = JSON.serialize(syncResultList)?.left(APILogUtility.MAX_LEN_PROCESS_RESULT);

    }

    private static List<DeviceSyncCalloutResult> processDeviceFoundForBatch(Map<String, Asset> assetMapByDeviceId, List<DeviceSyncCalloutResponse> deviceSyncResponses, List<String> deviceIdsToSync) {
        List<DeviceSyncCalloutResult> syncResultList = new List<DeviceSyncCalloutResult>();
        List<Asset> assetUpdateList = new List<Asset>();
        Map<Id,String> deviceIdByAssetIdMap = new Map<Id,String>();
        Map<String,DeviceSyncCalloutResponse> deviceResponseByDeviceIdMap = new Map<String,DeviceSyncCalloutResponse>();

        for ( DeviceSyncCalloutResponse deviceSyncVar : deviceSyncResponses ) {
            deviceResponseByDeviceIdMap.put(deviceSyncVar.id,deviceSyncVar);

            if ( assetMapByDeviceId.containsKey(deviceSyncVar.id) ) {
                Asset assetVar = assetMapByDeviceId.get(deviceSyncVar.id);
                assetVar.Registered_At__c = GeneralUtility.getDateTimeGMTFromString(deviceSyncVar.registered_at);
                assetVar.Last_Heartbeat_At__c = GeneralUtility.getDateTimeGMTFromString(deviceSyncVar.last_heartbeat_at);
                assetUpdateList.add(assetVar);
                deviceIdByAssetIdMap.put(assetVar.Id,assetVar.F_52_MACAddress__c);
            } else {
                syncResultList.add(new DeviceSyncCalloutResult(deviceSyncVar.id, DEVICE_NOT_FOUND_SALESFORCE_MESSAGE));
            }
        }

        if ( deviceIdsToSync != null && deviceIdsToSync.size() > 0) {
            for ( String deviceId : deviceIdsToSync ) {
                if ( !deviceResponseByDeviceIdMap.containsKey(deviceId) ) {
                    syncResultList.add(new DeviceSyncCalloutResult(deviceId, DEVICE_NOT_FOUND_EXTERNAL_MESSAGE));
                }
            }
        }

        if ( assetUpdateList.size() > 0 ) {
            Database.SaveResult [] updateResults = Database.update(assetUpdateList, false);
            for ( Database.SaveResult saveResultVar : updateResults ) {
                Id recordId = saveResultVar.getId();
                String deviceId = deviceIdByAssetIdMap.get(recordId);

                if (saveResultVar.isSuccess()) {
                    syncResultList.add(new DeviceSyncCalloutResult(deviceId, DEVICE_SYNC_SUCCESSFUL_MESSAGE));
                } else {
                    syncResultList.add(new DeviceSyncCalloutResult(deviceId, DEVICE_SYNC_UNSUCCESSFUL_MESSAGE));
                }
            }
        }
        return syncResultList;
    }
    

    public class DeviceSyncCalloutResponse {
        public String id;
        public String registered_at;
        public String last_heartbeat_at;
        public String created_at; 
    }

    public class DeviceSyncCalloutResult {
        public String id;
        public String syncResult;

        public DeviceSyncCalloutResult(String deviceId, String message) {
            this.id = deviceId;
            this.syncResult = message;
        }
    }
}