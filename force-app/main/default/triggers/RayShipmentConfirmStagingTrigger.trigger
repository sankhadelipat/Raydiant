/**
* @File Name          : RayShipmentConfirmStagingTrigger.apxt
* @Description        : Trigger on object Ray_Shipment_Confirmation_Staging__c.
*/
trigger RayShipmentConfirmStagingTrigger on Ray_Shipment_Confirmation_Staging__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    RayShipmentConfirmStagingTriggerHandler.entry(new TriggerParams(trigger.isBefore, trigger.isAfter, trigger.isInsert, trigger.isUpdate, trigger.isDelete, trigger.isUndelete, trigger.new, trigger.old, trigger.newMap, trigger.oldMap));
}