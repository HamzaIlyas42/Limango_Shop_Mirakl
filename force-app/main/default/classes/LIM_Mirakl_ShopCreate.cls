/**
 * LIM_Mirakl_ShopCreate
 * Handles Shop creation in Mirakl via POST /api/shops
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

    // ── Input ─────────────────────────────────────────────
    public class Input {
        @InvocableVariable(
            description='Id of the PartnerIntegration__c record for which a Mirakl shop should be created'
            required=true
        )
        public Id partnerIntegrationId;
    }

    // ── Output ────────────────────────────────────────────
    public class Output {
        @InvocableVariable(description='Mirakl Merchant Id returned after successful shop creation')
        public String merchantId;

        @InvocableVariable(description='Indicates whether the shop creation was successful')
        public Boolean success;

        @InvocableVariable(description='HTTP status code returned by the Mirakl API')
        public Integer statusCode;

        @InvocableVariable(description='Error message if the shop creation failed')
        public String errorMessage;

        @InvocableVariable(description='JSON body sent to the Mirakl API')
        public String requestJson;

        @InvocableVariable(description='Raw JSON response received from the Mirakl API')
        public String responseJson;
    }

    // ── Invocable Method ──────────────────────────────────
    @InvocableMethod(
        description='Creates a new shop in Mirakl for each provided PartnerIntegration record via POST /api/shops'
    )
    public static List<Output> createShop(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input input : inputs) {
            results.add(createShopForPartnerIntegration(input.partnerIntegrationId));
        }
        return results;
    }

    // ── Per-Record Logic ──────────────────────────────────
    private static Output createShopForPartnerIntegration(Id partnerIntegrationId) {
        Output result = new Output();

        try {
            // ── Step 1: Fetch PartnerIntegration__c to get related Account Id (CompanyName__c) ──
            List<PartnerIntegration__c> piList = [
                SELECT Id, CompanyName__c, Owner.Email
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
                    Shopname__c,
                    CommercialRegisterNumber__c,
                    AccountManager__r.Email,
                    TechSupportManager__r.Email,
                    (
                        SELECT Id, Email, FirstName, LastName, Salutation
                        FROM Contacts
                        WHERE RoleMarketplace__c = 'Mirakl Invitation'
                    ),
                    (
                        SELECT Id, Address__Street__s, Address__PostalCode__s, Address__City__s, Address__CountryCode__s
                        FROM Addresses__r
                        WHERE AddressType__c = 'Headquarter'
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

            // address - try alpha-3; if Mirakl still rejects, try alpha-2 or check API docs
            String countryCode = firstAddress != null ? (String) firstAddress.get('Address__CountryCode__s') : null;
            String countryForMirakl = (countryCode != null &&
                COUNTRY_ALPHA2_TO_ALPHA3.containsKey(countryCode.toUpperCase()))
                ? COUNTRY_ALPHA2_TO_ALPHA3.get(countryCode.toUpperCase())
                : countryCode;

            // street1 and civility required by Mirakl (authorized: Mr, Mrs, Miss, Neutral)
            String civility = toMiraklCivility(primaryContact != null ? primaryContact.Salutation : null);
            Map<String, Object> address = new Map<String, Object>{
                'city' => firstAddress != null ? firstAddress.get('Address__City__s') : null,
                'civility' => civility,
                'country' => countryForMirakl,
                'firstname' => contactFirst,
                'lastname' => contactLast,
                'street1' => firstAddress != null ? firstAddress.get('Address__Street__s') : null,
                'zip_code' => firstAddress != null ? firstAddress.get('Address__PostalCode__s') : null
            };

            String shopNameForMirakl = String.isNotBlank(acct.Shopname__c) ? acct.Shopname__c.trim() : null;
            if (String.isBlank(shopNameForMirakl)) {
                result.success = false;
                result.errorMessage = 'Shopname__c is required on the Account to create a Mirakl shop.';
                return result;
            }

            Map<String, Object> proDetails = new Map<String, Object>{
                'identification_number' => acct.CommercialRegisterNumber__c
            };
            Map<String, Object> newUser = new Map<String, Object>{ 'email' => contactEmail };

            Map<String, Object> shop = new Map<String, Object>{
                'address' => address,
                'new_user' => newUser,
                'pro_details' => proDetails,
                'email' => contactEmail,
                'shop_name' => shopNameForMirakl
            };

            String onboardingEmail = piList[0].Owner.Email;
            List<Object> assigneeList = new List<Object>();
            if (String.isNotBlank(acct.AccountManager__r?.Email)) {
                assigneeList.add(new Map<String, Object>{
                    'email' => acct.AccountManager__r.Email,
                    'role' => 'ACCOUNT_MANAGER'
                });
            }
            if (String.isNotBlank(acct.TechSupportManager__r?.Email)) {
                assigneeList.add(new Map<String, Object>{
                    'email' => acct.TechSupportManager__r.Email,
                    'role' => 'SUPPORT_SPECIALIST'
                });
            }
            if (String.isNotBlank(onboardingEmail)) {
                assigneeList.add(new Map<String, Object>{
                    'email' => onboardingEmail,
                    'role' => 'ONBOARDING_MANAGER'
                });
            }
            if (!assigneeList.isEmpty()) {
                shop.put('assignees', assigneeList);
            }

            // Mirakl expects shops[] array
            Map<String, Object> bodyMap = new Map<String, Object>{ 'shops' => new List<Object>{ shop } };
            String requestBody = JSON.serialize(bodyMap);
            result.requestJson = requestBody;

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
            result.responseJson = res.responseBody;

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
                                String code = String.valueOf(e.get('code'));
                                String field = String.valueOf(e.get('field'));
                                String msg = String.valueOf(e.get('message'));
                                if (String.isNotBlank(code)) {
                                    messages.add(code + ' - ' + field + ': ' + msg);
                                } else {
                                    messages.add(field + ': ' + msg);
                                }
                            }
                            result.errorMessage = String.join(messages, '; ');
                        } else {
                            result.errorMessage = 'Shop creation failed (see shop_error in response).';
                        }
                    } else if (firstReturn.containsKey('shop_created')) {
                        Map<String, Object> shopCreated = (Map<String, Object>) firstReturn.get('shop_created');
                        if (shopCreated != null && shopCreated.containsKey('shop_id')) {
                            result.merchantId = String.valueOf(shopCreated.get('shop_id'));
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

    // Mirakl authorized civility: Mr, Mrs, Miss, Neutral (case-sensitive)
    private static String toMiraklCivility(String salutation) {
        if (String.isBlank(salutation))
            return 'Mr';
        String t = salutation.trim().toLowerCase();
        if (t.contains('mrs') || t.contains('frau') || t.contains('madam'))
            return 'Mrs';
        if (t.contains('miss') || (t.contains('ms') && !t.contains('mr')))
            return 'Miss';
        if (t.contains('neutral') || t.contains('divers'))
            return 'Neutral';
        return 'Mr';
    }
}
