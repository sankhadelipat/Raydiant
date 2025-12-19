@RestResource(urlMapping='/Invoices/GetPDF/*')
global with sharing class RestAPIGetInvoicePDF {
    @HttpGet
    global static void doGet() {
        (new RestAPIGetInvoicePDFHandler()).processRequest();
    }
}