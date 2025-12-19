public with sharing class RestAPIGetAccountBalanceHandler extends RestAPIHandler {
    public RestAPIGetAccountBalanceHandler() {
        super();
        operation = 'RestAPIGetAccountBalanceHandler';
        className = 'RestAPIGetAccountBalanceHandler';
    }
        
    // override GET
    private void processGET() {
        //initialize save point
        initializeSavePoint();
        
        String accountId = request.params.get('accountId');
        if(String.isBlank(accountId)) {
            throw new InvalidInputException('accountId is a required parameter.');
        }
        Account myAccount;
        try {
            myAccount = RestAPIUtility.getAccount(accountId);
        } catch (Exception ex) {
            throw new InvalidInputException('No Account found for given Account Id. Exception: ' + ex.getMessage());
        }
        List<blng__Invoice__c> pastDueDateUnpaidInvoices = RestAPIUtility.getPastDueDateUnpaidInvoices(accountId);
         
        generateResponse(myAccount,pastDueDateUnpaidInvoices);
    }

        
    // override POST
    private void processPOST() {
        throw new InvalidInputException('POST not allowed');        
    }

    private void generateResponse(Account myAccount, List<blng__Invoice__c> pastDueDateUnpaidInvoices) {
        response = new RestAPIResponse(new RestAPIGetAccountBalanceResponse(myAccount, pastDueDateUnpaidInvoices));
    }


    public class RestAPIGetAccountBalanceResponse {
        public String accountId;
        public String  email;
        public Decimal balance;
        public Boolean hasOutstandingInvoices;

        public RestAPIGetAccountBalanceResponse(Account acct, List<blng__Invoice__c> pastDueDateUnpaidInvoices) {
            this.accountId = acct.Id;
            this.Email = acct.F52_Primary_Contact__r?.Email;
            if(acct.blng__AccountBalanceSnapshots__r != null && acct.blng__AccountBalanceSnapshots__r.size() == 1) {
                this.Balance = acct.blng__AccountBalanceSnapshots__r[0].blng__AccountBalance__c;
            }
            if ( pastDueDateUnpaidInvoices?.size() > 0 ) {
                this.hasOutstandingInvoices = true;
            } else {
                this.hasOutstandingInvoices = false;
            }
        }

    }
}