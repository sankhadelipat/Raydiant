@RestResource(urlMapping='/TicketUpload/*')
global with sharing class TicketUpload {


    public TicketUpload() {
    }

@HttpPOST
    global static String doPOST() {
        RestRequest req = RestContext.request;
        Blob ticketFile = req.requestBody;
        return procFileUpload(ticketFile);
         // mwc now has my data from PHP.
      }
    public static string procFileUpload(Blob myTicketFile){


        Map<String, Id> topicMap = new Map<String, Id>();
        Map<String, Id> contactMap = new Map<String, Id>();
//        Map<String, List<String>> topicByzendeskIDMap = new Map<String, List<String>>();

        for (Topic topicRec: [ SELECT Id, Name FROM Topic]){
            System.debug('id: ' + topicRec.Id +  ' Name: ' + topicRec.Name);
            topicMap.put(topicRec.Name, topicRec.Id);
        }
//       contactMap = populateContactMap();
        Map<String, Object> tickRec = (Map<String, Object>) JSON.deserializeUntyped(myticketFile.toString());


                for (String myKey : tickRec.keySet()){
                }

//                ZenDeskJSON zenDeskRec = new ZendeskJSON();
                Case caseOBJ = new Case();
                caseOBJ.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Support').getRecordTypeId();
                caseOBJ.Source__c = 'CX';
                caseOBJ.Zendesk_Support_Ticket_URL__c = (String) tickRec.get('url');
                caseOBJ.Zendesk_Support_Ticket_ID__c = String.valueOf(tickRec.get('id'));
                if (tickRec.get('created_at') != null){
                    caseOBJ.Zendesk_Support_Ticket_Created_At__c = (DateTime)JSON.deserialize('"'+tickRec.get('created_at')+'"', DateTime.class);
                }
                if (tickRec.get('updated_at') != null){
                    caseOBJ.Zendesk_Support_Ticket_Updated_At__c = (DateTime)JSON.deserialize('"'+tickRec.get('updated_at')+'"', DateTime.class);
                }
                caseOBJ.status =  getCaseStatus((String) tickRec.get('status'));
                caseObj.Description = (String) tickRec.get('description');
                caseObj.Subject = (String) tickRec.get('subject');

                //get date elements
                Map<String, Object> zdDatesMap = (Map<String, Object>) tickRec.get('dates');
                if ((zdDatesMap != null) && (zdDatesMap.size() > 0)){
                    if (zdDatesMap.get('initially_assigned_at') != null){
                        caseOBJ.Zendesk_Support_Ticket_Initial_Assigned__c = (Datetime) JSON.deserialize('"'+zdDatesMap.get('initially_assigned_at')+'"', DateTime.class);
                    }
                    if (zdDatesMap.get('solved_at') != null){
                        caseOBJ.Zendesk_Support_Ticket_Solved_At__c = (Datetime) JSON.deserialize('"'+zdDatesMap.get('solved_at')+'"', DateTime.class);
                    }
                }


                //get submitter info
                Map<String, Object> submitterMap = new Map<String, Object>();
                submitterMap = (Map<String, Object>) tickRec.get('submitter');
                String submitterID;
                if ((submitterMap != null) && (submitterMap.size() > 0)){
                     submitterID = String.valueOf(submitterMap.get('id'));
                }

                //caseOBJ.ContactId = contactMap.get(submitterID);
                if (submitterID != null){
                    Contact[] submitterList  =   [SELECT Id from Contact where Zendesk_ID__c = :submitterID LIMIT 5000];
                    if (submitterList.size() > 0){
                        caseObj.contactId = submitterList[0].Id;
                    }else{
                        TempTicket__c myTempTicket = new TempTicket__c();
                        myTempTicket.submitterID__c = submitterID;
                        myTempTicket.submitterName__c=(String) submitterMap.get('name');
                        myTempTicket.ticketID__c = caseOBJ.Zendesk_Support_Ticket_ID__c;
                        insert myTempTicket;
                    }
                }


                //get assignee info
                //Map<String, Object> assigneeMap = (Map<String, Object>) tickRec.get('assignee');

                Map<String, Object> assigneeMap = new Map<String, Object>();
                assigneeMap =  (Map<String, Object>)tickRec.get('assignee');
                if ((assigneeMap != null) && (assigneeMap.size() > 0)){
                    caseOBJ.Zendesk_Support_Ticket_Assignee_Name__c = String.valueOf(assigneeMap.get('name'));
                }

                //get assignee info
                Map<String, Object> requestorMap = (Map<String, Object>) tickRec.get('requester');
                if (requestorMap != null){
                   caseOBJ.Zendesk_Support_Ticket_Requestor_Name__c = String.valueOf(requestorMap.get('name'));
                   caseOBJ.Zendesk_Support_Ticket_Requestor_Email__c = String.valueOf(requestorMap.get('email'));
                   caseOBJ.Zendesk_Support_Ticket_Requestor_Phone__c = String.valueOf(requestorMap.get('phone'));
                }


                // get tags (zd) topics (sf)
                List<Object> zdTagList = (List<Object>) tickRec.get('tags');
                List<Id> tagIDList = new List<Id>();
                for (Object s: zdTagList){
                    String myKey = (String) s;
                    System.debug('myKey is ' + myKey);
                    tagIDList.add(topicMap.get(myKey.capitalize()));
                }


                //topicByzendeskIDMap.put(String.valueOf(zendeskRec.Id), tagIDList);

            try {
                insert caseOBJ;
            } catch(DmlException e) {
                System.debug('The exception on inserting case: ' + caseOBJ.Zendesk_Support_Ticket_ID__c + ': exception : ' + e.getMessage());
            }

        //insert topics with newly created case ID

            List<TopicAssignment> taInsertList = new List<TopicAssignment>();
            //for (String topicStr : topicByzendeskIDMap.get((String)caseOBJ.Zendesk_Support_Ticket_ID__c)){
                System.debug('tagIDList size is: ' + tagIDList.size());
            for (String topicStr : tagIDList){

                    TopicAssignment taRec = new TopicAssignment();
                    taRec.EntityId = caseOBJ.Id;
                    taRec.TopicId = topicStr;
                    System.debug('topicStr is: ' + topicStr + ' EntityId: ' + taRec.EntityId + '   TopicId: '+ taRec.TopicId);

                    taInsertList.add(taRec);
                }

                try{
                    insert taInsertList;
                } catch(DmlException e) {
                    System.debug('Error inserting taInsert List: ' + e.getMessage());
                }


                //get comments
                List<CaseComment> commentInsertList = new List<CaseComment>();
                List<Object> commentList = (List<Object>)tickRec.get('comments');
                for (Object commentItem : commentList){
                    Map<String,Object> dataMap = (Map<String,Object>)commentItem;
                   CaseComment myCaseComment = new CaseComment();
                   myCaseComment.ParentId  = caseObj.Id;
                   String tempCommentBody = (String)dataMap.get('plain_body');
                   tempCommentBody = tempCommentBody.replaceAll('&'+'nbsp;', ' ');
                   if (tempCommentBody.length() > 3999){
                        myCaseComment.CommentBody = tempCommentBody.substring(0, 4000);
                   } else {
                        myCaseComment.CommentBody = tempCommentBody;

                   }
                   myCaseComment.IsPublished = (Boolean)dataMap.get('public');
                   commentInsertList.add(myCaseComment);
                }
                if (commentInsertList.size() > 0){
                    try{
                        insert commentInsertList;
                    } catch(DmlException e){
                        System.debug('Error inserting case comment List: ' + e.getMessage());
                    }
                }

                    return((String)caseOBJ.Id);
    }



    private static Map<String, Id> populateContactMap(){
        Map<String, Id> myContactMap = new Map<String, Id>();
        for (Contact contactRec: [ SELECT Id,Zendesk_ID__c FROM Contact WHERE Zendesk_ID__c != null ]){
            myContactMap.put(contactRec.Zendesk_ID__c, contactRec.Id);
        }
        return myContactMap;
    }

    private static String getCaseStatus(String zdStatus){
        String retStatus = 'New';

        switch on zdStatus{
            when 'closed'{
                retStatus = 'Closed';
            }
            when 'solved'{
                retStatus = 'Solved';
            }
            when 'open'{
                retStatus = 'Open';
            }
            when 'pending'{
                retStatus = 'Pending';
            }
            when 'hold' {
                retStatus = 'On Hold';
            }
        }
        return retStatus;

    }
}