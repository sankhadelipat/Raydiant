@isTest
public class Test_BatchClass implements Database.Batchable<sObject> {
  private String suffix;

  public Test_BatchClass(String suffix) {
    this.suffix = suffix;
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator('SELECT id, Company, LastName, FirstName FROM Lead LIMIT 200'); 
  }

  public void execute(Database.BatchableContext bc, List<Lead> scope) {
    for (Lead lead : scope) {
      lead.FirstName = lead.FirstName + '_' + this.suffix;
    }

    // Push the first updates, triggering our trigger logic.
    update scope;

    // Now, because we didn't want to simplify our code and bulkify our
    // updates as we should have, let's execute some more code which updates
    // the exact same records and would otherwise trigger the double enqueue
    // in batch context limitation of Apex.

    for (Lead lead : scope) {
      lead.LastName = lead.LastName + '_' + this.suffix;
    }

    // Trigger the double enqueue.
    update scope;

    for (Lead lead : scope) {
      lead.Company = lead.Company + '_' + this.suffix;
    }

    // Trigger the double enqueue.
    update scope;

    Contact c = new Contact(FirstName='FirstName', LastName='LastName');
    insert c;
  }

  public void finish(Database.BatchableContext bc) { /* nothing to do */ } 
}