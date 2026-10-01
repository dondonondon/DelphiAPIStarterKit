# DelphiAPIStarterKit

`DelphiAPIStarterKit` adalah starter template Delphi WebBroker untuk membuat REST API dan web service dengan struktur yang lebih rapi: RTTI-based routing, response helper, request validation, service layer, repository layer, FireDAC connection factory, dan contoh module CRUD.

Project ini ditujukan sebagai fondasi awal API backend Delphi, bukan template production yang langsung aman tanpa konfigurasi ulang.

## Features

- Delphi WebBroker API server.
- RTTI-based route dispatch dari URL resource ke endpoint class yang sudah diregister.
- FireDAC database access dengan MySQL/MariaDB.
- Struktur module berbasis `RestAPI`, `Service`, `Repository`, `Validator`, dan `DTO`.
- Standard JSON response envelope.
- Auth example dengan session dan access token.
- Example modules:
  - Auth
  - Users
  - Category
  - Product
  - Customer
- Database schema sample di `assets/databases/demo_delphirest.sql`.
- API documentation dan Postman collection tersedia di folder `docs/api` jika folder docs ikut dipublish.

## Requirements

- Delphi dengan WebBroker, FireDAC, FireDAC MySQL driver, dan unit standar Indy/WebBroker bridge.
- IPPeer runtime units jika instalasi Delphi Anda memisahkan dependency tersebut.
- MySQL atau MariaDB server.
- MySQL/MariaDB native client library sesuai target aplikasi.
- Windows untuk build default `Win32`.
- Linux64 sudah aktif di project Delphi dan membutuhkan setup Delphi Linux toolchain/PAServer.

Build script default memakai target `Debug | Win32`. Gunakan environment variable untuk mengganti Delphi environment script, build configuration, atau platform.

## Project Structure

```text
sources/
  app/                         WebBroker module dan server bootstrap
  core/                        Core routing, response, request, constants, config
  infrastructure/
    database/                  FireDAC connection factory dan query helper
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

API response memakai envelope berikut:

```json
{
  "status": 200,
  "messages": "OK",
  "servertime": "1780962999",
  "data": []
}
```

Untuk error response, `status` mengikuti HTTP status code dan `data` dikembalikan sebagai array berisi object kosong.

## Database Setup

Database connection tidak disimpan di source code. Konfigurasikan sebelum menjalankan server.

Opsi utama: set environment variables:

```bat
setx DELPHI_API_DB_SERVER "localhost"
setx DELPHI_API_DB_DATABASE "demo_delphirest"
setx DELPHI_API_DB_USER "root"
setx DELPHI_API_DB_PASSWORD ""
```

Opsi alternatif: buat `config.ini` di application base directory:

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

Gunakan `config.example.ini` sebagai template. Jangan commit `config.ini` asli.

### Import Schema via MySQL CLI

File SQL sekarang memuat [kontrak target auth-v2](docs/bugs/auth-production-contract-2026-10-01.md).
Source auth-v2 telah diperbarui; SQL/source/client harus cutover bersama sesuai migration guide. Kedua file SQL
merupakan alternatif untuk database kosong; keduanya bukan script upgrade dan tidak memuat akun login bawaan.

Buat database:

```bat
mysql -u root -p -e "CREATE DATABASE demo_delphirest CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Import schema:

```bat
mysql -u root -p demo_delphirest < assets\databases\demo_delphirest.sql
```

Jika memakai PowerShell dan redirect bermasalah, jalankan lewat `cmd`:

```bat
cmd /c "mysql -u root -p demo_delphirest < assets\databases\demo_delphirest.sql"
```

### Import Schema via phpMyAdmin

1. Buka phpMyAdmin.
2. Buat database `demo_delphirest`.
3. Pilih database tersebut.
4. Buka tab `Import`.
5. Pilih file `assets/databases/demo_delphirest.sql`.
6. Jalankan import.

### Catatan Kompatibilitas MySQL

- Sample schema ditujukan untuk MySQL/MariaDB dengan InnoDB dan `utf8mb4`.
- Saat setup, database account butuh permission untuk membuat/import table.
- Saat runtime, gunakan application account khusus dengan permission CRUD seperlunya untuk database aplikasi.
- Baseline hanya memuat DDL. Full sample import menambahkan role, permission dan data bisnis generik tanpa credential login. Bootstrap offline dan migration legacy sudah diimplementasikan; production/client gates tetap terpisah. Tidak ada default credential.

## Auth security configuration

Use [config.example.ini](config.example.ini) and [Auth API](docs/api/auth.md). Argon2Library must be absolute,
Argon2SHA256 pinned, with matching OS/bitness dependencies. No default credential/provider fallback.
HMACSecret is used only by the original legacy verifier during an explicit finite LegacyHashDeadline;
new passwords use salted Argon2id and token storage uses canonical SHA-256. Inject process-only secrets,
never persist them via setx, command-line arguments, Postman saved values or repository config.

## MySQL Client Library

FireDAC MySQL membutuhkan native client library yang sesuai bitness aplikasi:

