# LIM_Mirakl_Connection_Test – What We Did and What We Checked

Summary of the test class for `LIM_Mirakl_Connection`: each test method, what it does, and what it asserts.

---

## Test Setup

- **Test class:** `LIM_Mirakl_Connection_Test` (`@IsTest`, `private`)
- **Mocks:** No real HTTP callouts. All tests use `Test.setMock(HttpCalloutMock.class, ...)` so the Mirakl API is never called.

### Mocks Used

| Mock | Purpose |
|------|--------|
| **MiraklCalloutMock(statusCode, body)** | Returns an `HttpResponse` with the given status code and body. Used for success (200, 201, 204) and failure (401) scenarios. |
| **MiraklEmptyBodyMock** | Returns 500 with an empty body. Used to ensure error handling works when the API returns no body. |

---

## Test Methods – What We Did and What We Checked

### 1. `executeRequests_success`

**What we did:** One GET request to `/`, mock returns 200 with body `{"version":"3.1248"}`.

**What we checked:**

- One result in the list.
- `success == true`.
- `statusCode == 200`.
- `responseBody == '{"version":"3.1248"}'`.
- `errorMessage == null`.

---

### 2. `executeRequests_failure`

**What we did:** One GET request to `/`, mock returns 401 with body `Unauthorized`.

**What we checked:**

- One result in the list.
- `success == false`.
- `statusCode == 401`.
- `errorMessage` is not blank (contains error info).

---

### 3. `executeRequests_emptyInput`

**What we did:** Call `executeRequests` with an empty list (no requests).

**What we checked:**

- Result list is empty (size 0). No callout is made.

---

### 4. `executeRequests_postWithBody`

**What we did:** One POST to `/orders` with body `{"key":"value"}`, mock returns 201 with `{"id":"123"}`.

**What we checked:**

- One result.
- `success == true`.
- `statusCode == 201`.
- `responseBody == '{"id":"123"}'`.

---

### 5. `executeRequests_shops`

**What we did:** One GET to `api/shops?shop_ids=2064`, mock returns 200 with shops JSON containing shop_id 2064.

**What we checked:**

- One result.
- `success == true`.
- `statusCode == 200`.
- `responseBody` contains `2064`.

---

### 6. `executeRequests_nullInput`

**What we did:** Call `executeRequests(null)`.

**What we checked:**

- Result list is empty (size 0). No exception; null is handled safely.

---

### 7. `executeRequests_nullRequestInList`

**What we did:** Pass a list with one element: `null` (a null request in the list).

**What we checked:**

- One result (one result per input).
- `success == false`.
- `statusCode == -1`.
- `errorMessage` contains `"null"` (validation error for null request).

---

### 8. `executeRequests_invalidMethod`

**What we did:** One request with `httpMethod = 'INVALID'` (not in allowed methods).

**What we checked:**

- One result.
- `success == false`.
- `statusCode == -1`.
- `errorMessage` contains `"Unsupported HTTP method"`.

---

### 9. `executeRequests_putWithBody`

**What we did:** One PUT to `/orders/1` with body `{"status":"shipped"}`, mock returns 200 with `{"updated":true}`.

**What we checked:**

- One result.
- `success == true`.
- `statusCode == 200`.

---

### 10. `executeRequests_delete`

**What we did:** One DELETE to `/orders/1`, mock returns 204 (No Content).

**What we checked:**

- One result.
- `success == true`.
- `statusCode == 204` (successful delete).

---

### 11. `executeRequests_patchWithBody`

**What we did:** One PATCH to `/orders/1` with body `{"status":"updated"}`, mock returns 200.

**What we checked:**

- One result.
- `success == true`.

---

### 12. `executeRequests_twoRequests`

**What we did:** Two GET requests to `/` in one call (batch of 2).

**What we checked:**

- Two results.
- First result: `success == true`.
- Second result: `success == true`.

---

### 13. `executeRequests_blankRelativePath`

**What we did:** One GET with `relativePath = ''` (blank path).

**What we checked:**

- One result.
- `success == true` (blank path defaults to `/` and request succeeds).

---

### 14. `executeRequests_nullHttpMethodDefaultsToGet`

**What we did:** One request with `httpMethod = null`.

**What we checked:**

- One result.
- `success == true` (null method defaults to GET).

---

### 15. `executeRequests_calloutLimitExceeded`

**What we did:** 101 GET requests in one call (over the normal callout limit in a transaction).

**What we checked:**

- 101 results (one per input).
- First result: `success == true`.
- 101st result: `success == false`, `statusCode == -1`, `errorMessage` contains `"Callout limit"` (limit check works).

---

### 16. `executeRequests_failureWithEmptyBody`

**What we did:** One GET request, mock returns 500 with empty body (`MiraklEmptyBodyMock`).

**What we checked:**

- One result.
- `success == false`.
- `statusCode == 500`.
- `errorMessage` is not blank (populateResponse still sets error when body is empty).

---

## Quick Reference Table

| Test | Scenario | Main checks |
|------|----------|-------------|
| `executeRequests_success` | GET 200 OK | success, 200, body, no error |
| `executeRequests_failure` | GET 401 | fail, 401, errorMessage set |
| `executeRequests_emptyInput` | Empty list | 0 results |
| `executeRequests_postWithBody` | POST with body | 201, body in response |
| `executeRequests_shops` | GET shops API | 200, body contains shop id |
| `executeRequests_nullInput` | null list | 0 results |
| `executeRequests_nullRequestInList` | null in list | fail, -1, error mentions null |
| `executeRequests_invalidMethod` | Invalid HTTP method | fail, -1, unsupported method |
| `executeRequests_putWithBody` | PUT with body | 200 success |
| `executeRequests_delete` | DELETE 204 | 204 success |
| `executeRequests_patchWithBody` | PATCH with body | success |
| `executeRequests_twoRequests` | 2 requests | 2 results, both success |
| `executeRequests_blankRelativePath` | Blank path | defaults to /, success |
| `executeRequests_nullHttpMethodDefaultsToGet` | Null method | defaults to GET, success |
| `executeRequests_calloutLimitExceeded` | 101 requests | first OK, 101st fails on limit |
| `executeRequests_failureWithEmptyBody` | 500 empty body | fail, 500, errorMessage set |

Use this as a reference for what each test does and what it verifies.
