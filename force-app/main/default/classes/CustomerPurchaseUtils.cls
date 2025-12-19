/**
* @File Name          : CustomerPurchaseUtils.apxc
* @Description        : Apex class for util functions.
*/
public class CustomerPurchaseUtils {
    public static Long convertToEpochTime(Datetime dt) {
        if(dt != NULL) { 
            return dt.getTime()/1000; 
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
    
    public static Integer checkNumberNull(Integer numb) {
        if(numb != NULL) { 
            return numb; 
        } else { 
            return 0; 
        }
    }
    
    public static void handleSuccessOrderItems(List<OrderItem> listOrderItems) {
        for(OrderItem orderItem : listOrderItems) {
            orderItem.Webhook_Status__c = 'Complete';
        }
        
        update listOrderItems;
    }
    
    public static void handleErrorOrderItems(List<OrderItem> listOrderItems) {
        for(OrderItem orderItem : listOrderItems) {
            orderItem.F52_Provisioning_Status__c = 'Error';
        }
        
        update listOrderItems;
        sendEmailAboutErrors();
    }
    
    public static void sendEmailAboutErrors() {   
        try {
            String emailSubject = 'Errors.';
            String emailBody = 'There are errors on order products during execution webhook.';
            List<String> listEmailRecipients = new List<String>();
            
            for(F52_CPQ_Configuration__mdt configuration : getEmailRecipients()) {
                if(String.isNotBlank(configuration.F52_Operations_Email_Address__c)) {
                    listEmailRecipients.add(configuration.F52_Operations_Email_Address__c);
                }
            }
            
            EmailManager.sendMail(listEmailRecipients, emailSubject, emailBody);
        } catch (Exception ex) {
            System.debug('Exception message: ' + ex.getMessage() 
                         + '\n Line number:' + ex.getLineNumber());
        }
    }
    
    private static List<F52_CPQ_Configuration__mdt> getEmailRecipients() {
        return [SELECT Id, F52_Operations_Email_Address__c FROM F52_CPQ_Configuration__mdt];
    } 
}