@isTest
public class APILogUtilityTest {
    
    static testMethod void testAPILogUtility(){

        String default_delim = APILogUtility.DEFAULT_DELIM;
        Integer max_len_request_body = APILogUtility.MAX_LEN_REQUEST_BODY;
        Integer max_len_response_body = APILogUtility.MAX_LEN_RESPONSE_BODY;
        Integer max_len_error = APILogUtility.MAX_LEN_ERROR;
        Integer max_len_debug = APILogUtility.MAX_LEN_DEBUG;
        Integer max_len_notif_body = APILogUtility.MAX_LEN_NOTIF_BODY;
        Integer max_len_process_result = APILogUtility.MAX_LEN_PROCESS_RESULT;
        Map<String, Integer> field_max_len = APILogUtility.FIELD_MAX_LEN;
        API_Log__c log = APILogUtility.createNewLog();
        APILogUtility.getNotifyEmailList();
        APILogUtility.fetchTransactionLimits('test');
        APILogUtility.populateApiLogRequest(log, 'endpoint', 'method', 0, null, null, null);
        
        log = new APILogUtility().apiLogRecord;
        log = new APILogUtility(log).apiLogRecord;
        log = new APILogUtility('Test Tag', 'Test Action', 'APILogUtilityTest').apiLogRecord;

        List<String> debugErrorList = new List<String>();
        debugErrorList.add('string1');
        debugErrorList.add('string2');

        log = new APILogUtility().addErrors(debugErrorList).apiLogRecord;
        log = new APILogUtility().addDebugInfo(debugErrorList).apiLogRecord;

        List<Exception> exList = new List<Exception>();
        exList.add(new HttpCalloutException('Test'));

        log = new APILogUtility().addErrors(exList).apiLogRecord;
        log = new APILogUtility().notifyErrorsDefault('Test Notify').apiLogRecord;
        log = new APILogUtility().notifyDefault('Test Notify', 'Test Notify Body').apiLogRecord;
        log = new APILogUtility().notify('test@test.com', 'Test Notify', 'Test Notify Body').apiLogRecord;
        log = new APILogUtility().notifyToList(new List<String>{'test@test.com'}, 'Test Notify', 'Test Notify Body').apiLogRecord;
    }
}