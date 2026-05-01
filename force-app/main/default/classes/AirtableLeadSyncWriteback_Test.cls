/**
 * Test class for AirtableLeadSyncWriteback
 */
@isTest
private class AirtableLeadSyncWriteback_Test {

    private class MockAirtablePatchSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"records":[]}');
            return res;
        }
    }

    private class MockAirtablePatchError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(422);
            res.setBody('{"error":{"type":"INVALID_PERMISSIONS","message":"No write access"}}');
            return res;
        }
    }

    @isTest
    static void testWritebackSuccess() {
        Map<String, String> writebackMap = new Map<String, String>{
            'recTEST00001' => '00Q000000000001',
            'recTEST00002' => '00Q000000000002'
        };
        Test.setMock(HttpCalloutMock.class, new MockAirtablePatchSuccess());
        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
        Test.stopTest();
    }

    @isTest
    static void testWritebackApiError() {
        Map<String, String> writebackMap = new Map<String, String>{
            'recTEST00001' => '00Q000000000001'
        };
        Test.setMock(HttpCalloutMock.class, new MockAirtablePatchError());
        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
        Test.stopTest();
    }

    @isTest
    static void testWritebackEmptyMap() {
        Map<String, String> writebackMap = new Map<String, String>();
        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
        Test.stopTest();
    }

    @isTest
    static void testWritebackNullMap() {
        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncWriteback(null));
        Test.stopTest();
    }

    @isTest
    static void testWritebackLargeBatch() {
        Map<String, String> writebackMap = new Map<String, String>();
        for (Integer i = 0; i < 25; i++) {
            writebackMap.put('recTEST' + String.valueOf(i).leftPad(5, '0'),
                           '00Q' + String.valueOf(i).leftPad(15, '0'));
        }
        Test.setMock(HttpCalloutMock.class, new MockAirtablePatchSuccess());
        Test.startTest();
        System.enqueueJob(new AirtableLeadSyncWriteback(writebackMap));
        Test.stopTest();
    }
}