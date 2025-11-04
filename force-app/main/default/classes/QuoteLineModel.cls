/**
 * @name : QuoteLineModel
 * @description: CPQ API Models: 
 * The Quote Line model represents a quote line data model in Salesforce CPQ.
 * 
 **/
public class QuoteLineModel {
    public SBQQ__QuoteLine__c record;
    public Boolean amountDiscountProrated;
    public Integer parentGroupKey;
    public Integer parentItemKey;
    public Integer key;
    public Boolean upliftable;
    public String configurationType;
    public String configurationEvent;
    public Boolean reconfigurationDisabled;
    public Boolean descriptionLocked;
    public Boolean productQuantityEditable;
    public Decimal productQuantityScale;
    public String dimensionType;
    public Boolean productHasDimensions;
    public Decimal targetCustomerAmount;
    public Decimal targetCustomerTotal;
}