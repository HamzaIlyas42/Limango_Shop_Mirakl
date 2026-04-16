/**
 * Tests for LIM_Mirakl_ShopsSyncFromMirakl — JSON sync, negative paths, HTTP mock.
 */
@IsTest
private class LIM_Mirakl_ShopsSyncFromMirakl_Test {
    private static String shopObjectJson(Integer shopIdNum) {
        return '{' +
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
            '}';
    }

    private static String buildSampleJson(Integer shopIdNum) {
        return buildSampleJson(shopIdNum, 1);
    }

    private static String buildSampleJson(Integer shopIdNum, Integer totalCount) {
        return '{' + '"total_count":' + totalCount + ',' + '"shops":[' + shopObjectJson(shopIdNum) + ']' + '}';
    }

    private static Account insertStubAccount(String merchantId) {
        Account a = new Account(Name = 'Stub ' + merchantId, MerchantId__c = merchantId);
        insert a;
        return a;
    }

    @IsTest
    static void testSyncShopsFromJson_createsAccountAddressContact() {
        insertStubAccount('999001');
        String json = buildSampleJson(999001);
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');
        System.assertEquals(200, out.statusCode);

        Account a = [
            SELECT Id, Name, MerchantId__c, Shopname__c, CommercialRegisterNumber__c, VatIdCompany__c
            FROM Account
            WHERE MerchantId__c = '999001'
            LIMIT 1
        ];
        System.assertEquals('999001', a.MerchantId__c);
        System.assertEquals('Stub 999001', a.Name, 'Account.Name must not be overwritten by sync');
        System.assertEquals('Test Mirakl Shop', a.Shopname__c, 'Shopname__c should be updated from Mirakl shop_name');

        Address__c addr = [
            SELECT Id, AddressType__c, Address__Street__s, Address__City__s, Address__PostalCode__s, Address__CountryCode__s
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
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson('{"total_count":0}');
        System.assertEquals(false, out.success);
    }

    @IsTest
    static void testSyncShopsFromJson_emptyShops() {
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(
            '{"shops":[],"total_count":0}'
        );
        System.assertEquals(true, out.success);
        System.assert(out.summaryMessage != null && out.summaryMessage.contains('No shops'), out.summaryMessage);
    }

    @IsTest
    static void testInvocable_syncShops_emptyInput() {
        List<LIM_Mirakl_ShopsSyncFromMirakl.Output> outs = LIM_Mirakl_ShopsSyncFromMirakl.syncShops(
            new List<LIM_Mirakl_ShopsSyncFromMirakl.Input>()
        );
        System.assertEquals(0, outs.size());
    }

    @IsTest
    static void testSyncShopsFromJson_skipsWhenNoAccount() {
        String json = buildSampleJson(999010);
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        System.assert(out.success, out.errorMessage != null ? out.errorMessage : '');
        System.assert(
            out.summaryMessage != null && out.summaryMessage.contains('999010'),
            out.summaryMessage
        );
        System.assert(
            out.summaryMessage != null && out.summaryMessage.contains('no Account in Salesforce'),
            out.summaryMessage
        );
        Integer n = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999010'];
        System.assertEquals(0, n, 'must not insert Account when none exists');
    }

    @IsTest
    static void testSyncShopsFromJson_partialSkip() {
        insertStubAccount('999020');
        String json = '{"total_count":2,"shops":[' + shopObjectJson(999020) + ',' + shopObjectJson(999021) + ']}';
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');
        System.assert(out.summaryMessage != null && out.summaryMessage.contains('999021'), out.summaryMessage);
        Account acc = [SELECT Id, Name, Shopname__c FROM Account WHERE MerchantId__c = '999020' LIMIT 1];
        System.assertEquals('Stub 999020', acc.Name, 'Account.Name must not be overwritten by sync');
        System.assertEquals('Test Mirakl Shop', acc.Shopname__c, 'Shopname__c should be updated from Mirakl shop_name');
        Integer nSkip = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999021'];
        System.assertEquals(0, nSkip);
    }

    @IsTest
    static void testInvocable_withJsonBody() {
        insertStubAccount('999002');
        LIM_Mirakl_ShopsSyncFromMirakl.Input inVar = new LIM_Mirakl_ShopsSyncFromMirakl.Input();
        inVar.jsonBody = buildSampleJson(999002);
        List<LIM_Mirakl_ShopsSyncFromMirakl.Output> outs = LIM_Mirakl_ShopsSyncFromMirakl.syncShops(
            new List<LIM_Mirakl_ShopsSyncFromMirakl.Input>{ inVar }
        );
        System.assertEquals(1, outs.size());
        System.assertEquals(true, outs[0].success, outs[0].errorMessage != null ? outs[0].errorMessage : '');
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
        insertStubAccount('999004');
        insertStubAccount('999005');
        Test.setMock(HttpCalloutMock.class, new MiraklTwoPageShopsMock());
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromMirakl();
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');
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
        insertStubAccount('999003');
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
        insertStubAccount('999003');
        Test.setMock(HttpCalloutMock.class, new MiraklGetShopsMock());
        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromMirakl();
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');
        System.assertEquals(200, out.statusCode);
        System.assert(out.requestJson != null && out.requestJson.contains('GET'));
        Integer n = [SELECT COUNT() FROM Account WHERE MerchantId__c = '999003'];
        System.assertEquals(1, n);
    }

    // ── Helpers for extended field tests ────────────────────────────────────

    private static String shopJsonWithExtras(Integer shopId, String civility, String channelCode, List<String[]> assignees) {
        String channelsPart = '';
        if (String.isNotBlank(channelCode)) {
            channelsPart = ',"channels":["' + channelCode + '"]';
        }
        String assigneesPart = '';
        if (assignees != null && !assignees.isEmpty()) {
            List<String> parts = new List<String>();
            for (String[] ra : assignees) {
                parts.add('{"role":"' + ra[0] + '","email":"' + ra[1] + '"}');
            }
            assigneesPart = ',"assignees":[' + String.join(parts, ',') + ']';
        }
        return '{' +
            '"shop_id":' + shopId + ',' +
            '"shop_name":"Extended Shop ' + shopId + '",' +
            '"shipping_country":"DEU",' +
            '"contact_informations":{' +
            '"email":"ext_sync_' + shopId + '@example.com",' +
            '"firstname":"Test","lastname":"User",' +
            '"civility":"' + (String.isNotBlank(civility) ? civility : 'Mr') + '"' +
            '},' +
            '"default_billing_information":{' +
            '"registration_address":{' +
            '"city":"Berlin","country_iso_code":"DEU","street_1":"Test St 1","zip_code":"10115"' +
            '}},' +
            '"commission":{"grid_label":"DE 15%"},' +
            '"pro_details":{"VAT_number":null,"identification_number":null}' +
            channelsPart +
            assigneesPart +
            '}';
    }

    private static User createTestUser(String alias, String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = alias,
            LastName = 'SyncTestUser',
            Email = email,
            Username = email + '.' + alias + '.synctest',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    // ── Contact.Salutation and Account.SalesChannel__c ─────────────────────

    @IsTest
    static void testSyncShopsFromJson_salesChannelAndSalutation() {
        insertStubAccount('999030');

        String json = '{"total_count":1,"shops":[' +
            shopJsonWithExtras(999030, 'Miss', 'DE', null) + ']}';

        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');

        Account a = [SELECT SalesChannel__c FROM Account WHERE MerchantId__c = '999030'];
        System.assertEquals('Germany', a.SalesChannel__c, 'Channel code DE should map to Germany');

        Contact c = [
            SELECT Salutation, Title
            FROM Contact
            WHERE AccountId = :a.Id AND RoleMarketplace__c = 'Mirakl Invitation'
            LIMIT 1
        ];
        System.assertEquals('Ms.', c.Salutation, 'Civility Miss should map to Salutation Ms.');
        System.assertEquals('Miss', c.Title, 'Title should store raw civility value');
    }

    // ── Account.AccountManager__c and TechSupportManager__c from assignees ─

    @IsTest
    static void testSyncShopsFromJson_accountManagerAndSupportSpecialist() {
        insertStubAccount('999031');
        User amUser = createTestUser('am11', 'am11_sync@example.com');
        User ssUser = createTestUser('ss11', 'ss11_sync@example.com');

        List<String[]> assignees = new List<String[]>{
            new String[]{ 'ACCOUNT_MANAGER', 'am11_sync@example.com' },
            new String[]{ 'SUPPORT_SPECIALIST', 'ss11_sync@example.com' }
        };
        String json = '{"total_count":1,"shops":[' +
            shopJsonWithExtras(999031, 'Mr', null, assignees) + ']}';

        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');

        Account a = [SELECT AccountManager__c, TechSupportManager__c FROM Account WHERE MerchantId__c = '999031'];
        System.assertEquals(amUser.Id, a.AccountManager__c, 'AccountManager__c should be set from ACCOUNT_MANAGER assignee');
        System.assertEquals(ssUser.Id, a.TechSupportManager__c, 'TechSupportManager__c should be set from SUPPORT_SPECIALIST assignee');
    }

    // ── PartnerIntegration__c.OwnerId from ONBOARDING_MANAGER assignee ─────

    @IsTest
    static void testSyncShopsFromJson_onboardingManagerUpdatesPartnerIntegration() {
        Account acc = insertStubAccount('999032');
        User omUser = createTestUser('om12', 'om12_sync@example.com');

        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        List<String[]> assignees = new List<String[]>{
            new String[]{ 'ONBOARDING_MANAGER', 'om12_sync@example.com' }
        };
        String json = '{"total_count":1,"shops":[' +
            shopJsonWithExtras(999032, 'Mr', null, assignees) + ']}';

        Test.startTest();
        LIM_Mirakl_ShopsSyncFromMirakl.Output out = LIM_Mirakl_ShopsSyncFromMirakl.syncShopsFromJson(json);
        Test.stopTest();

        System.assertEquals(true, out.success, out.errorMessage != null ? out.errorMessage : '');

        PartnerIntegration__c updated = [SELECT OwnerId FROM PartnerIntegration__c WHERE Id = :pi.Id];
        System.assertEquals(omUser.Id, updated.OwnerId, 'PI OwnerId should be set from ONBOARDING_MANAGER assignee');
    }
}
