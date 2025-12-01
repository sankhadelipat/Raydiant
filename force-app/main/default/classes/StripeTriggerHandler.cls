public class StripeTriggerHandler {
    // Map to hold bypass flags per object (e.g., Account, Invoice, etc.)
    private static Map<String, Boolean> bypassMap = new Map<String, Boolean>();

    /**
     * Enables trigger bypass for a specific object.
     * Example: StripeTriggerHandler.enableBypass('Account');
     */
    public static void enableBypass(String objectName) {
        if (String.isNotBlank(objectName)) {
            bypassMap.put(objectName.toLowerCase(), true);
        }
    }

    /**
     * Disables trigger bypass for a specific object.
     * Example: StripeTriggerHandler.disableBypass('Account');
     */
    public static void disableBypass(String objectName) {
        if (String.isNotBlank(objectName)) {
            bypassMap.put(objectName.toLowerCase(), false);
        }
    }

    /**
     * Checks if bypass is enabled for the given object.
     * Example: if (StripeTriggerHandler.isBypassEnabled('Account')) { return; }
     */
    public static Boolean isBypassEnabled(String objectName) {
        if (String.isBlank(objectName))
            return false;
        return bypassMap.containsKey(objectName.toLowerCase()) && bypassMap.get(objectName.toLowerCase());
    }

    /**
     * Utility method: Enables bypass for multiple objects at once.
     * Example: StripeTriggerHandler.enableBypassForAll(new List<String>{'Account', 'Invoice'});
     */
    public static void enableBypassForAll(List<String> objectNames) {
        if (objectNames == null)
            return;
        for (String name : objectNames) {
            enableBypass(name);
        }
    }

    /**
     * Utility method: Disables bypass for multiple objects at once.
     */
    public static void disableBypassForAll(List<String> objectNames) {
        if (objectNames == null)
            return;
        for (String name : objectNames) {
            disableBypass(name);
        }
    }

    /**
     * Clears all bypasses (optional safety method).
     */
    public static void resetAll() {
        bypassMap.clear();
    }
}
