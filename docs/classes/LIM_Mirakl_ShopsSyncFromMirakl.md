# LIM_Mirakl_ShopsSyncFromMirakl

**Type:** Apex Class | **Status:** Active | **API Version:** 66.0 | **Object/Trigger:** —

---

## Summary

Apex class **`LIM_Mirakl_ShopsSyncFromMirakl`** (`classes/LIM_Mirakl_ShopsSyncFromMirakl.cls`) is compiled and executed on the Salesforce server. It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures).

**Author / description from source comment:** LIM_Mirakl_ShopsSyncFromMirakl GET /api/shops (or inline JSON), parse Mirakl shops[], upsert Account (MerchantId**c), Address**c (Headquarter), Contact (Mirakl Invitation). Exposed to Flow via Invocable. Set {@code dryRun=true} on Invocable input to log Mirakl payload and skip all DML (see debug logs).

---

## Technical Details

### Methods (heuristic)

| Method Name              | Access | Return Type | Description       |
| ------------------------ | ------ | ----------- | ----------------- |
| `buildAccountFromShop`   | —      | —           | From source parse |
| `buildAddress`           | —      | —           | From source parse |
| `buildAlpha3ToAlpha2`    | —      | —           | From source parse |
| `buildContact`           | —      | —           | From source parse |
| `buildDryRunSummary`     | —      | —           | From source parse |
| `buildShopsQueryPath`    | —      | —           | From source parse |
| `buildShopsRelativePath` | —      | —           | From source parse |
| `buildSyncAuditJson`     | —      | —           | From source parse |
| `childMap`               | —      | —           | From source parse |
| `collectDmlErrors`       | —      | —           | From source parse |
| `extractMerchantId`      | —      | —           | From source parse |
| `firstNonBlank`          | —      | —           | From source parse |
| `getFromMap`             | —      | —           | From source parse |
| `hasAddressData`         | —      | —           | From source parse |
| `logDryRun`              | —      | —           | From source parse |
| `merchantKey`            | —      | —           | From source parse |
| `parseCommissionPercent` | —      | —           | From source parse |
| `parseTotalCount`        | —      | —           | From source parse |
| `stringVal`              | —      | —           | From source parse |
| `syncShops`              | —      | —           | From source parse |
| `syncShopsFromJson`      | —      | —           | From source parse |
| `syncShopsFromMirakl`    | —      | —           | From source parse |
| `toCommercialCountry`    | —      | —           | From source parse |
| `toCountryCode`          | —      | —           | From source parse |

### Source

