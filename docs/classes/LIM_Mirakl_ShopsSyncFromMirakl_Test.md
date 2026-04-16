# LIM_Mirakl_ShopsSyncFromMirakl_Test

**Type:** Apex Class | **Status:** Active | **API Version:** 66.0 | **Object/Trigger:** —

---

## Summary

Apex class **`LIM_Mirakl_ShopsSyncFromMirakl_Test`** (`classes/LIM_Mirakl_ShopsSyncFromMirakl_Test.cls`) is compiled and executed on the Salesforce server. It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures).

**Author / description from source comment:** Tests for LIM_Mirakl_ShopsSyncFromMirakl — JSON sync, negative paths, HTTP mock.

---

## Technical Details

### Methods (heuristic)

| Method Name       | Access | Return Type | Description       |
| ----------------- | ------ | ----------- | ----------------- |
| `buildSampleJson` | —      | —           | From source parse |
| `respond`         | —      | —           | From source parse |

### Source

```apex
/**
 * Tests for LIM_Mirakl_ShopsSyncFromMirakl — JSON sync, negative paths, HTTP mock.
 */
@IsTest
private class LIM_Mirakl_ShopsSyncFromMirakl_Test {
    private static String buildSampleJson(Integer shopIdNum) {
        return buildSampleJson(shopIdNum, 1);
    }

    private static String buildSampleJson(Integer shopIdNum, Integer totalCount) {
        return '{' +
            '"total_count":' +
            totalCount +
            ',' +
            '"shops":[' +
            '{' +
            '"shop_id":' +
            shopIdNum +
            ',' +
            '"shop_name":"Test Mirakl Shop",' +
            '"shipping_country":"DEU",' +
            '"contact_informations":{' +
            '"email":"mirakl_sync_test@example.com",' +
            '"firstname":"John",' +
            '"lastname":"Doe",' +
            '"phone":"0301234567",' +
            '"phone_secondary":"01701234567",' +
            '"civility":"Mr",' +
            '"web_site":"https://example.com",' +
            '"street1":"Contact Street 1",' +
            '"zip_code":"10115",' +
            '"city":"Berlin",' +
            '"country":"DEU"' +
            '},' +
            '"default_billing_information":{' +
            '"registration_address":{' +
            '"city":"Berlin",' +
            '"country_iso_code":"DEU",' +
            '"street_1":"Reg Street 1",' +
            '"zip_code":"10115"' +
            '},' +
            '"corporate_information":{' +
            '"company_registration_number":"HRB999001"' +
            '}' +
            '},' +
            '"commission":{"grid_label":"DE 15%"},' +
            '"pro_details":{' +
            '"VAT_number":"DE999001",' +
            '"identification_number":"ID999001"' +
            '}' +
            '}' +
            ']' +
            '}';
    }

    @IsTest
    static void testSyncShopsFromJson_createsAccountAddressContact() {
        String json = buildSampleJson(999001);
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage);
        System.assertEquals(200, out.statusCode);

        Account a = [
            SELECT Id, Name, MerchantId__c, Shopname__c, CommercialRegisterNumber__c, VatIdCompany__c
            FROM Account
            WHERE MerchantId__c = '999001'
            LIMIT 1
        ];
        System.assertEquals('999001', a.MerchantId__c);
        System.assertEquals('Test Mirakl Shop', a.Name);

        Address__c addr = [
            SELECT
                Id,
                AddressType__c,
                Address__Street__s,
                Address__City__s,
                Address__PostalCode__s,
                Address__CountryCode__s
            FROM Address__c
            WHERE Account__c = :a.Id AND AddressType__c = 'Headquarter'
            LIMIT 1
        ];
        System.assertEquals('DE', addr.Address__CountryCode__s);

        Contact c = [
            SELECT Id, FirstName, LastName, Email, RoleMarketplace__c
            FROM Contact
            WHERE AccountId = :a.Id AND RoleMarketplace__c = 'Mirakl Invitation'
            LIMIT 1
        ];
        System.assertEquals('John', c.FirstName);
        System.assertEquals('mirakl_sync_test@example.com', c.Email);
    }

    @IsTest
    static void testSyncShopsFromJson_invalidJson() {
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson('not-json');
        System.assertEquals(false, out.success);
        System.assertNotEquals(null, out.errorMessage);
    }

    @IsTest
    static void testSyncShopsFromJson_missingShops() {
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(
            '{"total_count":0}'
        );
        System.assertEquals(false, out.success);
    }

    @IsTest
    static void testSyncShopsFromJson_emptyShops() {
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(
            '{"shops":[],"total_count":0}'
        );
        System.assertEquals(true, out.success);
    }

    @IsTest
    static void testInvocable_syncShops_emptyInput() {
        List<LIM_Mirakl_ShopsSyncFromMirakl.Output> outs = LIM_Mirakl_ShopsSyncFromMirakl.syncShops(
            new List<LIM_Mirakl_ShopsSyncFromMirakl.Input>()
        );
        System.assertEquals(0, outs.size());
    }

    @IsTest
    static void testSyncShopsFromJson_dryRun_noDml() {
        String json = buildSampleJson(999010);
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json, true);
        System.assertEquals(true, out.success, out.errorMessage);
        System.assert(out.dryRunSummary != null && out.dryRunSummary.contains('dryRun'), out.dryRunSummary);
        Integer n = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999010'];
        System.assertEquals(0, n, 'dryRun must not insert Accounts');
    }

    @IsTest
    static void testInvocable_withJsonBody() {
        LIM_Mirakl_ShopsSyncFromMirakl.Input inVar = new LIM_Mirakl_ShopsSyncFromMirakl.Input();
        inVar.jsonBody = buildSampleJson(999002);
        List<LIM_Mirakl_ShopsSyncFromMirakl.Output> outs = LIM_Mirakl_ShopsSyncFromMirakl.syncShops(
            new List<LIM_Mirakl_ShopsSyncFromMirakl.Input>{ inVar }
        );
        System.assertEquals(1, outs.size());
        System.assertEquals(true, outs[0].success, outs[0].errorMessage);
    }

    private class MiraklGetShopsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(buildSampleJson(999003));
            return res;
        }
    }

    /** First page: one shop (total_count=2); second page (offset=1): second shop — exercises Mirakl max/offset pagination. */
    private class MiraklTwoPageShopsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint();
            if (ep != null && ep.contains('offset=1')) {
                res.setBody(buildSampleJson(999005, 2));
            } else {
                res.setBody(buildSampleJson(999004, 2));
            }
            return res;
        }
    }

    @IsTest
    static void testBuildShopsQueryPath_includesMaxOffsetAndUpdatedSince() {
        Datetime dt = Datetime.newInstanceGmt(2026, 3, 1, 12, 0, 0);
        String path = LIM_Mirakl_ShopsSyncFromMirakl.buildShopsQueryPath(dt, 100, 100);
        System.assert(path.contains('updated_since='), path);
        System.assert(path.contains('max=100'), path);
        System.assert(path.contains('offset=100'), path);
    }

    @IsTest
    static void testSyncShopsFromMirakl_twoPages_mergesAllShops() {
        Test.setMock(HttpCalloutMock.class, new MiraklTwoPageShopsMock());
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromMirakl();
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage);
        System.assert(out.requestJson != null && out.requestJson.contains('pagesFetched'), out.requestJson);
        Map<String, Object> merged = (Map<String, Object>) JSON.deserializeUntyped(out.responseJson);
        List<Object> shops = (List<Object>) merged.get('shops');
        System.assertEquals(2, shops.size(), 'merged payload should contain both pages');
        Integer n4 = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999004'];
        Integer n5 = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999005'];
        System.assertEquals(1, n4);
        System.assertEquals(1, n5);
    }

    @IsTest
    static void testBuildShopsRelativePath_updatedSince_urlEncodesIsoUtc() {
        Datetime dt = Datetime.newInstanceGmt(2026, 2, 19, 0, 0, 0);
        String path = LIM_Mirakl_ShopsSyncFromMirakl.buildShopsRelativePath(dt);
        System.assert(
            path.startsWith(LIM_Mirakl_ShopsSyncFromMirakl.MIRAKL_SHOPS_RELATIVE_PATH + '?updated_since='),
            path
        );
        System.assert(path.contains('2026-02-19T00%3A00%3A00Z'), path);
    }

    @IsTest
    static void testInvocable_passesUpdatedSince() {
        LIM_Mirakl_ShopsSyncFromMirakl.Input inVar = new LIM_Mirakl_ShopsSyncFromMirakl.Input();
        inVar.updatedSince = Datetime.newInstanceGmt(2026, 2, 19, 0, 0, 0);
        Test.setMock(HttpCalloutMock.class, new MiraklGetShopsMock());
        Test.startTest();
        List<LIM_Mirakl_ShopsSyncFromMirakl.Output> outs = LIM_Mirakl_ShopsSyncFromMirakl.syncShops(
            new List<LIM_Mirakl_ShopsSyncFromMirakl.Input>{ inVar }
        );
        Test.stopTest();
        System.assertEquals(1, outs.size());
        System.assert(
            outs[0].requestJson != null && outs[0].requestJson.contains('updatedSinceUtc'),
            outs[0].requestJson
        );
    }

    @IsTest
    static void testSyncShopsFromMirakl_withMock() {
        Test.setMock(HttpCalloutMock.class, new MiraklGetShopsMock());
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromMirakl();
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage);
        System.assertEquals(200, out.statusCode);
        System.assert(out.requestJson != null && out.requestJson.contains('GET'));
        Integer n = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999003'];
        System.assertEquals(1, n);
    }
}
```

---

## Dependencies

_(Review imports and type references in source above.)_

---
