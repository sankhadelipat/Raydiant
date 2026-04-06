public class MixmaxUtils {
  /**
   * Util function to determine if an SOBjectType belongs to a custom object.
   *
   * @param      SObjectType
   *
   * @return     Boolean
   */
  public static boolean isCustomObject(SObjectType type) {
    return String.valueOf(type).endsWith('__c');
  }
}