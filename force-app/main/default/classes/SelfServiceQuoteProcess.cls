@RestResource(urlMapping='/stripe/generate-quote')
global class SelfServiceQuoteProcess {
    @HttpPost
    global static void generateQuote() {
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
            
            System.debug('Processing quote request: ' + JSON.serialize(req));
            
            // 1. Validate input
            validateRequest(req);
            
            // 2. Create Opportunity
            // Opportunity opp = createOpportunity(req);
            
            // 3. Create Quote
            SBQQ__Quote__c qt = createQuote(req);
            
            // 4. Create Quote Line Items
            List<SBQQ__QuoteLine__c> lineItems = createQuoteLineItems(req, qt.Id);
            
            // 5. Return successful response
            response.statusCode = 200;  // OK
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                true,
            'Quote created successfully.',
            qt.Id
                )));
        } catch (CustomException e) {
            Database.rollback(sp);
            System.debug('Validation error processing quote: ' + e.getMessage());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Self-Service Quote Generating Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Validation Error',
            Apex_Class__c = 'SelfServiceQuoteProcess',
            Apex_Method__c = 'generateQuote',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            response.statusCode = 400;  // Bad Request
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                false,
            'Validation error: ' + e.getMessage(),
            null
                )));
        } catch (System.QueryException e) {
            Database.rollback(sp);
            System.debug('Query error processing quote: ' + e.getMessage());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Self-Service Quote Query Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Query Error',
            Apex_Class__c = 'SelfServiceQuoteProcess',
            Apex_Method__c = 'generateQuote',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            response.statusCode = 404; // Not Found
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                false,
            'Resource not found: ' + e.getMessage(),
            null
                )));
            
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Unexpected error generating quote: ' + e.getMessage());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Self-Service Quote Generating Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Error',
            Apex_Class__c = 'SelfServiceQuoteProcess',
            Apex_Method__c = 'generateQuote',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            response.statusCode = 500; // Internal Server Error
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                false,
            'Internal server error: ' + e.getMessage(),
            null
                )));
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
            if (pr.unitPrice == null || pr.unitPrice <= 0) {
                throw new CustomException('Unit price must be greater than 0 for all products');
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
    
    // private static Opportunity createOpportunity(Request req) {
        //     RecordTypeInfo customerOpportunityRtMap = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('CustomerOpportunity');
        //     if (customerOpportunityRtMap == null) {
            //         throw new CustomException('Customer Opportunity record type not found');
        //     }
        
        //     Id customerOpportunityRtId = customerOpportunityRtMap.getRecordTypeId();
        //     List<Account> accounts = [SELECT Id, Name FROM Account WHERE Stripe_Customer_ID__c = :req.customerId];
        //     if (accounts.isEmpty()) {
            //         throw new CustomException('Account not found');
        //     }
        
        //     Opportunity opp = new Opportunity(
        //         Name = accounts[0].Name + ' - ' + System.now().format(),
        //     AccountId = accounts[0].Id,
        //     RecordTypeId = customerOpportunityRtId,
        //     StageName = 'Discovery & Qualification',
        //     Type = 'New',
        //     ForecastCategoryName = 'Upside',
        //     CloseDate = System.today()
        //         );
        //     insert opp;
        //     return opp;
    // }
    
    private static SBQQ__Quote__c createQuote(Request req) {
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
        return qt;
    }
    
    private static List<SBQQ__QuoteLine__c> createQuoteLineItems(Request req, Id quoteId) {
        List<SBQQ__QuoteLine__c> lineItems = new List<SBQQ__QuoteLine__c>();
        
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
        
        Integer lineNumber = 1;
        
        for (ProductRequest pr : req.products) {
            Product2 product = productMap.get(pr.productId);
            if (product == null || product.PricebookEntries.isEmpty()) {
                continue;
            }
            
            PricebookEntry pbe = product.PricebookEntries[0];
            Decimal subscriptionTerm = Decimal.valueOf(req.subscriptionTerm);
            Decimal unitPrice = pr.unitPrice;
            Decimal regularUnitPrice;
            Decimal customerUnitPrice;
            Decimal partnerUnitPrice;
            Decimal netUnitPrice;
            Decimal prorateListPrice;
            Decimal prorateMultiplier;
            Decimal discountPercentage;
            Decimal discountAmount;
            
            if (pr.discount != null && pr.discount > 0) {
                if (pr.discountType == 'Percentage') {
                    discountPercentage = pr.discount;
                    
                    if (product.SBQQ__ChargeType__c == 'Recurring') {
                        regularUnitPrice = unitPrice * subscriptionTerm;
                        customerUnitPrice = regularUnitPrice * (1 - (discountPercentage / 100));
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = subscriptionTerm;
                        prorateListPrice = unitPrice * prorateMultiplier;
                    } else {
                        regularUnitPrice = unitPrice;
                        customerUnitPrice = regularUnitPrice * (1 - (discountPercentage / 100));
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = 1;
                        prorateListPrice = regularUnitPrice * prorateMultiplier;
                    }
                } else if (pr.discountType == 'Flat') {
                    discountAmount = pr.discount;
                    
                    if (product.SBQQ__ChargeType__c == 'Recurring') {
                        regularUnitPrice = unitPrice * subscriptionTerm;
                        customerUnitPrice = regularUnitPrice - discountAmount;
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = subscriptionTerm;
                        prorateListPrice = unitPrice * prorateMultiplier;
                    } else {
                        regularUnitPrice = unitPrice;
                        customerUnitPrice = regularUnitPrice - discountAmount;
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = 1;
                        prorateListPrice = regularUnitPrice * prorateMultiplier;
                    }
                } else if (pr.discountType == null) {
                    throw new CustomException('Discount type is required if discount is provided.');
                } else if (pr.discountType != 'Percentage' && pr.discountType != 'Flat') {
                    throw new CustomException('Discount type must be either Percentage or Flat.');
                }
            } else if (pr.discount == null) {
                if (product.SBQQ__ChargeType__c == 'Recurring') {
                    regularUnitPrice = unitPrice * subscriptionTerm;
                    customerUnitPrice = regularUnitPrice;
                    partnerUnitPrice = customerUnitPrice;
                    netUnitPrice = customerUnitPrice;
                    prorateMultiplier = subscriptionTerm;
                    prorateListPrice = unitPrice * prorateMultiplier;
                } else {
                    regularUnitPrice = unitPrice;
                    customerUnitPrice = regularUnitPrice;
                    partnerUnitPrice = customerUnitPrice;
                    netUnitPrice = customerUnitPrice;
                    prorateMultiplier = 1;
                    prorateListPrice = regularUnitPrice * prorateMultiplier;
                }
            } else if (pr.discount <= 0) {
                throw new CustomException('Discount must be greater than zero.');
            }
            
            SBQQ__QuoteLine__c qli = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = quoteId,
            SBQQ__Product__c = product.Id,
            SBQQ__Quantity__c = pr.quantity,
            SBQQ__Discount__c = discountPercentage,
            SBQQ__AdditionalDiscountAmount__c = discountAmount,
            SBQQ__ListPrice__c = unitPrice,
            SBQQ__OriginalPrice__c = unitPrice,
            SBQQ__RegularPrice__c = regularUnitPrice,
            SBQQ__SpecialPrice__c = unitPrice,
            SBQQ__CustomerPrice__c = customerUnitPrice,
            SBQQ__PartnerPrice__c = partnerUnitPrice,
            SBQQ__ProratedPrice__c = prorateListPrice,
            SBQQ__ProratedListPrice__c = prorateListPrice,
            SBQQ__NetPrice__c = netUnitPrice,
            SBQQ__Number__c = lineNumber++,
            SBQQ__PricebookEntryId__c = pbe.Id,
            SBQQ__ProrateMultiplier__c = prorateMultiplier,
            SBQQ__BillingType__c = product.SBQQ__BillingType__c,
            SBQQ__SubscriptionType__c = product.SBQQ__SubscriptionType__c,
            SBQQ__ProductSubscriptionType__c = product.SBQQ__SubscriptionType__c,
            SBQQ__SubscriptionPricing__c = product.SBQQ__SubscriptionPricing__c,
            SBQQ__SubscriptionBase__c = product.SBQQ__SubscriptionBase__c,
            SBQQ__BillingFrequency__c = product.SBQQ__ChargeType__c == 'Recurring' ? req.billingFrequency : null,
            SBQQ__PriceEditable__c = product.SBQQ__PriceEditable__c,
            SBQQ__SubscriptionTerm__c = product.SBQQ__ChargeType__c == 'Recurring' ? subscriptionTerm : null,
            SBQQ__DefaultSubscriptionTerm__c = product.SBQQ__SubscriptionTerm__c,
            SBQQ__ChargeType__c = product.SBQQ__ChargeType__c,
            SBQQ__Description__c = product.Description,
            CurrencyIsoCode = product.CurrencyIsoCode,
            RAY_Category__c = product.RAY_Category__c
                );
            
            lineItems.add(qli);
        }
        
        if (!lineItems.isEmpty()) {
            insert lineItems;
        } else {
            throw new System.QueryException('No valid products found for the quote');
        }
        
        return lineItems;
    }
    
    private static Id getStandardPricebookId() {
        Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        return standardPricebook.Id;
    }
    
    private static Set<String> getProductIds(List<ProductRequest> products) {
        Set<String> productIds = new Set<String>();
        for (ProductRequest product : products) {
            productIds.add(product.productId);
        }
        return productIds;
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
        public Decimal unitPrice;
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