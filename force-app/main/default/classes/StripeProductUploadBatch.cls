public class StripeProductUploadBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private  static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private  static final  String SECRET_KEY = stripeDetails.Serect_Key__c;
    
    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, ProductCode, Description, Family, 
            Stripe_Product_ID__c, IsActive, Grant_Scope_ID__c, RAY_JSON_Text__c,SBQQ__SubscriptionPricing__c,
            SBQQ__SubscriptionType__c,Customer_Facing_Pricing__c,RAY_Category__c,Product_Line__c
            FROM Product2
            WHERE Stripe_Product_ID__c = null and isActive = true
            // LIMIT 100
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Product2> scope) {
        System.debug('Scope: ' + scope);
        List<Product2> productsToUpdate = new List<Product2>();
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        for (Product2 prod : scope) {
            try {
                // Prepare HTTP request to create product in Stripe
                req.setEndpoint('https://api.stripe.com/v1/products');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                
                // Build the request body
                String requestBody = buildRequestBody(prod);
                req.setBody(requestBody);
                
                // Send the request
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    // Parse successful response
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String stripeProductId = (String) responseMap.get('id');
                    prod.Stripe_Product_ID__c = stripeProductId;
                    productsToUpdate.add(prod);
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add('Failed to create product ' + prod.Name + ' (Id: ' + prod.Id + '): ' + res.getBody());
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add('Error processing product ' + prod.Name + ' (Id: ' + prod.Id + '): ' + e.getMessage());
            } finally {
                processedCount++;
            }
        }
        
        // Update products
        if (!productsToUpdate.isEmpty()) {
            try {
                update productsToUpdate;
                productsToUpdate.clear();
            } catch (DmlException dmlEx) {
                for (Product2 p : productsToUpdate) {
                    errorMessages.add('DML Error updating product ' + p.Name + ' (Id: ' + p.Id + '): ' + dmlEx.getMessage());
                }
                productsToUpdate.clear();
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch Process Completed. Processed: ' + processedCount + ', Success: ' + successCount + ', Errors: ' + errorCount);
        
        if (!errorMessages.isEmpty()) {
            for (String errMsg : errorMessages) {
                System.debug(errMsg);
            }
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Product Upload Error',
                Message__c = errorMessages.size() + ' errors occurred during Stripe Product Upload Batch.',
                StackTrace__c = '',
                Status__c = 'Error',
                Apex_Class__c = 'StripeProductUploadBatch',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Product2',
                User_Email__c = UserInfo.getUserEmail()
            );
            insert logger;
        }
    }
    
    private String buildRequestBody(Product2 prod) {
        Map<String, String> params = new Map<String, String>{
            'name' => prod.Name,
                'active' => String.valueOf(prod.IsActive),
                'metadata[salesforce_product_id]' => prod.Id
                };
                    
                    if (String.isNotBlank(prod.Description)) {
                        params.put('description', prod.Description.left(350));
                    }
        if (String.isNotBlank(prod.ProductCode)) {
            params.put('metadata[salesforce_product_code]', prod.ProductCode);
        }
        if (String.isNotBlank(prod.Grant_Scope_ID__c)) {
            params.put('metadata[grant_scope_id]', prod.Grant_Scope_ID__c);
        }
        if (String.isNotBlank(prod.RAY_JSON_Text__c)) {
            params.put('metadata[json_text]', prod.RAY_JSON_Text__c);
        }
        
        if (String.isNotBlank(prod.SBQQ__SubscriptionPricing__c)) {
            params.put('metadata[Subscription Pricing]', prod.SBQQ__SubscriptionPricing__c);
        }
        if (String.isNotBlank(prod.SBQQ__SubscriptionType__c)) {
            params.put('metadata[Subscription Type]', prod.SBQQ__SubscriptionType__c);
        }
        if (String.isNotBlank(prod.Customer_Facing_Pricing__c)) {
            params.put('metadata[Customer Facing Pricing]', prod.Customer_Facing_Pricing__c);
        }if (String.isNotBlank(prod.RAY_Category__c)) {
            params.put('metadata[RAY Category]', prod.RAY_Category__c);
        }if (prod.IsActive == true) {
            params.put('metadata[Active]', 'true');
        }
        if (String.isNotBlank(prod.Product_Line__c)) {
            params.put('metadata[Product Line]', prod.Product_Line__c);
        }
        List<String> bodyParts = new List<String>();
        for (String key : params.keySet()) {
            bodyParts.add(EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }
        return String.join(bodyParts, '&');
    }
}