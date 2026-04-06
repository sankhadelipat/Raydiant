@isTest
private class Test_MixmaxUtils {
  @isTest
  static void testStandardObject() {
    Test.startTest();
    System.assert(MixmaxUtils.isCustomObject(Lead.getSObjectType()) == false);
    Test.stopTest();
  }

  @isTest
  static void testCustomObject() {
    Test.startTest();
    System.assert(MixmaxUtils.isCustomObject(MixmaxError__c.getSObjectType()) == true);
    Test.stopTest();
  }
}