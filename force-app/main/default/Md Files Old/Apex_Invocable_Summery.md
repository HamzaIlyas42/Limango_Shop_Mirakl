# LIM_Mirakl_Connection – Summary

## What This Class Does (In One Sentence)

This class lets **Salesforce Flow or Apex** call the **Mirakl API** over HTTP. You give it a method (GET, POST, etc.), a path, and optional body; it uses a **Named Credential** so you never put passwords in code, and it returns success/failure plus the response.

---

## Config (Settings at the Top)

| Setting                | What It Does                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------- |
| **NAMED_CREDENTIAL**   | Which Named Credential to use (e.g. `Mirakl_Token`). Salesforce uses this to get the base URL and auth. |
| **DEFAULT_TIMEOUT_MS** | How long to wait for the API (e.g. 60 seconds) before giving up.                                        |
| **ALLOWED_METHODS**    | Only these HTTP methods are allowed: GET, POST, PUT, PATCH, DELETE. Anything else is rejected.          |

---

## Main Entry Point (What Flow / Apex Calls)

### `executeRequests(List<CallMiraklApiInput> requests)`

- **Why it exists:** So Flow or other Apex can call Mirakl without writing HTTP code.
- **What it does:** Takes a list of requests. For each request it: checks limits, checks the input, builds the HTTP request, sends it, and fills the result (status, body, success, error). If the list is null or empty, it returns an empty list. If one request fails, the others still run; each result says whether that call succeeded or failed.

---

## Helper Functions (What Each One Does)

### `validateCalloutLimit()`

- **Why:** Salesforce limits how many callouts you can do in one run.
- **What it does:** Before sending a callout, it checks if you’re already at the limit. If yes, it throws so you don’t waste a call that would fail anyway.

### `validateRequest(CallMiraklApiInput request)`

- **Why:** Bad input can cause wrong or unsafe requests.
- **What it does:** Makes sure the request is not null and that the HTTP method is one of the allowed ones (GET, POST, PUT, PATCH, DELETE). If something is wrong, it throws with a clear message.

### `buildHttpRequest(CallMiraklApiInput request)`

- **Why:** The API needs a properly built HTTP request (URL, method, headers, body).
- **What it does:** Takes your input (method, path, body) and builds an `HttpRequest`: endpoint = Named Credential + path (with a leading `/` if missing), method, timeout, JSON headers. It only adds a body for POST, PUT, or PATCH when body is not blank.

### `shouldAttachBody(String method, String body)`

- **Why:** GET and DELETE usually don’t have a body; POST/PUT/PATCH often do.
- **What it does:** Returns true only when there is a non-blank body and the method is POST, PUT, or PATCH. So the class never sends a body for GET or DELETE.

### `sendHttpRequest(HttpRequest request)`

- **Why:** Someone has to actually send the request to the internet.
- **What it does:** Uses Salesforce’s `Http` class to send the request and returns the `HttpResponse`.

### `populateResponse(CallMiraklApiResult result, HttpResponse res)`

- **Why:** The caller needs a simple result: success or not, status code, body, and error message.
- **What it does:** Copies the status code and response body into the result, sets `success` to true when status is 200–299, and if it’s not successful, sets `errorMessage` from the status and body so you know what went wrong.

---

## Input and Output (What You Pass In and Get Back)

### CallMiraklApiInput (What you give)

| Field            | What it is                                                       |
| ---------------- | ---------------------------------------------------------------- |
| **httpMethod**   | GET, POST, PUT, PATCH, or DELETE.                                |
| **relativePath** | The path after the base URL (e.g. `/api/users/operators/roles`). |
| **requestBody**  | Optional. JSON string for POST/PUT/PATCH.                        |

### CallMiraklApiResult (What you get back)

| Field            | What it is                                                                  |
| ---------------- | --------------------------------------------------------------------------- |
| **success**      | True if the API returned 200–299, false otherwise.                          |
| **statusCode**   | The HTTP status code (e.g. 200, 404, 500).                                  |
| **responseBody** | The raw response text from the API.                                         |
| **errorMessage** | Filled when something went wrong (e.g. exception message or status + body). |

---

## Short Summary

- **Class:** Sends HTTP requests to Mirakl using a Named Credential; callable from Flow via `executeRequests`.
- **Safety:** Validates callout limit, null request, and HTTP method; only allows body on POST/PUT/PATCH; no secrets in code.
- **Flow:** One result per input; failures don’t stop the rest; errors are in the result object.

---

## Anonymous Apex Test Example

You can run this in **Developer Console → Debug → Open Execute Anonymous Window** to test the connection (ensure the user has the right Named Credential and permissions):

```apex
List<LIM_Mirakl_Connection.CallMiraklApiInput> requests = new List<LIM_Mirakl_Connection.CallMiraklApiInput>();
LIM_Mirakl_Connection.CallMiraklApiInput req = new LIM_Mirakl_Connection.CallMiraklApiInput();
req.httpMethod = 'GET';
req.relativePath = 'api/shops?shop_ids=2064';
req.requestBody = null;
requests.add(req);

List<LIM_Mirakl_Connection.CallMiraklApiResult> results = LIM_Mirakl_Connection.executeRequests(requests);

if (!results.isEmpty()) {
    System.debug('Status: ' + results[0].statusCode);
    System.debug('Success: ' + results[0].success);
    System.debug('Body: ' + results[0].responseBody);
}
```
