// No Schedulable Apex: schedule Mirakl sync from Salesforce using Flow only.
//
// Behaviour (incremental, no fixed start date):
//   LIM_Mirakl_ShopsSyncFromMirakl_Scheduled loads the latest Job__c (PARTNER_INTEGRATION_ACCOUNT with
//   ProcessingStarted__c not null), ordered by ProcessingStarted__c DESC, and passes that datetime into
//   LIM_Mirakl_ShopsSyncFromMirakl as varUpdatedSince → Mirakl GET uses ?updated_since=...
//   First run (no qualifying Job): varUpdatedSince is null → full shops pull.
//   Each run also stamps the new Job__c.ProcessingStarted__c when the job record is written (main flow) for the next run.
//
// Prerequisite: Job__c field ProcessingStarted__c (DateTime) must exist in the org.
//
// Schedule every 15 minutes (e.g. :00, :15, :30, :45) via Setup → Flows → LIM_Mirakl_ShopsSyncFromMirakl_Scheduled
// → Schedule / scheduled path (per your Salesforce edition).
