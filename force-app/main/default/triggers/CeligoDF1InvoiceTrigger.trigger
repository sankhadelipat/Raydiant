trigger CeligoDF1InvoiceTrigger on blng__Invoice__c (after insert, after update) 
  {
  integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport('df1connector'); 
}