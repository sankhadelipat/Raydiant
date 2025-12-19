public class PaymentMethod {
    public Id accountId;
    public Id paymentMethodId;
    public String lastFour;
    public String status;
    public String cardType;
    public String expirationYear;
    public String expirationMonth;
    public String nameOnCard;
    public blng__PaymentMethod__c getPaymentMethod() {
        blng__PaymentMethod__c pm = new blng__PaymentMethod__c(blng__Account__c = this.accountId);
        pm.Id = this.paymentMethodId;
        pm.blng__CardLastFour__c = this.lastFour;
        pm.blng__CardType__c = this.cardType;
        pm.blng__CardExpirationMonth__c = this.expirationMonth;
        pm.blng__CardExpirationYear__c = this.expirationYear;
        pm.blng__Nameoncard__c = this.nameOnCard;
        return pm;
    }
    public PaymentMethod(blng__PaymentMethod__c pm){
        this.paymentMethodId = pm.Id;
        this.accountId = pm.blng__Account__c;
        this.lastFour = pm.blng__CardLastFour__c;
        this.cardType = pm.blng__CardType__c;
        this.expirationMonth = pm.blng__CardExpirationMonth__c;
        this.expirationYear = pm.blng__CardExpirationYear__c;
        this.nameOnCard = pm.blng__Nameoncard__c;
        if(pm.blng__PaymentMethodTransactions__r != null) {
            for(blng__PaymentTransaction__c trans: pm.blng__PaymentMethodTransactions__r){ 
                this.status = trans.blng__Status__c;
            }
        }
    }
}