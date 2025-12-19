@isTest
public with sharing class TicketUploadTest {
    public static testMethod void  TicketUploadTest() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = 'services/apexrest/TicketUpload';
        req.httpMethod = 'POST';
        StaticResource ticketJSON = [SELECT Id, Body FROM StaticResource WHERE Name = 'CaseTestJSON' LIMIT 1];
        req.requestBody =  ticketJSON.Body;
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        String postResp =  TicketUpload.doPOST();
        String testRecId = (String)[SELECT Id FROM Case LIMIT 1].id;
        System.debug('postResp is: ' + postResp);
        System.debug('testRecId is: ' + testRecId);
        Test.stopTest();
        System.assertEquals(postResp, testRecId);



    }
}