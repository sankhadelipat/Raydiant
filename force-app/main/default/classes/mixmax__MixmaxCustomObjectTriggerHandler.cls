/**
 * Wrapper around MixmaxTriggerHandleWrapper exposed for external consumption.
 */
global class MixmaxCustomObjectTriggerHandler {
  SObjectType type;

  /**
   * Constructor for use in a trigger context (we'll grab the changed object by parsing System.Trigger).
   */
  global MixmaxCustomObjectTriggerHandler() {
    this.type = parseTypeFromTrigger(new RawTriggerValues(Trigger.oldMap, Trigger.newMap));
  }

  /**
   * Constructor for use in tests (we can simulate System.Trigger here, which isn't actually possible in APEX).
   *
   * @param      RawTriggerValues
   */
  public MixmaxCustomObjectTriggerHandler(RawTriggerValues maps) {
    this.type = parseTypeFromTrigger(maps);
  }

  /**
   * Trigger handler function exposed for external consumption.
   */
  global void handleTrigger() {
    // Ensure that we're handling a change event for a custom object.
    Boolean isCustomObject = MixmaxUtils.isCustomObject(type);
    if (!isCustomObject) return;

    new MixmaxTriggerHandleWrapper(this.type).handleTrigger();
  }

  /**
   * Getter for the parsed SObject type.
   *
   * @return     SObjectType
   */
  public SObjectType getType() {
    return this.type;
  }

  /**
   * Parses trigger data for the record type being updated.
   *
   * @param      RawTriggerValues  The trigger values
   *
   * @return     SObjectType
   */
  private static SObjectType parseTypeFromTrigger(RawTriggerValues triggerValues) {
    // `newMap` is not available in "after delete" triggers: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_Trigger.htm.
    if (triggerValues.newMap != null) {
      return triggerValues.newMap.getSObjectType();
    } else {
      return triggerValues.oldMap.getSObjectType();
    }
  }
}