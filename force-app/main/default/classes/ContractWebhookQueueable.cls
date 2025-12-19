public class ContractWebhookQueueable implements Queueable, Database.AllowsCallouts {
    
    final String SALESFORCE = 'Salesforce';
    private List<Contract> contractsToProcessNow;
    private List<Contract> contractsToProcessLater;
    private List<Contract> contractsProcessed;
    
    public ContractWebhookQueueable(List<Contract> contracts) {
        this.contractsToProcessNow = new List<Contract>();
        this.contractsToProcessLater = new List<Contract>();

        Integer count = 0;
        for (Contract c : contracts) {
            count++;
            if (count <= 50) {      //  to avoid API callout governor limits
                this.contractsToProcessNow.add(c);
            } else {
                this.contractsToProcessLater.add(c);
            }
        }
    }

    public void execute(QueueableContext context) {
        try {
            this.contractsProcessed = new List<Contract>();
            for (Contract contractIter : contractsToProcessNow) {
                ContractWebhookWrapper contractWebhookWrap = new ContractWebhookWrapper();
                contractWebhookWrap.content = new ContractWebhookWrapper.Content();
                contractWebhookWrap.content.contract = new ContractWebhookWrapper.Contract();
                // contractWebhookWrap.id = ContractWebhookUtils.checkStringNull(contractIter.SBQQ__Order__c);
                contractWebhookWrap.id = contractIter.Id; 
                contractWebhookWrap.occurred_at = ContractWebhookUtils.convertToEpochTime(contractIter.CreatedDate);
                contractWebhookWrap.source = SALESFORCE;
                // contractWebhookWrap.user = ContractWebhookUtils.checkStringNull(String.valueOf(contractIter.SBQQ__Order__r.SBQQ__Quote__r.Owner.Email));
                contractWebhookWrap.user = ContractWebhookUtils.checkStringNull(String.valueOf(contractIter.RAY_Dashboard_Email__c));
                // System.debug(ContractWebhookUtils.checkStringNull(String.valueOf(contractIter.SBQQ__Order__r.SBQQ__Quote__r.Owner.Email)));
                contractWebhookWrap.content.contract.contract_number = ContractWebhookUtils.checkStringNull(contractIter.Id);
                contractWebhookWrap.event_type = ContractWebhookUtils.convertEventType(contractIter);
                if (ContractWebhookUtils.checkContractWebhookWrapperValidity(JSON.serialize(contractWebhookWrap))) {
                    // System.debug('JSON.serialize(contractWebhookWrap): '+ JSON.serialize(contractWebhookWrap));
                    String body = JSON.serialize(contractWebhookWrap);
                    contractIter.Latest_Webhook_To_Send_JSON__c = String.valueOf(JSON.serialize(contractWebhookWrap));
                    contractIter.Latest_CX_EX_Webhooks_Sent_Date__c = Datetime.now();
                    contractIter.is_New_Webhook__c = false;
                    
                    HttpResponse response = ContractWebhookCallouts.sendContractWebhook(JSON.serialize(contractWebhookWrap), 'callout:Webhook');
                    contractIter.Latest_Webhook_Response_JSON__c = String.valueOf(response + response.getBody());                 //Changed Yu 04.06.21 to show whole answer, requested by Vivek
                    HttpResponse responseEx = ContractWebhookCallouts.sendContractWebhook(JSON.serialize(contractWebhookWrap), 'callout:Ex_Webhook');
                    contractIter.Latest_Ex_Webhook_Response_JSON__c = String.valueOf(responseEx + responseEx.getBody());
                    //TODO: should possibly update this to not add to the list until the end...re-test behavior when record gets added to list more than once and we dedupe with map
                    // CX endpoint success
                    if (isSuccessful(response)) {
                        contractsProcessed.add(ContractWebhookUtils.handleSuccessConract(contractIter));
                    }
                    // EX endpoint success
                    if (isSuccessful(responseEx)) {
                        contractsProcessed.add(ContractWebhookUtils.handleSuccessConractEx(contractIter));
                    }
                    // CX endpoint error
                    if (!isSuccessful(response)) {
                        contractsProcessed.add(ContractWebhookUtils.handleErrorContract(String.valueOf('Response: ' + response + ' Response Body: ' + response.getBody()), contractIter));
                    }
                    // EX endpoint error
                    if (!isSuccessful(responseEx)) {
                        contractsProcessed.add(ContractWebhookUtils.handleErrorContractEx(String.valueOf('Response: ' + responseEx + ' Response Body: ' + responseEx.getBody()), contractIter));
                    }
                } else {
                    contractsProcessed.add(ContractWebhookUtils.handleErrorContract('Webhook wrapper is not valid', contractIter));
                }
                System.debug('>>> # of contracts to process now: ' + contractsToProcessNow.size());
                System.debug('>>> # of contracts to process later: ' + contractsToProcessLater.size());
            }
            if (!contractsProcessed.isEmpty()) { 
                Map<Id, Contract> contractsProcessedWithoutDupesMap = new Map<Id, Contract>();
                contractsProcessedWithoutDupesMap.putAll(contractsProcessed);
                UPDATE contractsProcessedWithoutDupesMap.values();
                ContractWebhookUtils.sendEmailAboutErrors(contractsProcessed); 
            }
            if (!contractsToProcessLater.isEmpty()) {
                processNextJob();
            }
        } catch (Exception ex) {
            System.debug('Exception message: ' + ex.getMessage() 
                         + '\n Line number: ' + ex.getLineNumber());
        }
    }

    private Boolean isSuccessful(HttpResponse httpResponse) {
        if (httpResponse.getStatusCode() >= 200 && httpResponse.getStatusCode() < 300) {
            return true;
        } else {
            return false;
        }
    }

    private void processNextJob() {
        System.debug('>>> queueing a new webhook job');
        Id jobId = System.enqueueJob(new ContractWebhookQueueable(this.contractsToProcessLater));
    }

}