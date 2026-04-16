# Address\_\_c

**Type:** CustomObject (standard object extension) | **Status:** Deployed metadata | **API Version:** (see field files) | **Object/Trigger:** Address\_\_c

---

## Summary

The Address\_\_c object metadata in this project includes 12 field definition file(s), 0 validation rule(s), and 0 record type(s). These artifacts extend the standard Salesforce object with custom fields, validation, and segmentation used by processes and UIs in the org. Relationships to other objects in this bundle appear where custom Lookup or Master-Detail fields reference those targets.

---

## Flow / Component Diagram

Object-level relationship diagrams for the objects in this project are in [README.md](./README.md) (Architecture Diagram). This bundle does not contain a single executable flow; field and validation metadata is tabulated below.

---

## Technical Details

### Fields

| Label                          | API Name                          | Type     | Required | Unique | Description                                                                                                                     |
| ------------------------------ | --------------------------------- | -------- | -------- | ------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Account                        | Account\_\_c                      | Lookup   | true     |        |                                                                                                                                 |
| Address Company Name           | AddressCompanyName\_\_c           | Text     | false    | false  | If the name on the invoice is different from the company name, please enter it here. If it is the same, leave this field blank. |
| Address Status                 | AddressStatus\_\_c                | Picklist | false    |        |                                                                                                                                 |
| Address Type                   | AddressType\_\_c                  | Picklist | false    |        |                                                                                                                                 |
| Address                        | Address\_\_c                      | Address  |          |        |                                                                                                                                 |
| Business Unit AdSales Address  | BusinessUnitAdSalesAddress\_\_c   | Picklist | false    |        |                                                                                                                                 |
| Business Unit                  | BusinessUnit\_\_c                 | Picklist | false    |        |                                                                                                                                 |
| Contact Person                 | ContactPerson\_\_c                | Lookup   | false    |        |                                                                                                                                 |
| Invoice Configuration Language | InvoiceConfigurationLanguage\_\_c | Text     | false    | false  |                                                                                                                                 |
| Merchant Company Name          | MerchantCompanyName\_\_c          | Text     | false    | false  | Field needed for the integration to Merchant Center, to deliver correct invoice or return address company name                  |
| Phone Number                   | PhoneNumber\_\_c                  | Phone    | false    |        |                                                                                                                                 |
| Status                         | Status\_\_c                       | Picklist | false    |        |                                                                                                                                 |

### Relationships

No Lookup or Master-Detail fields found in retrieved field metadata for this object.

### Validation rules

| Rule Name | Condition | Error Message |
| --------- | --------- | ------------- |

### Record types

- —

### Page layouts

No `layouts/` metadata is present in this project snapshot for this object.

### Compact layouts

AdressCompactLayout.compactLayout-meta

### List views (metadata files)

AdSales.listView-meta, All.listView-meta

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
