# Contract

**Type:** CustomObject (standard object extension) | **Status:** Deployed metadata | **API Version:** (see field files) | **Object/Trigger:** Contract

---

## Summary

The Contract object metadata in this project includes 117 field definition file(s), 1 validation rule(s), and 3 record type(s). These artifacts extend the standard Salesforce object with custom fields, validation, and segmentation used by processes and UIs in the org. Relationships to other objects in this bundle appear where custom Lookup or Master-Detail fields reference those targets.

---

## Flow / Component Diagram

Object-level relationship diagrams for the objects in this project are in [README.md](./README.md) (Architecture Diagram). This bundle does not contain a single executable flow; field and validation metadata is tabulated below.

---

## Technical Details

### Fields

| Label                                    | API Name                                 | Type                | Required | Unique | Description                                                                                                  |
| ---------------------------------------- | ---------------------------------------- | ------------------- | -------- | ------ | ------------------------------------------------------------------------------------------------------------ |
|                                          | AccountId                                | Lookup              |          |        |                                                                                                              |
|                                          | ActivatedById                            | Lookup              |          |        |                                                                                                              |
|                                          | ActivatedDate                            |                     |          |        |                                                                                                              |
| AdSales Contract Type                    | AdSalesContractType\_\_c                 | Picklist            | false    |        |                                                                                                              |
| AdSales Invoice specialities             | AdSalesInvoiceSpecialities\_\_c          | Html                |          |        |                                                                                                              |
| Add.Agreement f. supply of branded goods | AddAgreementFSupplyOfBrandedGood\_\_c    | Checkbox            |          |        |                                                                                                              |
| BIC                                      | BIC\_\_c                                 | Text                | false    | false  |                                                                                                              |
| BLZ                                      | BLZ\_\_c                                 | Text                | false    | false  |                                                                                                              |
| Backend                                  | Backend\_\_c                             | Picklist            | false    |        | Choose the Backend via which the Merchant will connect to limango.                                           |
| Bank Account Holder                      | BankAccountHolder\_\_c                   | Text                | false    | false  |                                                                                                              |
| Bank Institution                         | BankInstitution\_\_c                     | Text                | false    | false  |                                                                                                              |
|                                          | BillingAddress                           |                     |          |        |                                                                                                              |
| Billing frequency                        | BillingFrequency\_\_c                    | Picklist            | false    |        |                                                                                                              |
| Blacklist                                | Blacklist\_\_c                           | Checkbox            |          |        |                                                                                                              |
| Business Unit AdSales Contract           | BusinessUnitAdSalesContract\_\_c         | Picklist            | false    |        |                                                                                                              |
| Business Unit                            | BusinessUnit\_\_c                        | Picklist            | false    |        |                                                                                                              |
| Carrier handover time                    | Carrierhandovertime\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Commission                               | Commission\_\_c                          | Percent             | false    |        |                                                                                                              |
|                                          | CompanySignedDate                        |                     |          |        |                                                                                                              |
|                                          | CompanySignedId                          | Lookup              |          |        |                                                                                                              |
| Connection Fee charged                   | ConnectionFeeCharged\_\_c                | Date                | false    |        |                                                                                                              |
| Connection Fee: Interface Change Charged | ConnectionFeeInterfaceChangeCharged\_\_c | Date                | false    |        |                                                                                                              |
| Connection Fee: Interface Change         | ConnectionFeeInterfaceChange\_\_c        | Currency            | false    |        |                                                                                                              |
| Connection Fee                           | ConnectionFee\_\_c                       | Picklist            | false    |        |                                                                                                              |
| Connection Type                          | ConnectionType\_\_c                      | Picklist            | false    |        |                                                                                                              |
| Contract adjustments                     | ContractAdjustments\_\_c                 | LongTextArea        |          |        |                                                                                                              |
| Contract sent                            | ContractSent\_\_c                        | Date                | false    |        |                                                                                                              |
| Contract signed                          | ContractSigned\_\_c                      | Date                | false    |        |                                                                                                              |
|                                          | ContractTerm                             |                     |          |        |                                                                                                              |
| Contract Type                            | ContractType\_\_c                        | Picklist            | false    |        |                                                                                                              |
| Contract Value                           | ContractValue\_\_c                       | Currency            | false    |        |                                                                                                              |
| Contract Visiblity Criteria              | ContractVisiblityCriteria\_\_c           | Picklist            | false    |        | Field needed to build restriction rules                                                                      |
| Contractual Amendment                    | ContractualAmendment\_\_c                | Checkbox            |          |        |                                                                                                              |
| Currency                                 | Currency\_\_c                            | Picklist            | false    |        |                                                                                                              |
|                                          | CustomerSignedDate                       |                     |          |        |                                                                                                              |
|                                          | CustomerSignedId                         | Lookup              |          |        |                                                                                                              |
|                                          | CustomerSignedTitle                      |                     |          |        |                                                                                                              |
| Delivery / Pickup                        | DeliveryPickup\_\_c                      | Picklist            | false    |        |                                                                                                              |
| Deliverynote in the package              | DeliverynoteInThePackage\_\_c            | Checkbox            |          |        |                                                                                                              |
|                                          | Description                              |                     |          |        |                                                                                                              |
|                                          | EndDate                                  |                     |          |        |                                                                                                              |
| Fixed bonus in %                         | FixedBonusInPercent\_\_c                 | Percent             | false    |        |                                                                                                              |
| Fixed bonus                              | FixedBonus\_\_c                          | Currency            | false    |        |                                                                                                              |
| Fixed contribution                       | FixedContribution\_\_c                   | Number              | false    | false  |                                                                                                              |
| Free Shipping Limit AT                   | FreeShippingLimitAt\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Free Shipping Limit DE                   | FreeShippingLimitDe\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Free Shipping Limit PL                   | FreeShippingLimitPL\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Free Shipping AT                         | Free_Shipping_AT\_\_c                    | Picklist            | false    |        |                                                                                                              |
| Free Shipping DE                         | Free_Shipping_DE\_\_c                    | Picklist            | false    |        |                                                                                                              |
| Fulfillment                              | Fulfillment\_\_c                         | MultiselectPicklist | false    |        | Service provider who carries out the shipping process for the partner                                        |
| IBAN                                     | IBAN\_\_c                                | Text                | false    | false  |                                                                                                              |
| Incoterms                                | Incoterms\_\_c                           | Picklist            | false    |        |                                                                                                              |
| Info about contract                      | InfoAboutContract\_\_c                   | LongTextArea        |          |        |                                                                                                              |
| Integration Agency                       | IntegrationAgency\_\_c                   | Picklist            | false    |        | Does an agency take over the integration for the partner?                                                    |
| Invoice discount                         | InvoiceDiscount\_\_c                     | Number              | false    | false  |                                                                                                              |
| Limango CEO (sign)                       | LimangoCeoSign\_\_c                      | Lookup              | false    |        |                                                                                                              |
| Limango Head of Purchasing (sign)        | LimangoHeadOfPurchasingSign\_\_c         | Lookup              | false    |        |                                                                                                              |
| Limango purchaser (sign)                 | LimangoPurchaserSign\_\_c                | Lookup              | false    |        |                                                                                                              |
| Limango TL/ Coordinator (confirm)        | LimangoTlCoordinatorConfirm\_\_c         | Lookup              | false    |        |                                                                                                              |
| Master Agreement                         | MasterAgreement\_\_c                     | Checkbox            |          |        |                                                                                                              |
| Master Purchase Agreement                | MasterPurchaseAgreement\_\_c             | Checkbox            |          |        |                                                                                                              |
| Merchant ID                              | MerchantId\_\_c                          | Text                | false    | true   |                                                                                                              |
| Monthly Fee                              | Monthly_Fee\_\_c                         | Picklist            | false    |        |                                                                                                              |
| Monthly Premium Fee                      | Monthly_Premium_Fee\_\_c                 | Picklist            | false    |        |                                                                                                              |
|                                          | Name                                     |                     |          |        |                                                                                                              |
| noship threshold                         | NoshipThreshold\_\_c                     | Percent             | false    |        |                                                                                                              |
|                                          | OwnerExpirationNotice                    |                     |          |        |                                                                                                              |
|                                          | OwnerId                                  | Lookup              |          |        |                                                                                                              |
| Payment term/due date for net payment    | PaymentTermDueDateForNetPayment\_\_c     | Number              | false    | false  |                                                                                                              |
| Premium support end date                 | Premium_support_end_date\_\_c            | Date                | false    |        |                                                                                                              |
| Premium support start date               | Premium_support_start_date\_\_c          | Date                | false    |        |                                                                                                              |
|                                          | Pricebook2Id                             | Lookup              |          |        |                                                                                                              |
| Return collection                        | ReturnCollection\_\_c                    | Picklist            | false    |        |                                                                                                              |
| Return Label Process                     | ReturnLabelProcess\_\_c                  | Picklist            | false    |        |                                                                                                              |
| Return quantity                          | ReturnQuantity\_\_c                      | Number              | false    | false  |                                                                                                              |
| Returns to Manufacturer                  | ReturnsToManufacturer\_\_c               | Picklist            | false    |        |                                                                                                              |
| Shared Cost                              | SharedCost\_\_c                          | Picklist            | false    |        |                                                                                                              |
|                                          | ShippingAddress                          |                     |          |        |                                                                                                              |
| Shipping costs AT                        | ShippingCostsAt\_\_c                     | Picklist            | false    |        |                                                                                                              |
| Shipping costs DE                        | ShippingCostsDe\_\_c                     | Picklist            | false    |        |                                                                                                              |
| Shipping Costs PL                        | ShippingCostsPL\_\_c                     | Picklist            | false    |        |                                                                                                              |
| Shipping costs TwoManHandling (DE)       | ShippingCostsTwoManHandling\_\_c         | Picklist            | false    |        |                                                                                                              |
| Shipping costs X country                 | ShippingCostsXCountry\_\_c               | Picklist            | false    |        |                                                                                                              |
| SLA                                      | Sla\_\_c                                 | LongTextArea        |          |        |                                                                                                              |
|                                          | SpecialTerms                             |                     |          |        |                                                                                                              |
|                                          | StartDate                                |                     |          |        |                                                                                                              |
|                                          | Status                                   | Picklist            |          |        |                                                                                                              |
| Status annual contract                   | StatusAnnualContract\_\_c                | Picklist            | false    |        |                                                                                                              |
| Supplier contact 1 (sign)                | SupplierContact1Sign\_\_c                | Lookup              | false    |        |                                                                                                              |
| Supplier contact 2 (sign)                | SupplierContact2Sign\_\_c                | Lookup              | false    |        |                                                                                                              |
| Supplier ID                              | SupplierId\_\_c                          | Text                | false    | true   |                                                                                                              |
| Term of payment                          | TermOfPayment\_\_c                       | Picklist            | false    |        |                                                                                                              |
| TwoManHandling (DE)                      | TwoManHandling\_\_c                      | Checkbox            |          |        |                                                                                                              |
| Type of contract                         | TypeOfContract\_\_c                      | Picklist            | false    |        |                                                                                                              |
| Valuta                                   | Valuta\_\_c                              | Number              | false    | false  |                                                                                                              |
| Warehouse (shipping AT)                  | WarehouseShippingAt\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Warehouse (shipping DE)                  | WarehouseShippingDe\_\_c                 | Picklist            | false    |        |                                                                                                              |
| Warehouse (shipping other country)       | WarehouseShippingOtherCountry\_\_c       | Picklist            | false    |        |                                                                                                              |
| Warehouse (shipping PL)                  | WarehouseshippingPL\_\_c                 | Picklist            | false    |        |                                                                                                              |
| 1. Up to k Euros                         | X1UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| 2. Up to k Euros                         | X2UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| 2mh Free Shipping Limit AT               | X2mh_Free_Shipping_Limit_AT\_\_c         | LongTextArea        |          |        |                                                                                                              |
| 2mh Free Shipping Limit DE               | X2mh_Free_Shipping_Limit_DE\_\_c         | LongTextArea        |          |        |                                                                                                              |
| 2mh Free Shipping Limit PL               | X2mh_Free_Shipping_Limit_PL\_\_c         | LongTextArea        |          |        |                                                                                                              |
| 2mh Shipping cost AT                     | X2mh_Shipping_cost_AT\_\_c               | LongTextArea        |          |        |                                                                                                              |
| 2mh Shipping cost DE                     | X2mh_Shipping_cost_DE\_\_c               | LongTextArea        |          |        |                                                                                                              |
| 2mh Shipping cost PL                     | X2mh_Shipping_cost_PL\_\_c               | LongTextArea        |          |        |                                                                                                              |
| 2mh free Shipping AT                     | X2mh_free_Shipping_AT\_\_c               | Picklist            | false    |        |                                                                                                              |
| 2mh free Shipping DE                     | X2mh_free_Shipping_DE\_\_c               | Picklist            | false    |        |                                                                                                              |
| 2mh free Shipping PL                     | X2mh_free_Shipping_PL\_\_c               | Picklist            | false    |        |                                                                                                              |
| 3. Up to k Euros                         | X3UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| 4. Up to k Euros                         | X4UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| 5. Up to k Euros                         | X5UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| 6. Up to k Euros                         | X6UpToKEuros\_\_c                        | Currency            | false    |        | Graduated bonus based on annual sales                                                                        |
| X% on invoice value                      | XPercentOnInvoiceValue\_\_c              | Percent             | false    |        |                                                                                                              |
| X% on return value (kickback)            | XPercentOnReturnValueKickback\_\_c       | Percent             | false    |        |                                                                                                              |
| of which SPA                             | of_which_SPA\_\_c                        | Currency            | false    |        | Field required for AdSales so that they can enter how much of the budget from the contract was spent on SPA. |

