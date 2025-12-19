public with sharing class RestAPIGetW9FormHandler extends RestAPIHandler {
    public RestAPIGetW9FormHandler() {
        super();
        operation = 'RestAPIGetW9FormHandler';
        className = 'RestAPIGetW9FormHandler';
    }
        
    // override GET
    private void processGET() {
        //initialize save point
        initializeSavePoint();
        
        generateResponse();
    }
        
    // override POST
    private void processPOST() {
        throw new InvalidInputException('POST not allowed');        
    }

    private void generateResponse() {
        response = new RestAPIResponse(new W9Response());
    }
        
    public class W9Response {
        public String URL;
        public W9Response() {
            this.URL = System.Label.W9_URL;
        }
    }
}