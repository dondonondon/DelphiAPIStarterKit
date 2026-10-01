# DelphiAPIStarterKit

![Delphi](https://img.shields.io/badge/Delphi-12.x%20WebBroker-E62431?style=flat-square&logo=embarcadero&logoColor=white)
![Database](https://img.shields.io/badge/Database-MySQL%20%7C%20MariaDB-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux64-1F6FEB?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Controller%20%2B%20Service%20%2B%20Repository-0E8A16?style=flat-square)
![Status](https://img.shields.io/badge/Status-Starter%20Template-F59E0B?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-111827?style=flat-square)

English | [Bahasa Indonesia](README.id.md)

`DelphiAPIStarterKit` is a Delphi WebBroker starter template for building REST APIs and web services with a clean backend structure: RTTI-based routing, response helpers, request validation, service layer, repository layer, FireDAC connection factory, and practical CRUD modules.

This project is intended as a reusable foundation for Delphi backend APIs. It is not a production-ready deployment template without additional configuration and security review.

## Features

- Delphi WebBroker API server.
- RTTI-based route dispatch from URL resources to registered endpoint classes.
- FireDAC database access for MySQL/MariaDB.
- Module structure based on `RestAPI`, `Service`, `Repository`, `Validator`, and `DTO` units.
- Standard JSON response envelope.
- Authentication example with sessions and access tokens.
- Example modules:
  - Auth
  - Users
  - Category
  - Product
  - Customer
- Sample database schema in `assets/databases/demo_delphirest.sql`.
- API documentation and Postman collection are available under `docs/api` if the docs folder is published.

## Requirements

- Delphi with WebBroker, FireDAC, FireDAC MySQL driver, and the standard Indy/WebBroker bridge units.
- IPPeer runtime units if your Delphi installation separates these dependencies.
- MySQL or MariaDB server.
- MySQL/MariaDB native client library matching the application target architecture.
- Windows for the default `Win32` build target.
- Linux64 is enabled in the Delphi project and requires the Delphi Linux toolchain/PAServer setup.

The default build script targets `Debug | Win32`. Use environment variables to change the Delphi environment script, build configuration, or platform.

## Project Structure

```text
sources/
  app/                         WebBroker module and server bootstrap
  core/                        Core routing, response, request, constants, config
  infrastructure/
    database/                  FireDAC connection factory and query helper
    security/                  Token/security helper
  modules/
    auth/                      Auth endpoint, service, repository, validator, DTO
    users/                     User endpoint, service, repository, validator, DTO
    category/                  Category endpoint, service, repository, validator, DTO
    products/                  Product endpoint, service, repository, validator, DTO
    customers/                 Customer endpoint, service, repository, validator, DTO
  shared/
    helpers/                   Reusable helpers

assets/
  databases/
    demo_delphirest.sql        MySQL/MariaDB sample schema
```

## JSON Response Format

API responses use this envelope:

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": []
}
```

For error responses, `status` follows the HTTP status code and `data` is returned as an array containing an empty object.

## Database Setup

The database connection is not stored in source code. Configure it before running the server.

Preferred option: set environment variables:

```bat
setx DELPHI_API_DB_SERVER "localhost"
setx DELPHI_API_DB_DATABASE "demo_delphirest"
setx DELPHI_API_DB_USER "root"
setx DELPHI_API_DB_PASSWORD ""
```

Alternative option: create `config.ini` in the application base directory:

```ini
[Database]
Server=localhost
Database=demo_delphirest
User_Name=root
Password=
CharacterSet=utf8mb4
POOL_MaximumItems=50
POOL_ExpireTimeout=300000
```

Use `config.example.ini` as the template. Do not commit your real `config.ini`.

### Import Schema via MySQL CLI

The SQL files now describe the [auth-v2 target contract](docs/bugs/auth-production-contract-2026-10-01.md).
The current Pascal authentication must be upgraded before using this schema with the server. Both SQL files
are alternatives for a fresh empty database; neither is an upgrade script or contains a default login account.

Create the database:

```bat
mysql -u root -p -e "CREATE DATABASE demo_delphirest CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Import the schema:

```bat
mysql -u root -p demo_delphirest < assets\databases\demo_delphirest.sql
```

If PowerShell causes redirect issues, run the command through `cmd`:

```bat
cmd /c "mysql -u root -p demo_delphirest < assets\databases\demo_delphirest.sql"
```

### Import Schema via phpMyAdmin

1. Open phpMyAdmin.
2. Create a database named `demo_delphirest`.
3. Select the database.
4. Open the `Import` tab.
5. Select `assets/databases/demo_delphirest.sql`.
6. Run the import.

### MySQL Compatibility Notes

- The sample schema targets MySQL/MariaDB with InnoDB and `utf8mb4`.
- During setup, the database account needs permission to create/import tables.
- At runtime, use a dedicated application account with only the required CRUD permissions for the application database.
- The baseline contains DDL only. The full sample import adds generic roles, permissions and business data, without login credentials. Source implements offline bootstrap and finite legacy HMAC migration; see docs/api/auth.md and docs/databases/auth-v2-cutover.md. No default credential is provided.

## Auth security configuration

Use [config.example.ini](config.example.ini) and [Auth API](docs/api/auth.md). Argon2Library must be absolute,
Argon2SHA256 pinned, with matching OS/bitness dependencies. No default credential/provider fallback.
HMACSecret is used only by the original legacy verifier during an explicit finite LegacyHashDeadline;
new passwords use salted Argon2id and token storage uses canonical SHA-256. Inject process-only secrets,
never persist them via setx, command-line arguments, Postman saved values or repository config.

## MySQL Client Library

FireDAC MySQL requires a native client library that matches the application bitness:

- A `Win32` application requires a 32-bit client library.
- A `Win64` application requires a 64-bit client library.
- A `Linux64` deployment requires a compatible 64-bit `libmysqlclient.so` or `libmariadb.so` available on the Linux server.

Do not download `libmysql.dll` from unofficial DLL mirrors. Use one of these official sources:

- MySQL C API / libmysqlclient: https://dev.mysql.com/downloads/c-api/
- MySQL Connector/C++ package: https://dev.mysql.com/downloads/connector/cpp/
- MariaDB Connector/C: https://mariadb.com/docs/connectors/mariadb-connector-c

MariaDB Connector/C can connect to MySQL and MariaDB, and MariaDB documents the C connector as LGPLv2.1 licensed.

### Adding `libmysql.dll`

Simple setup:

1. Download the MySQL/MariaDB client library from an official source.
2. Choose the same architecture as your Delphi build target.
3. Extract `libmysql.dll` from the package.
4. Place `libmysql.dll` in the same folder as the executable, for example:

```text
bin/libmysql.dll
```

Alternatively, place the DLL directory in the Windows `PATH`.

Use Database.VendorLib or DELPHI_API_DB_VENDOR_LIB for an absolute protected native client path.
When unset, FireDAC uses its normal platform library search. Configuration is executable-adjacent or
absolute DELPHI_API_CONFIG; startup no longer hardcodes current-directory VendorHome.

For an open-source repository, the recommended approach is not to commit `libmysql.dll` or binary ZIP files. Document the dependency and let users install the client library from the official vendor package.

### Linux Client Library Notes

For Linux64 deployment, install the MySQL/MariaDB client library on the target server using the server distribution package manager or the official vendor package.

Configure an absolute Database.VendorLib native .so path if system resolution is insufficient.
The source no longer hardcodes /www/server/mysql. Linux runtime/deployment still requires actual staging proof.

## Build

Default build script:

```bat
compile.bat
```

The script:

- Does not stop processes. Stop only your own verified dev instance before overwriting its artifact.
- Calls `rsvars.bat` from `DELPHI_RSVARS`, or from `%BDS%\bin\rsvars.bat` when running inside a Delphi command prompt.
- Builds the project via MSBuild.
- Defaults to `Debug | Win32`.

When running from a normal terminal, set `DELPHI_RSVARS` first:

```bat
set DELPHI_RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
compile.bat
```

Optional build overrides:

```bat
set BUILD_CONFIG=Release
set BUILD_PLATFORM=Win64
compile.bat
```

Linux64 build example:

```bat
set BUILD_CONFIG=Release
set BUILD_PLATFORM=Linux64
compile.bat
```

Linux builds require a configured Delphi Linux toolchain and PAServer connection.

Manual build:

```bat
msbuild DelphiAPIStarterKit.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /nologo /v:minimal
```

## Run

After building, run the executable from the output folder. Make sure:

- MySQL/MariaDB server is running.
- The `demo_delphirest` database exists and the schema has been imported.
- The MySQL client DLL is available to FireDAC.
- The server port is not already used by another application.

Default local base URL:

```text
http://localhost:9000
```

## API Quickstart

Import the Postman collection:

```text
docs/api/postman.collection.json
```

Set the collection variable:

```text
base_url = http://localhost:9000/
```

Login request example:

```bat
curl -X POST http://localhost:9000/api/v1/Auth/Login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"{{operator_selected_credential}}\",\"password\":\"{{operator_selected_credential}}\",\"device_id\":\"local-dev\",\"device_name\":\"CLI\"}"
```

The database schema does not insert a default demo user. Create your own local test user before expecting the login example to succeed.

All endpoints under `User`, `Product`, `Category`, and `Customer` require an access token from the login response. Pass the token via the `x-api-token` header:

```text
x-api-token: <access_token>
```

The server also accepts `access-token` and `Authorization: Bearer <token>` as fallback header names.

## API Route Pattern

Base route:

```text
/api/v1/{resource}
```

Examples:

```text
POST   /api/v1/auth/Login
POST   /api/v1/auth/Refresh
POST   /api/v1/auth/Logout
GET    /api/v1/users
POST   /api/v1/users
PUT    /api/v1/users/{user_id}
DELETE /api/v1/users/{user_id}
GET    /api/v1/category
GET    /api/v1/products
GET    /api/v1/customers
```

Routes are resolved to registered endpoint classes using a lightweight RTTI-based dispatcher.
The dispatcher builds the target class name from the API version and resource name:

```text
TRestClass{APIVersion}{RequestClass}
```

Example:

```text
/api/v1/users -> TRestClassV1User
```

Internally, the core dispatcher uses `FindClass` to locate the registered endpoint class, creates an instance, and invokes its `Route` method. The endpoint `Route` method then maps the HTTP method and path to the proper service action.

## Adding a New Endpoint

Example: adding an `orders` resource.

### 1. Create the Module Folder

```text
sources/modules/orders/
```

### 2. Create the DTO Unit

Example file:

```text
sources/modules/orders/Order.DTO.pas
```

Keep request and response records explicit:

```pascal
type
  TOrderCreateRequest = record
    CustomerID: string;
    OrderDate: TDateTime;
    Notes: string;
  end;
```

### 3. Create the Validator

Example file:

```text
sources/modules/orders/Order.Validator.pas
```

The validator reads and validates the `TFDMemTable` request before business logic runs.

Use existing helpers where possible:

```pascal
THelperValidator.GetRequiredString(...)
THelperValidator.GetOptionalString(...)
THelperValidator.ParseIntegerField(...)
```

### 4. Create the Repository

Example file:

```text
sources/modules/orders/Order.Repository.pas
```

Repositories should contain database access only. Use parameterized queries:

```pascal
TQueryFunction.SQLAdd(LDataset,
  'INSERT INTO orders (order_id, customer_internal_id, notes) VALUES (:order_id, :customer_id, :notes)',
  True
);
TQueryFunction.SQLParamByName(LDataset, 'order_id', AOrderID);
TQueryFunction.SQLParamByName(LDataset, 'customer_id', ACustomerID);
TQueryFunction.SQLParamByName(LDataset, 'notes', ANotes);
TQueryFunction.ExecSQL(LDataset);
```

Do not concatenate raw user input into SQL.

### 5. Create the Service

Example file:

```text
sources/modules/orders/Order.Service.pas
```

Services contain business logic, transaction handling, and repository calls.

Write operation pattern:

```pascal
FConnection.StartTransaction;
try
  FRepository.CreateOrder(...);
  FConnection.Commit;
except
  on E: Exception do begin
    THelperTransaction.Rollback(FConnection);
    Exit(InternalServerError);
  end;
end;
```

### 6. Create the RestAPI Unit

Example file:

```text
sources/modules/orders/RestAPI.Order.pas
```

The class must match the route naming pattern:

```pascal
type
  TRestClassV1Order = class(TPersistent)
  public
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): string;
  end;
```

Inside `Route`, use `THelperEndpoint.ExecuteRoute` like the existing modules.

### 7. Register the API Class

Add the new unit to the `uses` clause in:

```text
sources/core/BFA.Core.Rest.pas
```

Then register the class in `RegisterClassAPI`. This step is required because the RTTI dispatcher resolves endpoint classes through Delphi's class registry:

```pascal
RegisterClassAPI([TRestClassV1User, TRestClassV1Auth, TRestClassV1Product,
  TRestClassV1Category, TRestClassV1Customer, TRestClassV1Order]);
```

### 8. Add Units to the Project

Add the new units to:

- `DelphiAPIStarterKit.dpr`
- `DelphiAPIStarterKit.dproj`

If you use the Delphi IDE, add the units through the Project Manager so the `.dproj` file is updated.

### 9. Add the Database Table

Create a migration/schema update in the database assets or migration docs.

Example:

```sql
CREATE TABLE `orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` CHAR(36) NOT NULL,
  `customer_internal_id` BIGINT UNSIGNED NOT NULL,
  `notes` VARCHAR(255) NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_orders_public_id` (`order_id`),
  KEY `idx_orders_customer` (`customer_internal_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 10. Update API Documentation

Add endpoint documentation:

```text
docs/api/orders.md
```

Update the Postman collection if used:

```text
docs/api/postman.collection.json
```

## Current Database Tables

The sample schema contains:

- `m_role`
- `m_permission`
- `role_permission`
- `users`
- `user_session`
- `access_token`
- `refresh_token`
- `password_reset_token`
- `auth_security_event`
- `category`
- `product`
- `customer`

Import the schema from:

```text
assets/databases/demo_delphirest.sql
```

## Security Notes

Before production use:

- Move database credentials to config/environment variables.
- Configure the pinned Argon2 provider, security profile and finite legacy verifier only when needed.
- Source uses Argon2id PHC with per-password salt. Verify native packaging/cost, compromised-password blocklist and MFA/client storage on staging.
- Do not expose stack traces, SQL text, tokens, passwords, or secrets in responses/logs.
- Run the API behind HTTPS.
- Restrict CORS to trusted application domains.
- Give the MySQL user only the permissions it needs.

## License

The project source code uses the license provided in `LICENSE`.

Third-party dependencies such as MySQL/MariaDB client libraries follow their vendor licenses and should not be committed directly into this repository.

## Contributing

See `CONTRIBUTING.md` for development setup, coding standards, build validation, and documentation expectations.

### Repository orchestration skills

The [project-orchestrator skill](.agents/skills/project-orchestrator/SKILL.md) coordinates scoped implementation, bug fixes, reviews, build validation, and resumable work. Supporting skills live in `.agents/skills/`; [the project map](project-map.md) and [execution contract](.ai/ORCHESTRATOR.md) describe the current boundaries. Existing remediation tasks are linked through [the task index](.ai/TASK-INDEX.md) and run only when requested.

Example invocation: `Use $project-orchestrator to execute wave-01 using docs/bugs/prompt-execute-wave-01.md within its scope.`

Validate the package from the repository root with `powershell -NoProfile -File scripts/validate-orchestrator.ps1`. Local checkpoints and raw logs under `.ai/runs/` are ignored by Git; required task results remain in their existing documentation.

## Security Policy

See `SECURITY.md` for vulnerability reporting and security review guidance.

## Changelog

See `CHANGELOG.md` for unreleased changes and release notes.


## Auth-v2 WAVE-01 cutover

Source implements explicit permissions, role grants/delegation, last-admin protection, restricted initial-password sessions,
Argon2id PHC, OS CSPRNG 32-byte credentials, rotating refresh/reuse revocation, recent reauthentication,
owned session operations and one-time setup/reset redemption. Read [Auth API](docs/api/auth.md), [Users](docs/api/users.md),
[Roles](docs/api/roles.md) and [migration guide](docs/databases/auth-v2-cutover.md) before deploying SQL/source/client together.

Configuration authority: process DELPHI_API_CONFIG must be absolute; otherwise executable-adjacent config.ini, independent of CWD.
[config.example.ini](config.example.ini) intentionally contains no credential or runnable provider default. Security.Argon2Library must be
an absolute trusted native library of the matching OS/bitness with Argon2SHA256 lowercase pin and protected dependencies. Startup runs a
known-answer vector; no fast-hash fallback. Database.VendorLib is optional absolute native client path; LoginTimeout is bounded 1–30 seconds.
Default HTTP Port=9000, configurable DELPHI_API_PORT; CORS app allowlist empty by default, semicolon separated. Direct-peer IP only;
forwarded headers do not identify actor/origin. HTTPS/proxy integration remains a deployment gate.

Legacy HMACSecret is only needed when explicit finite LegacyHashDeadline activates the legacy verifier; new hashing/token storage do not
use it. Preserve secret whitespace and inject secrets at runtime; never pass credentials on a command line or save them in Postman.
Offline --bootstrap-admin reads process-only operator username/password and refuses nonempty users/replay; no HTTP bootstrap/default login.
Offline --auth-cleanup runs bounded retention, preserving active reuse chains. Legacy Encrypt/Decrypt/EncodeCrypt/DecodeCrypt are deprecated
obfuscation helpers forbidden for password/token/config secrets. No active security consumer exists in this repository; external consumers
must be inventoried before migration. Auth-v2 token parser rejects malformed Base64URL rather than falling back to plaintext.

Win64+MariaDB clone evidence and remaining Win32/Linux runtime, provider package, client storage/MFA/TLS production gates are recorded in
[WAVE-01 result](docs/bugs/wave-01-result.md). password-only baseline does not prove MFA; any unsupported security profile fails closed.
Build no longer kills processes by image name. Platform artifact collision/graceful supervisor shutdown remain T10 follow-up scope.
