---
name: Mirakl Shops to Salesforce Sync
overview: New Apex class that parses the Mirakl GET /shops response and upserts Account, Address__c, and Contact records in Salesforce, using the existing LIM_Mirakl_Integration.
todos: []
isProject: false
---

# Mirakl JSON → Salesforce Sync – Apex Class Plan

## Goal

Parse the Mirakl shops GET response and insert/update **Account**, **Addressc**, and **Contact** in Salesforce. Use the existing [LIM_Mirakl_Integration.cls](force-app/main/default/classes/LIM_Mirakl_Integration.cls) to perform the callout.

---

## Architecture (high-level)

See **[Mirakl_Shops_to_Salesforce_Sync_Plan.md](../Mirakl_Shops_to_Salesforce_Sync_Plan.md)** for the full diagrams: (1) Mirakl → Account / Address__c / Contact inside `LIM_Mirakl_ShopsSyncFromMirakl`, and (2) Flow **`LIM_Mirakl_ShopsSyncFromMirakl`**: Start → Invocable → `setJob` → **`Job__c`**.

---

## 1. New Apex Class: `LIM_Mirakl_ShopsSyncFromMirakl`

**Location:** `force-app/main/default/classes/LIM_Mirakl_ShopsSyncFromMirakl.cls`

**Responsibilities:**

- **Option A – Callout + sync:** Call GET via LIM_Mirakl_Integration, parse the response, and upsert to Salesforce (scheduled or single run).
- **Option B – Parse + sync only:** Caller (Flow or another class) supplies the JSON; the class only parses, maps, and upserts.

To support both:

- **Public method 1:** `syncShopsFromMirakl()` – Performs the GET call internally (relative path e.g. `'/api/shops'` or configurable), then calls `syncShopsFromJson(responseBody)`.
- **Public method 2:** `syncShopsFromJson(String jsonBody)` – Parses the supplied JSON and upserts Account/Address/Contact. Can also be called from Flow when the JSON is already available.

Make it Invocable so that “Mirakl shops sync” can be triggered from Flow.

---

## 2. JSON Parsing

Mirakl response structure:

```json
{ "shops": [ { "shop_id", "shop_name", "contact_informations": {...}, "default_billing_information": { "registration_address": {...}, "corporate_information": {...} }, "commission": {...}, "pro_details": {...}, ... } ], "total_count": N }
```

**Approach:** Use `JSON.deserializeUntyped(responseBody)` to get the root map, then the `shops` list; treat each element as `Map<String, Object>`. Nested objects (`contact_informations`, `default_billing_information`, `commission`, `pro_details`) will also be maps.

Typed wrapper classes are optional; all mapping can be done clearly with untyped maps. For better maintainability, you can add separate wrapper inner classes (e.g. `MiraklShop`, `MiraklContactInfo`, `MiraklAddress`).

---

## 3. Field Mapping (Mirakl → Salesforce)

### 3.1 Account (upsert by `MerchantId__c` External ID)

| Mirakl source                                                                                                         | Salesforce field                              | Notes                                                      |
| --------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------- |
| `shop_id`                                                                                                             | `MerchantId__c`                               | String; External ID, unique – upsert key                   |
| `shop_name`                                                                                                           | `Shopname__c` + `Name`                        | Account.Name required                                      |
| `contact_informations.web_site`                                                                                       | `Website`                                     |                                                            |
| `contact_informations.country` / `shipping_country`                                                                   | `CommercialCountry__c`                        | Picklist; DEU → DE mapping may be needed (check value set) |
| `commission.grid_label` (e.g. "DE 15%")                                                                               | `Commission__c`                               | Percent field; parse the number and set (15 → 15.00)       |
| `default_billing_information.corporate_information.company_registration_number` / `pro_details.identification_number` | `CommercialRegisterNumber__c`                 |                                                            |
| `pro_details.VAT_number` / `tax_identification_number`                                                                | `VatIdCompany__c`                             |                                                            |
| (if in response)                                                                                                      | `LucidNumber__c`, `WeeeRegistrationNumber__c` | When present in Mirakl                                     |
| —                                                                                                                     | `AccountManager__c`                           | User lookup; leave null unless business rule               |
| —                                                                                                                     | `ReturnLabelProcess__c`, `Sla__c`             | Not in JSON; null or default                               |

`MerchantCompanyName__c` is a formula per the image, so do not set it.

### 3.2 Addressc (Headquarter)

- **Accountc:** Account Id from after the upsert.
- **AddressTypec:** `'Headquarter'` (fixed for this sync).
- **Compound address:**  
  Use `contact_informations` or `default_billing_information.registration_address`:
    - `street1` (+ optional `street2`) → `Address__Street__s`
    - `zip_code` → `Address__PostalCode__s`
    - `city` → `Address__City__s`
    - `country` / `country_iso_code` → `Address__CountryCode__s` (DEU → DE if Salesforce uses alpha-2).

Logic: Use `registration_address` first; if empty, use city/street/zip/country from `contact_informations`.

### 3.3 Contact

