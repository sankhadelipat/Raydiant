public without sharing class AccountWebhookUtility {
    
    public static final String ACC_WEBHOOK_ENDPOINT_NAME = 'Account-Webhook';
    public static final String EVENT_TYPE_NEW_ACCOUNT = 'new_account';
    public static final String EVENT_TYPE_MERGE_ACCOUNT = 'account_merge';
    public static final String EVENT_TYPE_SUBSCRIPTION_CHANGED = 'subscription_changed';

    public static Boolean ContractTriggerCalled = false;
    public static Boolean SubscriptionTriggerCalled = false;
    
    public static string apiAction;
    public static API_Log__c log;
    public static Id accountId;

    public static String currentInstance { get {        
        if ( String.isBlank(currentInstance) ) {
            if ( GeneralUtility.isProdEnvironment ) {
                currentInstance = 'Production';
            } else {
                currentInstance = 'Staging';
            }
        }        
        return currentInstance;
    } set; }

    public static void accountWebhook(Set<String> accountIds, String apiActionVar) {
        apiAction = apiActionVar;
        accountWebhook(accountIds,new Map<Id,Set<String>>());
    }

    public static void accountWebhook(Map<Id,Set<String>> mergedAccountsMap, String apiActionVar) {
        apiAction = apiActionVar;
        accountWebhook(null,mergedAccountsMap);
    }

    private static void accountWebhook(Set<String> accountIds,Map<Id,Set<String>> mergedAccountsMap) {
        log = new APILogUtility('Account Webhook', apiAction, 'AccountWebhookUtility').apiLogRecord;
        Boolean hasError = false;   
        String endpoint; 
        String method;
        String requestBody;
        Map<String,String> headers = new Map<String,String>();
        Map<String,String> params = new Map<String,String>();
        HTTPRequest request;
        HTTPResponse response;
        Account accountToUpdate = new Account();
        List<Exception> exceptionList = new List<Exception>();

        try {

            //1. Fetch Endpoint Property. 
            Endpoint_Properties__c accWebhookProperty = HTTPCalloutUtility.fetchEndpointProperty(ACC_WEBHOOK_ENDPOINT_NAME,currentInstance);
            if ( accWebhookProperty == null ) {
                throw new HttpCalloutException('No Endpoint found for Account-Webhook');
            }

            //2. Get Endpoint.
            endpoint = accWebhookProperty.Endpoint_URL__c;

            //3. Request Method
            method = 'POST';

            //4. Headers
            headers.put('Content-Type',accWebhookProperty.Content_Type__c);

            //5. Chunk parameters to make 1 callout per queueable. 
            Set<String> mergedAccIds = new Set<String>();

            if ( apiAction == EVENT_TYPE_NEW_ACCOUNT || apiAction == EVENT_TYPE_SUBSCRIPTION_CHANGED ) {
                for ( String tempAccId : accountIds ) {
                    accountId = tempAccId;
                    break;
                }
                accountIds.remove(accountId);
            } else if ( apiAction == EVENT_TYPE_MERGE_ACCOUNT ) {
                for ( String tempAccId : mergedAccountsMap.keySet() ) {
                    accountId = tempAccId;
                    break;
                }
                mergedAccIds = mergedAccountsMap.get(accountId);
                mergedAccountsMap.remove(accountId);
            } else {
                throw new HttpCalloutException('Invalid apiAction - ' + apiAction);
            }

            accountToUpdate.Id =  accountId;

            //6. Form Request Body
            requestBody = JSON.serializePretty(new AccountWebhookRequest(apiAction,accountId,mergedAccIds));
            
            //7. Create Request
            request = HTTPCalloutUtility.newRequest(endpoint, method, null, requestBody, headers, params);

            //8. Send Request
            response = HTTPCalloutUtility.sendRequest(request);

            //9. Process Account To Update
            if ( response != null ) {
                
                if ( response.getStatusCode() == 200 ) {
                    Map<String,Object> accWebhookResponseMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                    if ( accWebhookResponseMap != null && accWebhookResponseMap.containsKey('profile_id') ) {
                        accountToUpdate.Account_Webhook_Profile_Id__c = (String) accWebhookResponseMap.get('profile_id');
                    }
                } else {
                    log.Has_Errors__c = true;
                }
                accountToUpdate.Account_Webhook_Sync_Time__c = System.now();
                accountToUpdate.Account_Webhook_Response__c = response.getBody();
                accountToUpdate.Account_Webhook_Event_Type__c = apiAction;

                update accountToUpdate;
            }
            
        } catch (Exception ex) {
            hasError = true;
            System.debug('Error during Sync Device callout Process: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            exceptionList.add(ex);
        } finally {
            try {
                system.debug('before log and body');
                log = APILogUtility.populateApiLogRequest(log, endpoint, method, null, requestBody, headers, params);
                system.debug('populated log and body');
                log.Response_Status_Code__c = response?.getStatusCode();
                log.Response_Body__c = response?.getBody()?.left(APILogUtility.MAX_LEN_REQUEST_BODY);
                log.Response_Length__c = log.Response_Body__c?.length();
                log.Account__c = accountId;
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
                backupLog.Class_Name__c = 'AccountWebhookUtility';
                backupLog.Direction__c = 'Outbound';
                backupLog.Action__c = apiAction;
                backupLog.Errors__c = 'line ' + e.getLineNumber() + ': ' + e.getMessage() + '\n' + e.getStackTraceString();
                backupLog.Has_Errors__c = true;
                insert backupLog;

            } finally {
                if ( hasError == false && !Test.isRunningTest() ) {
                    if ( accountIds != null && accountIds.size() > 0) {
                        System.enqueueJob(new AccountWebhookQueueable(accountIds,apiAction));
                    } else if ( mergedAccountsMap != null && mergedAccountsMap.size() > 0 ) {
                        System.enqueueJob(new AccountWebhookQueueable(mergedAccountsMap,apiAction));
                    }
                }
            }
        }
    }

    public class AccountWebhookRequest {
        public String event_type;
        public String account_id;
        public Set<String> account_merge;

        public AccountWebhookRequest(String eventType, String accId, Set<String> mergedAccounts) {
            this.event_type = eventType;
            this.account_id = accId;
            this.account_merge = new Set<String>();
            if ( mergedAccounts != null && mergedAccounts.size() > 0 ) {
                this.account_merge.addAll(mergedAccounts);
            }
        }
    }

}