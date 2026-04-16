// ============================================================
// Anonymous Apex: Test LIM_Mirakl_Integration + LIM_Mirakl_Connection
// Run in Developer Console: Debug > Open Execute Anonymous Window
// Paste this, check "Open Log", then Execute
// ============================================================

// --- 1) Test LIM_Mirakl_Integration (direct) ---
LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
req.httpMethod = 'GET';
req.relativePath = '/api/version';   // adjust to your Mirakl API path if needed
req.requestBody = null;

List<LIM_Mirakl_Integration.Input> requests = new List<LIM_Mirakl_Integration.Input>{ req };
List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(requests);

System.debug('=== LIM_Mirakl_Integration (direct) ===');
for (LIM_Mirakl_Integration.Output r : results) {
    System.debug('success: ' + r.success);
    System.debug('statusCode: ' + r.statusCode);
    System.debug('responseBody: ' + r.responseBody);
    System.debug('errorMessage: ' + r.errorMessage);
}

// --- 2) Test LIM_Mirakl_Connection (Invocable / Flow style) ---
// Uses helper so we don't reference Input/Output (avoids "Invalid type" in Execute Anonymous)
System.debug('=== LIM_Mirakl_Connection (Invocable) ===');
LIM_Mirakl_Connection.executeSingleAndDebug('GET', '/api/version', null);

System.debug('Done. Check debug log for results.');
