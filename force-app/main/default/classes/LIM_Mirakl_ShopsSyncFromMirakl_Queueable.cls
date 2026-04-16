/**
 * LIM_Mirakl_ShopsSyncFromMirakl_Queueable
 * Queueable worker invoked by LIM_Mirakl_ShopsSyncFromMirakl_Sched.
 * Implements Database.AllowsCallouts so the Flow can make HTTP callouts
 * to Mirakl — callouts are forbidden in a direct Scheduled Apex context,
 * and Salesforce does not allow Queueable + Schedulable on the same class.
 */
public with sharing class LIM_Mirakl_ShopsSyncFromMirakl_Queueable
    implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext ctx) {
        Map<String, Object> inputs = new Map<String, Object>();
        Flow.Interview interview = Flow.Interview.createInterview(
            'LIM_Mirakl_ShopsSyncFromMirakl', inputs
        );
        interview.start();
    }
}
