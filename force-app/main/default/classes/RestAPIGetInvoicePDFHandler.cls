public without sharing class RestAPIGetInvoicePDFHandler extends RestAPIHandler {
    public RestAPIGetInvoicePDFHandler() {
        super();
        operation = 'RestAPIGetInvoicePDFHandler';
        className = 'RestAPIGetInvoicePDFHandler';
    }
        
    // override GET
    private void processGET() {
        //initialize save point
        initializeSavePoint();
        
        try {
            RestRequest req = RestContext.request;
            Id recordId = (Id)req.params.get('contentDocumentId');
            Id accountId = (Id)req.params.get('accountId');
            Set<Id> entities = new Set<Id>();
            
            List<ContentDocumentLink> cdlList = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId =: recordId];
            for(ContentDocumentLink cdl: cdlList) {
                entities.add(cdl.LinkedEntityId);
            }
            blng__Invoice__c inv = [SELECT Id FROM blng__Invoice__c WHERE Id IN: entities AND blng__Account__c =: accountId];
            ContentDocument cd = [SELECT LatestPublishedVersionId FROM ContentDocument WHERE Id =: recordId];
            ContentVersion cv = [SELECT VersionData, Title FROM ContentVersion WHERE Id =: cd.LatestPublishedVersionId ];
            response = new RestAPIResponse(cv.VersionData);
        } catch (Exception e) {
            throw new InvalidInputException('Error Occurred');
        }
        
    }

    private void processPOST() {

    }
}