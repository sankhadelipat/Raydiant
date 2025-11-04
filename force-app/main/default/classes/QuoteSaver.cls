/**
 * @name : QuoteSaver
 * @description: CPQ API Models:
 * The Save Quote API takes a Quote model and saves it to your catalog. The Save Quote API returns the saved Quote model.
 *

 **/
public with sharing class QuoteSaver {
    public QuoteModel save(QuoteModel quote) {
        String quoteJSON = SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', JSON.serialize(quote));
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }
}