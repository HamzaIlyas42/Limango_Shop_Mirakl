# Named Credential & External Credential – Setup Spec

```
You are a Salesforce metadata developer.

I have added this spec file to the project: named_credential_spec.md

Before generating any files, ask me these 5 questions one by one and wait for Test or Production answers before proceeding:

1. What is the Customer / Prefix name?
   ({Customer_Name} — used for all file and credential naming)

2. What is the Test – Auth (token) URL?
   (e.g. https://google-token.com — used as Identity Provider URL in External Credential Test)

3. What is the Test – API base URL?
   (e.g. https://google.com — used as URL in Named Credential Test)

4. What is the Production – Auth (token) URL?
   (e.g. https://google.com — used as Identity Provider URL in External Credential Production)

5. What is the Production – API base URL?
   (e.g. https://google.com — used as URL in Named Credential Production)

Do NOT generate anything until I have answered Customer Name or Test Or Production questions.

Once I answer, replace every placeholder and generate exactly these 4 files following the spec in named_credential_spec.md:

  1. force-app/main/default/namedCredentials/{CustomerName}_Test.namedCredential-meta.xml
  2. force-app/main/default/namedCredentials/{CustomerName}_Production.namedCredential-meta.xml
  3. force-app/main/default/externalCredentials/{CustomerName}_External_Test.externalCredential-meta.xml
  4. force-app/main/default/externalCredentials/{CustomerName}_External_Production.externalCredential-meta.xml

Create folders namedCredentials and externalCredentials if they do not exist.
If they already exist, only create or update the files inside — do not recreate the folders.
```

---

## Placeholders Reference

| Placeholder      | Provided by user            | Example              |
| ---------------- | --------------------------- | -------------------- |
| `{CustomerName}` | Customer / Prefix name      | `{Customer_Name}`    |
| `{TestAuthURL}`  | Test Auth (token) URL       | `https://google.com` |
| `{TestApiURL}`   | Test API base URL           | `https://google.com` |
| `{ProdAuthURL}`  | Production Auth (token) URL | `https://google.com` |
| `{ProdApiURL}`   | Production API base URL     | `https://google.com` |

---

## Resulting File Names

| Type                           | File Name                                                        |
| ------------------------------ | ---------------------------------------------------------------- |
| Named Credential Test          | `{CustomerName}_Test.namedCredential-meta.xml`                   |
| Named Credential Production    | `{CustomerName}_Production.namedCredential-meta.xml`             |
| External Credential Test       | `{CustomerName}_External_Test.externalCredential-meta.xml`       |
| External Credential Production | `{CustomerName}_External_Production.externalCredential-meta.xml` |

---

## 1. Named Credential – Test

**Path:** `force-app/main/default/namedCredentials/{CustomerName}_Test.namedCredential-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{CustomerName} Test</label>
    <name>{CustomerName}_Test</name>
    <url>{TestApiURL}</url>
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <generateAuthorizationHeader>true</generateAuthorizationHeader>
    <externalCredential>{CustomerName}_External_Test</externalCredential>
</NamedCredential>
```

---

## 2. Named Credential – Production

**Path:** `force-app/main/default/namedCredentials/{CustomerName}_Production.namedCredential-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{CustomerName} Production</label>
    <name>{CustomerName}_Production</name>
    <url>{ProdApiURL}</url>
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <generateAuthorizationHeader>true</generateAuthorizationHeader>
    <externalCredential>{CustomerName}_External_Production</externalCredential>
</NamedCredential>
```

---

## 3. External Credential – Test

**Path:** `force-app/main/default/externalCredentials/{CustomerName}_External_Test.externalCredential-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{CustomerName} External Test</label>
    <name>{CustomerName}_External_Test</name>
    <authenticationProtocol>OAuth</authenticationProtocol>
    <principalType>NamedPrincipal</principalType>
    <principals>
        <principalName>{CustomerName}_Test</principalName>
        <sequenceNumber>1</sequenceNumber>
    </principals>
    <oauthFlow>ClientCredentials</oauthFlow>
    <identityProviderUrl>{TestAuthURL}</identityProviderUrl>
</ExternalCredential>
```

---

## 4. External Credential – Production

**Path:** `force-app/main/default/externalCredentials/{CustomerName}_External_Production.externalCredential-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{CustomerName} External Production</label>
    <name>{CustomerName}_External_Production</name>
    <authenticationProtocol>OAuth</authenticationProtocol>
    <principalType>NamedPrincipal</principalType>
    <principals>
        <principalName>{CustomerName}_Production</principalName>
        <sequenceNumber>1</sequenceNumber>
    </principals>
    <oauthFlow>ClientCredentials</oauthFlow>
    <identityProviderUrl>{ProdAuthURL}</identityProviderUrl>
</ExternalCredential>
```

---

## 5. Safety Rules

| #   | Rule                                                                                                                                                           |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Never hardcode URLs — always use placeholders replaced by user answers                                                                                         |
| 2   | Named Credential always references its External Credential via `<externalCredential>`                                                                          |
| 3   | External Credential always uses `ClientCredentials` OAuth flow                                                                                                 |
| 4   | Principal name matches the Named Credential name (Test → Test, Production → Production)                                                                        |
| 5   | Folder naming: `namedCredentials` and `externalCredentials` — exact casing, no variation                                                                       |
| 6   | File naming: `{CustomerName}_Test`, `{CustomerName}_Production`, `{CustomerName}_External_Test`, `{CustomerName}_External_Production` — single underscore only |
