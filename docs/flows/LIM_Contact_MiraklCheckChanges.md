# LIM_Contact_MiraklCheckChanges

**Type:** AutoLaunchedFlow | **Status:** Active | **API Version:** 64.0 | **Object/Trigger:** — / —

---

## Summary

The flow "LIM_Contact_MiraklCheckChanges" is a AutoLaunchedFlow flow (status Active). It does not use a record-triggered start element in metadata, or runs as screen/autolaunched/scheduled per its configuration. The automation includes 2 decision element(s) that branch execution based on configured conditions.

---

## Flow / Component Diagram

```mermaid
graph TD
  E_Start["Start"]
  E_ifContactChanged["ifContactChanged"]
  E_ifRelevant["ifRelevant"]
  E_setError["setError"]
  E_Start -->|"start"| E_ifRelevant
  E_ifContactChanged -->|"ContactChanged"| E_setError
  E_ifRelevant -->|"ContactRelevant"| E_ifContactChanged
```

---

## Technical Details

### Variables

| Name            | Type    | Input | Output | Default |
| --------------- | ------- | ----- | ------ | ------- |
| recContact      | SObject | True  | True   |         |
| recContactPrior | SObject | True  | False  |         |
| varErrorMessage | String  | True  | True   |         |

### Decision Elements

#### ifContactChanged

- **Default:** → `—` (ContactNotChanged)
- **Rule:** ContactChanged → `setError`
    - Condition logic: `or`
    - `recContact.Email` NotEqualTo `elementReference:recContactPrior.Email`
    - `recContact.FirstName` NotEqualTo `elementReference:recContactPrior.FirstName`
    - `recContact.LastName` NotEqualTo `elementReference:recContactPrior.LastName`
    - `recContact.Title` NotEqualTo `elementReference:recContactPrior.Title`

#### ifRelevant

- **Default:** → `—` (ContactNotRelevant)
- **Rule:** ContactRelevant → `ifContactChanged`
    - Condition logic: `and`
    - `recContact.Account.Backend__c` EqualTo `stringValue:Mirakl`
    - `recContact.RoleMarketplace__c` Contains `stringValue:Mirakl Invitation`
    - `$Permission.MiraklIntegration` EqualTo `booleanValue:false`

### Record Operations

#### Lookups

| Name | Object | Fault path | Filter logic |
| ---- | ------ | ---------- | ------------ |
| —    | —      | —          | —            |

#### Creates

| Name | Object | Fault path | Filter logic |
| ---- | ------ | ---------- | ------------ |
| —    | —      | —          | —            |

#### Updates

| Name | Object | Fault path | Filter logic |
| ---- | ------ | ---------- | ------------ |
| —    | —      | —          | —            |

#### Deletes

| Name | Object | Fault path | Filter logic |
| ---- | ------ | ---------- | ------------ |
| —    | —      | —          | —            |

### Record field assignments (creates and updates)

—

### Actions

| Name | Action | Type | Fault |
| ---- | ------ | ---- | ----- |
| —    | —      | —    | —     |

### Subflows

| Name | Called flow | Fault |
| ---- | ----------- | ----- |
| —    | —           | —     |

### Fault paths

Elements referencing a fault connector are listed in the Record Operations and Actions tables above.

---

## Dependencies

- **Objects:** —
- **Subflows:** —
- **Apex / invocable actions:** —

---