- App `Win32` butuh client library 32-bit.
- App `Win64` butuh client library 64-bit.
- Deployment `Linux64` butuh `libmysqlclient.so` atau `libmariadb.so` 64-bit yang compatible dan tersedia di server Linux.

Jangan mengambil `libmysql.dll` dari mirror tidak resmi. Gunakan salah satu sumber resmi:

- MySQL C API / libmysqlclient: https://dev.mysql.com/downloads/c-api/
- MySQL Connector/C++ package: https://dev.mysql.com/downloads/connector/cpp/
- MariaDB Connector/C: https://mariadb.com/docs/connectors/mariadb-connector-c

MariaDB Connector/C dapat dipakai untuk koneksi ke MySQL/MariaDB dan dokumentasi MariaDB menyebut library C connector berlisensi LGPLv2.1.

### Cara Menambahkan `libmysql.dll`

Opsi paling sederhana:

1. Download MySQL/MariaDB client library dari sumber resmi.
2. Pilih arsitektur yang sama dengan target build Delphi.
3. Ambil `libmysql.dll` dari package tersebut.
4. Letakkan `libmysql.dll` di folder yang sama dengan executable, misalnya:

```text
bin/libmysql.dll
```

atau letakkan folder DLL di `PATH` Windows.

Gunakan Database.VendorLib atau DELPHI_API_DB_VENDOR_LIB absolute. Bila unset, FireDAC memakai pencarian
platform normal. Config executable-adjacent/DELPHI_API_CONFIG absolute tidak bergantung CWD; startup tidak lagi hardcode VendorHome.

Rekomendasi untuk open-source repo: jangan commit `libmysql.dll` atau ZIP binary ke repository. Cukup dokumentasikan dependency dan cara install-nya.

### Catatan Client Library Linux

Untuk deployment Linux64, install MySQL/MariaDB client library di server target menggunakan package manager distro server atau package resmi vendor.

Konfigurasikan Database.VendorLib absolute bila system resolution tidak cukup. Hardcoded /www/server/mysql dihapus.
Runtime/deployment Linux tetap membutuhkan staging actual.

## Build

Default build script:

```bat
compile.bat
```

Script ini:

- Tidak menghentikan process; stop dev instance milik sendiri dengan PID/path yang terverifikasi sebelum overwrite artifact.
- Memanggil `rsvars.bat` dari `DELPHI_RSVARS`, atau dari `%BDS%\bin\rsvars.bat` jika dijalankan dari Delphi command prompt.
- Build project via MSBuild.
- Default target `Debug | Win32`.

Jika menjalankan dari terminal biasa, set `DELPHI_RSVARS` lebih dulu:

```bat
set DELPHI_RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
compile.bat
```

Override build optional:

```bat
set BUILD_CONFIG=Release
set BUILD_PLATFORM=Win64
compile.bat
```

Contoh build Linux64:

```bat
set BUILD_CONFIG=Release
set BUILD_PLATFORM=Linux64
compile.bat
```

Build Linux membutuhkan Delphi Linux toolchain dan koneksi PAServer yang sudah dikonfigurasi.

Build manual:

```bat
msbuild DelphiAPIStarterKit.dproj /t:Make /p:Config=Debug /p:Platform=Win32 /nologo /v:minimal
```

## Run

Setelah build, jalankan executable dari output folder. Pastikan:

- MySQL/MariaDB server berjalan.
- Database `demo_delphirest` sudah dibuat dan schema sudah diimport.
- MySQL client DLL tersedia untuk FireDAC.
- Port server tidak sedang dipakai aplikasi lain.

Default local base URL:

```text
http://localhost:9000
```

## API Quickstart

Import Postman collection:

```text
docs/api/postman.collection.json
```

Set collection variable:

```text
base_url = http://localhost:9000/
```

Contoh request login:

```bat
curl -X POST http://localhost:9000/api/v1/Auth/Login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"{{operator_selected_credential}}\",\"password\":\"{{operator_selected_credential}}\",\"device_id\":\"local-dev\",\"device_name\":\"CLI\"}"
```

Database schema tidak membuat default demo user. Buat user test lokal sendiri sebelum mengharapkan contoh login berhasil.

Semua endpoint di bawah `User`, `Product`, `Category`, dan `Customer` membutuhkan access token dari response login. Kirim token melalui header `x-api-token`:

```text
x-api-token: <access_token>
```

Server juga menerima `access-token` dan `Authorization: Bearer <token>` sebagai header fallback.

## API Route Pattern

Base route:

```text
/api/v1/{resource}
```

Contoh:

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

Route diarahkan ke endpoint class yang sudah diregister menggunakan lightweight RTTI-based dispatcher.
Dispatcher membentuk nama target class dari API version dan resource name:

```text
TRestClass{APIVersion}{RequestClass}
```

Contoh:

```text
/api/v1/users -> TRestClassV1User
```

Di internal core, dispatcher memakai `FindClass` untuk mencari endpoint class yang sudah diregister, membuat instance, lalu memanggil method `Route`. Method `Route` di endpoint kemudian memetakan HTTP method dan path ke service action yang sesuai.

## Menambahkan Endpoint Baru

Contoh menambahkan resource `orders`.

