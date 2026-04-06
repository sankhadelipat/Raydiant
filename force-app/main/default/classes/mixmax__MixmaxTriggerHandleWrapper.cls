/**
 * Wrapper around trigger logic.
 */
public class MixmaxTriggerHandleWrapper {
  ParsedTriggerValues triggerValues;

  /**
   * Constructor for use in a trigger context (we'll parse trigger data from System.Trigger).
   *
   * @param      SObjectType
   */
  public MixmaxTriggerHandleWrapper(SObjectType type) {
    this.triggerValues = getParsedTriggerValuesFromSystemTrigger(type);
  }

  /**
   * Constructor for use in tests (we can simulate System.Trigger here, which isn't actually possible in APEX).
   *
   * @param      SObjectType
   * @param      RawTriggerValues
   */
  public MixmaxTriggerHandleWrapper(SObjectType type, RawTriggerValues triggerValues) {
    this.triggerValues = getParsedTriggerValuesFromRawTrigger(type, triggerValues);
  }

  /**
   * Main trigger handler function; this just grabs the parsed trigger data and calls through to `MixmaxTriggerHandler#handle`.
   */
  public void handleTrigger() {
    if (MixmaxUpdater.getValidatedSettings() == null) {
        return;
    }

    ParsedTriggerValues triggerValues = this.triggerValues;
    new MixmaxTriggerHandler(triggerValues.type, triggerValues.verb).handle(triggerValues.oldMap, triggerValues.newMap);
  }

  /**
   * Getter for the parsed trigger values.
   */
  public ParsedTriggerValues getParsedTriggerValues() {
    return this.triggerValues;
  }

  /**
   * Parses trigger data from System.Trigger into data we care about. Proxies through to `getParsedTriggerValuesFromSystemTrigger`
   * after converting System.Trigger into a RawTriggerValues instance.
   *
   * @param      SObjectType
   *
   * @return     ParsedTriggerValues
   */
  private static ParsedTriggerValues getParsedTriggerValuesFromSystemTrigger(SObjectType type) {
    return getParsedTriggerValuesFromRawTrigger(
      type,
      new RawTriggerValues(Trigger.isUpdate, Trigger.isDelete, Trigger.oldMap, Trigger.newMap)
    );
  }

  /**
   * Parses raw trigger for data that we care about. Specifically, we want to know whether this is a "create", "update", or "delete"
   * operation, and what object type was just changed.
   *
   * @param      SObjectType
   * @param      RawTriggerValues
   *
   * @return     ParsedTriggerValues
   */
  private static ParsedTriggerValues getParsedTriggerValuesFromRawTrigger(SObjectType type, RawTriggerValues rawTriggerValues) {
    String verb;
    if (rawTriggerValues.isUpdate) {
      verb = 'update';
    } else if (rawTriggerValues.isDelete) {
      verb = 'delete';
    } else {
      verb = 'create';
    }

    Map<Id, SObject> oldMap = rawTriggerValues.oldMap;
    Map<Id, SObject> newMap = rawTriggerValues.newMap;

    return new ParsedTriggerValues(verb, type, oldMap, newMap);
  }
}