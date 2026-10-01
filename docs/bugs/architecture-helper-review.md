# DelphiAPIStarterKit Architecture, Helper, and Security Review

## Document status

- Status: Open
- Review date: 2026-09-15
- Review type: Static source review
- Scope: WebBroker entry point, routing, request parsing, response generation, authentication, authorization, services, repositories, helpers, database lifecycle, logging, and test readiness
- Source-change scope: Documentation only
- Build/runtime status: Not validated in this review because `DELPHI_RSVARS` and `BDS` were not available in the review shell

## Executive assessment

The project already has a useful modular direction:

```text
WebBroker WebModule
  -> REST endpoint
  -> Validator
  -> Service
  -> Repository
  -> FireDAC connection
```

The folders under `sources/modules` consistently separate endpoint, DTO, validator, service, and repository units. SQL is generally parameterized, write operations generally use explicit transactions, and each request obtains its own FireDAC connection from a pooled connection definition.

The project is therefore suitable as an architectural baseline, but it is not yet safe to present as a production-ready starter. The highest risks are missing role-based authorization, insecure refresh-session behavior, plaintext password exposure in a successful response, and an unsuitable password-hashing strategy. The core request/response and helper layers also contain implicit behavior that makes API contracts difficult to predict.

The recommended direction is incremental hardening. Preserve the current module layout, close the security and contract defects first, and only then simplify the helper and router infrastructure.

## Finding classification

- `CONFIRMED`: The behavior is directly visible in the current source.
- `CONTEXT-DEPENDENT`: The source contains the risk, but deployment controls such as a reverse proxy may reduce its runtime impact.
- `Critical`: Can enable account takeover, privilege escalation, or equivalent system-wide compromise.
- `High`: Can expose credentials, bypass an important security boundary, or materially affect availability.
- `Medium`: Can break API contracts, weaken diagnostics, produce resource leaks, or create significant maintenance risk.

## Findings and recommendations

### DASK-SEC-001 - User administration has authentication but no authorization

- Severity: Critical
- Classification: CONFIRMED
- Area: Authorization and privilege management

#### Evidence

