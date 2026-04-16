# Lim_Mirakl_Test.namedCredential-meta.xml

**Type:** NamedCredential (Metadata) | **Path:** `Lim_Mirakl_Test.namedCredential-meta.xml` | **Kind:** xml

---

## Summary

The org defines a **Named Credential** named **Lim_Mirakl_Test** so that declarative and programmatic integrations can call an external HTTP endpoint **without embedding secrets in code**. It is configured as **`SecuredEndpoint`**, with **callout status `Enabled`**, meaning callouts that reference this named credential are **allowed**. The **target endpoint** for the integration is **`https://limangode-dev.mirakl.net`** (often the base URL for OAuth or API calls). **Merge fields** in HTTP body are **allowed**; in headers **allowed**. The platform **will** auto-generate an **Authorization** header when the auth model requires it. Downstream, **Flows, Apex, OmniStudio, or integration features** that reference this named credential by API name will use these settings for every outbound request unless overridden.

_A **Named Credential** is a named connection definition Salesforce uses for **secure outbound HTTP callouts** (from Apex `HttpRequest`, Flows, External Services, Einstein, etc.) to external APIs. Instead of hard-coding URLs and secrets in code, integrations reference this component by **label/API name**. It typically stores the **endpoint URL**, whether **merge fields** are allowed in headers/body, whether an **Authorization header** is auto-generated, and links to an **External Credential** (or other auth model) for OAuth/API keys. **Callout status** controls whether callouts using this definition are allowed._

---

## Technical Details

### All simple (leaf) properties

| Property                      | Value           |
| ----------------------------- | --------------- |
| `allowMergeFieldsInBody`      | true            |
| `allowMergeFieldsInHeader`    | true            |
| `calloutStatus`               | Enabled         |
| `generateAuthorizationHeader` | true            |
| `label`                       | Lim_Mirakl_Test |
| `namedCredentialType`         | SecuredEndpoint |

### All values (including nested paths)

| Path                                                           | Value                            |
| -------------------------------------------------------------- | -------------------------------- |
| `NamedCredential.allowMergeFieldsInBody`                       | true                             |
| `NamedCredential.allowMergeFieldsInHeader`                     | true                             |
| `NamedCredential.calloutStatus`                                | Enabled                          |
| `NamedCredential.generateAuthorizationHeader`                  | true                             |
| `NamedCredential.label`                                        | Lim_Mirakl_Test                  |
| `NamedCredential.namedCredentialParameters.parameterName`      | Url                              |
| `NamedCredential.namedCredentialParameters.parameterType`      | Url                              |
| `NamedCredential.namedCredentialParameters.parameterValue`     | https://limangode-dev.mirakl.net |
| `NamedCredential.namedCredentialParameters.externalCredential` | Lim_Mirakl_External_Test         |
| `NamedCredential.namedCredentialParameters.parameterName`      | ExternalCredential               |
| `NamedCredential.namedCredentialParameters.parameterType`      | Authentication                   |
| `NamedCredential.namedCredentialType`                          | SecuredEndpoint                  |

---

## Dependencies

- **NamedCredential.allowMergeFieldsInBody:** `true`
- **NamedCredential.allowMergeFieldsInHeader:** `true`
- **NamedCredential.calloutStatus:** `Enabled`
- **NamedCredential.generateAuthorizationHeader:** `true`
- **NamedCredential.label:** `Lim_Mirakl_Test`
- **NamedCredential.namedCredentialParameters.parameterName:** `Url`
- **NamedCredential.namedCredentialParameters.parameterType:** `Url`
- **NamedCredential.namedCredentialParameters.parameterValue:** `https://limangode-dev.mirakl.net`
- **NamedCredential.namedCredentialParameters.externalCredential:** `Lim_Mirakl_External_Test`
- **NamedCredential.namedCredentialParameters.parameterName:** `ExternalCredential`
- **NamedCredential.namedCredentialParameters.parameterType:** `Authentication`
- **NamedCredential.namedCredentialType:** `SecuredEndpoint`

---
