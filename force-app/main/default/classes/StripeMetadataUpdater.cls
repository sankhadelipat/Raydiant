public with sharing class StripeMetadataUpdater {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    public class MetadataInput {
        @InvocableVariable(label='Stripe Customer ID')
        public String stripeCustomerId;
        @InvocableVariable(label='Account Record URL')
        public String accountRecordUrl;
        @InvocableVariable(label='Internal ID')
        public String internalId;
        @InvocableVariable(label='Account Number')
        public String accountNumber;
        @InvocableVariable(label='Raydiant Signup Type')
        public String raydiantSignupType;
    }

    @InvocableMethod(label='Update Stripe Customer Metadata')
    public static void updateMetadata(List<MetadataInput> inputs) {
        try {
            for (MetadataInput input : inputs) {
                Map<String, Object> metadata = new Map<String, Object>();

                if (input.accountRecordUrl != null)
                    metadata.put('Account_Record_URL', input.accountRecordUrl);
                if (input.internalId != null)
                    metadata.put('ID__c', input.internalId);
                if (input.accountNumber != null)
                    metadata.put('AccountNum__c', input.accountNumber);
                if (input.raydiantSignupType != null)
                    metadata.put('raydiant_signup_type__c', input.raydiantSignupType);

                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://api.stripe.com/v1/customers/' + input.stripeCustomerId);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                List<String> bodyParams = new List<String>();
                for (String key : metadata.keySet()) {
                    bodyParams.add(
                        'metadata[' + key + ']=' + EncodingUtil.urlEncode(String.valueOf(metadata.get(key)), 'UTF-8')
                    );
                }
                req.setBody(String.join(bodyParams, '&'));

                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() >= 400) {
                    System.debug('Stripe Metadata Update Failed: ' + res.getBody());
                    throw new CalloutException('Stripe API error: ' + res.getBody());
                } else {
                    System.debug('Metadata updated for customer ' + input.stripeCustomerId);
                }
            }
        } catch (Exception e) {
            System.debug('Metadata update failed: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Metadata Updating Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeMetadataUpdater',
                Apex_Method__c = 'updateMetadata',
                Object_Name__c = 'Account'
            );
            insert logger;
            throw e;
        }
    }

    @future(callout=true)
    public static void updateStripeCustomerMetadata(
        String stripeCustomerId,
        String accountRecordUrl,
        String internalId,
        String accountNumber
    ) {
        try {
            Map<String, Object> metadata = new Map<String, Object>();
            if (accountRecordUrl != null)
                metadata.put('Account_Record_URL', accountRecordUrl);
            if (internalId != null)
                metadata.put('ID__c', internalId);
            if (accountNumber != null)
                metadata.put('AccountNum__c', accountNumber);
            System.debug('metadata: ' + metadata);

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.stripe.com/v1/customers/' + stripeCustomerId);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':')));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            List<String> bodyParams = new List<String>();
            for (String key : metadata.keySet()) {
                bodyParams.add(
                    'metadata[' + key + ']=' + EncodingUtil.urlEncode(String.valueOf(metadata.get(key)), 'UTF-8')
                );
            }
            req.setBody(String.join(bodyParams, '&'));

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Metadata updated for customer ' + stripeCustomerId);
            } else {
                System.debug('Stripe Metadata Update Failed: ' + res.getBody());
                throw new CalloutException('Stripe API error: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Metadata update failed: ' + e.getMessage());
            Logger__c logger = new Logger__c(
                Name = 'Stripe Metadata Updating Error',
                Message__c = e.getMessage(),
                StackTrace__c = e.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeMetadataUpdater',
                Apex_Method__c = 'updateStripeCustomerMetadata',
                Object_Name__c = 'Account'
            );
            insert logger;
        }
    }
}
