# Salesforce – Mirakl API Integration Documentation

## 1. Overview

This document explains how the Mirakl API integration was implemented in Salesforce using the modern authentication framework.
Offical Documentation Link: https://help.salesforce.com/s/articleView?id=platform.external_services_define_named_credential.htm&type=5

The integration uses:

- **External Credential** for authentication
- **Named Credential** for API endpoint configuration
- **OAuth 2.0 Client Credentials Flow**
- **Apex Invocable Class** to execute HTTP callouts

This approach follows Salesforce best practices introduced in Winter ’23 for secure external system authentication.

---

## 2. Integration Architecture

The integration follows the architecture below:

```
Salesforce Flow / Apex
        ↓
Invocable Apex Class
        ↓
Named Credential
        ↓
External Credential
        ↓
OAuth Token Endpoint
        ↓
Mirakl API
```

The authentication token is automatically managed by Salesforce through the External Credential.

---

## 3. External Credential

### 3.1 Purpose

The External Credential defines how Salesforce authenticates to Mirakl.

It stores the authentication configuration required to obtain an access token.

The External Credential contains:

- OAuth authentication protocol
- Token endpoint
- Client ID
- Client Secret
- Principal configuration
- Permission set mapping

This ensures that sensitive authentication information is stored securely and not exposed in Apex code.

### 3.2 Configuration Details

| Setting                                     | Value                                              |
| ------------------------------------------- | -------------------------------------------------- |
| **External Credential Name**                | `Mirakl_External_Auth`                             |
| **Authentication Protocol**                 | OAuth 2.0                                          |
| **Flow Type**                               | Client Credentials with Client Secret Flow         |
| **Token URL**                               | Example: `https://auth-dev.mirakl.net/oauth/token` |
| **Client ID**                               | Provided by Mirakl                                 |
| **Client Secret**                           | Provided by Mirakl                                 |
| **Pass Client Credentials in Request Body** | Enabled                                            |

### 3.3 Principal Configuration

A Named Principal was configured within the External Credential.

This principal stores:

- Client ID
- Client Secret

The principal is then granted access through a Permission Set.

---

## 4. Named Credential

### 4.1 Purpose

The Named Credential defines the base URL for the Mirakl API.

It also links the endpoint to the External Credential used for authentication.

This allows Apex code to make authenticated callouts without managing tokens manually.

### 4.2 Configuration Details

| Setting                   | Value                                       |
| ------------------------- | ------------------------------------------- |
| **Named Credential Name** | `Mirakl_Token`                              |
| **Base URL**              | Example: `https://limangode-dev.mirakl.net` |
| **External Credential**   | `Mirakl_External_Auth`                      |

Callouts are performed using:

```
callout:Mirakl_Token
```

Salesforce automatically attaches the OAuth access token when the callout is executed.

---

## 5. Why Both External Credential and Named Credential Are Required

Salesforce separates authentication from endpoint configuration.

| Component               | Responsibility                |
| ----------------------- | ----------------------------- |
| **External Credential** | Defines authentication method |
| **Named Credential**    | Defines API endpoint          |

This separation improves:

- Security
- Maintainability
- Reusability
- Token management

The authentication process is handled automatically by Salesforce when a callout is executed.

---

## 6. Permission Configuration

Proper permissions must be configured so that Salesforce can use the External Credential during runtime.

### 6.1 Permission Set

A permission set was created to grant access to the External Credential.

| Setting                 | Value               |
| ----------------------- | ------------------- |
| **Permission Set Name** | `Mirakl_API_Access` |

The permission set includes:

- Access to the External Credential
- Access to the configured Principal

**This permission set must be assigned to the user who executes the integration.**

Without this permission, Salesforce will not allow the callout to authenticate.

---

## 7. Apex Implementation

A reusable Apex class was implemented to perform API requests.

| Setting        | Value                   |
| -------------- | ----------------------- |
| **Class Name** | `LIM_Mirakl_Connection` |

This class:

- Uses Named Credential for authentication
- Supports multiple HTTP methods
- Handles request and response processing
- Is compatible with Salesforce Flow through `@InvocableMethod`
- Supports bulk execution

The class accepts input parameters such as:

- **HTTP Method**
- **Relative API Path**
- **Request Body** (optional)

Example API endpoint used:

```
/api/users/operators/roles
```

---

## 8. Authentication Flow (Runtime Behavior)

When the Apex class performs a callout:

```
callout:Mirakl_Token/api/users/operators/roles
```

Salesforce automatically performs the following steps:

1. Reads the Named Credential configuration.
2. Identifies the linked External Credential.
3. Sends a request to the OAuth token endpoint.
4. Retrieves the access token using Client ID and Client Secret.
5. Adds the access token to the Authorization header.
6. Sends the request to the Mirakl API.
7. Returns the API response to Salesforce.

This process is handled automatically without manual token management.

---

## 9. Error Handling

The Apex class includes structured error handling.

For each request the following information is returned:

- **Success** flag
- **HTTP status code**
- **Response body**
- **Error message**

The integration handles:

| Status Code | Meaning              |
| ----------- | -------------------- |
| 200–299     | Successful request   |
| 401         | Unauthorized request |
| 403         | Access forbidden     |
| 500         | Server error         |

If an exception occurs during the callout, it is captured and returned in the response object.

---

## 10. Testing

A dedicated test class was created to validate the integration.

| Setting        | Value                        |
| -------------- | ---------------------------- |
| **Test Class** | `LIM_Mirakl_Connection_Test` |

The test class uses **HttpCalloutMock** to simulate Mirakl API responses.

---

## Note to You – Steps to Follow

When you see this document, use it as your checklist to set up or verify the Mirakl API integration:

1. **External Credential**  
   In Setup → External Credentials, create or verify `Mirakl_External_Auth`: OAuth 2.0, Client Credentials, Token URL, and a Principal with Client ID + Client Secret.

2. **Named Credential**  
   In Setup → Named Credentials, create or verify `Mirakl_Token`: set Base URL and link it to `Mirakl_External_Auth`.

3. **Permission Set**  
   Create or verify `Mirakl_API_Access` with access to the External Credential and Principal, and assign it to users who run the integration.

4. **Apex**  
   Deploy/use `LIM_Mirakl_Connection` (and `LIM_Mirakl_Connection_Test` with `HttpCalloutMock`) so callouts use `callout:Mirakl_Token` + relative path.

5. **Flow / Caller**  
   Call the Invocable method from Flow or Apex with HTTP Method, Relative Path, and optional Request Body.

If something fails, check: credential names, token URL, principal, permission set assignment, and that the Apex class uses the same Named Credential name (`Mirakl_Token`).
