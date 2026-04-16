// Anonymous Apex: Schedule LIM_Mirakl_ShopsSyncFromMirakl_Sched every 15 minutes.
// Run once in Developer Console → Execute Anonymous or via SFDX:
//   sf apex run --file scripts/LIM_Mirakl_ShopsSyncFromMirakl_Schedule.apex
//
// To remove existing jobs before re-scheduling:
//   for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'LIM_Mirakl_ShopsSyncFromMirakl_Sched%']) {
//       System.abortJob(ct.Id);
//   }

LIM_Mirakl_ShopsSyncFromMirakl_Sched miraklClass = new LIM_Mirakl_ShopsSyncFromMirakl_Sched();
System.Schedule('LIM_Mirakl_ShopsSyncFromMirakl_Sched  *:00', '0 0 * ? * 1,2,3,4,5,6,7', miraklClass);
System.Schedule('LIM_Mirakl_ShopsSyncFromMirakl_Sched  *:15', '0 15 * ? * 1,2,3,4,5,6,7', miraklClass);
System.Schedule('LIM_Mirakl_ShopsSyncFromMirakl_Sched  *:30', '0 30 * ? * 1,2,3,4,5,6,7', miraklClass);
System.Schedule('LIM_Mirakl_ShopsSyncFromMirakl_Sched  *:45', '0 45 * ? * 1,2,3,4,5,6,7', miraklClass);
