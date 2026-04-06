public class MixmaxUpdateFilter {
	Set<String> syncedFields;
	public MixmaxUpdateFilter(Set<String> syncedFields) {
		this.syncedFields = syncedFields;
	}

	/*
	 * Compares old and new versions of an SObject record (e.g. from Trigger.old and Trigger.new) and
	 * returns an object with structure { record: Map<String, Object>, changedFields: Set<String> },
	 * where `record` is the synced field projection of the new record, and `changedFields` is  the subset of synced
	 * fields which differ between the old and new records.
	 */
	public SObjectUpdate getSyncedUpdate(SObject oldObj, SObject newObj) {
		Set<String> changedFields = new Set<String>();

		for (String field: this.syncedFields) {
			Object newVal = newObj.get(field);
			if (newVal != oldObj.get(field)) {
				changedFields.add(field);
			}
		}

		// If there are changed fields, return the entire object so we update any fields that have
		// changed but aren't included in sync conditions.
		return changedFields.isEmpty() ? null : new SObjectUpdate(newObj.getPopulatedFieldsAsMap(), changedFields);
	}
}