@IsTest
public class dlrs_ContractTrigger_Test {

    @TestSetup
    static void setupData() {
        // Create test Account (required for Contract)
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create initial Contract
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert con;
    }

    @IsTest
    static void testInsertUpdateDeleteUndelete() {
        // Retrieve test data
        Contract con = [SELECT Id, AccountId FROM Contract LIMIT 1];

        // -------- Test Before & After Delete --------
        delete con; // Triggers before delete, after delete
        System.debug('Deleted Contract: ' + con.Id);

        // -------- Test After Undelete --------
        undelete con; // Triggers after undelete
        System.debug('Undeleted Contract: ' + con.Id);
    }
}