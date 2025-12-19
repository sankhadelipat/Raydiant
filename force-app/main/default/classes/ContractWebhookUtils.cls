/**
* @File Name          : ContractWebhookUtils.apxc
* @Description        : Apex class for util functions.
*/
public class ContractWebhookUtils {
    static final String SUBSCRIPTION_CREATED = 'subscription_created';
    static final String SUBSCRIPTION_CHANGED = 'subscription_changed';
    static final String SUBSCRIPTION_PAUSED = 'subscription_paused';
    static final String SUBSCRIPTION_CANCELLED = 'subscription_cancelled';
    public static Boolean firstRun = true;
    
    public static Long convertToEpochTime(Datetime dt) {
        if(dt != NULL) { 
            return dt.getTime() / 1000;  
        } else { 
            return 0; 
        }
    }
    
    public static String checkStringNull(String str) {
        if(str != NULL) { 
            return str; 
        } else { 
            return ''; 
        }
    }
    
    public static String convertEventType(Contract contract) {
        if(contract.is_New_Webhook__c) { 
            return SUBSCRIPTION_CREATED; 
        } else { 
            if(contract.Status == 'Activated') {
                return SUBSCRIPTION_CHANGED;
            } else if(contract.Status == 'Paused') {
                return Subscription_Paused;
            } else if(contract.Status == 'Cancelled') {
                return SUBSCRIPTION_CANCELLED;
            } else {
                return '';
            }
        }
    }
    
    public static boolean checkContractWebhookWrapperValidity(String json){
        try{
            ContractWebhookWrapper jsonObj= new ContractWebhookWrapper();
            jsonObj = (ContractWebhookWrapper) System.JSON.deserialize(json, ContractWebhookWrapper.class);
            return true;
        }catch(Exception e){
            return false;
        }
	}
 
    
    public static Contract handleSuccessConract(Contract contract) {
        	contract.Backend_Integration_Status__c = 'Success';
        return contract;
    }

    public static Contract handleSuccessConractEx(Contract contract) {
        contract.Backend_Integration_Status_EX__c = 'Success';
    return contract;
    }
    
    public static Contract handleErrorContract(String errorMessage, Contract contract) {
        contract.Backend_Integration_Status__c = 'Error';
        contract.Error_Message__c = errorMessage.length() > 256 ? errorMessage.substring(0, 255) : errorMessage.substring(0, errorMessage.length());
        
        return contract;
    }

    public static Contract handleErrorContractEx(String errorMessage, Contract contract) {
        contract.Backend_Integration_Status_EX__c = 'Error';
        contract.Error_Message_EX__c = errorMessage.length() > 256 ? errorMessage.substring(0, 255) : errorMessage.substring(0, errorMessage.length());
        
        return contract;
    }
    
    public static void sendEmailAboutErrors(List<Contract> listContracts) {   
        try {
            List<String> listEmailRecipients = getEmailRecipients();
            
            for(Contract con : listContracts) {
                if(con.Backend_Integration_Status__c == 'Error') {  //TODO: probably also evaluate new field here, and add EX error message
                    String emailSubject = 'Subject - Backend Integration Error for Contract#' + con.ContractNumber;
                    String emailBody = con.Error_Message__c;
                    
                    EmailManager.sendMail(listEmailRecipients, emailSubject, emailBody);
                }
            }
        } catch (Exception ex) {
            System.debug('Exception message: ' + ex.getMessage() 
                         + '\n Line number:' + ex.getLineNumber());
        }
    }
    
    private static List<String> getEmailRecipients() {
        List<String> listEmailRecipients = new List<String>();
        
        for(F52_CPQ_Configuration__mdt configuration : [SELECT Id, RAY_Engg_Email_Group__c FROM F52_CPQ_Configuration__mdt]) {
            if(String.isNotBlank(configuration.RAY_Engg_Email_Group__c)) {
                listEmailRecipients.add(configuration.RAY_Engg_Email_Group__c);
            }
        }
        
        return listEmailRecipients;
    }
}