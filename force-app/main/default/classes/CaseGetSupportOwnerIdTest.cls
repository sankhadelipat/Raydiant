@isTest
public with sharing class CaseGetSupportOwnerIdTest {
    public Static TestMethod void CaseGetSupportOwnerIdTest() {
        Group grp = new Group();
        grp.name = 'Test Group';
        grp.DeveloperName = 'Raydiant_Support';
        insert grp;

        String myId = CaseGetSupportOwnerId.getCaseOwnerId();
       // System.assertEquals(grp.Id, myId);



    }
}