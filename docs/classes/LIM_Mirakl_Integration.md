# LIM_Mirakl_Integration

**Type:** Apex Class | **Status:** Active | **API Version:** 66.0 | **Object/Trigger:** —

---

## Summary

Apex class **`LIM_Mirakl_Integration`** (`classes/LIM_Mirakl_Integration.cls`) is compiled and executed on the Salesforce server. It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures).

**Author / description from source comment:** LIM_Mirakl_Integration Handles all Salesforce → Mirakl HTTP integrations.

---

## Technical Details

### Methods (heuristic)

| Method Name            | Access | Return Type | Description       |
| ---------------------- | ------ | ----------- | ----------------- |
| `buildHttpRequest`     | —      | —           | From source parse |
| `callMiraklApi`        | —      | —           | From source parse |
| `executeRequests`      | —      | —           | From source parse |
| `getNamedCredential`   | —      | —           | From source parse |
| `populateResponse`     | —      | —           | From source parse |
| `sendHttpRequest`      | —      | —           | From source parse |
| `shouldAttachBody`     | —      | —           | From source parse |
| `validateCalloutLimit` | —      | —           | From source parse |
| `validateRequest`      | —      | —           | From source parse |

### Source

```apex
/**
 * LIM_Mirakl_Integration
 * Handles all Salesforce → Mirakl HTTP integrations.
 */
public with sharing class LIM_Mirakl_Integration {
    // ── Named Credentials ─────────────────────────────
    private static final String LIM_MIRAKL_TEST = 'Lim_Mirakl_Test';
    private static final String LIM_MIRAKL_PRODUCTION = 'Lim_Mirakl_Production';

    private static final Integer DEFAULT_TIMEOUT_MS = 60000;

    private static final Set<String> ALLOWED_METHODS = new Set<String>{ 'GET', 'POST', 'PUT', 'PATCH', 'DELETE' };

    // ── Input DTO (for Apex callers) ───────────────────
    public class Input {
        public String httpMethod;
        public String relativePath;
        public String requestBody;
    }

    // ── Output DTO (for Apex callers) ──────────────────
    public class Output {
        public Boolean success;
        public Integer statusCode;
        public String responseBody;
        public String errorMessage;
    }

    // ── Invocable Input (Flow / Process Builder / Apex) ─
    public class InvocableInput {
        @InvocableVariable(required=true description='HTTP method: GET, POST, PUT, PATCH, or DELETE')
        public String httpMethod;
        @InvocableVariable(
            required=true
            description='API path relative to Named Credential base URL (e.g. /api/orders)'
        )
        public String relativePath;
        @InvocableVariable(description='Optional JSON request body for POST/PUT/PATCH')
        public String requestBody;
    }

    // ── Invocable Output ───────────────────────────────
    public class InvocableOutput {
        @InvocableVariable(description='Whether the callout succeeded')
        public Boolean success;
        @InvocableVariable(description='HTTP status code')
        public String statusCode;
        @InvocableVariable(description='Response body from Mirakl')
        public String responseBody;
        @InvocableVariable(description='Error message if the call failed')
        public String errorMessage;
    }

    /**
     * Invocable entry point: call from Flow, Process Builder, or Apex.
     */
    @InvocableMethod(description='Call Mirakl API using Named Credential (Sandbox/Production).' category='Mirakl')
    public static List<InvocableOutput> callMiraklApi(List<InvocableInput> inputs) {
        List<InvocableOutput> outputs = new List<InvocableOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        List<Input> requests = new List<Input>();
        for (InvocableInput i : inputs) {
            Input req = new Input();
            req.httpMethod = i.httpMethod;
            req.relativePath = i.relativePath;
            req.requestBody = i.requestBody;
            requests.add(req);
        }

        List<Output> results = executeRequests(requests);

        for (Output r : results) {
            InvocableOutput out = new InvocableOutput();
            out.success = r.success;
            out.statusCode = r.statusCode != null ? String.valueOf(r.statusCode) : null;
            out.responseBody = r.responseBody;
            out.errorMessage = r.errorMessage;
            outputs.add(out);
        }
        return outputs;
    }

    // ── Named Credential Selector (Sandbox / Prod) ───
    private static String getNamedCredential() {
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];

        return org.IsSandbox ? LIM_MIRAKL_TEST : LIM_MIRAKL_PRODUCTION;
    }

    // ── Main Entry Method ─────────────────────────────
    public static List<Output> executeRequests(List<Input> requests) {
        List<Output> results = new List<Output>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        for (Input req : requests) {
            Output result = new Output();

            try {
                validateCalloutLimit();
                validateRequest(req);

                HttpRequest httpReq = buildHttpRequest(req);

                HttpResponse res = sendHttpRequest(httpReq);

                populateResponse(result, res);
            } catch (System.CalloutException ex) {
                result.success = false;
                result.errorMessage = 'Callout failed: ' + ex.getMessage();
            } catch (Exception ex) {
                result.success = false;
                result.errorMessage = 'Unexpected error: ' + ex.getMessage();
            }

            results.add(result);
        }

        return results;
    }

    // ── Check Salesforce Callout Limit ─────────────────
    private static void validateCalloutLimit() {
        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
            throw new CalloutException('Salesforce callout limit reached.');
        }
    }

    // ── Validate Request ──────────────────────────────
    private static void validateRequest(Input request) {
        if (request == null) {
            throw new IllegalArgumentException('Request cannot be null.');
        }

        if (String.isBlank(request.httpMethod)) {
            throw new IllegalArgumentException('HTTP method is required.');
        }

        if (!ALLOWED_METHODS.contains(request.httpMethod.toUpperCase())) {
            throw new IllegalArgumentException('Invalid HTTP method: ' + request.httpMethod);
        }

        if (String.isBlank(request.relativePath)) {
            throw new IllegalArgumentException('Relative path is required.');
        }
    }

    // ── Build HTTP Request ────────────────────────────
    private static HttpRequest buildHttpRequest(Input request) {
        HttpRequest req = new HttpRequest();

        String path = request.relativePath;

        if (!path.startsWith('/')) {
            path = '/' + path;
        }

        req.setEndpoint('callout:' + getNamedCredential() + path);

        req.setMethod(request.httpMethod.toUpperCase());

        req.setTimeout(DEFAULT_TIMEOUT_MS);

        req.setHeader('Content-Type', 'application/json');

        if (shouldAttachBody(request.httpMethod, request.requestBody)) {
            req.setBody(request.requestBody);
        }

        return req;
    }

    // ── Determine if Request Body Should Be Attached ──
    private static Boolean shouldAttachBody(String method, String body) {
        return !String.isBlank(body) && (method == 'POST' || method == 'PUT' || method == 'PATCH');
    }

    // ── Send HTTP Request ─────────────────────────────
    private static HttpResponse sendHttpRequest(HttpRequest request) {
        Http http = new Http();

        return http.send(request);
    }

    // ── Populate Result Object ────────────────────────
    private static void populateResponse(Output result, HttpResponse res) {
        result.statusCode = res.getStatusCode();
        result.responseBody = res.getBody();

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            result.success = true;
        } else {
            result.success = false;

            result.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
        }
    }
}
```

---

## Dependencies

_(Review imports and type references in source above.)_

---
