public class MixmaxSupportedStandardObjects {

  // The 7 standard object types Mixmax supports.
  public static final Set<SObjectType> SUPPORTED_STANDARD_OBJECTS = new Set<SObjectType>{
    Task.getSObjectType(),
    Contact.getSObjectType(),
    Account.getSObjectType(),
    Opportunity.getSObjectType(),
    OpportunityContactRole.getSObjectType(),
    Lead.getSObjectType(),
    User.getSObjectType(),
    Event.getSObjectType(),
    Campaign.getSObjectType(),
    CampaignMember.getSObjectType()
  };
}