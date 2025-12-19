public without sharing class RestAPIProductListResponse {
    
    public String grantScope;
    public List<ListOfProducts> productList;
    
    public RestAPIProductListResponse() {
        this.grantScope = '';
        this.productList = new List<ListOfProducts>();
    }

    public RestAPIProductListResponse(String grantScopeId, List<Product2> products) {
        this.grantScope = grantScopeId;
        this.productList = new List<ListOfProducts>();
        for (Product2 prod : products) {
            this.productList.add(new ListOfProducts(prod));
        }
    }


    public class ListOfProducts {
        public String   productName;
        public String   productId;
        public String   productCode;
        public String   productFamily;
        public String   productLine;
        public String   productAppPlan;
        public Boolean  marketplaceQuantityEditable;
        public Boolean  isQuantityRequired;
        public Integer  productDefaultQuantity;
        public Boolean  manualEnablementRequired;
        public String   businessUseCase;
        public Decimal  netPrice;
        public Integer  term;
        public String   clientFacingPlanDescription;
        public String   clientFacingPricing;     
        public String   productSubscriptionType;
        public Boolean  reachOutToSales;
        
        public List<PurchaseDetails> purchasedSubscriptionDetails;
        public List<PurchaseDetails> purchasedAssetDetails;

        public ListOfProducts(Product2 product) {
            this.productName = product.Name;
            this.productId = product.Id;
            this.productCode = product.ProductCode;
            this.productFamily = product.Family;
            this.productLine = product.Product_Line__c;
            this.productAppPlan = product.App_Plan__c;
            this.marketplaceQuantityEditable = product.Marketplace_Quantity_Editable__c;
            this.isQuantityRequired = product.Marketplace_Quantity_Editable__c;
            this.productDefaultQuantity = Integer.valueOf(product.Default_Quantity__c);
            this.manualEnablementRequired = product.Manual_Enablement_Required__c;
            this.businessUseCase = product.Business_Use_Case__c;
            this.term = Integer.valueOf(product.SBQQ__SubscriptionTerm__c);
            this.clientFacingPlanDescription = product.Client_Facing_Plan_Description__c;
            this.productSubscriptionType = product.SBQQ__SubscriptionType__c;

            if ( product.PricebookEntries != null && product.PricebookEntries.size() > 0 ) {
                
                this.netPrice = product.PricebookEntries[0].UnitPrice;

                if ( String.isNotBlank(product.Client_Facing_Pricing__c) ) {
                    this.clientFacingPricing = String.format(product.Client_Facing_Pricing__c, new List<Object>{product.PricebookEntries[0].UnitPrice});
                }

            }

            this.reachOutToSales = false;
            if ( String.isNotBlank(product.Customer_Facing_Pricing__c ) && product.Customer_Facing_Pricing__c.trim().containsIgnoreCase('Contact Sales') ) {
                this.reachOutToSales = true;
            }

            this.purchasedSubscriptionDetails = new List<PurchaseDetails>();
            this.purchasedAssetDetails = new List<PurchaseDetails>();

            if ( product.Assets != null && product.Assets.size() > 0 ) {
                if ( product.Business_Use_Case__c == 'Employee Experience' ) {
                    this.netPrice = product.Assets[0].Price;
                }
                for ( Asset assetVar : product.Assets ) {
                    this.purchasedAssetDetails.add(new PurchaseDetails(assetVar));
                }
            }

            if ( product.SBQQ__Subscriptions__r != null && product.SBQQ__Subscriptions__r.size() > 0 ) {
                //if ( product.Display_on_Marketplace__c ) {
                //    this.netPrice = product.SBQQ__Subscriptions__r[0].SBQQ__NetPrice__c/product.SBQQ__Subscriptions__r[0].SBQQ__Quantity__c/product.SBQQ__Subscriptions__r[0].SBQQ__ProrateMultiplier__c;
                //}
                
                for ( SBQQ__Subscription__c subVar : product.SBQQ__Subscriptions__r ) {
                    this.purchasedSubscriptionDetails.add(new PurchaseDetails(subVar));
                }
            }
        }
    }

    public class PurchaseDetails {
        public Integer quantity;
        public Integer term;
        public String billingTerm;
        public Date startDate;
        public String transactionId;

        public PurchaseDetails(Asset assetVar){
            this.quantity = Integer.valueOf(assetVar.Quantity);
            this.term = null;
            this.billingTerm = null;
            this.startDate = assetVar.CreatedDate.Date();
            this.transactionId = assetVar.Id;

        }

        public PurchaseDetails(SBQQ__Subscription__c subVar){
            this.quantity = Integer.valueOf(subVar.SBQQ__Quantity__c);
            this.term = Integer.valueOf(subVar.F52_Billing_Interval_Months__c);
            this.billingTerm = subVar.Quote_Billing_Freq__c;
            this.startDate = subVar.SBQQ__StartDate__c;
            this.transactionId = subVar.Id;            
        }
    }


}