```apex
/**
 * LIM_Mirakl_ShopsSyncFromMirakl
 * GET /api/shops (or inline JSON), parse Mirakl shops[], upsert Account (MerchantId__c),
 * Address__c (Headquarter), Contact (Mirakl Invitation). Exposed to Flow via Invocable.
 * Set {@code dryRun=true} on Invocable input to log Mirakl payload and skip all DML (see debug logs).
 */
public with sharing class LIM_Mirakl_ShopsSyncFromMirakl {
    /** Base path only; use {@link #buildShopsRelativePath} for optional {@code updated_since} query. */
    public static final String MIRAKL_SHOPS_RELATIVE_PATH = '/api/shops';

    private static final String QUERY_UPDATED_SINCE = 'updated_since';
    /** Mirakl: optional; default 10, max 100 items per page. */
    private static final String QUERY_MAX = 'max';
    /** Mirakl: index of first item in the full result set. */
    private static final String QUERY_OFFSET = 'offset';

    /** Use Mirakl maximum page size to minimize callouts. */
    public static final Integer SHOPS_PAGE_SIZE_MAX = 100;

    // ISO 3166-1 alpha-2 → alpha-3 (same set as LIM_Mirakl_ShopCreate; used to build reverse map)
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
        'PL' => 'POL',
        'SE' => 'SWE',
        'NO' => 'NOR',
        'DK' => 'DNK',
        'FI' => 'FIN',
        'CZ' => 'CZE',
        'IE' => 'IRL',
        'PT' => 'PRT',
        'LU' => 'LUX'
    };

    private static final Map<String, String> ALPHA3_TO_ALPHA2 = buildAlpha3ToAlpha2();

    private static Map<String, String> buildAlpha3ToAlpha2() {
        Map<String, String> rev = new Map<String, String>();
        for (String a2 : COUNTRY_ALPHA2_TO_ALPHA3.keySet()) {
            String a3 = COUNTRY_ALPHA2_TO_ALPHA3.get(a2);
            if (!rev.containsKey(a3)) {
                rev.put(a3, a2);
            }
        }
        return rev;
    }

    // ── Invocable ─────────────────────────────────────────
    public class Input {
        @InvocableVariable(
            description = 'Optional Mirakl shops JSON root with shops[]. If blank, performs GET /api/shops via LIM_Mirakl_Integration.'
        )
        public String jsonBody;

        @InvocableVariable(
            description = 'Optional UTC instant for Mirakl incremental sync. When set (and jsonBody is blank), GET uses /api/shops?updated_since=<ISO8601 URL-encoded>, e.g. 2026-02-19T00:00:00Z.'
        )
        public Datetime updatedSince;

        @InvocableVariable(
            description = 'If true: callout/JSON is processed and logged (System.debug INFO/DEBUG), but no Account/Address/Contact DML. Use to verify Mirakl data before going live.'
        )
        public Boolean dryRun;
    }

    public class Output {
        @InvocableVariable(description = 'Whether the HTTP call (if any) and DML sync completed without blocking errors')
        public Boolean success;

        @InvocableVariable(description = 'HTTP status code from Mirakl when a callout was made; 200 after successful JSON-only sync')
        public Integer statusCode;

        @InvocableVariable(description = 'Error message when sync fails')
        public String errorMessage;

        @InvocableVariable(description = 'Audit JSON for the request (GET descriptor or supplied jsonBody)')
        public String requestJson;

        @InvocableVariable(description = 'Raw Mirakl response body used for parsing (or same as input when jsonBody was supplied)')
        public String responseJson;

        @InvocableVariable(description = 'When dryRun was true: short summary (counts); null otherwise')
        public String dryRunSummary;
    }

    @InvocableMethod(
        description = 'Syncs Mirakl shops into Salesforce (Account, Address, Contact) and returns audit fields for Job__c.'
    )
    public static List<Output> syncShops(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }
        for (Input inVar : inputs) {
            Boolean dry = inVar.dryRun == true;
            if (String.isBlank(inVar.jsonBody)) {
                results.add(syncShopsFromMirakl(inVar.updatedSince, dry));
            } else {
                results.add(syncShopsFromJson(inVar.jsonBody, dry));
            }
        }
        return results;
    }

    /** GET /api/shops (no {@code updated_since}) then sync. */
    public static Output syncShopsFromMirakl() {
        return syncShopsFromMirakl(null, false);
    }

    /**
     * GET /api/shops, optionally {@code ?updated_since=<ISO8601>} (URL-encoded), then sync.
     * Example path: {@code /api/shops?updated_since=2026-02-19T00%3A00%3A00Z}
     */
    public static Output syncShopsFromMirakl(Datetime updatedSince) {
        return syncShopsFromMirakl(updatedSince, false);
    }

    /**
     * GET /api/shops (with optional {@code updated_since}). Fetches all pages using Mirakl {@code max}/{@code offset}
     * pagination, merges {@code shops[]}, then syncs. If {@code dryRun} is true, merged payload is logged and no DML runs.
     */
    public static Output syncShopsFromMirakl(Datetime updatedSince, Boolean dryRun) {
        Output out = new Output();
        Integer pageSize = SHOPS_PAGE_SIZE_MAX;
        Integer offset = 0;
        List<Object> allShops = new List<Object>();
        Integer totalCountFromApi = null;
        Integer pagesFetched = 0;
        Integer lastHttpStatus = null;
        String lastError = null;

        while (offset < 200000 && pagesFetched < 1000) {
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                out.success = false;
                out.errorMessage = 'Callout limit reached while paging Mirakl /api/shops (fetched ' + pagesFetched + ' page(s)).';
                out.statusCode = lastHttpStatus != null ? lastHttpStatus : 500;
                return out;
            }

            String relativePath = buildShopsQueryPath(updatedSince, offset, pageSize);
            LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
            req.httpMethod = 'GET';
            req.relativePath = relativePath;

            List<LIM_Mirakl_Integration.Output> responses = LIM_Mirakl_Integration.executeRequests(
                new List<LIM_Mirakl_Integration.Input>{ req }
            );
            LIM_Mirakl_Integration.Output res = responses[0];
            lastHttpStatus = res.statusCode;
            pagesFetched++;

            if (!res.success) {
                out.success = false;
                out.errorMessage = res.errorMessage;
                out.statusCode = res.statusCode;
                out.requestJson = buildSyncAuditJson(updatedSince, pagesFetched, offset, pageSize, allShops.size(), relativePath);
                return out;
            }

            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody);
            List<Object> pageShops = (List<Object>) root.get('shops');
            if (totalCountFromApi == null && root.containsKey('total_count')) {
                totalCountFromApi = parseTotalCount(root.get('total_count'));
            }

            if (pageShops != null && !pageShops.isEmpty()) {
                allShops.addAll(pageShops);
            }

            Boolean gotFullPage = pageShops != null && pageShops.size() == pageSize;
            Boolean moreByTotal =
                totalCountFromApi != null &&
                allShops.size() < totalCountFromApi &&
                pageShops != null &&
                !pageShops.isEmpty();

            if (!gotFullPage && !moreByTotal) {
                break;
            }
            if (pageShops == null || pageShops.isEmpty()) {
                break;
            }

            offset += pageShops.size();
        }

        Map<String, Object> mergedRoot = new Map<String, Object>();
        mergedRoot.put('shops', allShops);
        mergedRoot.put(
            'total_count',
            totalCountFromApi != null ? totalCountFromApi : allShops.size()
        );

        String mergedJson = JSON.serialize(mergedRoot);
        out.statusCode = lastHttpStatus != null ? lastHttpStatus : 200;
        out.responseJson = mergedJson;
        out.requestJson = buildSyncAuditJson(
            updatedSince,
            pagesFetched,
            offset,
            pageSize,
            allShops.size(),
            'merged ' + pagesFetched + ' page(s); see pagination in Mirakl docs (max/offset)'
        );

        return syncShopsFromJson(mergedJson, out, dryRun == true);
    }

    private static Integer parseTotalCount(Object raw) {
        if (raw == null) {
            return null;
        }
        if (raw instanceof Integer) {
            return (Integer) raw;
        }
        if (raw instanceof Long) {
            return ((Long) raw).intValue();
        }
        if (raw instanceof Decimal) {
            return ((Decimal) raw).intValue();
        }
        try {
            return Integer.valueOf(String.valueOf(raw));
        } catch (Exception e) {
            return null;
        }
    }

    private static String buildSyncAuditJson(
        Datetime updatedSinceUtc,
        Integer pagesFetched,
        Integer lastOffset,
        Integer pageSize,
        Integer mergedShopCount,
        String pathNote
    ) {
        return JSON.serialize(
            new Map<String, Object>{
                'httpMethod' => 'GET',
                'miraklPagination' => new Map<String, Object>{
                    'maxPerPage' => pageSize,
                    'pagesFetched' => pagesFetched,
                    'lastOffset' => lastOffset,
                    'mergedShopsCount' => mergedShopCount
                },
                'updatedSinceUtc' => updatedSinceUtc,
                'note' => pathNote
            }
        );
    }

    /**
     * Mirakl offset pagination: {@code max} (default 10, max 100) and {@code offset} (index of first item).
     * See Mirakl REST general documentation (pagination).
     */
    public static String buildShopsQueryPath(Datetime updatedSinceUtc, Integer offset, Integer max) {
        List<String> pairs = new List<String>();
        if (updatedSinceUtc != null) {
            String isoUtc = updatedSinceUtc.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            pairs.add(
                QUERY_UPDATED_SINCE + '=' + EncodingUtil.urlEncode(isoUtc, 'UTF-8')
            );
        }
        Integer m = max != null && max > 0 ? max : SHOPS_PAGE_SIZE_MAX;
        if (m > 100) {
            m = 100;
        }
        pairs.add(QUERY_MAX + '=' + String.valueOf(m));
        Integer off = offset != null && offset >= 0 ? offset : 0;
        pairs.add(QUERY_OFFSET + '=' + String.valueOf(off));
        return MIRAKL_SHOPS_RELATIVE_PATH + '?' + String.join(pairs, '&');
    }

    /**
     * Builds relative path for Mirakl GET shops without pagination params (single request), e.g. {@code /api/shops} or
     * {@code /api/shops?updated_since=...}. Full sync uses {@link #buildShopsQueryPath} with {@code max}/{@code offset}.
     */
    public static String buildShopsRelativePath(Datetime updatedSinceUtc) {
        if (updatedSinceUtc == null) {
            return MIRAKL_SHOPS_RELATIVE_PATH;
        }
        String isoUtc = updatedSinceUtc.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        return MIRAKL_SHOPS_RELATIVE_PATH +
            '?' +
            QUERY_UPDATED_SINCE +
            '=' +
            EncodingUtil.urlEncode(isoUtc, 'UTF-8');
    }

    /** Parse JSON and sync (no callout). */
    public static Output syncShopsFromJson(String jsonBody) {
        return syncShopsFromJson(jsonBody, false);
    }

    /** Parse JSON and sync; {@code dryRun=true} logs payload and skips DML. */
    public static Output syncShopsFromJson(String jsonBody, Boolean dryRun) {
        Output out = new Output();
        out.requestJson = jsonBody;
        out.responseJson = jsonBody;
        out.statusCode = 200;
        return syncShopsFromJson(jsonBody, out, dryRun == true);
    }

    private static Output syncShopsFromJson(String jsonBody, Output out, Boolean dryRun) {
        try {
            if (String.isBlank(jsonBody)) {
                out.success = false;
                out.errorMessage = 'JSON body is empty.';
                out.statusCode = out.statusCode != null ? out.statusCode : 400;
                return out;
            }

            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            List<Object> shopsRaw = (List<Object>) root.get('shops');

            if (shopsRaw == null) {
                out.success = false;
                out.errorMessage = 'Missing "shops" array in JSON.';
                return out;
            }

            if (shopsRaw.isEmpty()) {
                out.success = true;
                if (dryRun) {
                    logDryRun(jsonBody, root, shopsRaw);
                    out.dryRunSummary = buildDryRunSummary(root, shopsRaw);
                    out.errorMessage = out.dryRunSummary;
                } else {
                    out.errorMessage = null;
                }
                return out;
            }

            if (dryRun) {
                logDryRun(jsonBody, root, shopsRaw);
                out.success = true;
                out.dryRunSummary = buildDryRunSummary(root, shopsRaw);
                out.errorMessage = out.dryRunSummary;
                return out;
            }

            List<Account> accounts = new List<Account>();
            List<Map<String, Object>> shopMaps = new List<Map<String, Object>>();

            for (Object o : shopsRaw) {
                Map<String, Object> shop = (Map<String, Object>) o;
                String merchantKey = extractMerchantId(shop);
                if (String.isBlank(merchantKey)) {
                    continue;
                }
                shopMaps.add(shop);
                accounts.add(buildAccountFromShop(shop, merchantKey));
            }

            if (accounts.isEmpty()) {
                out.success = false;
                out.errorMessage = 'No valid shop_id in shops payload.';
                return out;
            }

            Database.UpsertResult[] accResults = Database.upsert(accounts, Account.MerchantId__c, false);
            List<String> errors = new List<String>();
            Map<String, Id> merchantToAccountId = new Map<String, Id>();

            for (Integer i = 0; i < accResults.size(); i++) {
                if (!accResults[i].isSuccess()) {
                    for (Database.Error err : accResults[i].getErrors()) {
                        errors.add('Account ' + merchantKey(i, accounts) + ': ' + err.getMessage());
                    }
                }

… *(13739 more characters omitted)*
```

---

## Dependencies

_(Review imports and type references in source above.)_

---
