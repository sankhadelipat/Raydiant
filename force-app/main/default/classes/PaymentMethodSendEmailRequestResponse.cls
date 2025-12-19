//standard salesforce error response structure
public class PaymentMethodSendEmailRequestResponse {
    public String errorCode;
    public String message;
    public PaymentMethodSendEmailRequestResponse(String errorCode, string message){
        this.errorCode = errorCode;
        this.message = message;
    }
}