### Relationships

No Lookup or Master-Detail fields found in retrieved field metadata for this object.

### Validation rules

| Rule Name                     | Condition                                                                                                                                                                                                                                                                                                        | Error Message                                                                       |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| ActivatedStatusFieldsRequired | `AND(     ISPICKVAL(Status, "activated"),     ISPICKVAL(Backend__c, "Merchant Center"),     OR(         ISBLANK(BankAccountHolder__c),         ISBLANK(BankInstitution__c),         ISBLANK(BIC__c),         ISBLANK(IBAN__c),         ISBLANK(Commission__c),         ISPICKVAL(ConnectionType__c, "")     ) )` | For the status 'activated', all Merchant Centre mandatory fields must be completed. |

### Record types

- **AdSales** (active: true): Record type for AdSales contracts
- **Marketplace** (active: true): Record type for marketplace contracts
- **Retail** (active: true): Record type for retail contracts

### Page layouts

No `layouts/` metadata is present in this project snapshot for this object.

### Compact layouts

ContractCompactLayout.compactLayout-meta, ContractCompactLayoutRetail.compactLayout-meta

### List views (metadata files)

AdSales_Contracts.listView-meta, AllActivatedContracts.listView-meta, AllContracts.listView-meta, AllDraftContracts.listView-meta, AllInApprovalContracts.listView-meta, MyActivatedContracts.listView-meta, MyDraftContracts.listView-meta, MyInApprovalContracts.listView-meta

### Web links

—

### Field sets

—

### Business processes

—

---

## Dependencies

- **Referenced objects (lookup targets):** —

---
