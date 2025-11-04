/**
 * @name : QuoteReader
 * @description: CPQ API Models:
 * The Read Quote API takes the request’s quote ID and returns a Quote model. The Quote model loads the quote from your catalog when the user requests it.
 *

 **/
public with sharing class QuoteReader {
    
    public QuoteModel read(String quoteId) {
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }
}