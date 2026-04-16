# Apex Invocable – CustomerName_Connection Specification (Blueprint)

You are a Salesforce Apex developer. I will give you this spec file (Apex_Invocable_Mirakl_TestHamza.md).

Before generating any code, ask me these 3 questions and wait for all answers:

1. What is the Class Name? ({Customer_Name}Connection)
2. What is the Function Name? (e.g. EstablishConnection)
3. What is the Customer Name?

Do NOT generate anything until I answer all 3. Once I answer, replace every {ClassName}, {FunctionName}, {CustomerName} placeholder in this spec and generate exactly these 4 files:

1. {ClassName}Connection.cls
2. {ClassName}Connection.cls-meta.xml
3. {ClassName}Connection_Test.cls
4. {ClassName}Connection_Test.cls-meta.xml

Then show an Execute Anonymous block at the end for quick testing in Developer Console.

---

## 1. Class Declaration & Sharing

- **Declaration:** `public with sharing class {ClassName}` (e.g. `ClassName__Connection`).
- **Sharing:** Always `with sharing` so that running user's sharing rules apply (security).

---

## 2. Config Section (Private Constants)

Define at the top of the class, in a section comment like `/* ===================== CONFIG ===================== */`:


| Constant                    | Type      | Value                         | Purpose                                                                   |
| --------------------------- | --------- | ----------------------------- | ------------------------------------------------------------------------- |
| `{CustomerName}_TEST`       | `String`  | `'{CustomerName}_Test'`       | Named Credential for sandbox; used when `Organization.IsSandbox` is true. |
| `{CustomerName}_PRODUCTION` | `String`  | `'{CustomerName}_Production'` | Named Credential for production.                                          |
| `DEFAULT_TIMEOUT_MS`        | `Integer` | `60000`                       | HTTP timeout in milliseconds (60 seconds).                                |


- **Helper:** `private static String getNamedCredential()` — query `Organization` for `IsSandbox`; return `{CustomerName}_TEST` if sandbox, else `{CustomerName}_PRODUCTION`. Use this in the invocable method for the endpoint (no hardcoded single credential).

---

## 3. Invocable Method

- **Annotation:** `@InvocableMethod(description='Establish Connection with {CustomerName} using Named Credential.')`
  - Adjust the `description` to match your integration if needed.
- **Signature:**  
`public static List<Boolean> {FunctionName}(List<Call{CustomerName}ApiInput> requests)`
  - Returns a `List<Boolean>`: one `true`/`false` per request (success = status code 200–299).
  - Replace `{FunctionName}` with your chosen name (e.g. `EstablishConnection`); keep `Call{CustomerName}ApiInput` for the input DTO.

**Behavior (exact logic):**

1. Create an empty `List<Boolean> results`.
2. For **each** `Call{CustomerName}ApiInput request` in `requests`:
  - In a **try** block:
  - Create `HttpRequest req = new HttpRequest();`
  - Set `req.setEndpoint('callout:' + getNamedCredential() + request.relativePath);`
  - Set `req.setMethod(request.httpMethod);`
  - Set `req.setTimeout(DEFAULT_TIMEOUT_MS);`
  - Set `req.setHeader('Content-Type', 'application/json');`
  - If `request.requestBody != null`, set `req.setBody(request.requestBody);`
  - Send: `HttpResponse res = new Http().send(req);`
  - Add to `results`: `res.getStatusCode() >= 200 && res.getStatusCode() < 300`
    - In **catch (Exception ex)**:
      - Add `false` to `results`.
3. Return `results`.

So: one boolean per input; one failure does not stop the rest; exceptions result in `false` for that request.

---

## 4. DTO Class (Invocable Input Only)

Section comment: `/* ===================== DTO CLASSES ===================== */`

### 4.1 Input: `Call{CustomerName}ApiInput` (public inner class)

- `@InvocableVariable(required=true)` `public String httpMethod;`
- `@InvocableVariable(required=true)` `public String relativePath;`
- `@InvocableVariable` `public String requestBody;` (optional)

There is **no** separate result DTO; the method returns `List<Boolean>`.

---

## 5. Safety & Best Practices (Must Preserve)

When generating the class, ensure these are respected:


| #   | Safety / practice         | Where it's enforced                                                   |
| --- | ------------------------- | --------------------------------------------------------------------- |
| 1   | **Sharing**               | `with sharing` on the class.                                          |
| 2   | **No hardcoded secrets**  | Only `callout:getNamedCredential()`; credentials in Named Credential. |
| 3   | **Timeout**               | `setTimeout(DEFAULT_TIMEOUT_MS)` to avoid hanging.                    |
| 4   | **Per-request try/catch** | One failed request doesn't abort the whole batch; error → `false`.    |


---

## 6. File & Metadata

- **File name:** `{ClassName}_Connection.cls` (e.g. `CustomerName_TestHamza.cls`).
- **Meta file:** `{ClassName}_Connection.cls-meta.xml` with at least:
  - `apiVersion` (e.g. `66.0`)
  - `status` Active.

---