- [`RestAPI.User.pas:32-57`](../../sources/modules/users/RestAPI.User.pas#L32-L57) enables authentication for the complete User resource but defines no role or permission requirement.
- [`BFA.Core.Endpoint.pas:97-136`](../../sources/core/BFA.Core.Endpoint.pas#L97-L136) verifies only that a valid token resolves to an active user.
- [`User.Service.pas:225-275`](../../sources/modules/users/User.Service.pas#L225-L275) permits creation of a user with a caller-supplied role.
- [`User.Service.pas:290-350`](../../sources/modules/users/User.Service.pas#L290-L350) permits password reset for a target user and returns the generated temporary password.
- [`User.Service.pas:355-433`](../../sources/modules/users/User.Service.pas#L355-L433) permits password, active-state, and role changes for a target user.
- [`users.md:310-316`](../api/users.md#L310-L316) describes password reset as an administrator operation, but the implementation does not enforce that requirement.

#### Problem

Authentication proves who the caller is, but the current endpoint does not determine what the caller may do. Every authenticated account can reach user-management operations. The existing role data in the database is stored and returned but is not used as an authorization policy.

#### Impact

An ordinary authenticated user can potentially:

- Create another user with a privileged role.
- Change the role or active status of another account.
- Set another user's password through the update endpoint.
- Reset another user's password and receive the temporary password.
- Soft-delete other users, including administrators.

This is a direct privilege-escalation and account-takeover path.

#### Recommended remediation

1. Introduce a per-request authentication context, for example:

   ```text
   TAuthContext
     UserInternalID
     UserID
     RoleInternalID
     RoleName
     IsSuperAdmin
     Permissions
     SessionInternalID
   ```

2. Resolve the context once after token validation. Do not execute a second token lookup inside individual services.
3. Attach an explicit authorization policy to every route. Recommended initial policies:
   - `User.Get`, `User.Insert`, `User.Update`, `User.Delete`, and `User.ResetPassword`: `users.manage` or super-admin.
   - `User.ChangePassword`: any authenticated user, but only for the authenticated account.
4. Separate self-service operations from administrative operations. A simple boundary is:
   - `POST /User/ChangePassword` for the current user.
   - Administrative User CRUD and reset actions guarded by `users.manage`.
5. Return HTTP 401 only when authentication is missing or invalid.
6. Return HTTP 403 when authentication succeeds but the permission is insufficient.
7. Add safeguards against deleting or disabling the last super-administrator if the starter intends to support that invariant.

#### Acceptance criteria

- [ ] An unauthenticated request receives HTTP 401.
- [ ] An authenticated non-admin receives HTTP 403 for every user-management route.
- [ ] A normal user can change only their own password and must provide the current password.
- [ ] Only an authorized administrator can change roles, active state, or another user's password.
- [ ] Authorization tests cover allow and deny cases for every User action.

### DASK-SEC-002 - ChangePassword returns plaintext password fields

- Severity: High
- Classification: CONFIRMED
- Area: Sensitive data exposure and API contract

#### Evidence

- [`User.Service.pas:73-129`](../../sources/modules/users/User.Service.pas#L73-L129) keeps `old_password` and `new_password` inside `FData`, then passes `FData` to the success response.
- [`BFA.Core.Response.pas:434-453`](../../sources/core/BFA.Core.Response.pas#L434-L453) serializes the supplied dataset into the response `data` array for successful status codes.
- [`users.md:285-293`](../api/users.md#L285-L293) documents an empty `data` array for this operation.

#### Problem

The response helper does not know whether a dataset represents a response payload or the original request. Passing `FData` as `ADataResponse` causes request credentials to be serialized back to the caller.

#### Impact

The old and new plaintext password can be captured by:

- Client-side logs or debug consoles.
- HTTP tracing and observability middleware.
- Reverse-proxy access capture.
- Error-reporting and session-replay products.
- Automated API-test artifacts.

#### Recommended remediation

1. Return a no-data success response from `ChangePassword`.
2. Make the no-data response contract produce `data: []` for HTTP 2xx.
3. Do not pass request datasets to a response payload overload.
4. If `request_detail` remains supported, make it opt-in and apply a mandatory sensitive-field redaction list that includes password, token, authorization, secret, and credential fields.
5. Add a response-level regression test that searches the complete JSON response for both submitted password values.

#### Acceptance criteria

- [ ] Neither password appears anywhere in the response body.
- [ ] Neither password appears in server logs.
- [ ] Successful password change returns `data: []`.
- [ ] A regression test fails if a sensitive request field is serialized.

### DASK-SEC-003 - Session ID and device ID function as an unprotected refresh credential

- Severity: High
- Classification: CONFIRMED
- Area: Session and token lifecycle

#### Evidence

- [`RestAPI.Auth.pas:32-56`](../../sources/modules/auth/RestAPI.Auth.pas#L32-L56) does not require authentication for Login, Logout, or Refresh.
- [`Auth.Service.pas:173-200`](../../sources/modules/auth/Auth.Service.pas#L173-L200) revokes a session using only `session_id` and `device_id`.
- [`Auth.Service.pas:203-246`](../../sources/modules/auth/Auth.Service.pas#L203-L246) issues a new access token after validating only `session_id` and `device_id`.
- [`Auth.Repository.pas:158-186`](../../sources/modules/auth/Auth.Repository.pas#L158-L186) performs the session lookup without a refresh-token proof.
- [`auth.md:107-147`](../api/auth.md#L107-L147) confirms that no separate refresh token is part of the documented contract.

#### Problem

`session_id` should identify a session, not authorize creation of new credentials. `device_id` is client-controlled metadata and is not an authentication factor. Together they currently behave as a reusable bearer credential stored as ordinary session data.

#### Impact

Anyone who obtains the session ID and device ID can mint access tokens until the session expires. The same values can be used to revoke a session without proving ownership, creating an account-level denial of service.

#### Recommended remediation

1. Generate a separate high-entropy refresh token during login.
2. Return the raw refresh token only once to the client and store only its hash server-side.
3. Associate the refresh-token record with the internal session ID, expiry, revocation state, token family, and rotation metadata.
4. On refresh:
   - Hash and validate the supplied refresh token.
   - Verify session and user active state.
   - Revoke or consume the previous refresh token.
   - Issue a new access token and a rotated refresh token in one transaction.
5. Detect reuse of an already-rotated refresh token and revoke the complete token family.
6. Require a valid access token for logout and verify that the authenticated context owns the session being revoked.
7. Derive IP address and user-agent information from the trusted server request boundary. Do not allow request JSON to override audit values.

#### Acceptance criteria

- [ ] Session ID alone cannot produce an access token.
- [ ] Refresh requires a valid, unexpired, unrevoked refresh token.
- [ ] A successful refresh invalidates the previous refresh token.
- [ ] Refresh-token reuse revokes the affected token family.
- [ ] Logout cannot revoke another user's session.
- [ ] Access and refresh tokens are never stored in plaintext in the database or logs.

### DASK-SEC-004 - Password hashing uses fast HMAC-SHA256 with one shared secret

- Severity: High
- Classification: CONFIRMED
- Area: Credential storage

#### Evidence

- [`BFA.Helper.Strings.pas:241-267`](../../sources/shared/helpers/BFA.Helper.Strings.pas#L241-L267) implements a shared-secret HMAC-SHA256 helper.
- [`Auth.Service.pas:106-121`](../../sources/modules/auth/Auth.Service.pas#L106-L121) uses the helper directly to verify passwords.
- [`User.Service.pas:249-256`](../../sources/modules/users/User.Service.pas#L249-L256) uses the same helper when creating a user.
- [`User.Service.pas:319-328`](../../sources/modules/users/User.Service.pas#L319-L328) and [`User.Service.pas:392-400`](../../sources/modules/users/User.Service.pas#L392-L400) use it for reset and update operations.

#### Problem

HMAC-SHA256 is appropriate for hashing high-entropy access tokens, but it is intentionally fast and therefore unsuitable as a password-storage algorithm. One shared secret also means all password hashes depend on the same application secret and have no unique per-user salt visible in the stored representation.

#### Impact

If password hashes and the application secret are exposed, password guessing can be performed much faster than with a password-specific key derivation function. Reuse of the helper for both tokens and passwords also makes secret rotation and security review harder.

#### Recommended remediation

1. Create a focused password hasher using Argon2id, bcrypt, or PBKDF2 with:
   - A unique cryptographically random salt per password.
   - A configurable work factor.
   - A versioned stored format such as `algorithm$parameters$salt$hash`.
2. Keep token hashing separate. HMAC-SHA256 may remain for random access/refresh tokens when it uses a dedicated token-hash secret.
3. Use a constant-time comparison for credential hashes.
4. Implement backward-compatible migration:
   - Recognize existing legacy HMAC hashes.
   - Verify them only during login.
   - Rehash the password with the new algorithm after successful legacy verification.
5. Do not require a forced reset of every account unless operational policy prefers that approach.
6. Remove or clearly quarantine the reversible `Encrypt`, `Decrypt`, `EncodeCrypt`, and `DecodeCrypt` methods. They must not be presented as security primitives.

#### Acceptance criteria

- [ ] Newly created and changed passwords use the approved password KDF.
- [ ] Every password hash has a unique salt.
- [ ] Legacy hashes can be migrated without exposing plaintext outside the login operation.
- [ ] Access-token hashing and password hashing use separate code and secrets.
- [ ] No production path uses the reversible character-shift encryption methods.

### DASK-SEC-005 - Request parsing has no application-level JSON body limit

- Severity: High
- Classification: CONTEXT-DEPENDENT
- Area: Resource exhaustion and input validation

#### Evidence

- [`App.WebModule.pas:75-92`](../../sources/app/App.WebModule.pas#L75-L92) passes every non-multipart request body directly to the core parser without checking body size or requiring a JSON content type.
- [`BFA.Core.Config.pas:8-12`](../../sources/core/BFA.Core.Config.pas#L8-L12) defines only a file-size limit.
- [`BFA.Helper.Dataset.pas:48-100`](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L48-L100) accepts either JSON objects or arrays and builds a dynamic memory table from client input.
- [`BFA.Helper.Dataset.pas:281-307`](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L281-L307) assigns a default string capacity of 250,000 characters when an actual size is unavailable.
- [`BFA.Helper.Dataset.pas:319-388`](../../sources/shared/helpers/BFA.Helper.Dataset.pas#L319-L388) derives array schemas from client-controlled object fields and their positions.

#### Problem

The application has no visible maximum JSON body size, maximum field count, or maximum nesting depth. Empty or null string fields can receive very large memory-table field capacities. Array bodies are accepted even though the current endpoints are single-object operations.

An upstream reverse proxy may provide a body limit, but the application must not rely on an undocumented external control.

#### Impact

Large or specially shaped requests can consume significant memory and CPU per request. Concurrent requests can amplify this into service degradation or process termination.

#### Recommended remediation

1. Add a configurable `MAX_JSON_BODY_SIZE` and reject oversized bodies with HTTP 413 before parsing.
2. Require `application/json` for JSON endpoints and return HTTP 415 for unsupported content types.
3. Reject JSON arrays unless a specific batch endpoint explicitly permits them.
4. Prefer parsing a `TJSONObject` directly into a typed request DTO.
5. Define maximum field lengths in validators before allocating large intermediate structures.
6. If `TFDMemTable` must remain temporarily:
   - Cap field count and field size.
   - Do not use 250,000 characters as a default for empty values.
   - Reject heterogeneous arrays.
   - Do not infer the schema by property position.
7. Configure an equivalent or stricter body limit at the reverse proxy.

#### Acceptance criteria

- [ ] Oversized requests consistently return HTTP 413.
- [ ] Invalid content types return HTTP 415.
- [ ] Invalid JSON returns HTTP 400 with the standard response envelope.
- [ ] Non-batch endpoints reject root JSON arrays.
- [ ] Load tests demonstrate bounded memory use for rejected requests.

### DASK-API-006 - Response serialization infers types from string contents

- Severity: Medium
- Classification: CONFIRMED
- Area: API contract correctness

#### Evidence

- [`BFA.Core.Response.pas:181-214`](../../sources/core/BFA.Core.Response.pas#L181-L214) converts numeric-looking strings into JSON numbers and JSON-looking strings into nested objects or arrays.
- [`BFA.Core.Response.pas:471-519`](../../sources/core/BFA.Core.Response.pas#L471-L519) uses one-element object arrays for some responses and relies on the same inference for key/value DTOs.
- [`Auth.DTO.pas:33-45`](../../sources/modules/auth/Auth.DTO.pas#L33-L45), [`Product.DTO.pas:47-63`](../../sources/modules/products/Product.DTO.pas#L47-L63), and [`Category.DTO.pas:34-45`](../../sources/modules/category/Category.DTO.pas#L34-L45) represent typed response values through `TStringList`.
- [`Customer.DTO.pas:59-82`](../../sources/modules/customers/Customer.DTO.pas#L59-L82) uses a different JSON-object construction strategy, showing that the DTO boundary is not yet consistent.

#### Problem

The serializer decides JSON types from text rather than from the DTO or dataset field type. A string such as an account code, postal code, external reference, scientific-looking value, or JSON document can change type without the endpoint explicitly requesting that behavior.

The no-payload success behavior also differs from documented examples that use `data: []`.

#### Impact

- Client contracts can change based on data values.
- Generated clients may fail deserialization.
- Numeric identifiers may lose formatting or precision.
- String fields containing JSON may unexpectedly become structured data.
- Postman examples and runtime output can diverge.

#### Recommended remediation

1. Define explicit response entry points:
   - `CreateEmptySuccess`
   - `CreateObjectResponse`
   - `CreateArrayResponse`
   - `CreateErrorResponse`
2. Preserve types from `TField.DataType` when serializing datasets.
3. Build DTO output with typed `TJSONValue` instances rather than `TStringList` inference.
4. Parse nested JSON only through an explicitly named API such as `AddRawJSON`, never automatically.
5. Standardize no-data contracts:
   - HTTP 2xx without payload: `data: []`.
   - Non-2xx: `data: [{}]` as required by the project contract.
6. Treat `request_detail` as a separate optional concern, not another response overload argument.

#### Acceptance criteria

- [ ] String values remain strings regardless of their contents.
- [ ] Integer, decimal, Boolean, null, object, and array output types are explicit.
- [ ] Every no-data success returns `data: []`.
- [ ] Every non-success response returns `data: [{}]`.
- [ ] Documentation and Postman examples match serialized runtime output.

### DASK-ARCH-007 - Reflection-based routing is implicit and weakly typed

- Severity: Medium
- Classification: CONFIRMED
- Area: Routing and maintainability

#### Evidence

- [`BFA.Core.Rest.pas:152-175`](../../sources/core/BFA.Core.Rest.pas#L152-L175) constructs a class name from URL values and resolves it through the Delphi class registry.
- [`BFA.Core.Rest.pas:178-240`](../../sources/core/BFA.Core.Rest.pas#L178-L240) resolves `Route` with `MethodAddress` and casts it to a function signature.
- [`BFA.Core.Rest.pas:247-255`](../../sources/core/BFA.Core.Rest.pas#L247-L255) separately maintains the list of registered resource classes.
- [`BFA.Core.Helper.pas:106-166`](../../sources/core/BFA.Core.Helper.pas#L106-L166) exposes published service methods through name-based RTTI resolution.
- [`BFA.Core.Helper.pas:11-17`](../../sources/core/BFA.Core.Helper.pas#L11-L17) declares `APIResourceAttribute`, but the router does not use the attribute value.

#### Problem

The effective route contract is distributed across URL naming conventions, class names, published method names, endpoint arrays, and manual class registration. Signature mismatches and accidental publication are detected late. The attribute suggests a metadata-driven router but currently has no functional effect.

Unknown resource classes may also pass through exception handling intended for internal failures instead of producing a deterministic 404 response.

#### Recommended remediation

1. Introduce one explicit route registry containing:
   - HTTP method.
   - Path template.
   - Authentication requirement.
   - Authorization policy.
   - Handler callback.
2. Keep WebModule dispatch thin and make the registry the single source of truth.
3. Choose one of these options:
   - Use `APIResource` and route attributes as actual registry input with signature validation at startup.
   - Remove the unused attributes and register routes directly in code.
4. Avoid calling service methods through `MethodAddress` strings.
5. Return deterministic errors:
   - Unknown resource/path: 404.
   - Known path with unsupported method: 405.
   - Invalid JSON: 400.
   - Unexpected server failure: 500.
6. Validate all route registrations during application startup and fail fast on duplicates.

#### Acceptance criteria

- [ ] All routes can be listed from one registry.
- [ ] Duplicate method/path combinations fail during startup.
- [ ] No service method becomes remotely callable merely because it is published.
- [ ] Unknown resources return 404, not 500.
- [ ] Route tests cover 404, 405, 401, and 403 independently.

### DASK-SEC-008 - Development and file endpoints are publicly registered

- Severity: Medium
- Classification: CONFIRMED for `/test`; CONTEXT-DEPENDENT for `/image` confidentiality
- Area: Exposed development surface

#### Evidence

- [`App.WebModule.dfm:14-22`](../../sources/app/App.WebModule.dfm#L14-L22) registers `/image` and `/test` without an authentication boundary.
- [`App.WebModule.pas:122-176`](../../sources/app/App.WebModule.pas#L122-L176) serves image files by requested filename.
- [`App.WebModule.pas:179-199`](../../sources/app/App.WebModule.pas#L179-L199) exposes a development handler that accepts file uploads.
- [`BFA.Core.Request.pas:153-193`](../../sources/core/BFA.Core.Request.pas#L153-L193) writes the uploaded stream to disk.

#### Problem

The `/test` route is development behavior in the production WebModule definition. `/image` is public regardless of whether stored images are intended to be public, tenant-scoped, or authenticated resources.

#### Impact

- Unnecessary upload functionality expands the attack surface.
- Public media access may bypass domain authorization.
- Test behavior can be accidentally deployed and relied upon as an undocumented API.

#### Recommended remediation

1. Remove `/test` from Release builds or return 404 unless an explicit development configuration enables it.
2. Move upload behavior into a documented module endpoint with validation, authentication, authorization, and a defined response contract.
3. Decide explicitly whether `/image` serves public assets or protected documents.
4. If protected, resolve a file identifier through a repository and verify ownership/permission before opening the physical file.
5. Validate file type using server-side content inspection when the file affects security; do not rely only on the extension.
6. Add download headers, caching policy, and maximum response size appropriate to the file category.

#### Acceptance criteria

- [ ] `/test` is unreachable in Release configuration.
- [ ] Uploads occur only through a documented authenticated route.
- [ ] Protected media cannot be accessed by filename alone.
- [ ] File-path traversal and unsupported-type tests are present.

### DASK-OPS-009 - Error handling and logging are fragmented

- Severity: Medium
- Classification: CONTEXT-DEPENDENT for concurrent file-write failures; CONFIRMED for duplication and lost exception details
- Area: Diagnostics, concurrency, and error consistency

#### Evidence

- [`BFA.Core.Rest.pas:98-107`](../../sources/core/BFA.Core.Rest.pas#L98-L107), [`BFA.Core.Endpoint.pas:139-150`](../../sources/core/BFA.Core.Endpoint.pas#L139-L150), and [`Auth.Service.pas:48-60`](../../sources/modules/auth/Auth.Service.pas#L48-L60) implement separate file-append loggers.
- [`User.Service.pas:252-280`](../../sources/modules/users/User.Service.pas#L252-L280) catches exceptions but converts them to a generic response without preserving the exception in the service's error helper.
- [`User.Service.pas:284-288`](../../sources/modules/users/User.Service.pas#L284-L288) creates a 500 response without logging the underlying failure.

#### Problem

Logging behavior differs depending on which layer catches the exception. Several services consume the exception before the endpoint can log it. Direct `TFile.AppendAllText` calls are not coordinated for concurrent requests, and a logging failure can interfere with the original error path.

#### Impact

- Production failures may return HTTP 500 without actionable diagnostics.
- Concurrent log writes may contend or fail depending on platform and filesystem behavior.
- Duplicate logging code can diverge in redaction, formatting, and storage paths.
- Sensitive database or request information may be logged inconsistently.

#### Recommended remediation

1. Introduce one focused logger abstraction or class with a thread-safe implementation.
2. Include timestamp, severity, source, correlation/request ID, and exception type.
3. Apply centralized redaction for passwords, tokens, authorization headers, secrets, and connection credentials.
4. Ensure logger failure never replaces the API response for the original exception.
5. Prefer one top-level unexpected-exception boundary in the endpoint pipeline.
6. Use typed application exceptions for expected validation, not-found, conflict, and forbidden outcomes.
7. Avoid catching an exception in a service only to discard it. Either handle it completely or re-raise it for centralized mapping.

#### Acceptance criteria

- [ ] Every unexpected exception produces one sanitized log entry and one standardized HTTP 500 response.
- [ ] Expected 4xx outcomes are not logged as unhandled server failures.
- [ ] Concurrent logging has a deterministic synchronization strategy.
- [ ] Sensitive-field redaction has automated tests.

### DASK-MEM-010 - Object cleanup is incomplete when initialization fails

- Severity: Medium
- Classification: CONFIRMED
- Area: Memory and startup lifecycle

#### Evidence

- [`DB.ConnectionFactory.pas:60-66`](../../sources/infrastructure/database/DB.ConnectionFactory.pas#L60-L66) creates the result connection and immediately opens it without freeing it if opening raises an exception.
- [`DelphiAPIStarterKit.dpr:192-230`](../../DelphiAPIStarterKit.dpr#L192-L230) creates the server and data module before entering the protecting `try/finally` block.
- [`App.WebModule.pas:75-92`](../../sources/app/App.WebModule.pas#L75-L92) acquires a connection and creates the dispatcher before its cleanup block is fully established.

#### Problem

When a constructor or connection-open operation raises before ownership is protected by `try/finally` or `try/except`, the already-created object is leaked. These failures are most likely during startup, database outages, invalid driver configuration, or resource exhaustion.

#### Recommended remediation

1. Construct into a local variable initialized to `nil`.
2. Protect ownership immediately after the first successful allocation.
3. In `GetConnection`, free the local connection if assigning `Connected := True` fails, then re-raise.
4. Start the outer server cleanup block immediately after server creation, before creating the data module.
5. Fail startup clearly when required database or security configuration cannot initialize.
6. Replace the unconditional infinite sleep loop with a controlled shutdown signal where service deployment requires graceful termination.

#### Acceptance criteria

- [ ] Simulated database-connect failure leaves no live connection object.
- [ ] Simulated data-module construction failure frees the server instance.
- [ ] Startup failure reports a clear fatal error and returns a non-zero process result.
- [ ] Shutdown stops accepting requests before releasing shared resources.

### DASK-TEST-011 - Critical contracts have no automated regression suite

- Severity: Medium
- Classification: CONFIRMED from the current repository inventory
- Area: Testability and scalability

#### Evidence

No Delphi unit-test or integration-test source was located during this review. Postman examples document requests but do not assert security boundaries or runtime behavior. List repository methods such as [`User.Repository.pas:165-190`](../../sources/modules/users/User.Repository.pas#L165-L190) also return an unbounded result set.

#### Problem

The most security-sensitive behavior is implemented across router, endpoint, helper, service, and repository layers. Without automated tests, refactoring those boundaries can silently reintroduce password leakage, authorization bypass, response-shape drift, or transaction errors.

#### Recommended remediation

1. Add unit tests for:
   - Response envelope and JSON type preservation.
   - Request validators and boundary values.
   - Route resolution and method handling.
   - Password-hash verification and legacy migration.
   - Authorization policy allow/deny decisions.
2. Add MySQL integration tests for:
   - Login, refresh rotation, logout, and revoked tokens.
   - Transaction rollback.
   - Unique conflicts.
   - Soft-delete behavior.
3. Add API-level negative tests for 400, 401, 403, 404, 405, 409, 413, 415, and 500 contracts.
4. Add pagination parameters with validated limits and deterministic ordering to list endpoints.
5. Treat Postman as consumer documentation and smoke-test input, not as the only test layer.

#### Acceptance criteria

- [ ] Security-critical services have positive and negative tests.
- [ ] Response-contract tests compare exact JSON types and array shapes.
- [ ] Repository integration tests run against a disposable database schema.
- [ ] List endpoints enforce a maximum page size.
- [ ] CI or the documented local validation command runs the complete suite.

## Healthy helper rules

### 1. One helper owns one technical concern

A helper should have a narrow name and a small, predictable API. A class named `TGlobalFunction` is a warning sign because it currently combines storage paths, INI configuration, HMAC, reversible encoding, Base64, HTTP download, file conversion, and UUID generation.

Recommended rule:

```text
If a method can change for a different reason than the other methods in the class,
it belongs in a different unit or class.
```

### 2. Helpers must not contain domain authorization or business rules

Generic helpers may parse headers, format JSON, hash bytes, or create queries. Decisions such as whether a user may reset another user's password belong to an authorization policy or domain service.

### 3. Prefer stateless and deterministic helpers

Given the same inputs, a helper should normally return the same output and should not silently read environment variables, write files, access the network, or modify global state. Operations with external side effects should be explicit infrastructure services.

### 4. Make ownership explicit

Every method returning an object must have a clear ownership rule. For this project:

- A repository returning `TFDQuery` transfers ownership to the caller.
- A JSON builder returning `TJSONObject` transfers ownership to the caller.
- A method borrowing a connection or request must never free it.
- Owned objects must enter a cleanup block immediately after construction.

Where possible, avoid returning live datasets across layers. Map repository data to records or response DTOs so ownership stays local to the repository.

### 5. Preserve explicit types

Never infer whether a value is a number, Boolean, string, object, or array from its textual appearance. The caller or DTO defines the type. Raw JSON insertion must use a clearly named, explicit method.

### 6. Use one error contract per abstraction

A method should either:

- Return a success/failure result with a documented error value, or
- Raise a documented exception.

It should not sometimes return `False`, sometimes mutate an error dataset, and sometimes raise for equivalent parsing failures. Expected client errors should map to 4xx; unexpected failures should reach the centralized 500 handler.

### 7. Respect dependency direction

Recommended dependency flow:

```text
WebModule/Endpoint -> Service -> Repository -> Database
                     |
                     +-> domain DTO/result

Infrastructure implements logging, security, configuration, and persistence.
Shared helpers do not depend on WebBroker endpoints or business modules.
```

A service should not require `TWebRequest` or build the final HTTP JSON response. The request boundary should create a typed context and pass only necessary values to the service.

### 8. Security helpers must be purpose-specific

Use distinct components for:

- Password hashing.
- Access/refresh token generation.
- Token hashing.
- Token extraction from HTTP headers.
- Authorization policies.

Do not expose reversible obfuscation functions under names that imply encryption.

### 9. Shared helpers must be thread-safe by construction

Avoid mutable global variables and shared request-specific objects. File logging, caches, counters, and configuration reloads require an explicit synchronization and lifecycle strategy.

### 10. Remove unused parameters and misleading abstractions

Unused parameters such as `ACheckHeader`, unused state such as `FRequestMethod`, and unused attributes such as `APIResource` make the architecture appear more capable than it is. Either implement their intended contract or remove them after confirming public compatibility.

### 11. Prefer focused names

Recommended naming examples:

- `TRequestJsonParser`
- `TResponseEnvelopeBuilder`
- `TDatasetJsonSerializer`
- `TDatabaseConfigReader`
- `TStoragePathResolver`
- `TBase64Codec`
- `TIdentifierGenerator`
- `TPasswordHasher`
- `TTokenGenerator`
- `TTokenHasher`
- `TAuthContextResolver`
- `TAuthorizationPolicy`
- `TAppLogger`

The goal is not to create an interface and factory for every class. Introduce an abstraction only when it protects a real boundary, enables testing, or supports multiple implementations.

## Recommended helper decomposition

| Current unit or class | Current mixed responsibilities | Recommended destination |
|---|---|---|
| `BFA.Helper.Strings.TGlobalFunction` | Storage paths, configuration, HMAC, encoding, file conversion, HTTP download, UUID | Split into config reader, storage service, codec, identifier generator, HTTP client wrapper, password/token security classes |
| `BFA.Helper.Dataset` | JSON parsing, XML parsing, dataset schema inference, dataset filling, error data, response serialization | Separate request JSON parser, optional XML adapter, and dataset serializer; remove error-response responsibilities |
| `BFA.Core.Response` | Envelope creation, dataset serialization, string type inference, raw JSON parsing, validation helpers | Keep envelope and typed serialization only; move value validation elsewhere |
| `BFA.Core.Helper` | Route resolution, CRUD method mapping, RTTI method lookup, method invocation | Replace with explicit route registry and small HTTP-method utilities |
| `BFA.Core.Endpoint` | Authentication SQL, route execution, error logging, response creation | Resolve authentication through a dedicated context resolver; use authorization policy and centralized exception middleware |
| `DB.Helper.Query` | Query construction wrappers with unused logging flags | Keep only query creation and genuinely shared FireDAC utilities; remove unused flags and duplicate query factories |
| `BFA.Core.Request` | Upload parsing, file saving, bitmap conversion, query creation | Split upload validation/storage from request parsing; move query creation to database infrastructure |

## Recommended target architecture

```text
sources/
  app/
    App.WebModule.pas

  core/
    http/
      BFA.Http.Router.pas
      BFA.Http.RequestContext.pas
      BFA.Http.Response.pas
      BFA.Http.ApiException.pas
    security/
      BFA.Security.AuthContext.pas
      BFA.Security.Authorization.pas

  infrastructure/
    database/
      DB.ConnectionFactory.pas
      DB.QueryFactory.pas
    logging/
      BFA.Logging.AppLogger.pas
    security/
      BFA.Security.PasswordHasher.pas
      BFA.Security.TokenService.pas
    storage/
      BFA.Storage.FileStore.pas

  modules/
    users/
      RestAPI.User.pas
      User.DTO.pas
      User.Validator.pas
      User.Service.pas
      User.Repository.pas

  shared/
    encoding/
      BFA.Encoding.Base64.pas
    validation/
      BFA.Validation.Common.pas

  tests/
    unit/
    integration/
```

This is a target boundary, not a requirement to rename or move every file immediately. Security and contract fixes should land before structural moves.

## Work priorities

### Priority 0 - Immediate security containment

#### P0-01 Stop sensitive request data from entering responses

- Fix `ChangePassword` first.
- Standardize empty-success responses as `data: []`.
- Add sensitive-field response and log regression tests.

Exit condition: no password, token, or authorization value can appear in a success/error response unless it is the explicitly issued credential at login or refresh.

#### P0-02 Introduce authenticated context and enforce User authorization

- Resolve identity, session, role, and permission once per request.
- Enforce administrator policy on user-management actions.
- Keep ChangePassword self-service only.
- Return 403 for insufficient permission.

Exit condition: a normal authenticated user cannot create, update, delete, reset, activate, deactivate, or assign roles to another user.

#### P0-03 Replace session-based refresh and protect logout

- Add hashed refresh tokens.
- Rotate refresh tokens transactionally.
- Add reuse detection.
- Require session ownership for logout.

Exit condition: `session_id + device_id` cannot mint or revoke credentials without an authenticated proof.

#### P0-04 Remove development routes from Release exposure

- Disable `/test` in Release.
- Decide and document the security model for `/image`.

Exit condition: no undocumented upload/debug endpoint is reachable in a production configuration.

### Priority 1 - Security and request-boundary hardening

#### P1-01 Migrate password hashes

- Introduce a password-specific KDF.
- Retain controlled legacy verification during migration.
- Rehash on successful login.
- Separate password and token secrets.

Exit condition: all new passwords use the approved KDF and legacy hashes have a documented retirement path.

#### P1-02 Enforce request contracts before business logic

- Validate JSON content type.
- Enforce body limits.
- Reject arrays for non-batch endpoints.
- Return precise 400, 413, and 415 envelopes.

Exit condition: malformed or oversized input never reaches a repository or creates unbounded memory-table structures.

#### P1-03 Centralize exception handling and logging

- Introduce one logger.
- Add correlation IDs and redaction.
- Let unexpected exceptions reach one top-level mapper.
- Keep validation and domain errors as explicit typed outcomes.

Exit condition: every unexpected failure yields a consistent 500 response and one useful sanitized log event.

### Priority 2 - API contract and architecture convergence

#### P2-01 Make response types explicit

- Replace `TStringList` type inference with typed JSON values or typed response DTO mapping.
- Standardize all data-array shapes.
- Update API docs and Postman examples together with the contract.

Exit condition: response types do not change based on string content.

#### P2-02 Replace dynamic method invocation with an explicit route registry

- Register method, path, authentication, authorization, and handler together.
- Detect duplicates at startup.
- Remove unused routing attributes or make them authoritative.

Exit condition: all public routes are discoverable from one deterministic registry and are covered by route tests.

#### P2-03 Split broad helpers without changing public behavior

- Decompose `TGlobalFunction` and dataset helper responsibilities.
- Remove duplicate query creation.
- Establish clear object ownership.
- Repair connection-cleanup paths.

Exit condition: each helper has one technical responsibility and no generic helper owns business or HTTP policy.

### Priority 3 - Robustness, scalability, and portability

#### P3-01 Add automated test layers

- Unit tests for core, validators, security, and policies.
- MySQL repository integration tests.
- API contract and negative tests.

#### P3-02 Add pagination and bounded reads

- Add validated `page`, `page_size`, and deterministic ordering.
- Enforce a maximum page size.
- Return pagination metadata through an explicit contract if needed.

#### P3-03 Isolate database-vendor behavior

- Keep MySQL-specific functions such as `NOW()`, `DATE_ADD`, `LAST_INSERT_ID()`, and `LIMIT` inside MySQL-specific repository/infrastructure code.
- Do not claim Firebird or SQL Server compatibility until equivalent implementations and integration tests exist.

#### P3-04 Complete deployment hardening

- Document HTTPS termination.
- Configure reverse-proxy body and timeout limits.
- Use a least-privilege database account.
- Define graceful shutdown, log retention, migration, backup, and recovery behavior.

## Overall definition of done

- [ ] Critical and High findings are closed or explicitly accepted with documented risk ownership.
- [ ] Authentication and authorization are separate, tested boundaries.
- [ ] Password and token secrets never enter ordinary responses or logs.
- [ ] Request body, content type, and JSON shape are validated before dispatch.
- [ ] Response envelopes and JSON types match documentation and Postman examples.
- [ ] All write operations have verified commit and rollback behavior.
- [ ] Object ownership remains correct on success and exception paths.
- [ ] Unit and integration tests cover all security-critical behavior.
- [ ] `compile.bat` succeeds for supported Windows targets in a configured Delphi environment.
- [ ] MySQL integration tests pass against a disposable schema.
- [ ] Live HTTP acceptance verifies representative 2xx, 4xx, and 5xx responses.

## Review limitations

- This review did not execute the application or connect to MySQL.
- No authenticated live endpoint tests were performed.
- No load, concurrency, reverse-proxy, or deployment tests were performed.
- No Delphi build was run because the required toolchain bootstrap variables were unavailable in the review shell.
- Findings are based on the source and documentation present in the checkout on the review date.
