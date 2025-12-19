/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_CHANNEL_ORDERS_Service_OrderTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_CHANNEL_ORDERS_Service_OrderTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new CHANNEL_ORDERS__Service_Order__c());
    }
}