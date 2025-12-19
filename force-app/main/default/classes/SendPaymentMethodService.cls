@RestResource(urlMapping='/sendPaymentMethod/*')
global  with sharing class  SendPaymentMethodService{
	
	@HttpPatch
	global static void sendPaymentMethodEmail() {
		
		RestRequest request = RestContext.request;
		RestResponse response = RestContext.response;
		//String email = request.requestURI.substring(request.requestURI.lastIndexOf('/')+1);
		String email = request.params.get('emailId');
		system.debug('Email :'+ email);
		//Process the Paymenthod Method logic
		response.responseBody = PaymentMethodSendEmailRequest.updatePaymentRecordAndSendEmail(email);
		//if any failure then use the response wrapper class to set the Message 
	}
}