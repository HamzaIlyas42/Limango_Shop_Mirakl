# Apex Integration REST API Class – Specification (Blueprint)

Use this document to generate a Apex_Integration_REST_API Apex class that calls **any REST API** via Named Credential. When you give this (or a similar) `.md` file to an AI, it should produce Apex code that matches this specification.

---

## What to ask when using this spec

When I share this .md file with you, ask me:

- **Class Name** {placeholder} 
- **Function name** {placeholder} 
- **Customer/Prefix name** {placeholder}

Use the names I provide for the main class (and test class: `<Class Name>_Test`), and for the invocable method. Named Credentials must exist in the org for the callout to work.

---

## 1. Class Declaration & Sharing

- **Declaration:** `public with sharing class <Class_Name>`
- **Sharing:** Always `with sharing` so that the running user’s sharing rules apply (security).

---

## 2. Config Section (Private Constants)

Define at the top of the class, in a section comment like `/* ===================== CONFIG ===================== */`:


| Constant                | Type      | Value                       | Purpose                                                                   |
| ----------------------- | --------- | --------------------------- | ------------------------------------------------------------------------- |
| `NAMED_CREDENTIAL_TEST` | `String`  | `'{Prefix}_Api_Test'`       | Named Credential for sandbox; used when `Organization.IsSandbox` is true. |
| `NAMED_CREDENTIAL_PROD` | `String`  | `'{Prefix}_Api_Production'` | Named Credential for production.                                          |
| `DEFAULT_TIMEOUT_MS`    | `Integer` | `60000`                     | HTTP timeout in milliseconds (60 seconds).                                |


- **Helper:** `private static String getNamedCredential()` — query `Organization` for `IsSandbox`; return `NAMED_CREDENTIAL_TEST` if sandbox, else `NAMED_CREDENTIAL_PROD`. Use this in `buildHttpRequest` for the endpoint.

---

## 3. Invocable Method

- **Annotation:** `@InvocableMethod(description='Calls the external REST API using Named Credential.')`
  - Adjust the `description` to match your integration (e.g. “Calls Stripe REST API”, “Calls Orders REST API”).
- **Signature:**  
`public static List<RestApiResult> <FunctionName>(List<RestApiInput> requests)`
  - Replace `<FunctionName>` with the **Function name** (e.g. `callApi`, `executeRequest`). Replace `RestApiInput`/`RestApiResult` with your input/result type names if you rename them.

**Behavior (exact logic):**

1. Create an empty `List<RestApiResult> responses`.
2. If `requests == null || requests.isEmpty()`, return `responses` immediately.
3. For **each** `RestApiInput request` in `requests`:
  - Create a new `RestApiResult response`.
  - In a **try** block:
    - Call `validateCalloutLimit();`
    - Call `validateRequest(request);`
    - Build: `HttpRequest httpRequest = buildHttpRequest(request);`
    - Send: `HttpResponse httpResponse = sendHttpRequest(httpRequest);`
    - Call `populateResponse(response, httpResponse);`
  - In **catch (Exception ex)**:
    - Set `response.success = false`, `response.statusCode = -1`, `response.errorMessage = ex.getMessage();`
  - Add `response` to `responses`.
4. Return `responses`.

So: one result per input; one failure does not stop the rest; exceptions are captured in the result object.

---

## 4. Private Helper Methods (Exact Behavior)

### 4.1 `validateCalloutLimit()`

- If `Limits.getCallouts() >= Limits.getLimitCallouts()` then throw `new CalloutException('Callout limit exceeded.');`
- Prevents starting a callout when the transaction would exceed the limit.

### 4.2 `validateRequest(RestApiInput request)`

- If `request == null`, throw `new CalloutException('Request cannot be null.');`
- No HTTP method whitelist; any method is accepted (caller responsibility).

### 4.3 `buildHttpRequest(RestApiInput request)`

- Method: normalize `request.httpMethod` (trim, uppercase; default `'GET'`).
- Path: `String path = String.isNotBlank(request.relativePath) ? request.relativePath.trim() : '/';`
- If `!path.startsWith('/')`, set `path = '/' + path;`
- Create `HttpRequest req = new HttpRequest();`
- Set:
  - `req.setEndpoint('callout:' + getNamedCredential() + path);`
  - `req.setMethod(method);`
  - `req.setTimeout(DEFAULT_TIMEOUT_MS);`
  - `req.setHeader('Content-Type', 'application/json');`
  - `req.setHeader('Accept', 'application/json');`
- If `shouldAttachBody(method, request.requestBody)` is true, then `req.setBody(request.requestBody);`
- Return `req`.

### 4.4 `shouldAttachBody(String method, String body)`

- Return `true` only when:
  - `String.isNotBlank(body)` **and**
  - `(method == 'POST' || method == 'PUT' || method == 'PATCH')`.
- So GET/DELETE never get a body.

### 4.5 `sendHttpRequest(HttpRequest request)`

- `Http http = new Http();`
- `return http.send(request);`

### 4.6 `populateResponse(RestApiResult result, HttpResponse res)`

- `Integer status = res.getStatusCode();`
- `result.statusCode = status;`
- `result.responseBody = res.getBody();`
- `result.success = (status >= 200 && status < 300);`
- If `!result.success`: `result.errorMessage = res.getStatus() + ': ' + res.getBody();`

