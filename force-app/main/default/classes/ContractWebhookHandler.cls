/**
* @File Name          : ContractWebhookHandler.apxc
* @Description        : Apex class for callout webhook from Process Builder.
*/
public class ContractWebhookHandler {

    @InvocableMethod
    public static void callWebhook(List<Id> contractIds) {
        System.debug('in callWebhook');
        if (ContractWebhookUtils.firstRun == true) {
            ContractWebhookUtils.firstRun = false;
            callWebhookFuture(new Set<Id>(contractIds));
        }
    }
    
    public static void callWebhookFuture(Set<Id> setContractIds) {  
        System.debug('in callWebhookFuture');
        List<Contract> listContracts = [SELECT Id, 
                                            CreatedDate, 
                                            SBQQ__Order__c, 
                                            SBQQ__Order__r.SBQQ__Quote__r.Owner.Email, 
                                            ContractNumber, 
                                            is_New_Webhook__c, 
                                            RAY_Dashboard_Email__c,
                                            Status 
                                        FROM Contract 
                                        WHERE Id IN :setContractIds];

        if (!listContracts.isEmpty()) {
            Id jobId = System.enqueueJob(new ContractWebhookQueueable(listContracts));
        }
    }

}