# LIM_Contract_MiraklCheckChanges

**Type:** AutoLaunchedFlow | **Status:** Active | **API Version:** 64.0 | **Object/Trigger:** — / —

---

## Summary

The flow "LIM_Contract_MiraklCheckChanges" is a AutoLaunchedFlow flow (status Active). It does not use a record-triggered start element in metadata, or runs as screen/autolaunched/scheduled per its configuration. The automation includes 2 decision element(s) that branch execution based on configured conditions.

---

## Flow / Component Diagram

```mermaid
graph TD
  E_Start["Start"]
  E_ifContractChanged["ifContractChanged"]
  E_ifRelevant["ifRelevant"]
  E_setError["setError"]
  E_Start -->|"start"| E_ifRelevant
  E_ifContractChanged -->|"ContractChanged"| E_setError
  E_ifRelevant -->|"ContractRelevant"| E_ifContractChanged
```

---

## Technical Details

### Variables

| Name             | Type    | Input | Output | Default |
| ---------------- | ------- | ----- | ------ | ------- |
| recContract      | SObject | True  | True   |         |
| recContractPrior | SObject | True  | False  |         |
| varErrorMessage  | String  | False | True   |         |

### Decision Elements

#### ifContractChanged

- **Default:** → `—` (ContractNotChanged)
- **Rule:** ContractChanged → `setError`
    - Condition logic: `or`
    - `recContract.AccountId` NotEqualTo `elementReference:recContractPrior.AccountId`

#### ifRelevant

- **Default:** → `—` (ContractNotRelevant)
- **Rule:** ContractRelevant → `ifContractChanged`
    - Condition logic: `and`
    - `recContract.Status` EqualTo `stringValue:Activated`
    - `recContract.ContractVisiblityCriteria__c` EqualTo `stringValue:Marketplace`
    - `recContract.Backend__c` EqualTo `stringValue:Mirakl`
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
