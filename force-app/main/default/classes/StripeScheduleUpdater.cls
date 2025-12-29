public class StripeScheduleUpdater {
    private static final Stripe_Details__c stripeDetails = Stripe_Details__c.getInstance('Stripe Details');
    private static final String SECRET_KEY = stripeDetails.Serect_Key__c;

    public static void handleStatusChanges(List<Contract> newContracts, Map<Id, Contract> oldMap) {
        List<Contract> toUpdate = new List<Contract>();
        List<Contract> toCancel = new List<Contract>();

        for (Contract con : newContracts) {
            Contract oldCon = oldMap.get(con.Id);

            if (oldCon.Status != con.Status) {
                if (con.Status == 'Updated') {
                    toUpdate.add(con);
                } else if (con.Status == 'canceled') {
                    toCancel.add(con);
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            System.enqueueJob(new ScheduleUpdateQueueable(toUpdate));
        }

        if (!toCancel.isEmpty()) {
            System.enqueueJob(new ScheduleCancelQueueable(toCancel));
        }
    }

    private class ScheduleUpdateQueueable implements Queueable, Database.AllowsCallouts {
        private List<Contract> contracts;

        ScheduleUpdateQueueable(List<Contract> contracts) {
            this.contracts = contracts;
        }

        public void execute(QueueableContext ctx) {
            Http http = new Http();

            for (Contract con : contracts) {
                try {
                    List<SBQQ__Subscription__c> items = [
                        SELECT Stripe_Price_ID__c, SBQQ__Quantity__c
                        FROM SBQQ__Subscription__c
                        WHERE SBQQ__Contract__c = :con.Id AND Stripe_Price_ID__c != NULL
                    ];

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(
                        'https://api.stripe.com/v1/subscription_schedules/' + con.Stripe_Subscription_Schedule_ID__c
                    );
                    req.setMethod('POST');
                    req.setHeader(
                        'Authorization',
                        'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                    );
                    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

                    List<String> body = new List<String>();

                    // Metadata
                    body.add(
                        'metadata[last_updated]=' + EncodingUtil.urlEncode(String.valueOf(System.now()), 'UTF-8')
                    );
                    body.add('metadata[last_updated_from_Salesforce]=true');

                    Long startDateUnix = null;
                    Long endDateUnix = null;

                    if (con.StartDate != null) {
                        Datetime startDt = Datetime.newInstance(
                            con.StartDate.year(),
                            con.StartDate.month(),
                            con.StartDate.day(),
                            0,
                            0,
                            0
                        );
                        startDateUnix = startDt.getTime() / 1000;
                    }

                    if (con.EndDate != null) {
                        Datetime endDt = Datetime.newInstance(
                            con.EndDate.year(),
                            con.EndDate.month(),
                            con.EndDate.day(),
                            0,
                            0,
                            0
                        );
                        endDateUnix = endDt.getTime() / 1000;
                    }

                    // If you want to update start date
                    if (startDateUnix != null) {
                        body.add('phases[0][start_date]=' + String.valueOf(startDateUnix));
                    }
                    // If you want to update end date
                    if (endDateUnix != null) {
                        body.add('phases[0][end_date]=' + String.valueOf(endDateUnix));
                    }

                    Integer i = 0;
                    for (SBQQ__Subscription__c s : items) {
                        body.add(
                            'phases[0][items][' +
                                i +
                                '][price]=' +
                                EncodingUtil.urlEncode(s.Stripe_Price_ID__c, 'UTF-8')
                        );
                        body.add('phases[0][items][' + i + '][quantity]=' + String.valueOf(s.SBQQ__Quantity__c));
                        i++;
                    }

                    req.setBody(String.join(body, '&'));
                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() == 200) {
                        Contract updatedCon = new Contract(Id = con.Id, Status = 'Pending');
                        update updatedCon;
                    } else {
                        throw new CalloutException(res.getBody());
                    }
                } catch (Exception e) {
                    insert new Logger__c(
                        Name = 'Stripe Schedule Update Error',
                        Message__c = e.getMessage(),
                        StackTrace__c = e.getStackTraceString(),
                        Status__c = 'Error',
                        Apex_Class__c = 'StripeScheduleUpdater',
                        Apex_Method__c = 'ScheduleUpdateQueueable.execute',
                        Object_Name__c = 'Contract'
                    );
                }
            }
        }
    }

    private class ScheduleCancelQueueable implements Queueable, Database.AllowsCallouts {
        private List<Contract> contracts;

        ScheduleCancelQueueable(List<Contract> contracts) {
            this.contracts = contracts;
        }

        public void execute(QueueableContext ctx) {
            Http http = new Http();

            for (Contract con : contracts) {
                try {
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(
                        'https://api.stripe.com/v1/subscription_schedules/' +
                            con.Stripe_Subscription_Schedule_ID__c +
                            '/cancel'
                    );
                    req.setMethod('POST');
                    req.setHeader(
                        'Authorization',
                        'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(SECRET_KEY + ':'))
                    );

                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                        Contract updatedCon = new Contract(
                            Id = con.Id,
                            Stripe_Status__c = 'canceled',
                            Latest_Change_Reason__c = 'Subscription Schedule Canceled from Salesforce'
                        );
                        update updatedCon;

                        System.debug('Schedule cancelled successfully: ' + con.Stripe_Subscription_Schedule_ID__c);

                        // Cancel related subscription items
                        List<SBQQ__Subscription__c> subsToCancel = [
                            SELECT Id, Status__c
                            FROM SBQQ__Subscription__c
                            WHERE SBQQ__Contract__c = :con.Id
                        ];

                        for (SBQQ__Subscription__c sub : subsToCancel) {
                            sub.Status__c = 'canceled';
                            sub.Latest_Change_Reason__c = 'Subscription Item Canceled Due to Schedule Cancellation';
                        }

                        if (!subsToCancel.isEmpty()) {
                            StripeTriggerHandler.enableBypass('SBQQ__Subscription__c');
                            update subsToCancel;
                            StripeTriggerHandler.disableBypass('SBQQ__Subscription__c');
                            System.debug('Canceled ' + subsToCancel.size() + ' SBQQ__Subscription__c records');
                        }
                    } else {
                        throw new CalloutException(res.getBody());
                    }
                } catch (Exception e) {
                    insert new Logger__c(
                        Name = 'Stripe Schedule Cancel Error',
                        Message__c = e.getMessage(),
                        StackTrace__c = e.getStackTraceString(),
                        Status__c = 'Error',
                        Apex_Class__c = 'StripeScheduleUpdater',
                        Apex_Method__c = 'ScheduleCancelQueueable.execute',
                        Object_Name__c = 'Contract'
                    );
                }
            }
        }
    }
}