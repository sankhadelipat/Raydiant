public class StripeContractHandler implements Database.Batchable<SObject>
{
    public Database.QueryLocator start(Database.BatchableContext bc) 
    {
        return Database.getQueryLocator([
            SELECT SBQQ__SubscriptionType__c, Id, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Contract__c,
            Stripe_Subscription_ID_Actual__c
            FROM SBQQ__Subscription__c 
            WHERE //F52_Active__c = true
            Stripe_Subscription_ID_Actual__c != null
            ///AND SBQQ__Product__r.Stripe_Product_ID__c != NULL 
            And  Stripe_Price_ID__c  !=null
        ]);
    }
    public void execute(Database.BatchableContext bc, List<SBQQ__Subscription__c> scope) {
        try
        {
            List<SBQQ__Subscription__c> updateScope = new List<SBQQ__Subscription__c> ();
            set<string> conExtId = new set<string>();
            Map<String, String> idwitstripeid = new map<string,String>();
            for(SBQQ__Subscription__c sub : scope)
            {
                conExtId.add(sub.Stripe_Subscription_ID_Actual__c);
            }
            
            list<Contract> conList = [select id ,Stripe_Subscription_ID__c from Contract where Stripe_Subscription_ID__c IN:conExtId];
            system.debug('conList--'+conList);
            for(Contract con : conList)
            {
                idwitstripeid.put(con.Stripe_Subscription_ID__c ,con.id);
                system.debug('idwitstripeid--'+idwitstripeid);
            }
            
            for(SBQQ__Subscription__c sub : scope)
            {
                if(idwitstripeid.containskey(sub.Stripe_Subscription_ID_Actual__c))
                {
                    sub.SBQQ__Contract__c = idwitstripeid.get(sub.Stripe_Subscription_ID_Actual__c);
                    updateScope.add(sub);
                }
            }
            update updateScope;
            system.debug('Scope is updated--');
        }
        catch (Exception ex) {
            System.debug('Error in batch execution: ' + ex.getMessage());
            /*insert new Logger__c(
                Name = 'Stripe Subscription Update Error',
                Message__c = ex.getMessage(),
                StackTrace__c = ex.getStackTraceString(),
                Status__c = 'Error',
                Apex_Class__c = 'StripeContractHandler',
                Apex_Method__c = 'execute',
                Object_Name__c = 'Subscription'
            );*/
        }
        
    }
    public void finish(Database.BatchableContext bc) {
        System.debug('Contract Tag');
    }
}