---

## description: Generate generic {Prefix}_{Entity}Create Apex class (and test) from spec; always ask for project prefix and entity name first
globs: '**/*.cls'
alwaysApply: false

# Generate {Prefix}_{Entity}Create Class (Super Generic)

Use this when generating a "create entity via API" class (e.g. ShopCreate, OrderCreate) that uses an Integration class for the HTTP call. Ask the user for the Integration class name (e.g. LIM_Mirakl_Integration). Customize all SObject names, field names, API path, and payload from the project spec or client requirements.

---

## Mandatory first step

**Before generating `{Prefix}_{Entity}` or `{Prefix}_{Entity}_Test`, you MUST ask the user:**

1. **Project prefix**
  > "What is the project prefix? (e.g. LIM, ACME)"
2. **Entity name**
  > "What is the entity name for this create flow? (e.g. Shop, Order, Merchant)"

3. **Integration class name**
  > "What is the name of the Integration class you created for HTTP callouts? (e.g. LIM_Mirakl_Integration)"
  Use this exact class name when building the request and calling executeRequests. Do not assume.

4. **Data to fetch (when building the create flow)**
  Before writing SOQL or building the request body, ask the user:
  - **Main record**: Which SObject to query for the input Id? ()
  - **Main record fields**: Which fields on that object? ()
  - **Related object(s)**: Any lookup/child relationships to query? Relationship name and which fields? ()
  - **Related filters**: Filters on related queries if needed? ()
   Use the answers for SOQL and payload construction. Do not assume object names, field names, or relationship names.

Use the answers as `{Prefix}` and `{Entity}`. Do not assume or invent values.

---

## Pattern overview

- **{Prefix}_{Entity}Create**: Invocable class that takes one or more record Ids, loads related data (per spec), builds a JSON request body, calls **the user-provided Integration class**.executeRequests with POST to a configurable path, parses the response, and returns success/entityId/errors.
- **{Prefix}_{Entity}_Test**: Test class that mocks callouts and covers empty/null input, validation errors, success, and API error paths.

All SObject names, field names, API path, request shape, and response parsing must come from the spec or client requirements—this doc describes only the structure.

---

## {Prefix}_{Entity}Create class (exact structure)

- **Class**: `public with sharing class {Prefix}_{Entity}`
- **Input inner class**:
  - One or more Ids (e.g. `recordId` or `partnerIntegrationId`). Use `@InvocableVariable(required=true description='...')`. Field name and description come from spec.
- **Output inner class** (standard shape):
  - `entityId` (String) — e.g. merchantId, shopId; from API response. Use name from spec (e.g. merchantId).
  - `success` (Boolean)
  - `statusCode` (Integer)
  - `errorMessage` (String)
  - `requestJson` (String) — optional; body sent to API
  - `responseJson` (String) — optional; raw response body
- **Invocable method**: `@InvocableMethod(description='...')` → `createXxx(List<Input> inputs)` (e.g. createShop). For each Input, call a private method that does the work and add the result to the output list.
- **Private “per-record” method**: e.g. `createXxxForRecord(Id recordId)` returning Output:
  1. **Load record(s)** — Query the main record (and related records) using SObject and field names from the spec. If not found or required relation missing, set success false, set errorMessage, return.
  2. **Build request body** — Construct a Map<String, Object> (and nested maps/lists) per API spec, then `JSON.serialize`. Optional: use static maps (e.g. country code alpha2→alpha3) or helpers (e.g. civility mapping) if the API requires.
  3. **Call Integration** — Use the Integration class name the user gave. Build `{IntegrationClassName}.Input`: httpMethod = 'POST', relativePath = path from spec (e.g. '/api/shops'), requestBody = serialized JSON. Call `{IntegrationClassName}.executeRequests(List<Input>)` and take the first Output.
  4. **Parse response** — If Integration output success: parse response body (e.g. JSON.deserializeUntyped), extract entity id and optional errors from the structure defined in spec (e.g. shop_returns[].shop_created.shop_id or shop_error). If API returns business errors in body, set success false and set errorMessage. If Integration output not success, set success false and errorMessage from Integration.
  5. **Populate Output** — success, statusCode, responseJson (and requestJson if desired), entityId, errorMessage.
- **Exception handling** — Catch QueryException and generic Exception; set success false and set errorMessage; return a single Output per input.
- **Constants** — Only what the API needs (e.g. API path, country map, civility map). All names and values from spec.

---

## Optional elements (ask user: yes → add, no → skip)

**Before generating, ask the user for each; only add if they say yes.**

1. **Static map**  
   > "Do you need a static map (e.g. country code alpha2→alpha3) for the request payload?"  
   - **Yes** → Add the map (e.g. `COUNTRY_ALPHA2_TO_ALPHA3`); key/value set from spec or ask user for entries.  
   - **No** → Do not add.

2. **Helper methods**  
   > "Do you need helper methods (e.g. civility/salutation mapping) for values allowed by the API?"  
   - **Yes** → Add helper(s); method name, logic, and allowed values from spec or ask user.  
   - **No** → Do not add.

---

## {Prefix}_{Entity}Create_Test class (cover all)

**Always generate** `{Prefix}_{Entity}Create_Test` for `{Prefix}_{Entity}Create`.

- **Class**: `@isTest private class {Prefix}_{Entity}Create_Test`
- **HttpCalloutMock inner classes** (adapt to actual API response shape from spec):
  - **MockCreated** — respond() returns 200 and a body that represents success (e.g. contains entity id in the path defined by spec).
  - **MockBusinessError** — respond() returns 200 and a body that represents API business error (e.g. error array or shop_error).
  - **MockHttpError** — respond() returns non-2xx (e.g. 500) and error body.
- **Test methods to include**:
  1. **Empty input** — createXxx(empty list) → empty list.
  2. **Null / invalid id** — input with null or invalid Id → one Output, success false, errorMessage set (e.g. “not found” or “required field missing”).
  3. **Record not found** — valid Id but record missing (or required relation missing) → success false, errorMessage indicates not found or missing relation.
  4. **Success path** — With MockCreated, insert required test data (main record + related per spec), call createXxx → one Output, success true, entityId set (and statusCode/responseJson as needed).
  5. **API business error** — With MockBusinessError, valid test data → success false, errorMessage set from parsed body if applicable.
  6. **HTTP error** — With MockHttpError → success false, statusCode and errorMessage set.
- Use `Test.setMock(HttpCalloutMock.class, new MockCreated())` (or MockBusinessError / MockHttpError) before callouts. Use `Test.startTest()` / `Test.stopTest()` around the invocable call. Create `{Prefix}_{Entity}Create_Test.cls-meta.xml` consistent with other test classes.

---

## Naming and placeholders

- Replace `{Prefix}` with the user-provided prefix (e.g. LIM).
- Replace `{Entity}` with the user-provided entity name (e.g. Shop → ShopCreate, Order → OrderCreate).
- All SObject names, field names, API path, request/response shapes, and error handling messages must come from the project spec or client requirements—keep the class generic in structure but concrete in names and logic once spec is given.

