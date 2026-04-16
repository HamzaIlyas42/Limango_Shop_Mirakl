# Apex Invocable Connection Class – Specification (Blueprint)

You are a Salesforce Apex developer. I will give you this spec file (apex_connection.md).

Before generating any code, ask me these 2 questions and wait for all answers:

1. What is the Class Name? (e.g. {Customer_Name}
2. What is the Project_Name? (e.g. Factory42 — used for named credential naming and file prefix)

Do NOT generate anything until I answer all 3. Once I answer, replace every {ClassName}, {FunctionName}, {CustomerName} placeholder in this spec and generate exactly these 4 files:

1. {ClassName}.cls
2. {ClassName}.cls-meta.xml
3. {ClassName}Test.cls
4. {ClassName}Test.cls-meta.xml

Then show an Execute Anonymous block at the end for quick testing in Developer Console.

---

## 1. Class Declaration & Sharing

- **Declaration:** `public with sharing class <{Customer_Name}_Name>` (e.g. `Customer_Name_Connection`).
- **Sharing:** Always `with sharing` so that running user’s sharing rules apply (security).

---

## 2. Config Section (Private Constants)

Define at the top of the class, in a section comment like `/* ===================== CONFIG ===================== */`:


| Constant                     | Type      | Value               | Purpose                                                                   |
| ---------------------------- | --------- | ------------------- | ------------------------------------------------------------------------- |
| `{Customer_Name}_TEST`       | `String`  | `'{Customer_Name}'` | Named Credential for sandbox; used when `Organization.IsSandbox` is true. |
| `{Customer_Name}_PRODUCTION` | `String`  | `'{Customer_Name}'` | Named Credential for production.                                          |
| `DEFAULT_TIMEOUT_MS`         | `Integer` | `60000`             | HTTP timeout in milliseconds (60 seconds).                                |


- **Helper:** `private static String getNamedCredential()` — query `Organization` for `IsSandbox`; return `{Customer_Name}_TEST` if sandbox, else `{Customer_Name}_PRODUCTION`. Use this in `buildHttpRequest` for the endpoint (no hardcoded single credential).

---

## 3. Invocable Method

- **Annotation:** `@InvocableMethod(description='Establish Connection with Mirakl using Named Credential.')`
  - Adjust the `description` to match your integration (e.g. “Establish Connection with Stripe using Named Credential”).
- **Signature:**  
`public static List<CallMiraklApiResult> EstablishConnection(List<CallMiraklApiInput> requests)`
  - Replace `EstablishConnection` with **Function Name** if you use a different one; same for `CallMiraklApiInput`/`CallMiraklApiResult`.

**Behavior (exact logic):**

1. Create an empty `List<CallMiraklApiResult> responses`.
2. If `requests == null || requests.isEmpty()`, return `responses` immediately.
3. For **each** `CallMiraklApiInput request` in `requests`:

- Create a new `CallMiraklApiResult response`.
- In a **try** block:
  - Call `validateCalloutLimit();`
  - Call `validateRequest(request);`
  - Build: `HttpRequest httpRequest = buildHttpRequest(request);`
  - Send: `HttpResponse httpResponse = sendHttpRequest(httpRequest);`
  - Call `populateResponse(response, httpResponse);`
- In **catch (Exception ex)**:
  - Set `response.success = false`, `response.statusCode = -1`, `response.errorMessage = ex.getMessage();`
- Add `response` to `responses`.

1. Return `responses`.

So: one result per input; one failure does not stop the rest; exceptions are captured in the result object.

---

## 4. Private Helper Methods (Exact Behavior)

### 4.1 `validateCalloutLimit()`

- If `Limits.getCallouts() >= Limits.getLimitCallouts()` then throw `new CalloutException('Callout limit exceeded.');`
- Prevents starting a callout when the transaction would exceed the limit.

### 4.2 `validateRequest(CallMiraklApiInput request)`

- If `request == null`, throw `new CalloutException('Request cannot be null.');`
- No HTTP method whitelist; any method is accepted (caller responsibility).

### 4.3 `buildHttpRequest(CallMiraklApiInput request)`

- Method: same normalization as in `validateRequest` (default `'GET'`).
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

### 4.6 `populateResponse(CallMiraklApiResult result, HttpResponse res)`

- `Integer status = res.getStatusCode();`
- `result.statusCode = status;`
- `result.responseBody = res.getBody();`
- `result.success = (status >= 200 && status < 300);`
- If `!result.success`: `result.errorMessage = res.getStatus() + ': ' + res.getBody();`

---

## 5. DTO Classes (Invocable Input & Result)

Section comment: `/* ===================== DTO CLASSES ===================== */`

### 5.1 Input: `CallMiraklApiInput` (public inner class)

- `@InvocableVariable(required=true)` `public String httpMethod;`
- `@InvocableVariable(required=true)` `public String relativePath;`
- `@InvocableVariable` `public String requestBody;` (optional)

### 5.2 Result: `CallMiraklApiResult` (public inner class)

- `@InvocableVariable` `public Boolean success;`
- `@InvocableVariable` `public Integer statusCode;`
- `@InvocableVariable` `public String responseBody;`
- `@InvocableVariable` `public String errorMessage;`

---

## 6. Safety & Best Practices (Must Preserve)

When generating the class, ensure these are all respected:


| #   | Safety / practice                  | Where it’s enforced                                                               |
| --- | ---------------------------------- | --------------------------------------------------------------------------------- |
| 1   | **Sharing**                        | `with sharing` on the class.                                                      |
| 2   | **No hardcoded secrets**           | Only `callout:getNamedCredential()`; credentials in Named Credential (test/prod). |
| 3   | **Callout limit**                  | `validateCalloutLimit()` before each `http.send()`.                               |
| 4   | **Null/empty input**               | Early return for null/empty list; null request rejected in `validateRequest`.     |
| 5   | **Path normalization**             | Trim, default `/`, ensure leading `/` so endpoint is valid.                       |
| 6   | **Body only for mutating methods** | `shouldAttachBody` restricts body to POST/PUT/PATCH.                              |
| 7   | **Timeout**                        | `setTimeout(DEFAULT_TIMEOUT_MS)` to avoid hanging.                                |
| 8   | **Per-request try/catch**          | One failed request doesn’t abort the whole batch; error in `CallMiraklApiResult`. |
| 9   | **Structured error in result**     | On failure: `success=false`, `statusCode=-1` or real code, `errorMessage` set.    |


---

## 7. File & Metadata

- **File name:** `<{Customer_Name}_Connection>.cls` (e.g. `{Customer_Name}_Connection.cls`).
- **Meta file:** `<{Customer_Name}_Connection>.cls-meta.xml` with at least:
  - `apiVersion` (e.g. `66.0`)
  - `status` Active.

---

