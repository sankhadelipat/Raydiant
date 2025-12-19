@isTest public with sharing class FlowDebugLoggerTest {
    public static testMethod void lowDebugLoggerTest() {

        String debugMsg = 'Debug Message';
        List<String> debugList = new List<String>();
        debugList.add(debugMsg);

        FlowDebugLogger.trace(debugList);
    }
}