---

## 5. DTO Classes (Invocable Input & Result)

Section comment: `/* ===================== DTO CLASSES ===================== */`

### 5.1 Input: `RestApiInput` (public inner class)

- `@InvocableVariable(required=true)` `public String httpMethod;`
- `@InvocableVariable(required=true)` `public String relativePath;`
- `@InvocableVariable` `public String requestBody;` (optional)

### 5.2 Result: `RestApiResult` (public inner class)

- `@InvocableVariable` `public Boolean success;`
- `@InvocableVariable` `public Integer statusCode;`
- `@InvocableVariable` `public String responseBody;`
- `@InvocableVariable` `public String errorMessage;`

---

## 6. Safety & Best Practices (Must Preserve)


| #   | Safety / practice                  | Where it’s enforced                                                            |
| --- | ---------------------------------- | ------------------------------------------------------------------------------ |
| 1   | **Sharing**                        | `with sharing` on the class.                                                   |
| 2   | **No hardcoded secrets**           | Only `callout:getNamedCredential()`; credentials in Named Credential.          |
| 3   | **Callout limit**                  | `validateCalloutLimit()` before each `http.send()`.                            |
| 4   | **Null/empty input**               | Early return for null/empty list; null request rejected in `validateRequest`.  |
| 5   | **Path normalization**             | Trim, default `/`, ensure leading `/` so endpoint is valid.                    |
| 6   | **Body only for mutating methods** | `shouldAttachBody` restricts body to POST/PUT/PATCH.                           |
| 7   | **Timeout**                        | `setTimeout(DEFAULT_TIMEOUT_MS)` to avoid hanging.                             |
| 8   | **Per-request try/catch**          | One failed request doesn’t abort the whole batch; error in `RestApiResult`.    |
| 9   | **Structured error in result**     | On failure: `success=false`, `statusCode=-1` or real code, `errorMessage` set. |


---

## 7. File & Metadata

- **File name:** `<Class_Name>.cls` (e.g. `ACME_Stripe_Api.cls`).
- **Meta file:** `<Class_Name>.cls-meta.xml` with at least:
  - `apiVersion` (e.g. `66.0`)
  - `status` Active.

---

## 8. REST API Examples (usage only — not connection)

Use these patterns from **Flow** or **Execute Anonymous** once the class is generated. Named Credential base URL is already set; `relativePath` is the path after that base.

### GET – List resources

- **httpMethod:** `GET`
- **relativePath:** `/v1/orders` or `/api/orders`
- **requestBody:** leave empty

Example (Execute Anonymous):

```apex
List<RestApiInput> inputs = new List<RestApiInput>();
RestApiInput req = new RestApiInput();
req.httpMethod = 'GET';
req.relativePath = '/v1/orders';
req.requestBody = null;
inputs.add(req);
List<RestApiResult> results = YourClassName.callApi(inputs);
// results[0].success, results[0].statusCode, results[0].responseBody
```

### GET – Single resource by ID

- **httpMethod:** `GET`
- **relativePath:** `/v1/orders/12345` or `/api/orders/12345`
- **requestBody:** leave empty

### POST – Create resource

- **httpMethod:** `POST`
- **relativePath:** `/v1/orders` or `/api/orders`
- **requestBody:** JSON string, e.g. `'{"customerId":"C001","amount":99.99}'`

Example (Execute Anonymous):

```apex
RestApiInput req = new RestApiInput();
req.httpMethod = 'POST';
req.relativePath = '/v1/orders';
req.requestBody = '{"customerId":"C001","amount":99.99}';
List<RestApiInput> inputs = new List<RestApiInput>{ req };
List<RestApiResult> results = YourClassName.callApi(inputs);
```

### PUT – Full update

- **httpMethod:** `PUT`
- **relativePath:** `/v1/orders/12345`
- **requestBody:** full JSON body of the resource

### PATCH – Partial update

- **httpMethod:** `PATCH`
- **relativePath:** `/v1/orders/12345`
- **requestBody:** JSON with only fields to update, e.g. `'{"status":"shipped"}'`

### DELETE – Remove resource

- **httpMethod:** `DELETE`
- **relativePath:** `/v1/orders/12345`
- **requestBody:** leave empty

---

## 9. Notes

- **Named Credential:** Create a Named Credential in Setup pointing at your API base URL (e.g. `https://api.example.com`). The class uses `callout:<Name>` + `relativePath`; no URLs or secrets in code.
- **Testing:** Write a test class that uses `Test.setMock(HttpCalloutMock.class, new YourMock())` so no real callouts run. Cover: empty list, null request, GET success, POST with body, failure (e.g. 404/500), and callout limit if possible.
- **Governor limits:** One callout per input; remember the per-transaction callout limit (e.g. 100). For large batches, split across transactions (e.g. async or multiple Flow runs).
- **JSON:** The class does not parse JSON; it only sends/receives strings. Flow or Apex can use `JSON.deserialize`* on `responseBody` if needed.

Using this spec as a blueprint, you can recreate the same safe, Flow-invocable REST API pattern for any external API that uses a Named Credential.