public without sharing class GeneralUtility {
    
    public static String joinSet(Set<String> strs, String delim) {
        return String.join(new List<String>(strs), delim);
    }

    public static Boolean isProdEnvironment { get {
        Organization org;
        if(org == null ) {            
            org = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
        }
        isProdEnvironment = !org.IsSandbox;
        
        return isProdEnvironment;
    } set;}

    //DateTimeString format -> 2022-12-13T14:05:15.630378Z / 2021-10-16T15:20:41.990679+00:00
    public static DateTime getDateTimeGMTFromString(String dateTimeString) {
        DateTime dateTimeInGMT;
        if ( String.isBlank(dateTimeString) ) {
            return null;
        }

        dateTimeInGMT = DateTime.valueOfGmt(dateTimeString.replace('T', ' '));
        return dateTimeInGMT;
    }
    
}