---
description: Generate generic {Prefix}_Connection, {Prefix}_Integration, and {Prefix}_Integration_Test Apex classes from spec; always ask for project prefix first
globs: '**/*.cls'
alwaysApply: false
---

# Generate {Prefix}\_Connection, {Prefix}\_Integration, and {Prefix}\_Integration_Test Classes

## Mandatory first step

**Before generating any `{Prefix}_Integration`, or `{Prefix}_Integration_Test` classes from a markdown or spec file, you MUST ask the user:**

> "What is the project prefix for the new classes? (e.g. LIM, ACME, MYAPP)"

Use the user's answer as `{Prefix}` everywhere (e.g. {Prefix}\_Integration_Test, {Prefix}\_Integration). Do not assume or invent a prefix.

---

## Pattern overview

- **{Prefix}\_Integration**: Holds all HTTP logic, Named Credentials, validation, and callouts.
- **{Prefix}\_Integration_Test**: Test class that covers all Integration behavior (invocable method, executeRequests, validation, mocks, errors). Generate this together with the Integration class.

---

## {Prefix}\_Integration class (exact structure)

- **Class**: `public with sharing class {Prefix}_Integration`
- **Constants**:
    - `{Prefix}_TEST` and `{Prefix}_PRODUCTION` (Named Credential names)
    - `DEFAULT_TIMEOUT_MS = 60000`
    - `ALLOWED_METHODS = new Set<String>{ 'GET', 'POST', 'PUT', 'PATCH', 'DELETE' }`
- **Inner classes**:
    - **Input**: `httpMethod`, `relativePath`, `requestBody` (for Apex callers; no @InvocableVariable)
    - **Output**: `success` (Boolean), `statusCode` (Integer), `responseBody`, `errorMessage` (for Apex)
    - **InvocableInput**: same fields as Input but with `@InvocableVariable(required=true)` on httpMethod and relativePath, description on each
    - **InvocableOutput**: same as Output but statusCode as String; all with `@InvocableVariable(description='...')`
- **Methods**:
    - `@InvocableMethod(description='...', category='...')  // optional: label='...'` → `callXxxApi(List<InvocableInput> inputs)` → converts to Input, calls `executeRequests`, maps to InvocableOutput
    - `getNamedCredential()`: private static; `Organization.IsSandbox` → TEST else PRODUCTION
    - `executeRequests(List<Input> requests)`: public static; returns `List<Output>`; for each request: validateCalloutLimit, validateRequest, buildHttpRequest, sendHttpRequest, populateResponse; catch CalloutException and Exception
    - `validateCalloutLimit()`: throw if `Limits.getCallouts() >= Limits.getLimitCallouts()`
    - `validateRequest(Input)`: null check, httpMethod required and in ALLOWED_METHODS, relativePath required
    - `buildHttpRequest(Input)`: endpoint `callout:{NamedCredential}{path}` (path with leading /), method, timeout, Content-Type application/json, attach body for POST/PUT/PATCH if not blank
    - `shouldAttachBody(method, body)`: true if body not blank and method in POST/PUT/PATCH
    - `sendHttpRequest(HttpRequest)`: `new Http().send(request)`
    - `populateResponse(Output, HttpResponse)`: statusCode, responseBody; success = true for 2xx else false and set errorMessage

---

## {Prefix}\_Integration_Test class (create to cover all)

**Always generate a test class** `{Prefix}_Integration_Test` for `{Prefix}_Integration` so that all public and critical behavior is covered.

- **Class**: `@isTest private class {Prefix}_Integration_Test`
- **HttpCalloutMock inner classes**:
    - **MockSuccess**: `respond()` returns HttpResponse with status 200, body `'{"success":true}'`, status 'OK'
    - **MockError**: `respond()` returns HttpResponse with status 404, body 'Not Found', status 'Not Found'
- **Test methods to include** (use `{Prefix}_Integration` and the actual invocable method name e.g. `callXxxApi`):
    1. **Invocable method**: `callXxxApi_emptyInput_returnsEmptyList` — empty list input → empty list output
    2. **Invocable method**: `callXxxApi_nullInput_returnsEmptyList` — null input → empty list output
    3. **Invocable method**: `callXxxApi_validInput_returnsResult` — with MockSuccess, one InvocableInput (GET, path, null body) → one InvocableOutput, success true, statusCode '200', responseBody matches mock, errorMessage null
    4. **executeRequests**: `executeRequests_emptyInput_returnsEmptyList` — empty list → empty list
    5. **executeRequests**: `executeRequests_nullInput_returnsEmptyList` — null → empty list
    6. **executeRequests**: `executeRequests_validRequest_success` — with MockSuccess, one Input (POST, path, body) → one Output, success true, statusCode 200, responseBody matches mock, errorMessage null
    7. **executeRequests**: `executeRequests_invalidMethod_returnsError` — Input with httpMethod 'INVALID' → one Output, success false, errorMessage contains 'Invalid HTTP method'
    8. **executeRequests**: `executeRequests_blankPath_returnsError` — Input with relativePath '' → success false, errorMessage contains 'Relative path'
    9. **executeRequests**: `executeRequests_blankMethod_returnsError` — Input with httpMethod '' → success false, errorMessage set
    10. **executeRequests**: `executeRequests_httpError_returnsErrorResult` — with MockError, valid Input → success false, statusCode 404, errorMessage set
    11. **executeRequests**: `executeRequests_pathWithoutLeadingSlash_buildsCorrectEndpoint` — with MockSuccess, relativePath without leading '/' → success true (path normalization works)

Use `Test.setMock(HttpCalloutMock.class, new MockSuccess())` or `new MockError()` before callouts. Wrap callouts in `Test.startTest()` / `Test.stopTest()`. Assert list size, success, statusCode, responseBody, and errorMessage as appropriate. Create the corresponding `{Prefix}_Integration_Test.cls-meta.xml` with the same metadata as other test classes in the project.

---

## Naming and placeholders

- Replace `{Prefix}` with the user-provided prefix (e.g. LIM).
- Replace API/system name (e.g. Mirakl) from the markdown/spec when generating labels, descriptions, and Named Credential constant names.
- Keep the same structure, method names, and logic as the reference LIM_Mirakl_Integration and only names and comments change.
