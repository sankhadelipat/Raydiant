@isTest
public class Test_BatchWithQueueable implements Database.Batchable<sObject> {
  private String suffix;

  public Test_BatchWithQueueable(String suffix) {
    this.suffix = suffix;
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator('SELECT id, LastName, FirstName FROM Lead LIMIT 200'); 
  }

  public void execute(Database.BatchableContext bc, List<Lead> scope) {
    // Enqueue a new job first just to be an asshole.
    System.enqueueJob(new Test_NoopQueueable());
    
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
  }

  public void finish(Database.BatchableContext bc) { /* nothing to do */ } 
}