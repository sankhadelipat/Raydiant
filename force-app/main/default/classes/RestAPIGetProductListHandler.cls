public without sharing class RestAPIGetProductListHandler extends RestAPIHandler {

    public RestAPIGetProductListHandler() {
        super();
        operation = 'RestAPIGetProductListHandler';
        className = 'RestAPIGetProductListHandler';
    }

    // override POST
    private void processPOST() {
        throw new InvalidInputException('POST not allowed');        
    }

    Account accountVar;

    private void processGET() {
        initializeSavePoint();

        //1 - fetch optional parameters.
        String productId = uriParams.get('productId');
        String grantScope = uriParams.get('grantScope');
        String accountId = uriParams.get('accountId');

        //2 - Check if Account exists.
        fetchAccount();

        //3 - Fetch Products
        List<Product2> productList = RestAPIUtility.getProductsList(accountId, productId, grantScope, '', true);

        //3 - Generate Response
        generateResponse(productList);
    }

    private void fetchAccount() {
        String accountId = uriParams.get('accountId');
        if ( String.isNotBlank(accountId) ) {
            try {
                accountVar = RestAPIUtility.getAccount(accountId);
            } catch (Exception ex) {
                throw new InvalidInputException('No Account found for given accountId.');
            }
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