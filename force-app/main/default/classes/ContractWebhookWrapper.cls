/**
* @File Name          : ContractWebhookWrapper.apxc
* @Description        : Apex wrapper class for wrap data from Contract.
*/
public class ContractWebhookWrapper {
    public String id {get;set;} 
    public Long occurred_at {get;set;} 
    public String source {get;set;} 
    public String user {get;set;} 
    public Content content {get;set;} 
    public String event_type {get;set;} 
    
    public class Content {
        public Contract contract {get;set;} 
    }
    
    public class Contract {
        public String contract_number {get;set;} 
    }
}