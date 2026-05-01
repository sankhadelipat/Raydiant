/**
 * ConversionSyncHelper
 * Prevents recursion between Lead and Opportunity triggers
 * when syncing Converted_Opportunity__c <-> From_Converted_Lead__c
 */
public class ConversionSyncHelper {

    // Static flags to prevent infinite loop
    private static Boolean isLeadUpdating = false;
    private static Boolean isOppUpdating = false;

    public static Boolean getIsLeadUpdating() {
        return isLeadUpdating;
    }

    public static Boolean getIsOppUpdating() {
        return isOppUpdating;
    }

    /**
     * Called from LeadTrigger - updates the related Opportunity
     */
    public static void syncLeadToOpportunity(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        if (isOppUpdating) return; // Opp trigger caused this - skip

        isLeadUpdating = true;

        Map<Id, Id> oppIdToLeadId = new Map<Id, Id>();

        for (Lead l : newLeads) {
            Lead oldLead = oldLeadMap.get(l.Id);

            // Field was changed and is not null
            if (l.Converted_Opportunity__c != null
                && l.Converted_Opportunity__c != oldLead.Converted_Opportunity__c) {
                oppIdToLeadId.put(l.Converted_Opportunity__c, l.Id);
            }
        }

        if (!oppIdToLeadId.isEmpty()) {
            List<Opportunity> oppsToUpdate = new List<Opportunity>();

            for (Id oppId : oppIdToLeadId.keySet()) {
                oppsToUpdate.add(new Opportunity(
                    Id = oppId,
                    From_Converted_Lead__c = oppIdToLeadId.get(oppId)
                ));
            }

            update oppsToUpdate;
        }

        isLeadUpdating = false;
    }

    /**
     * Called from OpportunityTrigger - updates the related Lead
     */
    public static void syncOpportunityToLead(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        if (isLeadUpdating) return; // Lead trigger caused this - skip

        isOppUpdating = true;

        Map<Id, Id> leadIdToOppId = new Map<Id, Id>();

        for (Opportunity o : newOpps) {
            Opportunity oldOpp = oldOppMap.get(o.Id);

            // Field was changed and is not null
            if (o.From_Converted_Lead__c != null
                && o.From_Converted_Lead__c != oldOpp.From_Converted_Lead__c) {
                leadIdToOppId.put(o.From_Converted_Lead__c, o.Id);
            }
        }

        if (!leadIdToOppId.isEmpty()) {
            List<Lead> leadsToUpdate = new List<Lead>();

            for (Id leadId : leadIdToOppId.keySet()) {
                leadsToUpdate.add(new Lead(
                    Id = leadId,
                    Converted_Opportunity__c = leadIdToOppId.get(leadId)
                ));
            }

            update leadsToUpdate;
        }

        isOppUpdating = false;
    }
}