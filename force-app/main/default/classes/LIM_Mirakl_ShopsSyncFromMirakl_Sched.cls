/**
 * LIM_Mirakl_ShopsSyncFromMirakl_Sched
 * Schedulable timer — runs every 15 minutes (:00, :15, :30, :45) via 4 cron jobs.
 * Delegates the actual Flow invocation to LIM_Mirakl_ShopsSyncFromMirakl_Queueable
 * because Salesforce does not allow Queueable and Schedulable on the same class,
 * and callouts are only permitted in a Queueable context.
 */
public with sharing class LIM_Mirakl_ShopsSyncFromMirakl_Sched implements Schedulable {
    public void execute(SchedulableContext ctx) {
        System.enqueueJob(new LIM_Mirakl_ShopsSyncFromMirakl_Queueable());
    }
}