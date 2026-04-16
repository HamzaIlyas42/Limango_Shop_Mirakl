# Contact

**Type:** CustomObject (standard object extension) | **Status:** Deployed metadata | **API Version:** (see field files) | **Object/Trigger:** Contact

---

## Summary

The Contact object metadata in this project includes 42 field definition file(s), 0 validation rule(s), and 0 record type(s). These artifacts extend the standard Salesforce object with custom fields, validation, and segmentation used by processes and UIs in the org. Relationships to other objects in this bundle appear where custom Lookup or Master-Detail fields reference those targets.

---

## Flow / Component Diagram

Object-level relationship diagrams for the objects in this project are in [README.md](./README.md) (Architecture Diagram). This bundle does not contain a single executable flow; field and validation metadata is tabulated below.

---

## Technical Details

### Fields

| Label                             | API Name                               | Type                | Required | Unique | Description                                                                                                                                                                               |
| --------------------------------- | -------------------------------------- | ------------------- | -------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|                                   | AccountId                              | Lookup              |          |        |                                                                                                                                                                                           |
| AdSales Accounting Email Adresses | AdSales_Accounting_Email_Adresses\_\_c | LongTextArea        |          |        | Field to list all email addresses belonging to the account that have the role/function AdSales Accounting. The field is triggered by the flow LIM_Contact_mergeAdSalesAccounting_Changes. |
|                                   | AssistantName                          |                     |          |        |                                                                                                                                                                                           |
|                                   | AssistantPhone                         |                     |          |        |                                                                                                                                                                                           |
|                                   | Birthdate                              |                     |          |        |                                                                                                                                                                                           |
| Business Unit AdSales Contact     | BusinessUnitAdSalesContact\_\_c        | Picklist            | false    |        | Used for AdSales only                                                                                                                                                                     |
| Business Unit                     | BusinessUnit\_\_c                      | Picklist            | false    |        |                                                                                                                                                                                           |
|                                   | BuyerAttributes                        | Picklist            |          |        |                                                                                                                                                                                           |
|                                   | ContactSource                          |                     |          |        |                                                                                                                                                                                           |
|                                   | Department                             |                     |          |        |                                                                                                                                                                                           |
|                                   | DepartmentGroup                        |                     |          |        |                                                                                                                                                                                           |
|                                   | Description                            |                     |          |        |                                                                                                                                                                                           |
|                                   | DoNotCall                              |                     |          |        |                                                                                                                                                                                           |
|                                   | Email                                  |                     |          |        |                                                                                                                                                                                           |
| ESPO ID                           | EspoId\_\_c                            | Text                | false    | true   |                                                                                                                                                                                           |
|                                   | Fax                                    |                     |          |        |                                                                                                                                                                                           |
|                                   | GenderIdentity                         | Picklist            |          |        |                                                                                                                                                                                           |
|                                   | HasOptedOutOfEmail                     |                     |          |        |                                                                                                                                                                                           |
|                                   | HasOptedOutOfFax                       |                     |          |        |                                                                                                                                                                                           |
|                                   | HomePhone                              |                     |          |        |                                                                                                                                                                                           |
| Integration Agency Name           | IntegrationAgencyName\_\_c             | Picklist            | false    |        | Name of integration agency contact belongs to.                                                                                                                                            |
| Integration Function              | IntegrationFunction\_\_c               | MultiselectPicklist | false    |        |                                                                                                                                                                                           |
|                                   | Jigsaw                                 |                     |          |        |                                                                                                                                                                                           |
| Language                          | Language\_\_c                          | Picklist            | false    |        |                                                                                                                                                                                           |
|                                   | LastCURequestDate                      |                     |          |        |                                                                                                                                                                                           |
|                                   | LastCUUpdateDate                       |                     |          |        |                                                                                                                                                                                           |
|                                   | LeadSource                             | Picklist            |          |        |                                                                                                                                                                                           |
|                                   | MailingAddress                         |                     |          |        |                                                                                                                                                                                           |
| Main Contact                      | Main_Contact\_\_c                      | Picklist            | false    |        |                                                                                                                                                                                           |
|                                   | MobilePhone                            |                     |          |        |                                                                                                                                                                                           |
|                                   | Name                                   |                     |          |        |                                                                                                                                                                                           |
|                                   | OtherAddress                           |                     |          |        |                                                                                                                                                                                           |
|                                   | OtherPhone                             |                     |          |        |                                                                                                                                                                                           |
|                                   | OwnerId                                | Lookup              |          |        |                                                                                                                                                                                           |
|                                   | Phone                                  |                     |          |        |                                                                                                                                                                                           |
|                                   | Pronouns                               | Picklist            |          |        |                                                                                                                                                                                           |
|                                   | ReportsToId                            | Lookup              |          |        |                                                                                                                                                                                           |
| Role / Function                   | RoleFunction\_\_c                      | Picklist            | false    |        |                                                                                                                                                                                           |
| Role Marketplace                  | RoleMarketplace\_\_c                   | MultiselectPicklist | false    |        | Roles only for Marketplace.                                                                                                                                                               |
| Status                            | Status\_\_c                            | Picklist            | false    |        |                                                                                                                                                                                           |
|                                   | Title                                  |                     |          |        |                                                                                                                                                                                           |
|                                   | TitleType                              |                     |          |        |                                                                                                                                                                                           |

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

ContactCompactLayout.compactLayout-meta

### List views (metadata files)

AdSales.listView-meta, AllContacts.listView-meta, All_Contacts_Live_Accounts.listView-meta, MyContacts.listView-meta, X01_Mailing_Liste.listView-meta, X02_PM_CS_Admin_Contacts.listView-meta

### Web links

GoogleMaps.webLink-meta, GoogleSearch.webLink-meta

### Field sets

—

### Business processes

—

---

## Dependencies

- **Referenced objects (lookup targets):** —

---
