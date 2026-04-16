# Lim_Mirakl_External_Test.externalCredential-meta.xml

**Type:** ExternalCredential (Metadata) | **Path:** `Lim_Mirakl_External_Test.externalCredential-meta.xml` | **Kind:** xml

---

## Summary

In this deployment file, the key settings include: **authenticationProtocol** = `Oauth`, **label** = `Lim_Mirakl_External_Test`.

**External Credential** holds **authentication material and handshake settings** (OAuth, JWT, API keys, certificates) that Named Credentials and other features use. It does not usually store the API URL by itself—that is often on the Named Credential—while this component defines **how** Salesforce authenticates to the external system.

---

## Technical Details

### All simple (leaf) properties

| Property                 | Value                    |
| ------------------------ | ------------------------ |
| `authenticationProtocol` | Oauth                    |
| `label`                  | Lim_Mirakl_External_Test |

### All values (including nested paths)

| Path                                                             | Value                                   |
| ---------------------------------------------------------------- | --------------------------------------- |
| `ExternalCredential.authenticationProtocol`                      | Oauth                                   |
| `ExternalCredential.externalCredentialParameters.parameterGroup` | DefaultGroup                            |
| `ExternalCredential.externalCredentialParameters.parameterName`  | Oauth                                   |
| `ExternalCredential.externalCredentialParameters.parameterType`  | AuthProtocolVariant                     |
| `ExternalCredential.externalCredentialParameters.parameterValue` | ClientCredentialsClientSecret           |
| `ExternalCredential.externalCredentialParameters.parameterGroup` | DefaultGroup                            |
| `ExternalCredential.externalCredentialParameters.parameterName`  | AuthProviderUrl                         |
| `ExternalCredential.externalCredentialParameters.parameterType`  | AuthProviderUrl                         |
| `ExternalCredential.externalCredentialParameters.parameterValue` | https://auth-dev.mirakl.net/oauth/token |
| `ExternalCredential.externalCredentialParameters.parameterGroup` | Lim_Mirakl_Test                         |
| `ExternalCredential.externalCredentialParameters.parameterName`  | Lim_Mirakl_Test                         |
| `ExternalCredential.externalCredentialParameters.parameterType`  | NamedPrincipal                          |
| `ExternalCredential.externalCredentialParameters.sequenceNumber` | 1                                       |
| `ExternalCredential.label`                                       | Lim_Mirakl_External_Test                |

---

## Dependencies

- **ExternalCredential.authenticationProtocol:** `Oauth`
- **ExternalCredential.externalCredentialParameters.parameterGroup:** `DefaultGroup`
- **ExternalCredential.externalCredentialParameters.parameterName:** `Oauth`
- **ExternalCredential.externalCredentialParameters.parameterType:** `AuthProtocolVariant`
- **ExternalCredential.externalCredentialParameters.parameterValue:** `ClientCredentialsClientSecret`
- **ExternalCredential.externalCredentialParameters.parameterName:** `AuthProviderUrl`
- **ExternalCredential.externalCredentialParameters.parameterType:** `AuthProviderUrl`
- **ExternalCredential.externalCredentialParameters.parameterValue:** `https://auth-dev.mirakl.net/oauth/token`
- **ExternalCredential.externalCredentialParameters.parameterGroup:** `Lim_Mirakl_Test`
- **ExternalCredential.externalCredentialParameters.parameterName:** `Lim_Mirakl_Test`
- **ExternalCredential.externalCredentialParameters.parameterType:** `NamedPrincipal`
- **ExternalCredential.externalCredentialParameters.sequenceNumber:** `1`
- **ExternalCredential.label:** `Lim_Mirakl_External_Test`

---
