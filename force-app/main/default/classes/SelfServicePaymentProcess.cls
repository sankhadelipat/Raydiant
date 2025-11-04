@RestResource(urlMapping='/stripe/payment-process')
global class SelfServicePaymentProcess {
    @HttpPost
    global static void processPayment() {
        RestResponse response = RestContext.response;
        if (response == null) {
            response = new RestResponse();
            RestContext.response = response;
        }
        
        try {
            // Parse the request body
            RestRequest request = RestContext.request;
            Request req = (Request) JSON.deserialize(request.requestBody.toString(), Request.class);
            
            System.debug('Processing payment request: ' + JSON.serialize(req));
            
            // 1. Validate input
            validateRequest(req);
            
            // 2. Generate the payment link
            String paymentLink = StripePaymentLinkFromQuote.getQuoteForSelfService(req.quoteId);
            
            // 3. Return successful response
            response.statusCode = 200;  // OK
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                true,
            'Payment link generated successfully.',
            paymentLink
                )));
        } catch (CustomException e) {
            System.debug('Validation error processing payment: ' + e.getMessage());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Processing Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Validation Error',
            Apex_Class__c = 'SelfServicePaymentProcess',
            Apex_Method__c = 'processPayment',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            response.statusCode = 400;  // Bad Request
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                false,
            'Validation error: ' + e.getMessage(),
            null
                )));
        } catch (CalloutException e) {
            System.debug('Callout error processing payment: ' + e.getMessage());
            
            Logger__c logger = new Logger__c(
                Name = 'Stripe Payment Query Error',
            Message__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            Status__c = 'Callout Error',
            Apex_Class__c = 'SelfServicePaymentProcess',
            Apex_Method__c = 'processPayment',
            User_Email__c = UserInfo.getUserEmail()
                );
            insert logger;
            
            response.statusCode = 500;
            response.responseBody = Blob.valueOf(JSON.serialize(new Response(
                false,
            'Resource not found: ' + e.getMessage(),
            null
                )));
        } catch (Exception e) {
            System.debug('Unexpected error processing payment: ' + e.getMessage());
            
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
        if (String.isBlank(req.quoteId)) {
            throw new CustomException('quoteId is required.');
        }
    }
    
    // Inner classes for request/response structure
    global class Request {
        public String quoteId;
    }
    
    global class Response {
        public Boolean success;
        public String message;
        public String paymentLink;
        
        public Response(Boolean success, String message, String paymentLink) {
            this.success = success;
            this.message = message;
            this.paymentLink = paymentLink;
        }
    }
}