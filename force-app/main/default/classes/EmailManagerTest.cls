@isTest
public class EmailManagerTest {
	@isTest
    static void testTheEmail(){
        Test.startTest();
            EmailManager.sendMail('test@test.com', 'Test', 'Test');
            Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();
        System.assertEquals(1, invocations, 'Email has not been sent');
}
    
   	@isTest
    static void testTheListOfEmails(){
        Test.startTest();
        EmailManager.sendMail(new List<String>{'test@test.com', 'test2@test.com', 'test3@test.com'}, 'Test', 'Test');
            Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();
        System.assertEquals(1, invocations, 'Email has not been sent');
}
}