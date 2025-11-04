/**
 * @name : ProductAdder
 * @description: CPQ API Models: 
 * The Read Product API takes the request’s product ID, pricebook ID, and currency code and returns a Product model. The Product model loads the product from your catalog when the user requests it.
 * 

 **/
public without sharing class ProductReader { 
    
    public ProductModel read(Id productId, Id pricebookId, String currencyCode) {
        ProductReaderContext ctx = new ProductReaderContext(pricebookId, currencyCode);
        String productJSON = SBQQ.ServiceRouter.load('SBQQ.ProductAPI.ProductLoader', productId, JSON.serialize(ctx));
        return (ProductModel) JSON.deserialize(productJSON, ProductModel.class);
    }
    
    private class ProductReaderContext {
        private Id pricebookId;
        private String currencyCode;
        
        private ProductReaderContext(Id pricebookId, String currencyCode) {
            this.pricebookId = pricebookId;
            this.currencyCode = currencyCode;
        }
    } 
}