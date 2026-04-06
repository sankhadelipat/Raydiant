@isTest
public class MixmaxUpdateHandlerCalloutMock implements HttpCalloutMock {

    static List<String> SUPPORTED_TYPES = new List<String>{
            String.valueOf(Account.SObjectType),
            String.valueOf(Contact.SOBjectType),
            String.valueOf(Event.SOBjectType),
            String.valueOf(Lead.SOBjectType),
            String.valueOf(Opportunity.SOBjectType),
            String.valueOf(OpportunityContactRole.SOBjectType),
            String.valueOf(Task.SOBjectType),
            String.valueOf(User.SOBjectType)
    };

    Boolean shouldBeFiltered;
    Boolean shouldHaveCustomObjectId;
    PayloadObjectsType expectedObjectsType;

    public MixmaxUpdateHandlerCalloutMock() {
        this(false, false, PayloadObjectsType.objects);
    }

    public MixmaxUpdateHandlerCalloutMock(Boolean shouldBeFiltered, Boolean shouldHaveCustomObjectId,
                                          PayloadObjectsType expectedObjectsType) {
        this.shouldBeFiltered = shouldBeFiltered;
        this.shouldHaveCustomObjectId = shouldHaveCustomObjectId;
        this.expectedObjectsType = expectedObjectsType;
    }

    /*
     * The schema for /salesforce/bulk payloads
     */
    class Payload {
        public List<SObjectUpdate> objectsWithChanges;
        public List<SObject> objects;
        public String type;
        public String verb;
        public Boolean filtered;
        public String customObjectId;
        public String organizationId;
    }

    public HttpResponse respond(HttpRequest req) {
        System.assertEquals('https://gateway.mixmax.com/salesforce/bulk', req.getEndpoint());
        System.assertEquals('POST', req.getMethod());

        // Confirm we have a valid request body with the expected properties
        Payload payload;
        try {
            payload = (Payload) JSON.deserializeStrict(req.getBody(), Payload.class);
        } catch (Exception ignored) {
            // We ignore the exception here, and instead fail using the following assertion. This is because unhandled
            // exceptions in deserialization do not cause tests using this mock to fail (possibly because this mock is
            // called from a @future method?)
        }
        if (payload == null) {
            System.debug(req.getBody());
            System.assert(false);
        }

        this.assertValidPayload(payload);

        HttpResponse res = new HttpResponse();
        // Set an empty success response since we don't use the response body.
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        return res;
    }

    void assertValidPayload(Payload payload) {
        System.assert(payload.verb == 'create' || payload.verb == 'update' || payload.verb == 'delete');
        System.assert(SUPPORTED_TYPES.contains(payload.type) || sobjectIsCustom(payload.type));

        if (payload.verb == 'update') {
            System.assert(this.shouldHaveCustomObjectId == (payload.customObjectId != null));
            System.assert(this.shouldBeFiltered == payload.filtered);

            // objectsWithChanges is only applicable to updates
            if (this.expectedObjectsType == PayloadObjectsType.objectsWithChanges) {
                System.assert(payload.objectsWithChanges != null);
            }
        }

        if (payload.verb != 'update' || this.expectedObjectsType == PayloadObjectsType.objects) {
            System.assert(payload.objects != null);
        }
    }

    static Boolean sobjectIsCustom(String type) {
        return Schema.getGlobalDescribe().get(type).getDescribe().isCustom();
    }
}