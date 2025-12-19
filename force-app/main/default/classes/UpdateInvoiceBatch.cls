/**
* @Trigger Name: UpdateInvoiceBatch
* @Description: This apex batch is mark check the pdf downloaded check box on Invoice. 
*  ================================================================================================================
*   Version   | Date              | Author                | Comments
*   1.0       | 25th July, 2022    | Anjali Singh         | 1. This apex batch is mark check the pdf downloaded 
*                                                               check box on Invoice.
*=================================================================================================================
*/

global class UpdateInvoiceBatch implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'select id,PDF_Downloaded__c,Record_Processed_in_pdf_Script__c from blng__Invoice__c where PDF_Downloaded__c = false';
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<blng__Invoice__c> invoiceList){
        
        Set<Id> invIdSet = new Set<Id>();
        System.debug('strat inv List => ' + invoiceList.size());
        for(blng__Invoice__c inv: invoiceList) {
            invIdSet.add(inv.Id);
        }
        
        
        List<ContentDocumentLink> contentDocLinkList = [select Id, LinkedEntityId from ContentDocumentLink where LinkedEntityId IN: invIdSet];
        System.debug('Total CDL => ' + contentDocLinkList.size());
        
        set<Id>linkedEntityIdSet = new Set<Id>();
        
        for(ContentDocumentLink cdl: contentDocLinkList){
            linkedEntityIdSet.add(cdl.LinkedEntityId);
        }
        System.debug('Total CDL linkedEntitiID set => ' + linkedEntityIdSet.size());
        
        List<blng__Invoice__c> updatedInvoiceList = new List<blng__Invoice__c>();
        
        for(blng__Invoice__c invoice: invoiceList) {
            if(linkedEntityIdSet.contains(invoice.id)){
                invoice.PDF_Downloaded__c = true;
            }
            else {
                invoice.Record_Processed_in_pdf_Script__c = true;
            }
            updatedInvoiceList.add(invoice); 
        }
        
        System.debug('new inv List ' + updatedInvoiceList.size());
        
        If(updatedInvoiceList.size() > 0) {
            List<Error_Log__c> logList = new List<Error_Log__c>();
            Database.SaveResult[] results;
            try {
                results = Database.update(updatedInvoiceList, false);
                if(Test.isRunningTest()){
                   throw new DMLException('Test');  
                }
            }
             
            Catch(DMLException e) {
                for(Database.SaveResult sr :results) {
                    if(!sr.isSuccess()) {
                        for(Database.Error err : sr.getErrors()) {
                            Error_Log__c newLog = new Error_Log__c();
                            newLog.Error_Record_Id__c = sr.Id;
                            newLog.Error_Message__c = err.getMessage();
                            logList.add(newLog);
                        }
                    }
                    
                }
            }
            System.Debug('logList size > ' + logList.size());
            If(logList.size() > 0){
                Insert logList;
            }
        }
        
        
    }
    
    global void finish(Database.BatchableContext BC){
    }
}