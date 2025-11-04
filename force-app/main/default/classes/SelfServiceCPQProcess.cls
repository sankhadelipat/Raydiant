@RestResource(urlMapping='/stripe/payment-process')
global class SelfServicePaymentProcess {
    @HttpPost
    global static Response processPayment() {
        RestResponse response = RestContext.response;
        if (response == null) {
            response = new RestResponse();
            RestContext.response = response;
        }
        
        Savepoint sp = Database.setSavepoint();
        try {
            // Parse the request body
            RestRequest request = RestContext.request;
            Request req = (Request) JSON.deserialize(request.requestBody.toString(), Request.class);
            
            System.debug('Processing payment request: ' + JSON.serialize(req));
            
            // 1. Validate input
            validateRequest(req);
            
            // 3. Create Quote
            QuoteModel quoteModel = createQuoteModel(req);
            
            // 4. Add products using CPQ API
            addProductsToQuote(quoteModel, req);
            
            // 5. Calculate pricing
            calculateQuote(quoteModel);
            
            // 8. Return response
            return new Response(
                true,
            'Payment process initiated successfully.',
            quoteModel.record.Id
                );
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error processing payment: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Processing Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Error',
            Apex_Class__c = 'SelfServicePaymentProcess',
            Apex_Method__c = 'processPayment',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            return new Response(
                false,
            'Error processing payment: ' + e.getMessage(),
            null
                );
        }
    }
    
    public class CustomException extends Exception {}
    
    private static void validateRequest(Request req) {
        if (String.isBlank(req.customerId)) {
            throw new CustomException('Customer ID is required');
        }
        if (req.products == null || req.products.isEmpty()) {
            throw new CustomException('At least one product is required');
        }
        if (String.isBlank(req.billingFrequency)) {
            throw new CustomException('Billing frequency is required');
        }
        if (String.isBlank(req.subscriptionTerm)) {
            throw new CustomException('Contract term is required');
        }
        
        // Validate products
        for (ProductRequest pr : req.products) {
            if (String.isBlank(pr.productId)) {
                throw new CustomException('Product ID is required for all products');
            }
            if (pr.quantity == null || pr.quantity <= 0) {
                throw new CustomException('Quantity must be greater than 0 for all products');
            }
            if (pr.discount != null && pr.discount < 0) {
                throw new CustomException('Discount cannot be negative');
            }
            if (pr.discount != null && pr.discountType == null) {
                throw new CustomException('Discount type is required when discount is provided');
            }
            if (pr.discountType != null && !new Set<String>{'Percentage', 'Flat'}.contains(pr.discountType)) {
                throw new CustomException('Discount type must be either "Percentage" or "Flat"');
            }
        }
    }
    
    private static QuoteModel createQuoteModel(Request req) {
        List<Account> accounts = [SELECT Id, Dashboard_Email__c, Bill_To_Email__c FROM Account WHERE Stripe_Customer_ID__c = :req.customerId];
        
        String dashboardEmail;
        
        if (accounts.isEmpty()) {
            throw new System.QueryException('Account not found');
        } else if (accounts[0].Dashboard_Email__c != null) {
            dashboardEmail = accounts[0].Dashboard_Email__c;
        } else if (accounts[0].Bill_To_Email__c != null) {
            dashboardEmail = accounts[0].Bill_To_Email__c;
        }
        System.debug('Dashboard Email: ' + dashboardEmail);
        
        Id pricebookId = getStandardPricebookId();
        if (pricebookId == null) {
            throw new System.QueryException('Standard Pricebook not found');
        }
        
        // Create the quote with required fields
        SBQQ__Quote__c qt = new SBQQ__Quote__c(
            SBQQ__Account__c = accounts[0].Id,
        SBQQ__Primary__c = true,
        SBQQ__SubscriptionTerm__c = Decimal.valueOf(req.subscriptionTerm),
        SBQQ__PaymentTerms__c = req.paymentTerm,
        SBQQ__StartDate__c = System.today(),
        SBQQ__PriceBook__c = pricebookId,
        SBQQ__PricebookId__c = pricebookId,
        Billing_Frequency_Override__c = req.billingFrequency,
        RAY_Dashboard_Email__c = dashboardEmail,
        RAY_Expiry_Date_Time__c = System.now()
            );
        insert qt;
        
        // Read the created quote using CPQ API
        QuoteReader reader = new QuoteReader();
        QuoteModel quoteModel = reader.read(qt.Id);
        System.debug('Created QuoteModel: ' + JSON.serializePretty(quoteModel));
        
        return quoteModel;
    }
    
    private static void addProductsToQuote(QuoteModel quoteModel, Request req) {
        ProductReader productReader = new ProductReader();
        ProductAdder productAdder = new ProductAdder();
        
        // Get all required product data in a single query
        List<Product2> productsWithDetails = [
            SELECT Id, Stripe_Product_ID__c, SBQQ__BillingType__c, SBQQ__SubscriptionType__c, SBQQ__SubscriptionPricing__c, SBQQ__SubscriptionBase__c, SBQQ__PriceEditable__c, SBQQ__SubscriptionTerm__c, SBQQ__ChargeType__c, Description, CurrencyIsoCode, RAY_Category__c, 
            (SELECT Id, Product2Id, UnitPrice FROM PricebookEntries WHERE IsActive = true AND Pricebook2.IsActive = true AND Pricebook2.IsStandard = true)
            FROM Product2 
            WHERE Stripe_Product_ID__c IN :getProductIds(req.products)
        ];
        
        Map<String, Product2> productMap = new Map<String, Product2>();
        
        for (Product2 prod : productsWithDetails) {
            if (String.isNotBlank(prod.Stripe_Product_ID__c)) {
                productMap.put(prod.Stripe_Product_ID__c, prod);
            }
        }
        System.debug('productMap: ' + productMap);
        
        // Prepare products for addition
        List<ProductModel> productModels = new List<ProductModel>();
        
        Integer lineNumber = 1;
        
        for (ProductRequest pr : req.products) {
            try {
                Product2 product = productMap.get(pr.productId);
                if (product == null || product.PricebookEntries.isEmpty()) {
                    continue;
                }
                PricebookEntry pbe = product.PricebookEntries[0];
                
                // Read product using CPQ API
                ProductModel productModel = productReader.read(product.Id, pbe.Id, 'USD');
                System.debug('ProductModel for ' + product.Id + ': ' + JSON.serializePretty(productModel));
                
                // Set quantity and discount
                // productModel.record.SBQQ__Quantity__c = pr.quantity;
                
                // if (pr.discount != null && pr.discount > 0) {
                    //     if (pr.discountType == 'Percentage') {
                        //         productModel.record.SBQQ__Discount__c = pr.discount;
                    //     } else if (pr.discountType == 'Flat') {
                        //         productModel.record.SBQQ__AdditionalDiscountAmount__c = pr.discount;
                    //     } else if (pr.discountType == null) {
                        //         throw new CustomException('Discount type is required if discount is provided.');
                    //     } else {
                        //         throw new CustomException('Discount type must be either Percentage or Flat.');
                    //     }
                // } else if (pr.discount != null && pr.discount <= 0) {
                    //     throw new CustomException('Discount must be greater than zero.');
                // }
                
                productModels.add(productModel);
            } catch (Exception e) {
                System.debug('Error processing product ' + pr.productId + ': ' + e.getMessage());
                throw new CustomException('Error processing product: ' + e.getMessage());
            }
        }
        
        if (productModels.isEmpty()) {
            throw new CustomException('No valid products found for the quote');
        }
        
        // Add products to quote using CPQ API
        quoteModel = productAdder.add(quoteModel, productModels, 0);
        
        QuoteSaver saver = new QuoteSaver();
        quoteModel = saver.save(quoteModel);
        System.debug('QuoteModel after adding products: ' + JSON.serializePretty(quoteModel));
    }
    
    private static Id getStandardPricebookId() {
        Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        return standardPricebook.Id;
    }
    
    // Inner classes for request/response structure
    global class Request {
        public String customerId;
        public List<ProductRequest> products;
        public String billingFrequency;
        public String subscriptionTerm;
        public String paymentTerm = 'Prepayment';
    }
    
    global class ProductRequest {
        public String productId;
        public Decimal discount;
        public String discountType;
        public Integer quantity;
    }
    
    global class Response {
        public Boolean success;
        public String message;
        public String quoteId;
        
        public Response(Boolean success, String message, String quoteId) {
            this.success = success;
            this.message = message;
            this.quoteId = quoteId;
        }
    }
}