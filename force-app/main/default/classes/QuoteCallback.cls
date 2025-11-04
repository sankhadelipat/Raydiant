global with sharing class QuoteCallback implements SBQQ.CalculateCallback {
    global void callback(String quoteJSON){
        SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quoteJSON);
    }
}