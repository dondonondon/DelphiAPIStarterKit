# DelphiAPIStarterKit

`DelphiAPIStarterKit` adalah starter template Delphi WebBroker untuk membuat REST API dan web service dengan struktur yang lebih rapi: routing, response helper, request validation, service layer, repository layer, FireDAC connection factory, dan contoh module CRUD.

Project ini ditujukan sebagai fondasi awal API backend Delphi, bukan template production yang langsung aman tanpa konfigurasi ulang.

## Features

- Delphi WebBroker API server.
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

- Delphi dengan WebBroker, DataSnap, FireDAC, dan FireDAC MySQL driver.
- MySQL atau MariaDB server.
- MySQL/MariaDB native client library sesuai target aplikasi.
- Windows untuk build default `Win32`.

Project saat ini memakai Delphi path lokal di `compile.bat`. Sesuaikan path `rsvars.bat` jika versi Delphi berbeda.

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

Default database name di source saat ini:

```text
demo_delphirest
```

Connection default ada di:

```text
sources/infrastructure/database/DB.ConnectionFactory.pas
```

Default local configuration saat ini:

```text
Server    = localhost
Database  = demo_delphirest
User_Name = root
Password  =
Driver    = MySQL
```

Untuk production atau public deployment, pindahkan konfigurasi ini ke file config atau environment variable.

### Import Schema via MySQL CLI

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

## MySQL Client Library

FireDAC MySQL membutuhkan native client library yang sesuai bitness aplikasi:

- App `Win32` butuh client library 32-bit.
- App `Win64` butuh client library 64-bit.

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

Jika menjalankan dari IDE dan current directory berbeda, pastikan `VendorHome` mengarah ke folder yang berisi DLL. Saat ini Windows runtime code mengisi:

```pascal
DM.FDPhysMySQLDriverLink.VendorHome := GetCurrentDir;
```

Artinya aplikasi akan mencari client library berdasarkan current directory. Jika DLL disimpan di folder khusus, sesuaikan `VendorHome` di startup code.

Rekomendasi untuk open-source repo: jangan commit `libmysql.dll` atau ZIP binary ke repository. Cukup dokumentasikan dependency dan cara install-nya.

## Build

Default build script:

```bat
compile.bat
```

Script ini:

- Menghentikan proses `DelphiAPIStarterKit.exe` jika sedang berjalan.
- Memanggil `rsvars.bat`.
- Build project via MSBuild.

Jika Delphi terinstall di path atau versi berbeda, ubah path ini:

```bat
C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
```

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

Route akan diarahkan ke class dengan pola:

```text
TRestClass{APIVersion}{RequestClass}
```

Contoh:

```text
/api/v1/users -> TRestClassV1User
```

Setelah itu request masuk ke method `Route`, lalu dipetakan ke service action.

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

Lalu register class di `RegisterClassAPI`:

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
- `users`
- `user_session`
- `access_token`
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
- Ganti hardcoded token signature secret.
- Review ulang password hashing.
- Review DataSnap demo authentication.
- Jangan expose stack trace, SQL text, token, password, atau secret di response/log.
- Jalankan API di balik HTTPS.
- Batasi CORS sesuai domain aplikasi.
- Pastikan MySQL user hanya punya permission yang diperlukan.

## License

Project source code menggunakan license di file `LICENSE`.

Dependency pihak ketiga seperti MySQL/MariaDB client library mengikuti lisensi masing-masing vendor dan tidak disarankan untuk dicommit langsung ke repository ini.
