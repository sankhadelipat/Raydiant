public class StripeCustomerCreateBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private  static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private  static final  String SECRET_KEY = stripeDetails.Serect_Key__c;
    
    private Integer processedCount = 0;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    private List<String> errorMessages = new List<String>();
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
if (Test.isRunningTest())
{
    return Database.getQueryLocator([
            SELECT Id, Name, Bill_To_Email__c, Phone, Description, Account_Number__c, Account_Record_URL__c, Raydiant_Signup_Type__c
            FROM Account
            WHERE Stripe_Customer_ID__c = null   limit 500
            
        ]);
}
        else {
        return Database.getQueryLocator([
            SELECT Id, Name, Bill_To_Email__c, Phone, Description, Account_Number__c, Account_Record_URL__c, Raydiant_Signup_Type__c
            FROM Account
            WHERE Stripe_Customer_ID__c = null  And Status_Calculated__c ='Active Customer' 
            
        ]);
        }
    }
    
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        System.debug('Scope: ' + scope);
        List<Account> accountsToUpdate = new List<Account>();
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        stripeGC__Stripe_Account__c stripeOrgAccount = [
                        SELECT Id, Name FROM stripeGC__Stripe_Account__c LIMIT 1
                    ];
        for (Account acc : scope) {
            try {
                // Prepare HTTP request to create customer in Stripe
                req.setEndpoint('https://api.stripe.com/v1/customers');
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                
                // Build the request body
                String requestBody = buildRequestBody(acc);
                req.setBody(requestBody);
                
                // Send the request
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    // Parse successful response
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String stripeCustomerId = (String) responseMap.get('id');
                    acc.Stripe_Customer_ID__c = stripeCustomerId;
                    acc.Stripe_Customer_URL__c = 'https://dashboard.stripe.com/customers/' + stripeCustomerId;
                    acc.Stripe_Org_Account__c = stripeOrgAccount.Id;
                    accountsToUpdate.add(acc);
                    successCount++;
                } else {
                    errorCount++;
                    errorMessages.add('Failed to create customer for ' + acc.Name + ' (Id: ' + acc.Id + '): ' + res.getBody());
                }
            } catch (Exception e) {
                errorCount++;
                errorMessages.add('Error processing Account ' + acc.Name + ' (Id: ' + acc.Id + '): ' + e.getMessage());
            } finally {
                processedCount++;
            }
        }
        
        // Update accounts
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
                accountsToUpdate.clear();
            } catch (DmlException dmle) {
                for (Account a : accountsToUpdate) {
                    errorMessages.add('DML Error updating account ' + a.Name + ' (Id: ' + a.Id + '): ' + dmle.getMessage());
                }
                accountsToUpdate.clear();
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
                Name = 'Stripe Customer Creation Error',
            Message__c = errorMessages.size() + ' errors occurred during Stripe Customer Creation Batch.',
            StackTrace__c = '',
            Status__c = 'Error',
            Apex_Class__c = 'StripeCustomerCreateBatch',
            Apex_Method__c = 'execute',
            Object_Name__c = 'Account',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
        }
    }
    
    private String buildRequestBody(Account acc) {
        Map<String, String> params = new Map<String, String>{
            'name' => acc.Name,
            'metadata[ID__c]' => acc.Id,
            'metadata[Account_Record_URL]' => acc.Account_Record_URL__c,
            'metadata[AccountNum__c]' => acc.Account_Number__c
        };
        
        if (String.isNotBlank(acc.Raydiant_Signup_Type__c)) {
            params.put('metadata[raydiant_signup_type__c]', acc.Raydiant_Signup_Type__c);
        }
        if (String.isNotBlank(acc.Bill_To_Email__c)) {
            params.put('email', acc.Bill_To_Email__c);
        }
        if (String.isNotBlank(acc.Phone)) {
            params.put('phone', acc.Phone);
        }
        if (String.isNotBlank(acc.Description)) {
            params.put('description', acc.Description.left(350));
        }
        
        List<String> bodyParts = new List<String>();
        for (String key : params.keySet()) {
            bodyParts.add(EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }
        return String.join(bodyParts, '&');
    }
}