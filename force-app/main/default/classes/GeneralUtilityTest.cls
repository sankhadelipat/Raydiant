@IsTest
public class GeneralUtilityTest {
    @IsTest
    public static void test() {

        String joinedString = GeneralUtility.joinSet(new Set<String>{'test123123,123123,123123'}, ',');
        system.assertEquals('test123123,123123,123123',joinedString);
        
        Boolean prod = GeneralUtility.IsProdEnvironment;
        
        DateTime dateTimeVar = GeneralUtility.getDateTimeGMTFromString('2022-12-12 12:12:12');
        system.assertNotEquals(null,dateTimeVar,'formed date/time');

        dateTimeVar = GeneralUtility.getDateTimeGMTFromString(null);
        system.assertEquals(null,dateTimeVar,'null date/time');
    }
}