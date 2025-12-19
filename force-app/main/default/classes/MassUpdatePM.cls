public class MassUpdatePM {
    public List<Id> SelectedPMIDs{get;set;}
    public String recordIdPrefix;
    public ApexPages.StandardSetController stdSetController;
    public MassUpdatePM(ApexPages.StandardSetController listcontroller)
    {
        if (!Test.isRunningTest()) {
            listcontroller.addFields(new List<String>{'blng__PaymentMethod__c'});
        }
        stdSetController = listcontroller;
        if(listcontroller.getSelected().size() == 0 ) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.FATAL,'Please select atleast one invoice'));
        }
        if(listcontroller.getSelected() != null && listcontroller.getSelected().size() > 50) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.FATAL,'Please select maximum of 50 invoices'));
        }
        if(listcontroller.getSelected() != null && listcontroller.getSelected().size() > 0 && listcontroller.getSelected().size() <= 50) {
            
            Set<Id> setPMId = new Set<Id>();
            for(blng__Invoice__c invoice : (List<blng__Invoice__c>)listcontroller.getSelected()) {
                setPMId.add(invoice.blng__PaymentMethod__c);
                recordIdPrefix = String.valueOf(invoice.Id).left(3);
            }
            
            SelectedPMIDs = new List<Id>(setPMId);
            system.debug('===' + SelectedPMIDs);
        }
        //this.SelectedPMIDs = (blng__Invoice__c)listcontroller.getRecord();      
    }
    
    public pageReference getRedirectToInvoices(){
        return new PageReference('/'+recordIdPrefix);
    }
    
    public pageReference back() {
        return stdSetController.cancel();
    }
    
}