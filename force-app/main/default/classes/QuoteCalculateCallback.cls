/**
 * @name : QuoteCalculateCallback
 * @description: CPQ API Models: 
 * This class must implement the CPQ CalculateCallback interface to save the quote after calculating it in the background.
 * 
 **/
global without sharing class QuoteCalculateCallback implements SBQQ.CalculateCallback {
    
    global void callback(String quoteJSON){
        System.debug('>> '+quoteJSON);
        QuoteModel theQuoteModel;
        try {
            SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quoteJSON);
            theQuoteModel = (QuoteModel)JSON.deserialize(quoteJSON, QuoteModel.class);
            //orderQuote(theQuoteModel.record.Id);
            closeOpportunity(theQuoteModel.record.SBQQ__Opportunity2__c);
        } catch (Exception ex) {
            //try {
                //theQuoteModel = (QuoteModel)JSON.deserialize(quoteJSON, QuoteModel.class);

                API_Log__c apiLog = new API_Log__c();
                apiLog.Action__c = 'RestAPIBuyNow-QuoteCalculateCallback';
                apiLog.Direction__c = 'Inbound';
                apiLog.Class_Name__c = 'QuoteCalculateCallback';
                apiLog.Quote__c = theQuoteModel?.record.Id;
                apiLog.Opportunity__c = theQuoteModel?.record.SBQQ__Opportunity2__c;
                apiLog.Errors__c = 'Error in Calculating Quote during Buy Now. \n ' + ex.getLineNumber() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString();
                apiLog.Has_Errors__c = true;
                insert apiLog;

            /*} catch (Exception e) {
                API_Log__c backupLog = new API_Log__c();
                backupLog.Action__c = 'RestAPIBuyNow-QuoteCalculateCallback';
                backupLog.Class_Name__c = 'QuoteCalculateCallback';
                backupLog.Quote__c = theQuoteModel?.record.Id;
                backupLog.Opportunity__c = theQuoteModel?.record.SBQQ__Opportunity2__c;
                backupLog.Errors__c = 'Error in saving error log for Buy Now QuoteCalculateCallback. \n ' + e.getLineNumber() + ': ' + e.getMessage() + '\n' + e.getStackTraceString();
                backupLog.Has_Errors__c = true;
                insert backupLog;
            }*/
        }
        

    }

    /*global static void orderQuote(Id quoteId){
        List<SBQQ__Quote__c> toUpdate = new List<SBQQ__Quote__c>([SELECT Id, SBQQ__Ordered__c FROM SBQQ__Quote__c WHERE Id =: quoteId LIMIT 1]);
        toUpdate[0].SBQQ__Ordered__c = true;
        update toUpdate;
    }*/

    global static void closeOpportunity(Id oppId){
        List<Opportunity> toUpdate = new List<Opportunity>([SELECT Id, StageName, sbaa__ApprovalStatus__c, F52_BypassValidationForProcessBuilder__c FROM Opportunity WHERE Id=:oppId LIMIT 1]);
        toUpdate[0].sbaa__ApprovalStatus__c = 'Approved';
        toUpdate[0].StageName = 'Closed Won';
        toUpdate[0].F52_BypassValidationForProcessBuilder__c = false;
      
        update toUpdate;
    }
}