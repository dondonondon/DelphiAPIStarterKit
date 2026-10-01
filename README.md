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
- The schema file creates tables only. If you need test login data, insert a demo role and user that match your configured `DELPHI_API_HMAC_SECRET`.

## Application Secret Setup

The HMAC signature secret is not stored in source code. Configure it before using login, password hashing, token creation, or token validation.

Preferred option: set an environment variable:

```bat
setx DELPHI_API_HMAC_SECRET "replace-with-a-long-random-secret"
```

For the current terminal session only:

```bat
set DELPHI_API_HMAC_SECRET=replace-with-a-long-random-secret
```

Alternative option: create `config.ini` in the application base directory:

```ini
[Security]
HMACSecret=replace-with-a-long-random-secret
```

Use `config.example.ini` as the template. Do not commit your real `config.ini`.

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

If you run from the IDE and the current directory is different, make sure `VendorHome` points to the directory containing the DLL. The current Windows startup code sets:

```pascal
DM.FDPhysMySQLDriverLink.VendorHome := GetCurrentDir;
```

This means the application looks for the native client library from the current directory. If the DLL is stored elsewhere, adjust `VendorHome` in the startup code.

For an open-source repository, the recommended approach is not to commit `libmysql.dll` or binary ZIP files. Document the dependency and let users install the client library from the official vendor package.

### Linux Client Library Notes

For Linux64 deployment, install the MySQL/MariaDB client library on the target server using the server distribution package manager or the official vendor package.

The current Linux startup code sets:

```pascal
DM.FDPhysMySQLDriverLink.VendorHome := '/www/server/mysql/';
```

If your Linux server stores the client library in a different location, adjust `VendorHome` in `DelphiAPIStarterKit.dpr` or adapt the startup code to read this path from deployment configuration.

## Build

Default build script:

```bat
compile.bat
```

The script:

- Stops `DelphiAPIStarterKit.exe` if it is already running.
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
http://localhost:9381
```

## API Quickstart

Import the Postman collection:

```text
docs/api/postman.collection.json
```

Set the collection variable:

```text
base_url = http://localhost:9381/
```

Login request example:

```bat
curl -X POST http://localhost:9381/api/v1/Auth/Login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"demo_admin\",\"password\":\"demo_admin\",\"device_id\":\"local-dev\",\"device_name\":\"CLI\"}"
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
- `users`
- `user_session`
- `access_token`
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
- Configure `DELPHI_API_HMAC_SECRET` or `[Security] HMACSecret` in `config.ini`.
- Review the password hashing strategy. The starter currently uses HMAC-SHA256 with an application secret for simplicity; production systems should use a password hashing algorithm such as bcrypt, Argon2, or PBKDF2 with per-user salts and an appropriate work factor.
- Do not expose stack traces, SQL text, tokens, passwords, or secrets in responses/logs.
- Run the API behind HTTPS.
- Restrict CORS to trusted application domains.
- Give the MySQL user only the permissions it needs.

## License

The project source code uses the license provided in `LICENSE`.

Third-party dependencies such as MySQL/MariaDB client libraries follow their vendor licenses and should not be committed directly into this repository.

## Contributing

See `CONTRIBUTING.md` for development setup, coding standards, build validation, and documentation expectations.

## Security Policy

See `SECURITY.md` for vulnerability reporting and security review guidance.

## Changelog

See `CHANGELOG.md` for unreleased changes and release notes.
