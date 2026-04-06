@isTest
public class Test_Utils {
    // Assumes Apex tests run in a single thread.
    static Integer generated = 0;

    public static String getFakeId(Schema.SObjectType sot) {
        String result = String.valueOf(generated++);
        return sot.getDescribe().getKeyPrefix() +
                '0'.repeat(12-result.length()) + result;
    }

    public static void insertLeads(Integer count) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            leads.add(new Lead(
                    Company = 'Company:' + i,
                    FirstName = 'FirstName:' + i,
                    LastName = 'LastName:' + i
            ));
        }
        insert leads;
    }

    public static void insertContacts(Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                    FirstName = 'FirstName:' + i,
                    LastName = 'LastName:' + i
            ));
        }
        insert contacts;
    }
}