/**
 * LIM_Mirakl_ShopsSyncFromMirakl
 * GET /api/shops (or inline JSON), parse Mirakl shops[], **update** existing Account by MerchantId__c
 * (no Account insert). Address__c (Headquarter), Contact (Mirakl Invitation) for matched Accounts only.
 * Exposed to Flow via Invocable.
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

    private static final Map<String, String> CHANNEL_CODE_TO_SALESCHANNEL = new Map<String, String>{
        'DE' => 'Germany',
        'AT' => 'Austria',
        'PL' => 'Poland'
    };

    /** Maps ISO 2-letter country codes to the API names of the CommercialCountry restricted picklist. */
    private static final Map<String, String> ISO2_TO_COMMERCIAL_COUNTRY = new Map<String, String>{
        'AT' => 'Austria',
        'BE' => 'Belgium',
        'BG' => 'Bulgaria',
        'HR' => 'Croatia',
        'CY' => 'Cyprus',
        'CZ' => 'Czech-Republic',
        'DK' => 'Denmark',
        'EE' => 'Estonia',
        'FI' => 'Finland',
        'FR' => 'France',
        'DE' => 'Germany',
        'GR' => 'Greece',
        'HU' => 'Hungary',
        'IE' => 'Ireland',
        'IT' => 'Italy',
        'LV' => 'Latvia',
        'LT' => 'Lithuania',
        'LU' => 'Luxembourg',
        'MT' => 'Malta',
        'NL' => 'Netherlands',
        'NO' => 'Norway',
        'PL' => 'Poland',
        'PT' => 'Portugal',
        'RO' => 'Romania',
        'SK' => 'Slovakia',
        'SI' => 'Slovenia',
        'ES' => 'Spain',
        'SE' => 'Sweden',
        'GB' => 'United Kingdom',
        'UK' => 'United Kingdom'
    };

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

        @InvocableVariable(
            description = 'Human-readable sync outcome: counts updated vs skipped (no Account in Salesforce for merchant id). Not an error.'
        )
        public String summaryMessage;
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
            if (String.isBlank(inVar.jsonBody)) {
                results.add(syncShopsFromMirakl(inVar.updatedSince));
            } else {
                results.add(syncShopsFromJson(inVar.jsonBody));
            }
        }
        return results;
    }

    /** GET /api/shops (no {@code updated_since}) then sync. */
    public static Output syncShopsFromMirakl() {
        return syncShopsFromMirakl(null);
    }

    /**
     * GET /api/shops, optionally {@code ?updated_since=<ISO8601>} (URL-encoded), then sync.
     * Example path: {@code /api/shops?updated_since=2026-02-19T00%3A00%3A00Z}
     */
    /**
     * GET /api/shops (optional {@code updated_since}). Pages with {@code max}/{@code offset}, merges {@code shops[]}, then syncs.
     */
    public static Output syncShopsFromMirakl(Datetime updatedSince) {
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

        return syncShopsFromJson(mergedJson, out);
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
        Output out = new Output();
        out.requestJson = jsonBody;
        out.responseJson = jsonBody;
        out.statusCode = 200;
        return syncShopsFromJson(jsonBody, out);
    }

    private static Output syncShopsFromJson(String jsonBody, Output out) {
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
                out.errorMessage = null;
                out.summaryMessage = 'No shops in payload.';
                return out;
            }

            List<Map<String, Object>> shopMaps = new List<Map<String, Object>>();
            Set<String> merchantKeys = new Set<String>();

            for (Object o : shopsRaw) {
                Map<String, Object> shop = (Map<String, Object>) o;
                String merchantKey = extractMerchantId(shop);
                if (String.isBlank(merchantKey)) {
                    continue;
                }
                shopMaps.add(shop);
                merchantKeys.add(merchantKey);
            }

            if (shopMaps.isEmpty()) {
                out.success = false;
                out.errorMessage = 'No valid shop_id in shops payload.';
                return out;
            }

            // ── Collect assignee emails from all shops ────────────────
            Set<String> allAssigneeEmails = new Set<String>();
            Map<String, Map<String, String>> assigneeEmailByRoleByMerchant = new Map<String, Map<String, String>>();
            for (Map<String, Object> shop : shopMaps) {
                String mk = extractMerchantId(shop);
                List<Object> assignees = (List<Object>) shop.get('assignees');
                Map<String, String> roleToEmail = new Map<String, String>();
                if (assignees != null) {
                    for (Object asgn : assignees) {
                        Map<String, Object> aMap = (Map<String, Object>) asgn;
                        String role = stringVal(aMap.get('role'));
                        String email = stringVal(aMap.get('email'));
                        if (String.isNotBlank(role) && String.isNotBlank(email)) {
                            roleToEmail.put(role, email);
                            allAssigneeEmails.add(email.toLowerCase());
                        }
                    }
                }
                assigneeEmailByRoleByMerchant.put(mk, roleToEmail);
            }

            // ── Bulk query Users by email ──────────────────────────────
            Map<String, Id> userIdByEmail = new Map<String, Id>();
            if (!allAssigneeEmails.isEmpty()) {
                for (User u : [
                    SELECT Id, Email
                    FROM User
                    WHERE Email IN :allAssigneeEmails
                    AND IsActive = true
                ]) {
                    userIdByEmail.put(u.Email.toLowerCase(), u.Id);
                }
            }

            Map<String, Id> existingAccountIdByMerchant = new Map<String, Id>();
            for (Account acc : [
                SELECT Id, MerchantId__c
                FROM Account
                WHERE MerchantId__c IN :merchantKeys
            ]) {
                existingAccountIdByMerchant.put(acc.MerchantId__c, acc.Id);
            }

            List<String> skippedNoAccount = new List<String>();
            for (String mk : merchantKeys) {
                if (!existingAccountIdByMerchant.containsKey(mk)) {
                    skippedNoAccount.add(mk);
                }
            }

            Map<String, Account> accountUpdateByMerchant = new Map<String, Account>();
            for (Map<String, Object> shop : shopMaps) {
                String merchantKey = extractMerchantId(shop);
                if (String.isBlank(merchantKey) || !existingAccountIdByMerchant.containsKey(merchantKey)) {
                    continue;
                }
                Account a = buildAccountFromShop(shop, merchantKey);
                a.Id = existingAccountIdByMerchant.get(merchantKey);
                Map<String, String> roles = assigneeEmailByRoleByMerchant.get(merchantKey);
                if (roles != null) {
                    String amEmail = roles.get('ACCOUNT_MANAGER');
                    if (String.isNotBlank(amEmail) && userIdByEmail.containsKey(amEmail.toLowerCase())) {
                        a.AccountManager__c = userIdByEmail.get(amEmail.toLowerCase());
                    }
                    String ssEmail = roles.get('SUPPORT_SPECIALIST');
                    if (String.isNotBlank(ssEmail) && userIdByEmail.containsKey(ssEmail.toLowerCase())) {
                        a.TechSupportManager__c = userIdByEmail.get(ssEmail.toLowerCase());
                    }
                }
                accountUpdateByMerchant.put(merchantKey, a);
            }
            List<Account> accountsToUpdate = accountUpdateByMerchant.values();

            List<String> errors = new List<String>();
            Map<String, Id> merchantToAccountId = new Map<String, Id>();

            if (!accountsToUpdate.isEmpty()) {
                Database.SaveResult[] accResults = Database.update(accountsToUpdate, false);
                for (Integer i = 0; i < accResults.size(); i++) {
                    if (!accResults[i].isSuccess()) {
                        for (Database.Error err : accResults[i].getErrors()) {
                            errors.add('Account ' + merchantKey(i, accountsToUpdate) + ': ' + err.getMessage());
                        }
                    } else {
                        merchantToAccountId.put(
                            accountsToUpdate[i].MerchantId__c,
                            accountsToUpdate[i].Id
                        );
                    }
                }
            }

            skippedNoAccount.sort();
            out.summaryMessage = buildSyncSummaryMessage(merchantToAccountId.size(), skippedNoAccount);

            if (merchantToAccountId.isEmpty()) {
                out.success = errors.isEmpty();
                out.errorMessage = errors.isEmpty() ? null : String.join(errors, '; ');
                return out;
            }

            Set<Id> accountIds = new Set<Id>(merchantToAccountId.values());

            Map<Id, Id> hqAddressByAccount = new Map<Id, Id>();
            for (Address__c addr : [
                SELECT Id, Account__c
                FROM Address__c
                WHERE Account__c IN :accountIds AND AddressType__c = :ADDRESS_TYPE_HQ
            ]) {
                hqAddressByAccount.put(addr.Account__c, addr.Id);
            }

            Map<Id, Contact> miraklContactByAccount = new Map<Id, Contact>();
            for (Contact c : [
                SELECT Id, AccountId, RoleMarketplace__c
                FROM Contact
                WHERE AccountId IN :accountIds AND RoleMarketplace__c INCLUDES (:ROLE_MIRAKL_INVITATION)
            ]) {
                miraklContactByAccount.put(c.AccountId, c);
            }

            List<Address__c> addressUpsert = new List<Address__c>();
            List<Contact> contactUpsert = new List<Contact>();

            for (Map<String, Object> shop : shopMaps) {
                String merchantKey = extractMerchantId(shop);
                if (!merchantToAccountId.containsKey(merchantKey)) {
                    continue;
                }
                Id accountId = merchantToAccountId.get(merchantKey);

                Address__c addr = buildAddress(shop, accountId);
                if (addr != null) {
                    if (hqAddressByAccount.containsKey(accountId)) {
                        addr.Id = hqAddressByAccount.get(accountId);
                    }
                    addressUpsert.add(addr);
                }

                Contact existingContact = miraklContactByAccount.get(accountId);
                Contact ct = buildContact(shop, accountId, existingContact);
                if (existingContact != null) {
                    ct.Id = existingContact.Id;
                }
                contactUpsert.add(ct);
            }

            if (!addressUpsert.isEmpty()) {
                Database.UpsertResult[] ar = Database.upsert(addressUpsert, false);
                collectDmlErrors(ar, errors, 'Address__c');
            }
            if (!contactUpsert.isEmpty()) {
                Database.UpsertResult[] cr = Database.upsert(contactUpsert, false);
                collectDmlErrors(cr, errors, 'Contact');
            }

            // ── Update PartnerIntegration__c.OwnerId from ONBOARDING_MANAGER ──
            Map<Id, PartnerIntegration__c> latestPiByAccount = new Map<Id, PartnerIntegration__c>();
            for (PartnerIntegration__c pi : [
                SELECT Id, CompanyName__c, OwnerId
                FROM PartnerIntegration__c
                WHERE CompanyName__c IN :accountIds
                ORDER BY CreatedDate DESC
            ]) {
                if (!latestPiByAccount.containsKey(pi.CompanyName__c)) {
                    latestPiByAccount.put(pi.CompanyName__c, pi);
                }
            }

            List<PartnerIntegration__c> piToUpdate = new List<PartnerIntegration__c>();
            for (String mk : merchantToAccountId.keySet()) {
                Id accId = merchantToAccountId.get(mk);
                Map<String, String> piRoles = assigneeEmailByRoleByMerchant.get(mk);
                if (piRoles == null) continue;
                String omEmail = piRoles.get('ONBOARDING_MANAGER');
                if (String.isBlank(omEmail)) continue;
                Id omUserId = userIdByEmail.get(omEmail.toLowerCase());
                if (omUserId == null) continue;
                PartnerIntegration__c pi = latestPiByAccount.get(accId);
                if (pi != null) {
                    pi.OwnerId = omUserId;
                    piToUpdate.add(pi);
                }
            }
            if (!piToUpdate.isEmpty()) {
                Database.SaveResult[] piResults = Database.update(piToUpdate, false);
                collectSaveErrors(piResults, errors, 'PartnerIntegration__c');
            }

            out.success = errors.isEmpty();
            out.errorMessage = errors.isEmpty() ? null : String.join(errors, '; ');
            return out;
        } catch (Exception ex) {
            out.success = false;
            out.errorMessage = ex.getMessage();
            out.statusCode = out.statusCode != null ? out.statusCode : 500;
            return out;
        }
    }

    private static String buildSyncSummaryMessage(Integer accountsUpdatedOk, List<String> skippedMerchantIds) {
        String msg =
            'Accounts updated successfully: ' +
            accountsUpdatedOk +
            '. ';
        if (skippedMerchantIds == null || skippedMerchantIds.isEmpty()) {
            msg += 'No merchants skipped (each had an Account with matching MerchantId__c).';
        } else {
            msg +=
                'Skipped ' +
                skippedMerchantIds.size() +
                ' merchant(s) (no Account in Salesforce): ' +
                String.join(skippedMerchantIds, ', ') +
                '.';
        }
        return msg;
    }

    private static void collectDmlErrors(
        Database.UpsertResult[] results,
        List<String> errors,
        String entity
    ) {
        for (Database.UpsertResult ur : results) {
            if (!ur.isSuccess()) {
                for (Database.Error err : ur.getErrors()) {
                    errors.add(entity + ': ' + err.getMessage());
                }
            }
        }
    }

    private static void collectSaveErrors(
        Database.SaveResult[] results,
        List<String> errors,
        String entity
    ) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    errors.add(entity + ': ' + err.getMessage());
                }
            }
        }
    }

    private static String merchantKey(Integer i, List<Account> accounts) {
        return accounts[i].MerchantId__c;
    }

    private static final String ROLE_MIRAKL_INVITATION = 'Mirakl Invitation';
    private static final String ADDRESS_TYPE_HQ = 'Headquarter';

    private static String extractMerchantId(Map<String, Object> shop) {
        Object sid = shop.get('shop_id');
        if (sid == null) {
            return null;
        }
        return String.valueOf(sid);
    }

    private static Account buildAccountFromShop(Map<String, Object> shop, String merchantKey) {
        Account a = new Account();
        a.MerchantId__c = merchantKey;

        String shopName = stringVal(shop.get('shop_name'));
        a.Shopname__c = shopName;

        List<Object> channelCodes = (List<Object>) shop.get('channels');
        if (channelCodes != null && !channelCodes.isEmpty()) {
            String code = String.valueOf(channelCodes[0]).toUpperCase();
            if (CHANNEL_CODE_TO_SALESCHANNEL.containsKey(code)) {
                a.SalesChannel__c = CHANNEL_CODE_TO_SALESCHANNEL.get(code);
            }
        }

        Map<String, Object> contactInfo = childMap(shop, 'contact_informations');
        if (contactInfo != null) {
            a.Website = stringVal(contactInfo.get('web_site'));
            String countrySrc = firstNonBlank(
                stringVal(contactInfo.get('country')),
                stringVal(shop.get('shipping_country'))
            );
            a.CommercialCountry__c = toCommercialCountry(countrySrc);
        } else {
            a.CommercialCountry__c = toCommercialCountry(stringVal(shop.get('shipping_country')));
        }

        Map<String, Object> commission = childMap(shop, 'commission');
        if (commission != null) {
            String gridLabel = stringVal(commission.get('grid_label'));
            Decimal pct = parseCommissionPercent(gridLabel);
            if (pct != null) {
                a.Commission__c = pct / 100;
            }
        }

        Map<String, Object> proDetails = childMap(shop, 'pro_details');
        Map<String, Object> defaultBilling = childMap(shop, 'default_billing_information');
        Map<String, Object> corp = defaultBilling != null
            ? childMap(defaultBilling, 'corporate_information')
            : null;

        String regNum = corp != null ? stringVal(corp.get('company_registration_number')) : null;
        String idNum = proDetails != null ? stringVal(proDetails.get('identification_number')) : null;
        a.CommercialRegisterNumber__c = firstNonBlank(regNum, idNum);

        if (proDetails != null) {
            a.VatIdCompany__c = firstNonBlank(
                stringVal(proDetails.get('VAT_number')),
                stringVal(proDetails.get('tax_identification_number'))
            );
            String lucid = stringVal(proDetails.get('lucid_number'));
            if (String.isNotBlank(lucid)) {
                a.LucidNumber__c = lucid;
            }
            String weee = stringVal(proDetails.get('weee_registration_number'));
            if (String.isNotBlank(weee)) {
                a.WeeeRegistrationNumber__c = weee;
            }
        }

        return a;
    }

    private static Address__c buildAddress(Map<String, Object> shop, Id accountId) {
        Map<String, Object> defaultBilling = childMap(shop, 'default_billing_information');
        Map<String, Object> regAddr = defaultBilling != null
            ? childMap(defaultBilling, 'registration_address')
            : null;
        Map<String, Object> contactInfo = childMap(shop, 'contact_informations');

        Map<String, Object> src = regAddr;
        if (!hasAddressData(regAddr)) {
            src = contactInfo;
        }
        if (!hasAddressData(src)) {
            return null;
        }

        Address__c addr = new Address__c();
        addr.Account__c = accountId;
        addr.AddressType__c = ADDRESS_TYPE_HQ;

        String street = firstNonBlank(
            stringVal(getFromMap(src, 'street1')),
            stringVal(getFromMap(src, 'street_1'))
        );
        String street2 = firstNonBlank(
            stringVal(getFromMap(src, 'street2')),
            stringVal(getFromMap(src, 'street_2'))
        );
        if (String.isNotBlank(street2)) {
            street = (street != null ? street + '\n' : '') + street2;
        }
        addr.Address__Street__s = street;
        addr.Address__PostalCode__s = stringVal(getFromMap(src, 'zip_code'));
        addr.Address__City__s = stringVal(getFromMap(src, 'city'));

        String countryIso = firstNonBlank(
            stringVal(getFromMap(src, 'country_iso_code')),
            stringVal(getFromMap(src, 'country'))
        );
        addr.Address__CountryCode__s = toCountryCode(countryIso);

        return addr;
    }

    private static Boolean hasAddressData(Map<String, Object> m) {
        if (m == null) {
            return false;
        }
        return String.isNotBlank(stringVal(getFromMap(m, 'street1'))) ||
            String.isNotBlank(stringVal(getFromMap(m, 'street_1'))) ||
            String.isNotBlank(stringVal(getFromMap(m, 'city'))) ||
            String.isNotBlank(stringVal(getFromMap(m, 'zip_code')));
    }

    private static Contact buildContact(Map<String, Object> shop, Id accountId, Contact existing) {
        Map<String, Object> contactInfo = childMap(shop, 'contact_informations');
        Contact c = new Contact();
        c.AccountId = accountId;
        c.RoleMarketplace__c = mergeRoleMarketplace(
            existing != null ? existing.RoleMarketplace__c : null,
            ROLE_MIRAKL_INVITATION
        );

        if (contactInfo != null) {
            c.FirstName = stringVal(contactInfo.get('firstname'));
            c.LastName = firstNonBlank(stringVal(contactInfo.get('lastname')), 'Unknown');
            c.Email = stringVal(contactInfo.get('email'));
            c.Phone = stringVal(contactInfo.get('phone'));
            c.MobilePhone = stringVal(contactInfo.get('phone_secondary'));
            String civ = stringVal(contactInfo.get('civility'));
            c.Title = civ;
            c.Salutation = toSalesforceSalutation(civ);
        } else {
            c.LastName = 'Unknown';
        }

        return c;
    }

    /**
     * Merges a required role value into an existing multiselect picklist string.
     * Preserves other role tokens so upsert does not wipe combined roles.
     */
    private static String mergeRoleMarketplace(String existing, String requiredRole) {
        if (String.isBlank(existing)) {
            return requiredRole;
        }
        Set<String> roles = new Set<String>(existing.split(';'));
        roles.add(requiredRole);
        List<String> sorted = new List<String>(roles);
        sorted.sort();
        return String.join(sorted, ';');
    }

    private static Map<String, Object> childMap(Map<String, Object> parent, String key) {
        if (parent == null || !parent.containsKey(key)) {
            return null;
        }
        Object o = parent.get(key);
        if (o instanceof Map<String, Object>) {
            return (Map<String, Object>) o;
        }
        return null;
    }

    private static Object getFromMap(Map<String, Object> m, String key) {
        return m != null ? m.get(key) : null;
    }

    private static String stringVal(Object o) {
        if (o == null) {
            return null;
        }
        String s = String.valueOf(o);
        return String.isBlank(s) || s.equalsIgnoreCase('null') ? null : s;
    }

    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }

    private static String toCountryCode(String miraklCountry) {
        if (String.isBlank(miraklCountry)) {
            return null;
        }
        String t = miraklCountry.trim().toUpperCase();
        if (t.length() == 2) {
            return t;
        }
        if (ALPHA3_TO_ALPHA2.containsKey(t)) {
            return ALPHA3_TO_ALPHA2.get(t);
        }
        return null;
    }

    private static String toCommercialCountry(String miraklCountry) {
        String iso2 = toCountryCode(miraklCountry);
        if (iso2 == null) return null;
        return ISO2_TO_COMMERCIAL_COUNTRY.get(iso2);
    }

    private static String toSalesforceSalutation(String miraklCivility) {
        if (String.isBlank(miraklCivility)) return null;
        String t = miraklCivility.trim();
        if (t.equalsIgnoreCase('Mr'))   return 'Mr.';
        if (t.equalsIgnoreCase('Mrs'))  return 'Mrs.';
        if (t.equalsIgnoreCase('Miss')) return 'Ms.';
        return null;
    }

    private static Decimal parseCommissionPercent(String gridLabel) {
        if (String.isBlank(gridLabel)) {
            return null;
        }
        Matcher m = Pattern.compile('(\\d+(?:\\.\\d+)?)').matcher(gridLabel);
        if (m.find()) {
            return Decimal.valueOf(m.group(1));
        }
        return null;
    }
}
