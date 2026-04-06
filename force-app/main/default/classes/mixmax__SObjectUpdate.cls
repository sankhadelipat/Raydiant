public class SObjectUpdate {
	public Map<String, Object> record;
	public Set<String> changedFields;

	public SObjectUpdate(Map<String, Object> record, Set<String> changedFields) {
		this.record = record;
		this.changedFields = changedFields;
	}
}