public class StripeProductCreator {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    @InvocableMethod(
        label='Create Stripe Product'
        description='Creates a product in Stripe for the given list of Product2 records'
    )
    public static List<Response> createStripeProduct(List<Request> requests) {
        List<Response> responses = new List<Response>();
        List<Product2> productsToUpdate = new List<Product2>();

        for (Request req : requests) {
            Response res = new Response();
            try {
                // Prepare HTTP request to create product in Stripe
                Http http = new Http();
                HttpRequest httpReq = new HttpRequest();

                if (String.isBlank(req.stripeProductId)) {
                    httpReq.setEndpoint('https://api.stripe.com/v1/products');
                } else {
                    httpReq.setEndpoint('https://api.stripe.com/v1/products/' + req.stripeProductId);
                }
                httpReq.setMethod('POST');
                httpReq.setHeader(
                    'Authorization',
                    'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                );
                httpReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                // Build the request body
                String requestBody = buildRequestBody(req);
                httpReq.setBody(requestBody);

                // Send the request
                HttpResponse httpRes = http.send(httpReq);

                if (httpRes.getStatusCode() == 200) {
                    // Parse successful response
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    String stripeProductId = (String) responseMap.get('id');

                    Product2 prod = new Product2(Id = req.productId, Stripe_Product_ID__c = stripeProductId);

                    if (String.isBlank(req.stripeProductId)) {
                        productsToUpdate.add(prod);
                    }
                } else {
                    throw new HandledException(
                        'Failed to create product ' + req.productName + ': ' + httpRes.getBody()
                    );
                }

                res.success = true;
                res.message = 'Products processed successfully';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Error: ' + e.getMessage();

                Logger__c logger = new Logger__c(
                    Name = 'Stripe Product Creation Error',
                    Message__c = e.getMessage(),
                    StackTrace__c = e.getStackTraceString(),
                    Status__c = 'Error',
                    Apex_Class__c = 'StripeProductCreator',
                    Apex_Method__c = 'createStripeProduct',
                    Object_Name__c = 'Product2',
                    User_Email__c = UserInfo.getUserEmail()
                );
                insert logger;
            }
            responses.add(res);
        }

        // Update products with Stripe Product IDs
        if (!productsToUpdate.isEmpty()) {
            update productsToUpdate;
        }

        return responses;
    }

    private static String buildRequestBody(Request req) {
        Product2 prod = [
            SELECT
                Id,
                Name,
                ProductCode,
                Description,
                Family,
                Stripe_Product_ID__c,
                IsActive,
                Grant_Scope_ID__c,
                RAY_JSON_Text__c,
                SBQQ__SubscriptionPricing__c,
                SBQQ__SubscriptionType__c,
                Customer_Facing_Pricing__c,
                RAY_Category__c,
                Product_Line__c
            FROM Product2
            WHERE id = :req.productId
        ];

        Map<String, String> params = new Map<String, String>{
            'name' => req.productName,
            'active' => String.valueOf(req.isActive),
            'metadata[salesforce_product_id]' => req.productId
        };

        if (String.isNotBlank(req.description)) {
            params.put('description', req.description.left(350));
        }
        if (String.isNotBlank(req.productCode)) {
            params.put('metadata[salesforce_product_code]', req.productCode);
        }
        if (String.isNotBlank(req.grantScopeId)) {
            params.put('metadata[grant_scope_id]', req.grantScopeId);
        }
        if (String.isNotBlank(req.jsonText)) {
            params.put('metadata[json_text]', req.jsonText);
        }
        if (String.isNotBlank(prod.SBQQ__SubscriptionPricing__c)) {
            params.put('metadata[Subscription Pricing]', prod.SBQQ__SubscriptionPricing__c);
        }
        if (String.isNotBlank(prod.SBQQ__SubscriptionType__c)) {
            params.put('metadata[Subscription Type]', prod.SBQQ__SubscriptionType__c);
        }
        if (String.isNotBlank(prod.Customer_Facing_Pricing__c)) {
            params.put('metadata[Customer Facing Pricing]', prod.Customer_Facing_Pricing__c);
        }
        if (String.isNotBlank(prod.RAY_Category__c)) {
            params.put('metadata[RAY Category]', prod.RAY_Category__c);
        }
        if (prod.IsActive == true) {
            params.put('metadata[Active]', 'true');
        }
        if (String.isNotBlank(prod.Product_Line__c)) {
            params.put('metadata[Product Line]', prod.Product_Line__c);
        }

        List<String> bodyParts = new List<String>();
        for (String key : params.keySet()) {
            bodyParts.add(
                EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8')
            );
        }
        return String.join(bodyParts, '&');
    }

    public class Request {
        @InvocableVariable(required=true label='Product ID')
        public Id productId;

        @InvocableVariable(label='Stripe Product ID')
        public String stripeProductId;

        @InvocableVariable(required=true label='Product Name')
        public String productName;

        @InvocableVariable(label='Product Description')
        public String description;

        @InvocableVariable(label='Product Code')
        public String productCode;

        @InvocableVariable(label='Is Active' description='Indicates if the product is active')
        public Boolean isActive;

        @InvocableVariable(label='Grant Scope ID')
        public String grantScopeId;

        @InvocableVariable(label='JSON Text')
        public String jsonText;
    }

    public class Response {
        @InvocableVariable(label='Success' description='Indicates if the operation was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Details about the operation result')
        public String message;
    }
}