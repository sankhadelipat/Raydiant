@RestResource(urlMapping='/stripe/order')
global class SelfServiceOrderProcess {
    @HttpPost
    global static Response processOrder() {
        Savepoint sp = Database.setSavepoint();
        try {
            // Parse the request body
            RestRequest request = RestContext.request;
            Request req = (Request) JSON.deserialize(request.requestBody.toString(), Request.class);
            
            System.debug('Processing order request: ' + JSON.serialize(req));
            
            // 1. Validate input
            validateRequest(req);
            
            // 2. Create Order
            Order order = createOrder(req);
            
            // 3. Create Order Items
            List<OrderItem> orderItems = createOrderItems(req, order.Id);
            
            // 6. Return response
            return new Response(true, 'Order created successfully.', null);
        } catch (Exception e) {
            Database.rollback(sp);
            return new Response(false, 'Error processing order: ' + e.getMessage(), null);
        }
    }
    
    public class CustomException extends Exception {}
    
    private static void validateRequest(Request req) {
        if (String.isBlank(req.accountId)) {
            throw new CustomException('Account ID is required');
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
    }
    
    private static Order createOrder(Request req) {
        List<Account> accounts = [SELECT Id, Name, blng__BillToContact__c, blng__BillToContact__r.Email FROM Account WHERE Id = :req.accountId];
        
        List<Pricebook2> pricebooks = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true ];
        
        if (accounts.isEmpty()) {
            throw new CustomException('Account not found: ' + req.accountId);
        } else if (accounts[0].blng__BillToContact__c == null) {
            throw new CustomException('Billing contact is not set for account: ' + req.accountId);
        }
        
        Integer subscriptionTerm = Integer.valueOf(req.subscriptionTerm);
        Date startDate = System.today();
        Date endDate = startDate.addMonths(subscriptionTerm);
        
        Order order = new Order(
            Name = accounts[0].Name + ' - ' + System.now().format(),
        AccountId = req.accountId,
        Pricebook2Id = pricebooks.isEmpty() ? null : pricebooks[0].Id,
        Status = 'Draft',
        EffectiveDate = startDate,
        endDate = endDate,
        SBQQ__PaymentTerm__c = 'Due on receipt',
        F52_Sales_Type__c = 'Sales',
        RAY_Ship_to_Account__c = req.accountId
            );
        
        insert order;
        
        System.debug('Order created: ' + order.Id);
        return order;
    }
    
    private static List<OrderItem> createOrderItems(Request req, Id orderId) {
        List<OrderItem> orderItems = new List<OrderItem>();
        
        // Get all required product data in a single query
        List<Product2> productsWithDetails = [
            SELECT Id, SBQQ__BillingType__c, SBQQ__SubscriptionType__c, SBQQ__SubscriptionPricing__c, SBQQ__SubscriptionBase__c, SBQQ__PriceEditable__c, SBQQ__SubscriptionTerm__c, SBQQ__ChargeType__c, Description, CurrencyIsoCode, RAY_Category__c, 
            (SELECT Id, Product2Id, UnitPrice FROM PricebookEntries WHERE IsActive = true AND Pricebook2.IsStandard = true)
            FROM Product2 
            WHERE Id IN :getProductIds(req.products)
        ];
        
        Map<Id, Product2> productMap = new Map<Id, Product2>(productsWithDetails);
        
        Integer lineNumber = 1;
        for (ProductRequest pr : req.products) {
            Product2 product = productMap.get(pr.productId);
            if (product == null || product.PricebookEntries.isEmpty()) {
                throw new CustomException('Product not found: ' + pr.productId);
            }
            
            PricebookEntry pbe = product.PricebookEntries[0];
            Decimal subscriptionTerm = Decimal.valueOf(req.subscriptionTerm);
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
                        regularUnitPrice = pbe.UnitPrice * subscriptionTerm;
                        customerUnitPrice = regularUnitPrice * (1 - (discountPercentage / 100));
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = subscriptionTerm;
                        prorateListPrice = pbe.UnitPrice * prorateMultiplier;
                    } else {
                        regularUnitPrice = pbe.UnitPrice;
                        customerUnitPrice = regularUnitPrice * (1 - (discountPercentage / 100));
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = 1;
                        prorateListPrice = regularUnitPrice * prorateMultiplier;
                    }
                } else if (pr.discountType == 'Flat') {
                    discountAmount = pr.discount;
                    
                    if (product.SBQQ__ChargeType__c == 'Recurring') {
                        regularUnitPrice = pbe.UnitPrice * subscriptionTerm;
                        customerUnitPrice = regularUnitPrice - discountAmount;
                        partnerUnitPrice = customerUnitPrice;
                        netUnitPrice = customerUnitPrice;
                        prorateMultiplier = subscriptionTerm;
                        prorateListPrice = pbe.UnitPrice * prorateMultiplier;
                    } else {
                        regularUnitPrice = pbe.UnitPrice;
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
                    regularUnitPrice = pbe.UnitPrice * subscriptionTerm;
                    customerUnitPrice = regularUnitPrice;
                    partnerUnitPrice = customerUnitPrice;
                    netUnitPrice = customerUnitPrice;
                    prorateMultiplier = subscriptionTerm;
                    prorateListPrice = pbe.UnitPrice * prorateMultiplier;
                } else {
                    regularUnitPrice = pbe.UnitPrice;
                    customerUnitPrice = regularUnitPrice;
                    partnerUnitPrice = customerUnitPrice;
                    netUnitPrice = customerUnitPrice;
                    prorateMultiplier = 1;
                    prorateListPrice = regularUnitPrice * prorateMultiplier;
                }
            } else if (pr.discount <= 0) {
                throw new CustomException('Discount must be greater than zero.');
            }
            
            OrderItem item = new OrderItem(
                OrderId = orderId,
            Product2Id = product.Id,
            PricebookEntryId = pbe.Id,
            Quantity = pr.quantity,
            UnitPrice = pbe.UnitPrice,
            ListPrice = pbe.UnitPrice,
            SBQQ__DefaultSubscriptionTerm__c = product.SBQQ__SubscriptionTerm__c
                );
            
            orderItems.add(item);
        }
        
        if (!orderItems.isEmpty()) {
            insert orderItems;
        } else {
            throw new CustomException('No valid order items to create.');
        }
        
        System.debug('Order items created: ' + orderItems.size());
        return orderItems;
    }
    
    private static Set<Id> getProductIds(List<ProductRequest> products) {
        Set<Id> productIds = new Set<Id>();
        for (ProductRequest product : products) {
            productIds.add(product.productId);
        }
        return productIds;
    }
    
    // Inner classes for request/response structure
    global class Request {
        public String accountId;
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
        public String orderId;
        
        public Response(Boolean success, String message, String orderId) {
            this.success = success;
            this.message = message;
            this.orderId = orderId;
        }
    }
}