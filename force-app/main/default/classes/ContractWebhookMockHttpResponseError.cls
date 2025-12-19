@isTest
global class ContractWebhookMockHttpResponseError implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(500);
        res.setStatus('Bad Request');
        
        return res;
    }
}