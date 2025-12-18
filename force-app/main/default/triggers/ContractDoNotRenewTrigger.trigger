trigger ContractDoNotRenewTrigger on Contract(after update) {
    List<Id> contractsToCancel = new List<Id>();

    for (Contract con : Trigger.New) {
        Contract oldCon = Trigger.OldMap.get(con.Id);
        Date today = Date.today();
        Date thirtyDaysFromToday = today.addDays(30);

        if (
            con.DO_NOT_RENEW__c == true &&
            oldCon.DO_NOT_RENEW__c == false &&
            con.Renewal_Scheduled__c == true &&
            con.EndDate > today &&
            con.EndDate <= thirtyDaysFromToday
        ) {
            contractsToCancel.add(con.Id);
            System.debug('Contract ' + con.Id + ' will be canceled');
        }
    }

    if (!contractsToCancel.isEmpty()) {
        System.enqueueJob(new StripeRenewalCancellationService(contractsToCancel));
    }
}
