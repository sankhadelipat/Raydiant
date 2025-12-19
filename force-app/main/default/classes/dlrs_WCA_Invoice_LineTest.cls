/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_WCA_Invoice_LineTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_WCA_Invoice_LineTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new WCA_Invoice_Line__c());
    }
}