### 1. Buat Folder Module

```text
sources/modules/orders/
```

### 2. Buat Unit DTO

Contoh nama file:

```text
sources/modules/orders/Order.DTO.pas
```

Isi DTO dengan record request/response yang eksplisit, misalnya:

```pascal
type
  TOrderCreateRequest = record
    CustomerID: string;
    OrderDate: TDateTime;
    Notes: string;
  end;
```

### 3. Buat Validator

Contoh nama file:

```text
sources/modules/orders/Order.Validator.pas
```

Validator bertugas membaca dan memvalidasi `TFDMemTable` request sebelum business logic berjalan.

Gunakan helper yang sudah ada seperti:

```pascal
THelperValidator.GetRequiredString(...)
THelperValidator.GetOptionalString(...)
THelperValidator.ParseIntegerField(...)
```

### 4. Buat Repository

Contoh nama file:

```text
sources/modules/orders/Order.Repository.pas
```

Repository hanya berisi akses database. Gunakan parameterized query:

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

Jangan concat raw user input ke SQL.

### 5. Buat Service

Contoh nama file:

```text
sources/modules/orders/Order.Service.pas
```

Service berisi business logic, transaction handling, dan pemanggilan repository.

Pola write operation:

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

### 6. Buat RestAPI Unit

Contoh nama file:

```text
sources/modules/orders/RestAPI.Order.pas
```

Class harus mengikuti naming route:

```pascal
type
  TRestClassV1Order = class(TPersistent)
  public
    function Route(AConnection: TFDConnection; AData: TFDMemTable;
      AWebAction: TWebActionItem; ARequest: TWebRequest;
      AResponse: TWebResponse; out AStatusCode: Integer): string;
  end;
```

Di dalam `Route`, gunakan `THelperEndpoint.ExecuteRoute` seperti module lain.

### 7. Register Class API

Tambahkan unit baru ke `uses` di:

```text
sources/core/BFA.Core.Rest.pas
```

Lalu register class di `RegisterClassAPI`. Step ini wajib karena RTTI dispatcher mencari endpoint class melalui Delphi class registry:

```pascal
RegisterClassAPI([TRestClassV1User, TRestClassV1Auth, TRestClassV1Product,
  TRestClassV1Category, TRestClassV1Customer, TRestClassV1Order]);
```

### 8. Tambahkan Unit ke Project

Tambahkan unit baru ke:

- `DelphiAPIStarterKit.dpr`
- `DelphiAPIStarterKit.dproj`

Jika memakai Delphi IDE, tambahkan unit melalui project manager agar `.dproj` ikut diperbarui.

### 9. Tambahkan Database Table

Buat migration/schema update untuk table baru di folder database asset atau migration docs.

Contoh:

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

Tambahkan dokumentasi endpoint baru di:

```text
docs/api/orders.md
```

Update Postman collection jika digunakan:

```text
docs/api/postman.collection.json
```

## Current Database Tables

Schema sample saat ini berisi:

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

Import schema dari:

```text
assets/databases/demo_delphirest.sql
```

## Security Notes

Sebelum production:

- Pindahkan credential database ke config/environment.
- Konfigurasikan pinned Argon2 provider/profile dan finite legacy verifier hanya bila diperlukan.
- Source memakai salted Argon2id PHC. Validasi provider package/cost, compromised-password blocklist dan MFA/client storage actual di staging.
- Jangan expose stack trace, SQL text, token, password, atau secret di response/log.
- Jalankan API di balik HTTPS.
- Batasi CORS sesuai domain aplikasi.
- Pastikan MySQL user hanya punya permission yang diperlukan.

## License

Project source code menggunakan license di file `LICENSE`.

Dependency pihak ketiga seperti MySQL/MariaDB client library mengikuti lisensi masing-masing vendor dan tidak disarankan untuk dicommit langsung ke repository ini.

## Contributing

Lihat `CONTRIBUTING.md` untuk development setup, coding standards, build validation, dan aturan update dokumentasi.

### Skill orchestrator project

[Skill project-orchestrator](.agents/skills/project-orchestrator/SKILL.md) mengatur implementasi, perbaikan bug, review, validasi build, dan kelanjutan pekerjaan melalui checkpoint. Skill pendukung berada di `.agents/skills/`; lihat [project map](project-map.md), [kontrak eksekusi](.ai/ORCHESTRATOR.md), dan [indeks task existing](.ai/TASK-INDEX.md). Pembuatan paket ini tidak memulai task perbaikan.

Contoh pemakaian: `Gunakan $project-orchestrator untuk mengeksekusi wave-01 melalui docs/bugs/prompt-execute-wave-01.md sesuai scope-nya.`

Validasi paket dari root repo: `powershell -NoProfile -File scripts/validate-orchestrator.ps1`. Checkpoint dan raw log lokal di `.ai/runs/` diabaikan Git; hasil task wajib tetap memakai dokumentasi existing.

## Security Policy

Lihat `SECURITY.md` untuk proses pelaporan vulnerability dan panduan security review.

## Changelog

Lihat `CHANGELOG.md` untuk unreleased changes dan release notes.


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
