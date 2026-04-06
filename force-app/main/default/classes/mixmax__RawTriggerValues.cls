/**
* Raw trigger values, usually grabbed from System.Trigger but occasionally injected (e.g. in tests).
*/
public class RawTriggerValues {
  public Boolean isUpdate;
  public Boolean isDelete;
  public Map<Id, SObject> oldMap;
  public Map<Id, SObject> newMap;

  public RawTriggerValues(Boolean isUpdate, Boolean isDelete, Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
    this.isUpdate = isUpdate;
    this.isDelete = isDelete;
    this.oldMap = oldMap;
    this.newMap = newMap;
  }

  public RawTriggerValues(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
    this.oldMap = oldMap;
    this.newMap = newMap;
  }
}