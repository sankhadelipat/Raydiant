/**
 * Parsed trigger values; `verb` and `type` are the values not on System.Trigger that we compute before instantiating this class.
 */
public class ParsedTriggerValues {
  public String verb;
  public SObjectType type;
  public Map<Id, SObject> oldMap;
  public Map<Id, SObject> newMap;

  public ParsedTriggerValues(String verb, SObjectType type, Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
    this.verb = verb;
    this.type = type;
    this.oldMap = oldMap;
    this.newMap = newMap;
  }
}