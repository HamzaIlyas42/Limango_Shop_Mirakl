# LIM_Mirakl_ShopCreate_Test

**Type:** Apex Class | **Status:** Active | **API Version:** 66.0 | **Object/Trigger:** —

---

## Summary

Apex class **`LIM_Mirakl_ShopCreate_Test`** (`classes/LIM_Mirakl_ShopCreate_Test.cls`) is compiled and executed on the Salesforce server. It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures).

**Author / description from source comment:** Test class for LIM_Mirakl_ShopCreate

---

## Technical Details

### Methods (heuristic)

| Method Name | Access | Return Type | Description       |
| ----------- | ------ | ----------- | ----------------- |
| `respond`   | —      | —           | From source parse |

### Source

```apex
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
        Account acc = new Account(Name = 'Shop Test Account', CommercialRegisterNumber__c = 'CR123');
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
    }

    @isTest
    static void createShop_shopError_returnsError() {
        Account acc = new Account(Name = 'Shop Error Account', CommercialRegisterNumber__c = 'CR456');
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
        Account acc = new Account(Name = 'Shop HTTP Fail Account', CommercialRegisterNumber__c = 'CR789');
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
        Account acc = new Account(Name = 'No Contract Account', CommercialRegisterNumber__c = 'CR');
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
        Account acc = new Account(Name = 'Civility Account', CommercialRegisterNumber__c = 'CR');
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
        addr.put('Address__Stre

… *(4546 more characters omitted)*
```

---

## Dependencies

_(Review imports and type references in source above.)_

---
