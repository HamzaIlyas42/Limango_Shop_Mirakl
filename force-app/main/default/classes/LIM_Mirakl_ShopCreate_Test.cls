/**
 * Test class for LIM_Mirakl_ShopCreate
 */
@isTest
private class LIM_Mirakl_ShopCreate_Test {
    private class MockShopCreated implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"shop_returns":[{"shop_created":{"shop_id":"MIRAKL_123"}}]}');
            res.setStatus('OK');
            return res;
        }
    }

    private class MockShopError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"shop_returns":[{"shop_error":{"errors":[{"field":"email","message":"Invalid"}]}}]}');
            res.setStatus('OK');
            return res;
        }
    }

    private class MockHttpError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            res.setStatus('Internal Server Error');
            return res;
        }
    }

    @isTest
    static void createShop_emptyInput_returnsEmptyList() {
        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>()
        );
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    @isTest
    static void createShop_partnerIntegrationNotFound_returnsError() {
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = null;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
        System.assert(
            results[0].errorMessage.contains('PartnerIntegration not found') ||
            results[0].errorMessage.contains('Record not found'),
            'Should indicate not found'
        );
    }

    @isTest
    static void createShop_partnerIntegrationNoCompanyName_returnsError() {
        PartnerIntegration__c pi = new PartnerIntegration__c();
        insert pi;
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
        System.assert(
            results[0].errorMessage.contains('PartnerIntegration not found') ||
            results[0].errorMessage.contains('no CompanyName'),
            'Should mention CompanyName'
        );
    }

    @isTest
    static void createShop_accountNotFound_returnsError() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;
        delete acc;

        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void createShop_success_updatesMerchantId() {
        Account acc = new Account(
            Name = 'Shop Test Account',
            Shopname__c = 'Shop Test Account',
            CommercialRegisterNumber__c = 'CR123',
            SalesChannel__c = 'Germany'
        );
        insert acc;

        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            Salutation = 'Mr',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;

        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'Test St 1');
        addr.put('Address__PostalCode__s', '12345');
        addr.put('Address__City__s', 'Berlin');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;

        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        ctr.Sla__c = 'Contract SLA body text';
        update ctr;

        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals('MIRAKL_123', results[0].merchantId, 'MerchantId should be set');
        System.assert(results[0].requestJson != null, 'Request JSON should be set');
        System.assert(results[0].responseJson != null, 'Response JSON should be set');
        System.assert(
            results[0].requestJson.contains('"channels"') && results[0].requestJson.contains('DE'),
            'Request should include Mirakl channels from SalesChannel__c'
        );
        System.assert(
            results[0].requestJson.contains('shop_additional_fields') &&
            results[0].requestJson.contains('Contract SLA body text'),
            'Request should include shop_additional_fields from Contract Sla__c'
        );
    }

    @isTest
    static void createShop_shopError_returnsError() {
        Account acc = new Account(
            Name = 'Shop Error Account',
            Shopname__c = 'Shop Error Account',
            CommercialRegisterNumber__c = 'CR456'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'F',
            LastName = 'L',
            Email = 'e@x.com',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopError());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void createShop_httpFailure_returnsError() {
        Account acc = new Account(
            Name = 'Shop HTTP Fail Account',
            Shopname__c = 'Shop HTTP Fail Account',
            CommercialRegisterNumber__c = 'CR789'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'F',
            LastName = 'L',
            Email = 'e@x.com',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockHttpError());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void createShop_noMiraklInvitationContact_returns999() {
        Account acc = new Account(Name = 'No Contact Role Account', CommercialRegisterNumber__c = 'CR');
        insert acc;
        Contact con = new Contact(AccountId = acc.Id, FirstName = 'F', LastName = 'L', Email = 'norole@x.com');
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;
        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void createShop_noHeadquarterAddress_returns999() {
        Account acc = new Account(Name = 'No HQ Address Account', CommercialRegisterNumber__c = 'CR');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'F',
            LastName = 'L',
            Email = 'hq@x.com',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'InvoiceAddress');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;
        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void createShop_noActivatedMarketplaceContract_returns999() {
        Account acc = new Account(
            Name = 'No Contract Account',
            Shopname__c = 'No Contract Shop',
            CommercialRegisterNumber__c = 'CR'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'F',
            LastName = 'L',
            Email = 'noc@x.com',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;
        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Contract check removed; API call runs and mock returns success');
        System.assertEquals('MIRAKL_123', results[0].merchantId, 'MerchantId from mock');
    }

    @isTest
    static void createShop_civilityMrs_mapsCorrectly() {
        Account acc = new Account(
            Name = 'Civility Account',
            Shopname__c = 'Civility Shop',
            CommercialRegisterNumber__c = 'CR'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'limango' + String.valueOf(System.now().getTime()) + '@factory42.com',
            Salutation = 'Mrs',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assert(
            results[0].requestJson != null && results[0].requestJson.contains('Mrs'),
            'Request should contain Mrs civility'
        );
    }

    /**
     * Mirrors the flow scenario: Account with 3 addresses (Invoice, Return, Headquarter).
     * Ensures createShop finds the Headquarter address and uses it in the Mirakl request.
     */
    @isTest
    static void createShop_withMultipleAddressTypes_usesHeadquarterAndSucceeds() {
        Account acc = new Account(
            Name = 'Factory42_Hamza',
            Shopname__c = 'Factory42 Hamza Shop',
            CommercialRegisterNumber__c = 'CR123'
        );
        insert acc;

        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Hamza',
            LastName = 'Test',
            Email = 'hamza.factory42@example.com',
            Salutation = 'Mr',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;

        // Same 3 address types as the flow creates (Invoice, Return, Headquarter)
        List<Address__c> addrs = new List<Address__c>();
        for (String addrType : new List<String>{ 'InvoiceAddress', 'AddressForReturns', 'Headquarter' }) {
            Address__c a = new Address__c(
                Account__c = acc.Id,
                AddressType__c = addrType,
                AddressStatus__c = 'Active',
                BusinessUnit__c = 'Marketplace'
            );
            a.put(
                'Address__Street__s',
                addrType == 'InvoiceAddress'
                    ? 'Invoice-Weg 23'
                    : addrType == 'AddressForReturns' ? 'Return-Weg 23' : 'Headquarter-Platz 17'
            );
            a.put('Address__PostalCode__s', '12345');
            a.put('Address__City__s', 'Hamburg');
            a.put('Address__CountryCode__s', 'DE');
            addrs.add(a);
        }
        insert addrs;

        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;

        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals('MIRAKL_123', results[0].merchantId, 'MerchantId should be set');
        System.assert(
            results[0].requestJson != null && results[0].requestJson.contains('Headquarter-Platz 17'),
            'Request should use Headquarter address street from the flow-created addresses'
        );
        System.assert(
            results[0].requestJson.contains('Hamburg') && results[0].requestJson.contains('12345'),
            'Request should contain Headquarter city and postal code'
        );
    }

    @isTest
    static void createShop_blankShopname_returnsError() {
        Account acc = new Account(Name = 'No Shopname Account', CommercialRegisterNumber__c = 'CR');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'F',
            LastName = 'L',
            Email = 'noshop@x.com',
            RoleMarketplace__c = 'Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'St');
        addr.put('Address__PostalCode__s', '1');
        addr.put('Address__City__s', 'City');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail when Shopname__c is blank');
        System.assert(
            results[0].errorMessage != null && results[0].errorMessage.contains('Shopname__c'),
            'Error message should mention Shopname__c'
        );
    }

    @isTest
    static void createShop_existingUser_sendsExistingUserPayload() {
        Account acc = new Account(
            Name = 'Existing User Account',
            Shopname__c = 'Existing User Shop',
            CommercialRegisterNumber__c = 'CR_EU'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Ex',
            LastName = 'User',
            Email = 'existing@mirakl.com',
            RoleMarketplace__c = 'Mirakl Invitation',
            ExistingMiraklUser__c = 'Yes'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'Existing St');
        addr.put('Address__PostalCode__s', '99999');
        addr.put('Address__City__s', 'Munich');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed with existing_user');
        System.assert(
            results[0].requestJson != null && results[0].requestJson.contains('"existing_user"'),
            'Request JSON should contain existing_user'
        );
        System.assert(
            !results[0].requestJson.contains('"new_user"'),
            'Request JSON must NOT contain new_user when existing user flag is Yes'
        );
    }

    @isTest
    static void createShop_combinedRoleIncludesMiraklInvitation_succeeds() {
        Account acc = new Account(
            Name = 'Multi Role Account',
            Shopname__c = 'Multi Role Shop',
            CommercialRegisterNumber__c = 'CR_MR'
        );
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Multi',
            LastName = 'Role',
            Email = 'multirole@example.com',
            RoleMarketplace__c = 'Sales Contact;Mirakl Invitation'
        );
        insert con;
        Address__c addr = new Address__c(Account__c = acc.Id, AddressType__c = 'Headquarter');
        addr.put('Address__Street__s', 'Multi St');
        addr.put('Address__PostalCode__s', '11111');
        addr.put('Address__City__s', 'Berlin');
        addr.put('Address__CountryCode__s', 'DE');
        insert addr;
        Contract ctr = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today().addMonths(-1),
            ContractTerm = 12,
            ContractVisiblityCriteria__c = 'Marketplace',
            Status = 'Draft'
        );
        insert ctr;
        ctr.Status = 'Activated';
        ctr.ActivatedDate = Date.today();
        update ctr;
        PartnerIntegration__c pi = new PartnerIntegration__c(CompanyName__c = acc.Id);
        insert pi;

        Test.setMock(HttpCalloutMock.class, new MockShopCreated());
        LIM_Mirakl_ShopCreate.Input input = new LIM_Mirakl_ShopCreate.Input();
        input.partnerIntegrationId = pi.Id;

        Test.startTest();
        List<LIM_Mirakl_ShopCreate.Output> results = LIM_Mirakl_ShopCreate.createShop(
            new List<LIM_Mirakl_ShopCreate.Input>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Contact with combined roles should be found via INCLUDES');
        System.assertEquals('MIRAKL_123', results[0].merchantId, 'MerchantId should be set');
        System.assert(
            results[0].requestJson != null && results[0].requestJson.contains('"new_user"'),
            'Request JSON should contain new_user (ExistingMiraklUser__c defaults to No)'
        );
    }

    @isTest
    static void miraklChannelCode_mapsLabelsAndReturnsNullForUnknown() {
        System.assertEquals('DE', LIM_Mirakl_ShopCreate.miraklChannelCodeForSalesChannel('Germany'), 'Germany → DE');
        System.assertEquals(
            'PL',
            LIM_Mirakl_ShopCreate.miraklChannelCodeForSalesChannel('poland'),
            'Case-insensitive Poland → PL'
        );
        System.assertEquals(
            null,
            LIM_Mirakl_ShopCreate.miraklChannelCodeForSalesChannel('France'),
            'Unknown label → null'
        );
    }
}
