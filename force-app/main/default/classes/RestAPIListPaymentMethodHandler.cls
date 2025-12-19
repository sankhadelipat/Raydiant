public with sharing class RestAPIListPaymentMethodHandler extends RestAPIHandler {
    public RestAPIListPaymentMethodHandler() {
        super();
        operation = 'RestAPIListPaymentMethodHandler';
        className = 'RestAPIListPaymentMethodHandler';
    }
    
    Account accountVar;
        
    // override GET
    private void processGET() {
        //initialize save point
        initializeSavePoint();
        
        //1. Check if Account exists.
        fetchAccount();

        String accountId = request.params.get('accountId');
        List<blng__PaymentMethod__c> paymentMethods = RestAPIUtility.getPaymentMethod(accountId);
        
        generateResponse(paymentMethods, accountVar);
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

    private void generateResponse(List<blng__PaymentMethod__c> paymentMethods, Account myAccount) {
        response = new RestAPIResponse(new RestAPIListPaymentMethodResponse(paymentMethods, myAccount));
    }


    public class RestAPIListPaymentMethodResponse {
        public String  id;
        public String  email;
        public String firstName;
        public String lastName;
        public String billingStreet;
        public String billingCity;
        public String billingState;
        public String billingCountry;
        public String billingPostalCode;
        public List<PaymentMethod> paymentMethods = new List<PaymentMethod>();

        public RestAPIListPaymentMethodResponse(List<blng__PaymentMethod__c> paymentMethods, Account acct) {
            this.Id = acct.Id;
            this.FirstName = acct.blng__BillToContact__r.FirstName;
            this.LastName = acct.blng__BillToContact__r.LastName;
            this.Email = acct.blng__BillToContact__r.Email;
            this.BillingStreet = acct.BillingStreet;
            this.BillingCity = acct.BillingCity;
            this.BillingState = acct.BillingState;
            this.BillingCountry = acct.BillingCountry;
            this.BillingPostalCode = acct.BillingPostalCode;
            for(blng__PaymentMethod__c pm: paymentMethods) {
                this.paymentMethods.add(new PaymentMethod(pm));
            }
        }

    }
    public class PaymentMethod {
        public String billingCompany;
        public String billingFirstName;
        public String billingLastName;
        public String billingEmail;
        public String billingPhone;       
        public String cardLastFour;
        public String lastPaymentStatus;
        public String cardType;
        public String cardExpirationYear;
        public String cardExpirationMonth;
        public String nameOnCard;
        
        public String paymentType;
        public String nickName;
        public String notes;

        public String billingAddress;
        public String streetAddress1;
        public String streetAddress2;
        public String billingStateProvince;
        public String billingCity;
        public String billingCountry;
        public String billingZipPostal;
        public String id;
        public Boolean isDeleted;
        public Boolean isActive;
        public PaymentMethod(blng__PaymentMethod__c pm){
            this.id = pm.Id;
            this.billingCompany = pm.blng__BillingCompany__c;
            this.billingFirstName = pm.blng__BillingFirstName__c;
            this.billingLastName = pm.blng__BillingLastName__c;
            this.billingEmail = pm.blng__BillingEmail__c;
            this.billingPhone = pm.blng__BillingPhone__c;
            this.isDeleted = pm.IsDeleted__c;
            this.isActive = pm.blng__Active__c;
            this.cardLastFour = pm.blng__CardLastFour__c;
            this.CardType = pm.blng__CardType__c;
            this.cardExpirationMonth = pm.blng__CardExpirationMonth__c;
            this.cardExpirationYear = pm.blng__CardExpirationYear__c;
            this.NameOnCard = pm.blng__Nameoncard__c;
            this.paymentType = pm.blng__PaymentType__c;
            this.nickName = pm.blng__NickName__c;
            this.notes = pm.blng__Notes__c;
            this.billingAddress = pm.blng__BillingAddress__c;
            this.streetAddress1 = pm.blng__BillingStreet__c;
            this.streetAddress2 = pm.blng__StreetAddress2__c;
            this.billingCity = pm.blng__BillingCity__c;
            this.billingStateProvince = pm.blng__BillingStateProvince__c;
            this.billingCountry = pm.blng__BillingCountry__c;
            this.billingZipPostal = pm.blng__BillingZipPostal__c;
            if(pm.blng__PaymentMethodTransactions__r != null) {
                for(blng__PaymentTransaction__c trans: pm.blng__PaymentMethodTransactions__r){ 
                    this.lastPaymentStatus = trans.blng__ResponseStatus__c;
                }
            }
        }
    }
}