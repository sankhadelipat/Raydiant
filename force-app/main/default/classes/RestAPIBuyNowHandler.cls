public without sharing class RestAPIBuyNowHandler extends RestAPIHandler {
    
    public RestAPIBuyNowHandler() {
        super();
        operation = 'RestAPIBuyNowHandler';
        className = 'RestAPIBuyNowHandler';
    }

    public void processGET() {
        
    }

    public void processPost() {
        
        //initialize save point 
        initializeSavePoint();

        if ( String.isBlank(requestBody) ) {
            throw new InvalidInputException('Please specify a valid request body');
        }

        BuyNowRequest inboundBuyNowRequest;
        
        //try catch around deserializing to throw a valid request instead of a 500 Internal Server error.
        try {
            inboundBuyNowRequest = (BuyNowRequest)JSON.deserialize(requestBody, BuyNowRequest.class);
        } catch ( Exception e ) {
            throw new InvalidInputException('Unable to parse request - please confirm your request format is valid.');
        }

        //1 - Check Duplicate Opportunity for given Unique Key
        validateDuplicateOpportunity(inboundBuyNowRequest.uniqueKey);

        //2 - Check if Account exists.
        validateAccount(inboundBuyNowRequest.accountId);

        //3 - Check if Payment Method exists.
        validatePaymentMethod(inboundBuyNowRequest.paymentMethodId, inboundBuyNowRequest.accountId);

        //4 - Check if Product Exists
        validateProduct(inboundBuyNowRequest.productId, inboundBuyNowRequest.accountId);

        //5 - Validate Required fields
        validateRequiredFields(inboundBuyNowRequest);

        //6 - Create Opportunity
        Id oppId = createOpportunity(inboundBuyNowRequest);

        //7 - Create Quote
        Id quoteId = createQuote(oppId, inboundBuyNowRequest);

        //8 - Create Quote Line Products
        createQuoteLineFromProductOfInterest(oppId, quoteId, inboundBuyNowRequest);

        //9 - Populate quote and opportunity lookups on API Log
        populateAPILogValues(oppId, quoteId);

        //10 - Return response
        generateResponse(oppId, quoteId);
    }

    private void generateResponse(Id oppId, Id quoteId) {
        String message = 'The Opportunity and quote was created successfully.';
        response = new RestAPIResponse( new BuyNowResponse(oppId, quoteId, message) );
    }

    private void validateRequiredFields(BuyNowRequest inboundBuyNowRequest) {
        Set<String> requiredFields = new Set<String>();

        if( String.isBlank(inboundBuyNowRequest.accountId) ) {
            requiredFields.add('accountId');
        }
        if( String.isBlank(inboundBuyNowRequest.productId) ) {
            requiredFields.add('productId');
        }
        if( String.isBlank(inboundBuyNowRequest.uniqueKey) ) {
            requiredFields.add('uniqueKey');
        }
        if( inboundBuyNowRequest.quantity == null || inboundBuyNowRequest.quantity <= 0 ) {
            requiredFields.add('quantity');
        }
        if ( prodVar != null && prodVar.Display_on_Marketplace__c ) {
            if( String.isBlank(inboundBuyNowRequest.billingFrequency) ) {
                requiredFields.add('billingFrequency');
            }
        }
        
        if( String.isBlank(inboundBuyNowRequest.paymentMethodId) ) {
            requiredFields.add('paymentMethodId');
        }

        if(!requiredFields.isEmpty()) {
            throw new InvalidInputException('Missing required fields: [' + GeneralUtility.joinSet(requiredFields, ',') + ']');
        }
    }

    private void validateDuplicateOpportunity(String uniqueKey) {     
        if ( String.isBlank(uniqueKey) ) {
            return;
        }

        List<Opportunity> oppList = [SELECT Id FROM Opportunity WHERE Buy_Now_Opp_Unique_Key__c =: uniqueKey];
        if( oppList.size() > 0 ) {
            throw new ValidationException('Order already placed for uniqueKey: ' + uniqueKey);
        }
    }

    private void validateAccount(String accountId) {
        List<Account> accountList = [SELECT Id, Name FROM Account WHERE Id =: accountId];
        if( accountList.size() == 0 ) {
            throw new InvalidInputException('No account found for given accountId: ' + accountId);
        }
        accVar = new Account();
        accVar = accountList[0];
    }

    private void validatePaymentMethod(String paymentMethodId, String accountId) {
        try {
            paymentMethod = RestAPIUtility.getActivePaymentMethodByIdForAccount(paymentMethodId, accountId);
        } catch ( Exception ex ) {
            throw new InvalidInputException('No Active Payment Method found for given Payment Method Id: ' + paymentMethodId + ' against the account: ' + accountId);
        }
    }

    private void validateProduct(String productId, String accountId) {

        List<Product2> productList = RestAPIUtility.getProductsList(accountId, productId, '', '', false);
        if( productList.size() != 1 ) {
            throw new InvalidInputException('No Product found/More than 1 Product found for given Product Id: ' + productId);
        }
        prodVar = new Product2();
        prodVar = productList[0];
        netPrice = null;

        if ( prodVar.PricebookEntries != null && prodVar.PricebookEntries.size() > 0 ) {        
            netPrice = prodVar.PricebookEntries[0].UnitPrice;
        }
        if ( prodVar.Business_Use_Case__c == 'Employee Experience' ) {
            if ( prodVar.Assets != null && prodVar.Assets.size() > 0 ) {
                netPrice = prodVar.Assets[0].Price;
            }
        }
    }

    private Id createOpportunity(BuyNowRequest inboundBuyNowRequest) {
        Opportunity oppVar = new Opportunity();
        oppVar.AccountId = inboundBuyNowRequest.accountId;
        oppVar.Amount = netPrice * inboundBuyNowRequest.quantity;
        oppVar.Buy_Now_Opp_Unique_Key__c = inboundBuyNowRequest.uniqueKey;
        oppVar.Name = getOppName(inboundBuyNowRequest);
        oppVar.CloseDate = System.today();
        oppVar.StageName = 'Commited';
        oppVar.Pricebook2Id = getPricebookId();
        oppVar.SBQQ__Ordered__c = false;
        oppVar.LeadSource = 'Self-Service';

        try {
            insert oppVar;
        } catch (Exception ex) {
            throw new ValidationException('Unable to create the Opportunity record. Error: ' + ex.getMessage());
        }

        return oppVar.Id;
    }

    private Id createQuote(Id oppId, BuyNowRequest inboundBuyNowRequest) {
        SBQQ__Quote__c quoteVar = new SBQQ__Quote__c();

        quoteVar.SBQQ__Account__c = inboundBuyNowRequest.accountId; 
        quoteVar.SBQQ__PriceBook__c = getPricebookId();
        quoteVar.SBQQ__PricebookId__c = String.valueOf(getPricebookId()); 
        quoteVar.SBQQ__Opportunity2__c = oppId; 
        quoteVar.SBQQ__StartDate__c = System.today();
        quoteVar.SBQQ__Status__c = 'Approved';
        quoteVar.SBQQ__BillingFrequency__c = inboundBuyNowRequest.billingFrequency;
        quoteVar.F52_Payment_Method__c = inboundBuyNowRequest.paymentMethodId; 
        //quoteVar.SBQQ__SubscriptionTerm__c = inboundBuyNowRequest.term; 
        quoteVar.SBQQ__Primary__c=true;
        quoteVar.SBQQ__Ordered__c=false;

        try {
            insert quoteVar;
        } catch (Exception ex) {
            throw new ValidationException('Unable to create the Quote record. Error: ' + ex.getMessage());
        }

        return quoteVar.Id;    
    }

    private void createQuoteLineFromProductOfInterest(Id createdOppId, Id createdQuoteId, BuyNowRequest inboundBuyNowRequest ) {
        /*
        RestAPIBuyNowQueueable buyNowQueueable = new RestAPIBuyNowQueueable(createdOppId, createdQuoteId, pricebookId, prodVar.Id, inboundBuyNowRequest.quantity);
        System.enqueueJob(buyNowQueueable);*/
        try{
            QuoteModel theQuoteModel = new QuoteReader().read(createdQuoteId);
            ProductReader reader = new ProductReader();
            ProductModel product = reader.read(prodVar.Id, pricebookId, null);
            
            List<ProductModel> productModels = new List<ProductModel>();
            productModels.add(product);
            
            theQuoteModel = new ProductAdder().add(theQuoteModel, productModels, null);
            theQuoteModel.lineItems[0].record.SBQQ__Quantity__c = inboundBuyNowRequest.quantity;
            
            QuoteCalculator calculator = new QuoteCalculator();
            calculator.calculate(theQuoteModel, 'QuoteCalculateCallback');
        } catch (Exception ex) {
            throw new ValidationException('Unable to create the Quote Line record. Error: ' + ex.getMessage());
        }
    }

    private void populateAPILogValues(Id createdOppId, Id createdQuoteId) {
        apiLog.Opportunity__c = createdOppId;
        apiLog.Quote__c = createdQuoteId;
    }

    private static Id pricebookId {get; set;}
    private static String oppName {get; set;}
    private static Account accVar {get; set;}
    private static Product2 prodVar {get; set;}
    private static blng__PaymentMethod__c paymentMethod {get;set;}
    private static Decimal netPrice {get;set;}
    
    private Id getPricebookId() {
        if( pricebookId == null ) {
            pricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true].Id;
        }
        return pricebookId;
    }

    private String getOppName(BuyNowRequest inboundBuyNowRequest) {
        if( String.isBlank(oppName) ) {
            oppName = accVar.Name + ' ' + inboundBuyNowRequest.productId + ' starting on ' + System.today().format();
        }
        return oppName;
    }



    public class BuyNowRequest {
        public String   accountId;
        public String   productId;
        public String   uniqueKey;
        public Integer  quantity;
        public String   billingFrequency;
        public String   paymentMethodId;

    }

    public class BuyNowResponse {
        public String oppId;
        public String quoteId;
        public String message;

        public BuyNowResponse(String oppIdVar, String quoteIdVar, String messageVar) {
            this.oppId = oppIdVar;
            this.quoteId = quoteIdVar;
            this.message = messageVar;
        }
    }
}