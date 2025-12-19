public without sharing class HTTPCalloutUtility {
    
    public final static String ENDPOINT_INSTANCE_DEV = 'Dev';
    public final static String ENDPOINT_INSTANCE_STAGING = 'Staging';
    public final static String ENDPOINT_INSTANCE_PRODUCTION = 'Production';
    
    public static Endpoint_Properties__c fetchEndpointProperty(String endpointName, String instance) {        
        List<Endpoint_Properties__c> endpoint = new List<Endpoint_Properties__c>();
        endpoint = [SELECT Id, Name, Endpoint_URL__c, Content_Type__c, Custom_Header_Key__c, Endpoint_Instance__c
                    FROM Endpoint_Properties__c
                    WHERE Name =: endpointName
                    AND Endpoint_Instance__c =: instance];
        
        if ( endpoint.size() != 1 ) {
            return null;
        } else {
            return endpoint[0];
        }  
    }

    public static HttpRequest newRequest(String endpoint, String method, Integer timeout, Object reqBody, Map<String, String> headers, Map<String, String> params) {
        
        if ( String.isBlank(endpoint) || String.isBlank(method) ) {
            throw new HttpCalloutException('Request Endpoint and method are required.');
        }

        endpoint = appendURLParameters(endpoint,params);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);

        if ( timeout != null ) {
			req.setTimeout(timeout);
		}

        req = addRequestBody(req, reqBody);		
		req = addHeaderParameters(req, headers);

        return req;
    }

    public static HTTPResponse sendRequest(HTTPRequest request) {
        HttpResponse resp = (new Http()).send(request);
        return resp;
    }
	
	private static HttpRequest addRequestBody(HttpRequest req, Object requestBody) {
        if ( requestBody != null ) {
            if ( requestBody instanceof String ) {
                req.setBody((String)requestBody);
            } else if ( requestBody instanceof Blob ) {
                req.setBodyAsBlob((Blob)requestBody);
            } else {
                req.setBody(JSON.serialize(requestBody, true));
            }
        }
        return req;
    }

    private static String appendURLParameters(String endpoint, Map<String, String> params) {
        
        if( !params.isEmpty() ) {
            endpoint += '?';
            for ( String urlParamKey : params.keySet() ) {
                endpoint += urlParamKey + '=' + params.get(urlParamKey) + '&';
            }
            endpoint = endpoint.substringBeforeLast('&');
        }
		return endpoint;
    }

    private static HttpRequest addHeaderParameters(HttpRequest req, Map<String, String> requestHeader) {

        if( !requestHeader.isEmpty() ){
            for ( String key :requestHeader.keySet() ) {
                req.setHeader(key, requestHeader.get(key));
            }
        }
        return req;
    }

}