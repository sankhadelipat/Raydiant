public class StripeUnixTimestampsConverter {

    public class UnixTimestampInputs {
        @InvocableVariable(label='created') public Long created;
        @InvocableVariable(label='start_date') public Long start_date;
        @InvocableVariable(label='current_period_start') public Long current_period_start;
        @InvocableVariable(label='current_period_end') public Long current_period_end;
        @InvocableVariable(label='cancel_at') public Long cancel_at;
        @InvocableVariable(label='canceled_at') public Long canceled_at;
        @InvocableVariable(label='ended_at') public Long ended_at;
        @InvocableVariable(label='trial_start') public Long trial_start;
        @InvocableVariable(label='trial_end') public Long trial_end;
    }

    public class DatetimeOutputs {
        @InvocableVariable(label='created') public Datetime created;
        @InvocableVariable(label='start_date') public Datetime start_date;
        @InvocableVariable(label='current_period_start') public Datetime current_period_start;
        @InvocableVariable(label='current_period_end') public Datetime current_period_end;
        @InvocableVariable(label='cancel_at') public Datetime cancel_at;
        @InvocableVariable(label='canceled_at') public Datetime canceled_at;
        @InvocableVariable(label='ended_at') public Datetime ended_at;
        @InvocableVariable(label='trial_start') public Datetime trial_start;
        @InvocableVariable(label='trial_end') public Datetime trial_end;
    }

    @InvocableMethod(label='Convert Stripe Timestamps to Salesforce Datetime')
    public static List<DatetimeOutputs> convert(List<UnixTimestampInputs> inputList) {
        List<DatetimeOutputs> outputList = new List<DatetimeOutputs>();

        for (UnixTimestampInputs input : inputList) {
            DatetimeOutputs output = new DatetimeOutputs();
            output.created = convertUnix(input.created);
            output.start_date = convertUnix(input.start_date);
            output.current_period_start = convertUnix(input.current_period_start);
            output.current_period_end = convertUnix(input.current_period_end);
            output.cancel_at = convertUnix(input.cancel_at);
            output.canceled_at = convertUnix(input.canceled_at);
            output.ended_at = convertUnix(input.ended_at);
            output.trial_start = convertUnix(input.trial_start);
            output.trial_end = convertUnix(input.trial_end);
            outputList.add(output);
        }

        return outputList;
    }

    private static Datetime convertUnix(Long timestamp) {
        if (timestamp == null) return null;
        return Datetime.newInstance(timestamp * 1000);
    }
}