/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_CHANNEL_ORDERS_Service_OrderTrigger on CHANNEL_ORDERS__Service_Order__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(CHANNEL_ORDERS__Service_Order__c.SObjectType);
}