- **AccountId:** Same Account Id (after upsert).
- **FirstName, LastName, Email:** `contact_informations.firstname`, `lastname`, `email`.
- **Phone / MobilePhone:** `contact_informations.phone`, `phone_secondary` (map per your standard).
- **Title / Salutation:** `contact_informations.civility` (Mr/Mrs etc.) → Title or Salutation.
- **RoleMarketplacec:** `'Mirakl Invitation'` (existing pattern, [LIM_Mirakl_ShopCreate.cls](force-app/main/default/classes/LIM_Mirakl_ShopCreate.cls) line 188).

Strategy: One primary Contact per shop – if the Account already has a “Mirakl Invitation” contact, update it; otherwise insert a new one. Match by AccountId + RoleMarketplacec = 'Mirakl Invitation' (and optionally Email).

---

## 4. Country Code

- **CommercialCountryc** is a picklist ([CommercialCountryc](force-app/main/default/objects/Account/fields/CommercialCountry__c.field-meta.xml)); check the value set (DE vs DEU).
- **Address**CountryCode**s** is a compound address field; Salesforce often uses alpha-2 (DE).  
  If Salesforce uses alpha-2, you need Mirakl alpha-3 (DEU) → alpha-2 (DE) mapping. [LIM_Mirakl_ShopCreate.cls](force-app/main/default/classes/LIM_Mirakl_ShopCreate.cls) has alpha-2 → alpha-3; define or reuse a reverse map (alpha-3 → alpha-2) for this class.

---

## 5. Execution Flow (per shop)

1. Parse root → `shops` list.
2. For each shop:

- Build the Account record (MerchantIdc = `shop_id` as string); remaining fields from the mapping.
- `Database.upsert(accounts, Account.MerchantId__c)`.
- Using the upserted Account Id:
    - **Addressc:** Headquarter address from registration_address / contact_informations; insert (or match by “Headquarter” + AccountId and update – per business rule).
    - **Contact:** Create or update Mirakl Invitation contact (AccountId + RoleMarketplacec).

1. Bulk-safe: Build full Account list, Address list, and Contact list; then run `upsert` / `insert` / `update` in batch (e.g. lists up to 200; respect DML limits).

---

## 6. Error Handling & Limits

- Callout: [LIM_Mirakl_Integration](force-app/main/default/classes/LIM_Mirakl_Integration.cls) already checks callout limits.
- JSON parse failure → try/catch, return or set a clear error message.
- DML: For partial success use `Database.upsert(..., false)`; return results and error list to inform the caller.
- Governor limits: If there are many shops, consider a batch/scheduled run (e.g. `LIM_Mirakl_ShopsSyncFromMiraklBatch`) later.

---

## 7. Mirakl API Path

The user-provided response structure has `shops` and `total_count`. The endpoint is typically a **GET** shops list (e.g. `/api/shops` or the documented path). Confirm the exact path from Mirakl docs; keep the path in a constant or Custom Setting in the class so it is easy to change.

---

## 8. Test Class

- **`LIM_Mirakl_ShopsSyncFromMirakl_Test.cls`:**
    - `syncShopsFromJson` with static JSON (the user’s sample) – no callout.
    - Verify: Account upsert (MerchantId**c), Address**c (Headquarter), Contact (RoleMarketplace = Mirakl Invitation).
    - Negative: invalid JSON, empty shops, missing required fields.
    - Test the callout method with `Test.setMock(HttpCalloutMock, ...)` so the actual GET is not executed.

---

## 9. Optional / Future

- **Contract:** In the image, BillingFrequency**c and TermOfPayment**c were on Contract; there is no direct match in the Mirakl JSON. If needed later, add separate mapping and a Contract create/update step.
- **Closing times / Premium rules:** Image notes (“Schließzeiten in Salesforce anlegen”, “Premium Rule anlegen”) – these are separate objects/features; keep out of scope for this plan.
- **Batch/scheduled:** If the number of shops is large, run sync via `LIM_Mirakl_ShopsSyncFromMiraklBatch` (Batchable) and Scheduler.

---

## 10. Files to Add/Change

| Action    | File                                                                                                  |
| --------- | ----------------------------------------------------------------------------------------------------- |
| Create    | `force-app/main/default/classes/LIM_Mirakl_ShopsSyncFromMirakl.cls` – sync logic, mapping, upsert                |
| Create    | `force-app/main/default/classes/LIM_Mirakl_ShopsSyncFromMirakl.cls-meta.xml`                                     |
| Create    | `force-app/main/default/classes/LIM_Mirakl_ShopsSyncFromMirakl_Test.cls` – tests with static JSON + mock callout |
| Create    | `force-app/main/default/classes/LIM_Mirakl_ShopsSyncFromMirakl_Test.cls-meta.xml`                                |
| No change | `LIM_Mirakl_Integration.cls` – use as-is for GET                                                      |

---

## Summary

- **`LIM_Mirakl_ShopsSyncFromMirakl`** parses the Mirakl shops JSON and creates/updates **Account** (upsert by MerchantId__c), **Address__c** (Headquarter), and **Contact** (Mirakl Invitation).
- Use **LIM_Mirakl_Integration** to perform the GET call and get the response, then run insert/update via `syncShopsFromJson` in the same class.
- Country and Commission mapping will need some logic (alpha-3→alpha-2, number from grid_label); the rest is direct field mapping.
- The test class should cover JSON-based sync and mock callout; batch/scheduler can be added later.
