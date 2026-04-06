public class MixmaxUpdaterQueueable implements Queueable {
    private String type;
    private String verb;
    private String objectString;
    private String customObjectId;
    private Boolean filtered;
    private String objectsType;

    public MixmaxUpdaterQueueable(String type, String verb, String objectString, String customObjectId,
                                  Boolean filtered, String objectsType) {
        this.type = type;
        this.verb = verb;
        this.objectString = objectString;
        this.customObjectId = customObjectId;
        this.filtered = filtered;
        this.objectsType = objectsType;
    }

    public void execute(QueueableContext context) {
        MixmaxUpdater.handleCallout(this.type, this.verb, this.objectString, this.customObjectId, this.filtered, this.objectsType);
    }
}