/*
 * Enumerates the properties used to store Salesforce object data in payloads to Mixmax' Gateway endpoint. Each property
 * corresponds to a different structure of object, and each payload should have exactly one such property. For example,
 * an `objects` property in a payload will be an array of `SObject`s, while an `objectsWithChanges` property will be
 * an array of `SObjectUpdate`s.
 */
public enum PayloadObjectsType {
        objects, // An array of SObject objects
        objectsWithChanges // An array of SOBjectUpdate objects
}