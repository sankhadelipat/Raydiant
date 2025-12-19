/**
* @File Name          : ContractWebhookCallouts.apxc
* @Description        : Apex class for callouts.
*/
public with sharing class ContractWebhookCallouts {    
    public static HttpResponse sendContractWebhook(String dataBody, String namedCredential) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        // request.setEndpoint('callout:Webhook');
        request.setEndpoint(namedCredential);
        request.setBody(dataBody);
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        return response;
    }
}