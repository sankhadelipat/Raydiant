/**
 * @author: Tim
 * @description: CPQ API Models: 
The Configuration model represents a bundle product in Salesforce CPQ.
 * 
 * @name : ConfigurationModel
 * 
 * @createdDate: May 25th, 2020
 **/

public class ConfigurationModel { 
    public Id configuredProductId; 
    public Id optionId; 
    public SBQQ__ProductOption__c optionData; // Editable data about the option in question, such as quantity or discount 
    public SBQQ__ProductOption__c configurationData; 
    public SBQQ__ProductOption__c inheritedConfigurationData; 
    public ConfigurationModel[] optionConfigurations; 
    public Boolean configured; 
    public Boolean configurationEntered; 
    public Boolean changedByProductActions; 
    public Boolean isDynamicOption; 
    public Boolean isUpgrade; 
    public Set<Id> disabledOptionIds; 
    public Set<Id> hiddenOptionIds; 
    public Decimal listPrice; 
    public Boolean priceEditable; 
    public String[] validationMessages; 
    public String dynamicOptionKey; 
}