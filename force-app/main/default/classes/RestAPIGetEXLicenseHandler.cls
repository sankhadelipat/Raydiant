public without sharing class RestAPIGetEXLicenseHandler extends RestAPIHandler {
    public RestAPIGetEXLicenseHandler() {
        super();
        operation = 'RestAPIGetEXLicenseHandler';
        className = 'RestAPIGetEXLicenseHandler';
    }

    // override POST
    private void processPOST() {
        throw new InvalidInputException('POST not allowed');        
    }

    Account accountVar;

    private void processGET() {
        initializeSavePoint();

        //1 - Validate URI Params.
        validateUriParamValues();        

        //2 - Check if Account exists.
        fetchAccount();

        String accountId = uriParams.get('accountId');
        
        //3 - Fetch Products - EX Products will have Display on Marketplace = false. 
        List<Product2> productList = RestAPIUtility.getProductsList(accountId, '', '', 'Employee Experience', false);

        //4 - Generate Response
        generateResponse(productList);
    }  

    private void validateUriParamValues(){
        Set<String> requiredFields = new Set<String>();

        String accountId = uriParams.get('accountId');
        if(String.isBlank(accountId)) {
            requiredFields.add('accountId');
        }

        if(!requiredFields.isEmpty()) {
            throw new InvalidInputException('Missing required fields: [' + GeneralUtility.joinSet(requiredFields, ',') + ']');
        }
    }

    private void fetchAccount() {
        String accountId = uriParams.get('accountId');
        try {
            accountVar = RestAPIUtility.getAccount(accountId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Account found for given accountId.');
        }
    }

    private void generateResponse(List<Product2> productList) {
        Map<String,List<Product2>> productsByGrantScope = new Map<String,List<Product2>>();

        for ( Product2 prod : productList ) {
            if ( productsByGrantScope.containskey(prod.Grant_Scope_ID__c) ) {
                productsByGrantScope.get(prod.Grant_Scope_ID__c).add(prod);
            } else {
                productsByGrantScope.put(prod.Grant_Scope_ID__c, new List<Product2>{prod});
            }
        } 
        List<RestAPIProductListResponse> productWrapperList = new List<RestAPIProductListResponse>();
        for ( String grantScope : productsByGrantScope.keySet() ) {
            productWrapperList.add( new RestAPIProductListResponse(grantScope,productsByGrantScope.get(grantScope)) );
        }
        response = new RestAPIResponse(productWrapperList);
    }

}