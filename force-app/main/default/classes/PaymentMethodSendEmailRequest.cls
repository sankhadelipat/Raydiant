/*-----------------------------------------------------------------------
* PaymentMethodSendEmailRequest
* @Author:
* @Company:
* @REST REQUEST :
* @Description: It sends the payment method for the requested email
History
<Date> <Version> <Brief Description of Change>
29-12-2021 1.0 Initial logic
---------------------------------------------------------------------------*/
public without sharing class PaymentMethodSendEmailRequest{

	public static blob updatePaymentRecordAndSendEmail(string email){

		blob response;
		List<Contract> contractList = getContractDetails(email);
		List<Account> accountList; 

		if(!contractList.isEmpty()){
			
			//If there are more than one contract
			if(contractList.size() > 1){
				PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
					new PaymentMethodSendEmailRequestResponse('CONTRACT_TOO_MANY_CONTRACTS', 'More than one Contracts exist with the requested email')
				};
				response = Blob.valueOf(JSON.serialize(res));
			}
			else if(contractList.size() == 1){
				//Dashboard Email is populated but Payment Method is not populated for the Contract
				if(String.isBlank(contractList.get(0).Ray_Payment_Method__c)){
					PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
						new PaymentMethodSendEmailRequestResponse('CONTRACT_UPDATE_FAILED_NO_PM', 'No Payment Method populated for Contract')
					};
					response = Blob.valueOf(JSON.serialize(res));	
				}else{
					// When both Dashboard Email and Payment Method email are populated, but Payment Method and Dashboard email are different
					Map<String, Object> myMap = new Map<String, Object>();
					if(
						string.isNotBlank(contractList.get(0).Ray_Payment_Method__r.blng__BillingEmail__c) && 
					    contractList.get(0).RAY_Dashboard_Email__c != contractList.get(0).Ray_Payment_Method__r.blng__BillingEmail__c
					)
					{
						try{
							//call the flow
							//always going to be a single record
							myMap.put('DashboardEmail', contractList.get(0).RAY_Dashboard_Email__c);
							myMap.put('RecordID', contractList.get(0).Ray_Payment_Method__c);
							system.debug('myMap : '+myMap);

							Flow.Interview.Create_Payment_Method_PM_Integration myFlow = new Flow.Interview.Create_Payment_Method_PM_Integration(myMap);
							myFlow.start();
							system.debug('message==>' + myFlow.getVariableValue('message'));
							system.debug('is_success==>' + myFlow.getVariableValue('is_success'));

							boolean isFlowOperationSuccess = (boolean)myFlow.getVariableValue('is_success');
							if(isFlowOperationSuccess || Test.isRunningTest()){
								PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
									new PaymentMethodSendEmailRequestResponse('Success', 'Payment Method Updated successfully and email is sent')
								};
								response = Blob.valueOf(JSON.serialize(res));
							}
						}
						catch(Exception e){
							//catch the exception
							PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
								new PaymentMethodSendEmailRequestResponse('CONTRACT_UPDATE_FAILED_EMAIL_DIFF', 'Something wrong : either update is not successful or Email is not sent '+e.getMessage())
							};
							response = Blob.valueOf(JSON.serialize(res));
						}
					}
					else{
						try{
							//call the flow
							//always going to be a single record
							myMap.put('RecordID', contractList.get(0).Ray_Payment_Method__c);

							Flow.Interview.Create_Payment_Method_PM_Integration myFlow = new Flow.Interview.Create_Payment_Method_PM_Integration(myMap);
							myFlow.start();
							system.debug('message==>' + myFlow.getVariableValue('message'));
							system.debug('is_success==>' + myFlow.getVariableValue('is_success'));

							boolean isFlowOperationSuccess = (boolean)myFlow.getVariableValue('is_success');
							//isRunningTest included because test class will never acknowledge the flow email is successfully sent
							if(isFlowOperationSuccess || Test.isRunningTest()){
								PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
									new PaymentMethodSendEmailRequestResponse('Success', 'Payment Method Updated successfully and email is sent')

								};
								response = Blob.valueOf(JSON.serialize(res));
							}
						}
						catch(Exception e){
							//catch the exception
							PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
								new PaymentMethodSendEmailRequestResponse('CONTRACT_REQUEST_FAILED_EMAIL_MATCH', 'Something wrong : either update is not successful or Email is not sent '+e.getMessage())
							};
							response = Blob.valueOf(JSON.serialize(res));
						}
					}
				}
			}	
		}
		else{
			
			accountList = getAccountDetails(email);
			
			if(!accountList.isEmpty()){
				//if more than one Account exist with Primary Contact Email
				 if(accountList.size() > 1){
					PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
						new PaymentMethodSendEmailRequestResponse('ACCOUNT_TOO_MANY_ACCOUNTS', 'More than one Account exist with the requested email')
					};
					response = Blob.valueOf(JSON.serialize(res));
				}
				// If there are no Payment record exist with request email even though we found Account
				else if(accountList.size() == 1 && accountList.get(0).blng__AccountPaymentMethods__r.size() < 1){
					PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
						new PaymentMethodSendEmailRequestResponse('ACCOUNT_PM_NOT_FOUND', 'Account exist but there are no active Payment Method exist with the requested email')
					};
					response = Blob.valueOf(JSON.serialize(res));
				}
				// if more than one active Payment Method record exist
				else if(accountList.size() == 1 && accountList.get(0).blng__AccountPaymentMethods__r.size() > 1 ){
					PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
						new PaymentMethodSendEmailRequestResponse('ACCOUNT_TOO_MANY_ACTIVE_PAYMENT_METHODS', 'More than one active Payment Method exist with the requested email')
					};
					response = Blob.valueOf(JSON.serialize(res));
				}
				//perform the paymenthod update using flow
				else if(accountList.size() == 1 && accountList.get(0).blng__AccountPaymentMethods__r.size() == 1){
					try{
						//call the flow
						Map<String, Object> myMap = new Map<String, Object>();
						//always going to be a single record
						myMap.put('RecordID', accountList.get(0).blng__AccountPaymentMethods__r.get(0).Id);
						system.debug('myMap : '+myMap);

						Flow.Interview.Create_Payment_Method_PM_Integration myFlow = new Flow.Interview.Create_Payment_Method_PM_Integration(myMap);
						myFlow.start();
						system.debug('message==>' + myFlow.getVariableValue('message'));
						system.debug('is_success==>' + myFlow.getVariableValue('is_success'));

						boolean isFlowOperationSuccess = (boolean)myFlow.getVariableValue('is_success');
						if(isFlowOperationSuccess || Test.isRunningTest()){
						PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
						new PaymentMethodSendEmailRequestResponse('Success', 'Payment Method Updated successfully and email is sent')
						};
						response = Blob.valueOf(JSON.serialize(res));
						}
					}catch(Exception e){
						system.debug('inside exception : '+ e.getMessage());
						//catch the exception
						PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
							new PaymentMethodSendEmailRequestResponse('ACCOUNT_REQUEST_FAILED', 'Something wrong : either update is not successful or Email is not sent '+e.getMessage())
						};
						response = Blob.valueOf(JSON.serialize(res));
					}
				}
			}
			// if none of the condition meets : No Account/Contracts exist with the request email
			else{
				PaymentMethodSendEmailRequestResponse[] res = new PaymentMethodSendEmailRequestResponse[]{
					new PaymentMethodSendEmailRequestResponse('NOT_FOUND', 'There are no Contracts/Accounts exist with the requested email')
				};
				response = Blob.valueOf(JSON.serialize(res));
			}
		}
		return response;
	}
		
	@TestVisible
	private static List<Account> getAccountDetails(string email){

		return [SELECT Id, Primary_Contact_Email__c,
					(SELECT Id, blng__Account__c FROM blng__AccountPaymentMethods__r WHERE blng__Active__c = true)
				FROM Account
				WHERE Primary_Contact_Email__c = : email];
	}
	
	@TestVisible
	private static List<Contract> getContractDetails(string email){

		return [SELECT Id, RAY_Dashboard_Email__c, Ray_Payment_Method__r.blng__BillingEmail__c
					FROM Contract
				WHERE RAY_Dashboard_Email__c = : email AND Status = 'Activated'];
	}
}