/**
 * @name : QuoteReader
 * @description: CPQ API Models: 
 * The Read Quote API reads a quote from a CPQ quote ID.
 * 
 **/
public with sharing class QuoteReader {
    
    public QuoteModel read(String quoteId) {
        system.debug('***QuoteReaderquoteId '+quoteId);
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
        system.debug('***quoteJSON '+quoteJSON);
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }
    /*
    public static void testReadQuote(){
        QuoteReader reader = new QuoteReader();
        QuoteModel quote = reader.read('a0u2x000000RFWrAAO');
        System.debug(quote);
    }
    */
}