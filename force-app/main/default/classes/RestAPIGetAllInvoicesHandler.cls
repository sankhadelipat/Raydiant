public with sharing class RestAPIGetAllInvoicesHandler extends RestAPIHandler {
    public RestAPIGetALLInvoicesHandler() {
        super();
        operation = 'RestAPIGetALLInvoicesHandler';
        className = 'RestAPIGetALLInvoicesHandler';
    }
    
    Account accountVar;
        
    // override GET
    private void processGET() {
        //initialize save point
        initializeSavePoint();
        
        //1. Check if Account exists.
        fetchAccount();
        
        String accountId = request.params.get('accountId');
        Boolean hasOutstandingBalance;
        Date minDueDate, minIssueDate, maxIssueDate;
        String invoiceStatus;
        if(request.params.get('hasOutstandingBalance') != null){
            hasOutstandingBalance = Boolean.valueOf(request.params.get('hasOutstandingBalance'));
        }
        if(request.params.get('minDueDate') != null){
            minDueDate = Date.valueOf(request.params.get('minDueDate'));
        }
        if(request.params.get('minIssueDate') != null){
            minIssueDate = Date.valueOf(request.params.get('minIssueDate'));
        }
        if(request.params.get('maxIssueDate') != null){
            maxIssueDate = Date.valueOf(request.params.get('maxIssueDate'));
        }
        if( String.isNotBlank(request.params.get('invoiceStatus')) ) {
            invoiceStatus = String.valueOf(request.params.get('invoiceStatus'));
        }
        
        List<blng__Invoice__c> myInvoices = RestAPIUtility.getInvoices(accountId, minDueDate, minIssueDate, maxIssueDate, hasOutstandingBalance, invoiceStatus);
        Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> allocationsByInvoiceId = RestApiUtility.getPaymentAllocationsByInvoiceId(myInvoices);
        
        generateResponse(myInvoices, accountVar, allocationsByInvoiceId);
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

    private void generateResponse(List<blng__Invoice__c> myInvoices, Account myAccount, Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> allocationsByInvoiceId) {
        response = new RestAPIResponse(new RestAPIGetALLInvoicesResponse(myInvoices, myAccount, allocationsByInvoiceId));
    }


    public class RestAPIGetALLInvoicesResponse {
        public String accountId;
        public List<Invoice> invoices = new List<Invoice>();
        public String firstName;
        public String lastName;
        
        public RestAPIGetAllInvoicesResponse(List<blng__Invoice__c> invoiceList, Account acct, Map<Id, List<blng__PaymentAllocationInvoiceLine__c>> allocationsByInvoiceId) {
            this.accountId = acct.Id;
            this.firstName = acct.blng__BillToContact__r.FirstName;
            this.lastName = acct.blng__BillToContact__r.LastName;
        
            for(blng__Invoice__c inv: invoiceList) {
                invoices.add(new Invoice(inv, allocationsByInvoiceId.get(inv.Id)));
            }
        }
    }
    public class Invoice {
        public Date dueDate;
        public Decimal amount;
        public Decimal subTotal;
        public String currencyIsoCode = 'USD';
        public Id id;
        public String invoiceStatus;
        public String name;
        public BillToAddress billToInfo;
        public Date issueDate;
        public Decimal taxAmount;
        public String paymentStatus;
        public String contentDocumentId;
        public List<Payment> payments = new List<Payment>();
        public Invoice(blng__Invoice__c inv, List<blng__PaymentAllocationInvoiceLine__c> pails) {
            this.subTotal = inv.blng__Subtotal__c;
            this.name = inv.name;
            this.id = inv.Id;
            this.invoiceStatus = inv.blng__InvoiceStatus__c;
            this.billToInfo = new BillToAddress(inv);
            this.amount = inv.blng__TotalAmount__c;
            this.dueDate = inv.blng__DueDate__c;
            this.issueDate = inv.blng__InvoiceDate__c;
            this.taxAmount = inv.blng__TaxAmount__c;
            this.paymentStatus = inv.blng__PaymentStatus__c;
            if(inv.ContentDocumentLinks != null && inv.ContentDocumentLinks.size() > 0) {
                this.contentDocumentId = inv.ContentDocumentLinks[0].ContentDocumentId;
            }
            if(pails != null) {
                Map<Id, Payment> paymentById = new Map<Id, Payment>();
                for(blng__PaymentAllocationInvoiceLine__c p: pails) {
                    if ( paymentById.containsKey(p.blng__payment__c) ) {
                        Payment paymentInstance = paymentById.get(p.blng__payment__c);
                        paymentInstance.amount += p.blng__Amount__c;
                        paymentById.put(p.blng__payment__c, paymentInstance);
                    } else {
                        Payment paymentInstance = new Payment();
                        paymentInstance.paymentMethodId = p.blng__Payment__r.blng__PaymentMethod__c;
                        paymentInstance.amount = p.blng__Payment__r.blng__Amount__c;
                        paymentInstance.status = p.blng__Payment__r.blng__Status__c;
                        paymentInstance.name = p.blng__Payment__r.Name;
                        paymentInstance.paymentDate = p.blng__InvoiceLine__r.blng__Invoice__r.blng__InvoiceDate__c;
                        paymentById.put(p.blng__payment__c, paymentInstance);
                    }
                    //paymentById.put(p.blng__payment__c, new Payment(p));      //use the blng__payment__c rather than pail.id
                }
                this.payments.addAll(paymentById.values());
            }
        }
    }

    public class BillToAddress {
        public String billingStreet;
        public String billingCity;
        public String billingState;
        public String billingPostalCode;
        public String billingCountry;

        public BillToAddress(blng__Invoice__c inv) {
            this.billingStreet = inv.RAY_BillTo_Street__c;
            this.billingCity = inv.RAY_BillTo_City__c;
            this.billingState = inv.RAY_BillTo_State__c;
            this.billingPostalCode = inv.RAY_BillTo_PostalCode__c;
            this.billingCountry = inv.RAY_BillTo_Country__c;
        }
    }

    public class Payment {
        public String paymentMethodId;
        public Decimal amount;
        public String name;
        public String status;
        public Date paymentDate;

        public Payment() {
            this.paymentMethodId = '';
            this.amount = null;
            this.status = '';
            this.name = '';
            this.paymentDate = null;
        }
    }
}