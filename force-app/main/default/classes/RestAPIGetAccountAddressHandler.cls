public with sharing class RestAPIGetAccountAddressHandler extends RestAPIHandler {
    public RestAPIGetAccountAddressHandler() {
        super();
        operation = 'RestAPIGetAccountAddressHandler';
        className = 'RestAPIGetAccountAddressHandler';
    }
    
    Account accountVar;
        
    // override GET
    private void processGET() {
        
        //1. Check if Account exists.
        fetchAccount();
        
        String accountId = request.params.get('accountId');
        List<SBQQ__Subscription__c> subList = RestAPIUtility.getSubscriptionByAccountId(accountId);
        List<Asset> assetList = RestAPIUtility.getAssetByAccountId(accountId);
        
        generateResponse(accountVar, subList, assetList);
    }
        
    // override POST
    private void processPOST() {
        throw new InvalidInputException('POST not allowed');        
    }
    
    private void fetchAccount() {
        String accountId = request.params.get('accountId');
        try {
            accountVar = RestAPIUtility.getAccount(accountId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Account found for given accountId.');
        }
    }

    private void generateResponse(Account myAccount, List<SBQQ__Subscription__c> subList, List<Asset> assetList) {
        response = new RestAPIResponse(new RestAPIGetAccountAddressResponse(myAccount, subList, assetList));
    }


    public class RestAPIGetAccountAddressResponse {
        //public String email;
        public String dashboardEmail;
        public Id id;                       // Avoid using Id as a variable name as a reserved keyword.
        //public String firstName;
        //public String lastName;
        public ContactInfo primaryContact;
        public ContactInfo billToContact;
        public String billingStreet;
        public String billingCity;
        public String billingState;
        public String billingCountry;
        public String billingPostalCode;
        public String shippingStreet;
        public String shippingCity;
        public String shippingState;
        public String shippingCountry;
        public String shippingPostalCode;
        public Boolean invoiceDeliveryMethod;
        public Set<String> grantScope = new Set<String>();
        
        public RestApiGetAccountAddressResponse(Account acct, List<SBQQ__Subscription__c> subList, List<Asset> assetList) {
            this.Id = acct.Id;
            //this.Email = acct.F52_Primary_Contact__r?.Email;
            this.DashboardEmail = acct.Dashboard_Email__c;
            //this.FirstName = acct.F52_Primary_Contact__r.FirstName;
            //this.LastName = acct.F52_Primary_Contact__r.LastName;
            system.debug('------------'+acct.F52_Primary_Contact__r);
            this.primaryContact = new ContactInfo(acct.F52_Primary_Contact__r);
            this.billToContact = new ContactInfo(acct.blng__BillToContact__r);
            this.BillingStreet = acct.BillingStreet;
            this.BillingCity = acct.BillingCity;
            this.BillingState = acct.BillingState;
            this.BillingCountry = acct.BillingCountry;
            this.BillingPostalCode = acct.BillingPostalCode;
            this.ShippingStreet = acct.ShippingStreet;
            this.ShippingCity = acct.ShippingCity;
            this.ShippingState = acct.ShippingState;
            this.ShippingCountry = acct.ShippingCountry;
            this.ShippingPostalCode = acct.ShippingPostalCode;
            this.invoiceDeliveryMethod = acct.Invoice_delivery_method__c == 'Email';
            if(subList != null) {
                for ( SBQQ__Subscription__c sub : subList ) {
                    this.grantScope.addAll(returnGrantScope(sub.SBQQ__Product__r.RAY_JSON_Text__c));
                }
            }
            this.grantScope.remove(null);
        }
        
    }


    public class ContactInfo {
        public String contactId;
        public String firstName;
        public String lastName;
        public String emailAddress;
        public String streetAddress;
        public String city;
        public String state;
        public String postalCode;
        public String country;

        public ContactInfo(Contact con) {
            if ( con != null ) {
                this.contactId = con.Id;
                this.firstName = con.FirstName;
                this.lastName = con.LastName;
                this.emailAddress = con.Email;
                this.streetAddress = con.MailingStreet;
                this.city = con.MailingCity;
                this.state = con.MailingState;
                this.postalCode = con.MailingPostalCode;
                this.country = con.MailingCountry;
            }            
        }

    }



    public static Set<String> returnGrantScope(String fieldValue) {
        Set<String> grantScope = new Set<String>();
        Map<String,Object> grantMap = (fieldValue!=null && fieldValue!='') ? (Map<String, Object>)JSON.deserializeUntyped(fieldValue) : (new Map<String, Object>());
        system.debug('grant Map =='+grantMap);
    
        List<Object> grantScopeList = new List<Object>();
        if ( grantMap.containsKey('content_grant_scopes')) {
            grantScopeList = (List<Object>)grantMap.get('content_grant_scopes');
        }
        if ( grantScopeList.size() > 0 ) {
            for ( Object obj : grantScopeList ) {
                String tempGrant = (String)obj;
                if ( String.isNotBlank(tempGrant) ) {
                    grantScope.add(tempGrant);
                }
                //grantScope += (String)obj + ',';
            }
            //grantScope = grantScope.substringBeforeLast(',');
        }
        system.debug('--grantScope--'+grantScope);
        
        return grantScope;
    }
}