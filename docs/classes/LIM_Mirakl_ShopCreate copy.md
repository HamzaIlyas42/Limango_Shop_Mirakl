# LIM_Mirakl_ShopCreate copy

**Type:** Apex Class | **Status:** — | **API Version:** — | **Object/Trigger:** —

---

## Summary

Apex class **`LIM_Mirakl_ShopCreate copy`** (`classes/LIM_Mirakl_ShopCreate copy.cls`) is compiled and executed on the Salesforce server. It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures).

**Author / description from source comment:** LIM_Mirakl_ShopCreate Handles Shop creation in Mirakl via POST /shop/create Input : PartnerIntegration\_\_c Id Output : MerchantId, Success, StatusCode, ErrorMessage

---

## Technical Details

### Methods (heuristic)

| Method Name        | Access | Return Type | Description       |
| ------------------ | ------ | ----------- | ----------------- |
| `shopCreate`       | —      | —           | From source parse |
| `toMiraklCivility` | —      | —           | From source parse |

### Source

```apex
/**
 * LIM_Mirakl_ShopCreate
 * Handles Shop creation in Mirakl via POST /shop/create
 * Input  : PartnerIntegration__c Id
 * Output : MerchantId, Success, StatusCode, ErrorMessage
 */
public with sharing class LIM_Mirakl_ShopCreate {
    // ISO 3166-1 alpha-2 → alpha-3 (Mirakl may expect 3-letter code; if not, try passing alpha-2 as-is)
    private static final Map<String, String> COUNTRY_ALPHA2_TO_ALPHA3 = new Map<String, String>{
        'DE' => 'DEU',
        'AT' => 'AUT',
        'CH' => 'CHE',
        'FR' => 'FRA',
        'NL' => 'NLD',
        'BE' => 'BEL',
        'IT' => 'ITA',
        'ES' => 'ESP',
        'GB' => 'GBR',
        'UK' => 'GBR',
        'US' => 'USA',
        'CA' => 'CAN',
        'AU' => 'AUS',
        'NZ' => 'NZL',
        'IE' => 'IRL',
        'PT' => 'PRT',
        'PL' => 'POL',
        'SE' => 'SWE',
        'NO' => 'NOR',
        'DK' => 'DNK',
        'FI' => 'FIN',
        'CZ' => 'CZE',
        'SK' => 'SVK',
        'HU' => 'HUN',
        'RO' => 'ROU',
        'BG' => 'BGR',
        'GR' => 'GRC',
        'HR' => 'HRV',
        'SI' => 'SVN',
        'RS' => 'SRB',
        'BA' => 'BIH',
        'ME' => 'MNE',
        'MK' => 'MKD',
        'AL' => 'ALB',
        'LU' => 'LUX',
        'IS' => 'ISL',
        'EE' => 'EST',
        'LV' => 'LVA',
        'LT' => 'LTU',
        'CN' => 'CHN',
        'JP' => 'JPN',
        'KR' => 'KOR',
        'IN' => 'IND',
        'PK' => 'PAK',
        'BD' => 'BGD',
        'LK' => 'LKA',
        'NP' => 'NPL',
        'AF' => 'AFG',
        'TH' => 'THA',
        'VN' => 'VNM',
        'MY' => 'MYS',
        'SG' => 'SGP',
        'ID' => 'IDN',
        'PH' => 'PHL',
        'LA' => 'LAO',
        'KH' => 'KHM',
        'MM' => 'MMR',
        'AE' => 'ARE',
        'SA' => 'SAU',
        'QA' => 'QAT',
        'KW' => 'KWT',
        'OM' => 'OMN',
        'BH' => 'BHR',
        'JO' => 'JOR',
        'IL' => 'ISR',
        'LB' => 'LBN',
        'IQ' => 'IRQ',
        'TR' => 'TUR',
        'IR' => 'IRN',
        'KZ' => 'KAZ',
        'UZ' => 'UZB',
        'KG' => 'KGZ',
        'TJ' => 'TJK',
        'TM' => 'TKM',
        'RU' => 'RUS',
        'UA' => 'UKR',
        'BY' => 'BLR',
        'MD' => 'MDA',
        'ZA' => 'ZAF',
        'NG' => 'NGA',
        'KE' => 'KEN',
        'TZ' => 'TZA',
        'UG' => 'UGA',
        'ET' => 'ETH',
        'GH' => 'GHA',
        'DZ' => 'DZA',
        'MA' => 'MAR',
        'TN' => 'TUN',
        'BR' => 'BRA',
        'AR' => 'ARG',
        'CL' => 'CHL',
        'CO' => 'COL',
        'PE' => 'PER',
        'VE' => 'VEN',
        'UY' => 'URY',
        'PY' => 'PRY',
        'BO' => 'BOL',
        'MX' => 'MEX',
        'GT' => 'GTM',
        'CR' => 'CRI',
        'PA' => 'PAN',
        'CU' => 'CUB',
        'DO' => 'DOM',
        'JM' => 'JAM'
    };

    // Mirakl authorized civility: Mr, Mrs, Miss, Neutral (case-sensitive)
    private static String toMiraklCivility(String title) {
        if (String.isBlank(title))
            return 'Mr';
        String t = title.trim().toLowerCase();
        if (t.contains('mrs') || t.contains('frau') || t.contains('madam'))
            return 'Mrs';
        if (t.contains('miss') || t.contains('ms') && !t.contains('mr'))
            return 'Miss';
        if (t.contains('neutral') || t.contains('divers'))
            return 'Neutral';
        return 'Mr';
    }

    // ── Output Wrapper ────────────────────────────────
    public class ShopCreateResult {
        public String merchantId;
        public Boolean success;
        public Integer statusCode;
        public String errorMessage;
    }

    // ── Main Method ───────────────────────────────────
    public static ShopCreateResult shopCreate(Id partnerIntegrationId) {
        ShopCreateResult result = new ShopCreateResult();

        try {
            // ── Step 1: Fetch PartnerIntegration__c to get related Account Id (CompanyName__c) ──
            List<PartnerIntegration__c> piList = [
                SELECT Id, CompanyName__c
                FROM PartnerIntegration__c
                WHERE Id = :partnerIntegrationId AND CompanyName__c != NULL
                LIMIT 1
            ];

            if (piList.isEmpty()) {
                result.success = false;
                result.errorMessage = 'PartnerIntegration not found or has no CompanyName: ' + partnerIntegrationId;
                return result;
            }

            Id accountId = piList[0].CompanyName__c;

            // ── Step 2: Fetch Account with Contacts and Addresses subqueries ──
            List<Account> accounts = [
                SELECT
                    Id,
                    Name,
                    CommercialRegisterNumber__c,
                    (SELECT Id, Email, FirstName, LastName, Title FROM Contacts),
                    (
                        SELECT Id, Address__Street__s, Address__PostalCode__s, Address__City__s, Address__CountryCode__s
                        FROM Addresses__r
                    )
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                result.success = false;
                result.errorMessage = 'Account not found for CompanyName: ' + accountId;
                return result;
            }

            Account acct = accounts[0];

            // First Contact (for email, firstname, lastname)
            Contact primaryContact = acct.Contacts != null && !acct.Contacts.isEmpty() ? acct.Contacts[0] : null;
            // First Address (for address block)
            SObject firstAddress = (acct.Addresses__r != null && !acct.Addresses__r.isEmpty())
                ? acct.Addresses__r[0]
                : null;

            // ── Step 3: Build Request Body ─────────────────────────────

            String contactEmail = primaryContact != null ? primaryContact.Email : null;
            String contactFirst = primaryContact != null ? primaryContact.FirstName : null;
            String contactLast = primaryContact != null ? primaryContact.LastName : null;

            // -- Address (try alpha-3; if Mirakl still rejects, try alpha-2 or check API docs) --
            String countryCode = firstAddress != null ? (String) firstAddress.get('Address__CountryCode__s') : null;
            String countryForMirakl = (countryCode != null &&
                COUNTRY_ALPHA2_TO_ALPHA3.containsKey(countryCode.toUpperCase()))
                ? COUNTRY_ALPHA2_TO_ALPHA3.get(countryCode.toUpperCase())
                : countryCode;

            // street1 and civility required by Mirakl (authorized: Mr, Mrs, Miss, Neutral)
            String street1 = firstAddress != null ? (String) firstAddress.get('Address__Street__s') : null;
            String civility = toMiraklCivility(primaryContact != null ? primaryContact.Title : null);
            Map<String, Object> address = new Map<String, Object>{
                'city' => firstAddress != null ? firstAddress.get('Address__City__s') : null,
                'civility' => civility,
                'country' => countryForMirakl,
                'firstname' => contactFirst,
                'lastname' => contactLast,
                'street1' => street1,
                'zip_code' => firstAddress != null ? firstAddress.get('Address__PostalCode__s') : null
            };

            // -- Pro Details (identification_number only) --
            Map<String, Object> proDetails = new Map<String, Object>{
                'identification_number' => acct.CommercialRegisterNumber__c
            };

            // -- New User (email only) --
            Map<String, Object> newUser = new Map<String, Object>{ 'email' => contactEmail };

            // -- Shop (minimal payload) --
            Map<String, Object> shop = new Map<String, Object>{
                'address' => address,
                'new_user' => newUser,
                'pro_details' => proDetails,
                'email' => contactEmail,
                'shop_name' => acct.Name
            };

            // -- Wrap in shops[] array (Mirakl expects this structure) --
            Map<String, Object> bodyMap = new Map<String, Object>{ 'shops' => new List<Object>{ shop } };

            String requestBody = JSON.serialize(bodyMap);

            // ── Step 4: Build Input for LIM_Mirakl_Integration ────────
            LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
            req.httpMethod = 'POST';
            req.relativePath = '/api/shops';
            req.requestBody = requestBody;

            // ── Step 5: Execute Request ────────────────────────────────
            List<LIM_Mirakl_Integration.Output> outputs = LIM_Mirakl_Integration.executeRequests(
                new List<LIM_Mirakl_Integration.Input>{ req }
            );

            LIM_Mirakl_Integration.Output res = outputs[0];

            result.success = res.success;
            result.statusCode = res.statusCode;

            // ── Step 6: Parse Response (Mirakl returns shop_returns[], not shops[]) ──
            if (res.success) {
                Map<String, Object> jsonResult = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody);
                List<Object> shopReturns = (List<Object>) jsonResult.get('shop_returns');
                if (shopReturns != null && !shopReturns.isEmpty()) {
                    Map<String, Object> firstReturn = (Map<String, Object>) shopReturns[0];
                    if (firstReturn.containsKey('shop_error')) {
                        Map<String, Object> shopError = (Map<String, Object>) firstReturn.get('shop_error');
                        result.success = false;
                        List<Object> errors = (List<Object>) shopError.get('errors');
                        if (errors != null && !errors.isEmpty()) {
                            List<String> messages = new List<String>();
                            for (Object err : errors) {
                                Map<String, Object> e = (Map<String, Object>) err;
                                messages.add(String.valueOf(e.get('field')) + ': ' + String.valueOf(e.get('message')));
                            }
                            result.errorMessage = String.join(messages, '; ');
                        } else {
                            result.errorMessage = 'Shop creation failed (see shop_error in response).';
                        }
                    } else if (firstReturn.containsKey('shop_created')) {
                        Map<String, Object> shopCreated = (Map<String, Object>) firstReturn.get('shop_created');
                        if (shopCreated != null && shopCreated.containsKey('shop_id')) {
                            result.merchantId = String.valueOf(shopCreated.get('shop_id'));
                            if (String.isNotBlank(result.merchantId)) {
                                try {
                                    PartnerIntegration__c piUpdate = new PartnerIntegration__c();
                                    piUpdate.Id = partnerIntegrationId;
                                    piUpdate.MerchantId__c = result.merchantId;
                                    update piUpdate;
                                } catch (DmlException dmlEx) {
                                    // Shop created in Mirakl; keep success + merchantId, report update failure (e.g. Flow/validation)
                                    result.errorMessage =
                                        'Shop created (MerchantId ' +
                                        result.merchantId +
                                        ') but PartnerIntegration update failed: ' +
                                        dmlEx.getDmlMessage(0);
                                }
                            }
                        }
                    }
                }
            } else {
                result.errorMessage = res.errorMessage;
            }
        } catch (QueryException ex) {
            result.success = false;
            result.errorMessage = 'Record not found: ' + ex.getMessage();
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = 'Unexpected error: ' + ex.getMessage();
        }

        return result;
    }
}
```

---

## Dependencies

_(Review imports and type references in source above.)_

---
