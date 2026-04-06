public class MixmaxUpdater {

    private static Http http = new Http();

    public static void handle(String type, String verb, String objectString) {
        handle(type, verb, objectString, null, false, PayloadObjectsType.objects);
    }

    public static void handle(String type, String verb, String objectString, String customObjectId,
                              Boolean filtered, PayloadObjectsType objectsType) {
        // Since futures cannot be executed inside another future context, use queueable jobs
        // instead when inside future or batch contexts.
        //
        // However, Salesforce Apex has a hard limit of only allowing a single
        // job to be enqueued in batch context. In most cases this is fine,
        // however, if a batch job is written to update the same types of
        // records multiple times in its execute block, then we would try to
        // enqueue multiple jobs.
        //
        // If we hit this limitation, we follow Salesforce Apex best practices
        // and simply drop the job.
        Integer limitFutureCalls = Limits.getLimitFutureCalls();
        if (Limits.getQueueableJobs() == Limits.getLimitQueueableJobs()) {
            System.debug(
                LoggingLevel.INFO,
                'Dropping Mixmax updates due to Governor queueable limitations');
            return;
        } else if (limitFutureCalls > 0 && Limits.getFutureCalls() >= limitFutureCalls) {
            // When we are in System.isBatch environments the limit of @future calls is 0.
            // So, to prevent false positives, only exit when we actually have a limit of
            // @future calls. In case there's no limit for @futures (aka: 0), let the next
            // condition determine if we should enqueue the job or call the @future method.
            System.debug(
                LoggingLevel.INFO,
                'Dropping Mixmax updates due to Governor future limitations');
            return;
        } else if (System.isFuture() || System.isBatch()) {
            System.enqueueJob(new MixmaxUpdaterQueueable(type, verb, objectString, customObjectId, filtered, String.valueOf(objectsType)));
            return;
        }

        MixmaxUpdater.handleCallout(type, verb, objectString, customObjectId, filtered, String.valueOf(objectsType));
    }

    @future(callout=true)
    public static void handleCallout(String type, String verb, String objectString, String customObjectId,
                                     Boolean filtered, String objectsType) {
        try {
            MixmaxSettings__c mixmaxSettings = MixmaxUpdater.getValidatedSettings();
            if (mixmaxSettings == null) {
                // We guard against this here because it's possible for the Mixmax Settings to have been modified
                // between the initial trigger execution and now.
                return;
            }
            String token = mixmaxSettings.MixmaxToken__c;

            String mixmaxGatewayUrl = mixmaxSettings.MixmaxGatewayUrl__c; // Allow setting via CustomSetting for testing purposes.
            if (mixmaxGatewayUrl == null) {
                // Use default domain.
                mixmaxGatewayUrl = 'https://gateway.mixmax.com';
            }

            // Set up and send request.
            String body = makePayload(type, verb, objectString, customObjectId, filtered, objectsType);
            String method = 'POST';
            String url = mixmaxGatewayUrl + '/salesforce/bulk';
            Map<String, String> headers = new Map<String, String>{'X-API-Token' => token, 'Content-Type' => 'application/json'};

            HttpRequest req = new HttpRequest();
            req.setMethod(method);
            req.setEndpoint(url);
            req.setBody(body);
            for(String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
            http.send(req);
        } catch (Exception e) {
            // Be handle any exceptions so they do not cascade to other future handlers.
            // See presentation here: https://www.slideshare.net/developerforce/defensive-apex-programming
            String errorInfo = type + ',' + verb;
            handleException(e, errorInfo);
        }
    }

    public static String makePayload(String type, String verb, String objectString, String customObjectId,
                                     Boolean filtered, String objectsType) {
        String body = '{ ' +
            '"organizationId": "' + UserInfo.getOrganizationId() + '", ' +
            '"verb": "' + verb + '", ' +
            '"type": "' + type + '", ' +
            '"filtered": ' + String.valueOf(filtered) + ', ';
        if (customObjectId != null) {
            body = body + '"customObjectId": "' + customObjectId + '", ';
        }
        body = body + '"' + objectsType + '": ' + objectString + ' }';
        return body;
    }

    /*
     * Returns the MixmaxSettings__c custom settings instance if it exists and has values for the fields needed
     * to make requests to the gateway service's real-time sync endpoint. Returns null otherwise.
     */
    public static MixmaxSettings__c getValidatedSettings() {
        MixmaxSettings__c mixmaxSettings = MixmaxSettings__c.getInstance();
        if (mixmaxSettings == null) {
            return null;
        }

        // This setting, if checked, allows users to leave the package installed but in a non-functional state, so
        // as to not consume any async Apex quota if they happen to run out.
        Boolean disabled = mixmaxSettings.ApexCalloutsDisabled__c;
        if (disabled == true) {
            return null;
        }

        String token = mixmaxSettings.MixmaxToken__c;
        if (token == null) {
            // We can get here if a salesforce admin deleted the Mixmax token (in Salesforce) after setting it during
            // initial real-time sync setup.
            return null;
        }
        return mixmaxSettings;
    }

    public static void handleException(Exception e, String errorInfo) {
        // Check if user has error logging enabled.
        MixmaxSettings__c mixmaxSettings = MixmaxSettings__c.getInstance();
        if (mixmaxSettings == null) {
            return; // Nothing to do here until it is set up.
        }
        Boolean errorLoggingEnabled = mixmaxSettings.ErrorLoggingEnabled__c;
        if (errorLoggingEnabled == null || errorLoggingEnabled != true) {
            // By default we do not want to log errors because they will cost the user storage.
            // This is something that can be enabled to troubleshoot issues if we cannot debug issues on our side.
            return;
        }

        // User has error logging enabled, let's write to the error log.
        // Inspired by: https://success.salesforce.com/answers?id=90630000000hXXHAA2
        insert new MixmaxError__c(
            Message__c = e.getMessage(),
            TypeName__c = e.getTypeName(),
            Info__c = errorInfo,
            LineNumber__c = e.getLineNumber()
        );
    }
}