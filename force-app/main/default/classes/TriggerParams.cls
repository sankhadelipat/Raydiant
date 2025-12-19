/**
* @File Name          : TriggerParams.cls
* @Description        : This class is invoked from all triggers.
**/
public with sharing class TriggerParams {
    public Boolean isBefore;
    public Boolean isAfter;
    public Boolean isInsert;
    public Boolean isUpdate;
    public Boolean isDelete;
    public Boolean isUndelete;
    public List<sObject> triggerNew;
    public List<sObject> triggerOld;
    public Map<Id, sObject> newMap;
    public Map<Id, sObject> oldMap;
    
    public TriggerParams(Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete, List<sObject> triggerNew, List<sObject> triggerOld, Map<Id, sObject> newMap, Map<Id, sObject> oldMap) {
        this.isBefore = isBefore;
        this.isAfter = isAfter; 
        this.isInsert = isInsert;
        this.isUpdate = isUpdate;
        this.isDelete = isDelete; 
        this.isUndelete = isUndelete;
        this.triggerNew = triggerNew;
        this.triggerOld = triggerOld;
        this.newMap = newMap;
        this.oldMap = oldMap;
    }
}