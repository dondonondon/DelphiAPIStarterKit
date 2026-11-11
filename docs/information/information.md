# Struktur Folder `sources`

Struktur saat ini berfokus pada WebBroker REST API starter kit. DataSnap sample server dan legacy method units sudah tidak menjadi bagian dari project publish.

## Struktur Saat Ini

```text
sources/
  app/
    App.WebModule.dfm
    App.WebModule.pas

  core/
    BFA.Core.Config.pas
    BFA.Core.Constants.pas
    BFA.Core.Endpoint.pas
    BFA.Core.Helper.pas
    BFA.Core.Messages.pas
    BFA.Core.Request.pas
    BFA.Core.Response.pas
    BFA.Core.Rest.pas

  infrastructure/
    database/
      DB.ConnectionFactory.pas
      DB.Helper.Query.pas
    security/
      BFA.Security.Token.pas

  modules/
    auth/
      RestAPI.Auth.pas
      Auth.DTO.pas
      Auth.Repository.pas
      Auth.Service.pas
      Auth.Validator.pas
    category/
      RestAPI.Category.pas
      Category.DTO.pas
      Category.Repository.pas
      Category.Service.pas
      Category.Validator.pas
    customers/
      RestAPI.Customer.pas
      Customer.DTO.pas
      Customer.Repository.pas
      Customer.Service.pas
      Customer.Validator.pas
    products/
      RestAPI.Product.pas
      Product.DTO.pas
      Product.Repository.pas
      Product.Service.pas
      Product.Validator.pas
    sample/
      RestAPI.Sample.pas
    users/
      RestAPI.User.pas
      User.DTO.pas
      User.Repository.pas
      User.Service.pas
      User.Validator.pas

  shared/
    helpers/
      BFA.Helper.Dataset.pas
      BFA.Helper.Strings.pas
      BFA.Helper.Transaction.pas
      BFA.Helper.Validator.pas
```

## Responsibility Map

- `sources/app`: WebBroker module, request dispatching, file/image route handling, and top-level routing.
- `sources/core`: common endpoint execution, REST abstractions, JSON request/response helpers, messages, config, and constants.
- `sources/infrastructure/database`: FireDAC connection factory and query helper.
- `sources/infrastructure/security`: access token extraction helper.
- `sources/modules/<feature>`: endpoint handler, DTO, validator, service, and repository for each feature.
- `sources/shared/helpers`: reusable dataset, string, transaction, and validation helpers.

## Pengembangan Endpoint Baru

Fitur bisnis baru dibuat di:

```text
sources/modules/<feature-name>/
```

Gunakan pola file berikut:

```text
RestAPI.<Feature>.pas
<Feature>.DTO.pas
<Feature>.Repository.pas
<Feature>.Service.pas
<Feature>.Validator.pas
```

Setelah unit dibuat, update:

- `DelphiAPIStarterKit.dpr`
- `sources/app/App.WebModule.pas`
- `docs/api/<feature-name>.md`
- `docs/api/postman.collection.json`
- `README.md` jika setup atau behavior publik berubah

## Catatan Publish

Runtime file seperti `config.ini`, `libmysql.dll`, executable, generated proxy, dan uploaded image tidak dipublish ke Git. Gunakan `config.example.ini` dan dokumentasi README untuk setup lokal.

## Exception Logging

`THelperEndpoint.WriteErrorLog` di `sources/core/BFA.Core.Endpoint.pas` menulis timestamp, sumber, kelas exception, dan pesan exception melalui `Writeln` serta ke `server-error.log` di direktori executable. `WriteConsoleLog` menyediakan output diagnostik console. Kedua jalur memakai satu critical section sehingga baris timing/error dari request paralel tidak tercampur; output tetap sinkron dan timing default nonaktif.

Core dispatch, route, Auth service, serta penanganan exception User/Product/Category/Customer service menggunakan logger yang sama. `App.WebModule.WMapiAction` mencatat exception sebelum dispatch, termasuk kegagalan membuka koneksi database. Kegagalan output console atau file log tidak menggantikan exception asli atau respons API.

Respons HTTP 500 tetap memakai pesan `Internal server error.`; detail exception tersedia pada console/log server. Logger tidak menambahkan request body atau header autentikasi. Pesan exception tetap dapat mengandung detail internal, sehingga akses log mengikuti akses operator server.

## Serializer dan Customer Benchmark

`BFA.Core.Response` menginisialisasi konteks angka `en-US` sekali untuk `TValueValidator.IsNumber`, lalu menggunakannya sebagai konteks read-only lintas request. Pengaturan format global pada `RunServer` tetap terpisah.

`App.WebModule.SendToCoreAPI` menyediakan `DELPHI_API_REQUEST_TIMING=1` untuk durasi koneksi, dispatch, penyiapan respons, dan total sampai cleanup. Setiap baris memiliki request ID per proses dan route tanpa ID aktual. Total tidak mencakup HTTP send, antrean sebelum handler, console output, atau pembentukan respons exception oleh handler luar. Default nonaktif melewati stopwatch/counter/logging.

Serializer menyiapkan referensi field sekali per array dan membaca dataset sampai `Eof`. Batas `RecordCount` awal tidak lagi memotong hasil ketika FireDAC mengambil batch lanjutan. Urutan field/record serta konversi JSON lama dipertahankan. `Product.DTO` dan `Product.Validator` juga menginisialisasi konteks angka `en-US` sekali.

## Konfigurasi dan Startup

Kompresi JSON tersedia melalui `sources/infrastructure/http/BFA.HTTP.Compression.pas`. `THTTPCompression.Apply` dipanggil oleh `App.WebModule.WebModuleAfterDispatch` yang terhubung pada DFM. Helper memproses `Accept-Encoding`, gzip wrapper zlib, `Vary`, serta ownership stream per request; tidak memakai compressor global.

`TServerConfig.GzipEnabled/GzipMinimumBytes/GzipLevel` membaca `[HTTP]` sekali saat startup dengan default `True/1024/1`. Nilai invalid menghentikan startup; perubahan memerlukan restart. Kompresi hanya untuk JSON yang diterima client, melewati batas ukuran UTF-8, dan menghasilkan body lebih kecil. Existing coding/stream, gambar, HEAD/CONNECT, status tanpa body/partial, range, `no-transform`, dan validator/digest yang sudah ada dilewati.

JSON memakai `Content-Type: application/json; charset=utf-8`. `Content-Encoding` kosong pada identity dan `gzip` hanya ketika body dikompresi. Timing `SendToCoreAPI` berhenti sebelum `AfterDispatch`, sehingga biaya gzip berada di luar `total_ms`; durasi HTTP k6 mencakup kompresi/pengiriman.

- `BFA.Core.Config.TServerConfig.Initialize/ConfigFileName/ReadString`: resolver bersama DB/security; `DELPHI_API_CONFIG` absolut dan harus ada, lalu default file di samping executable, dengan fallback current directory saat startup. Environment tiap setting tetap prioritas.
- `BFA.Helper.Strings.TGlobalFunction.InitializeSecurity`: validasi dan cache HMAC sebelum listener aktif; request tidak membaca environment/INI atau memeriksa direktori lagi untuk hashing. Perubahan secret membutuhkan restart. Tanpa konfigurasi eksplisit dan tanpa secret environment, secret Linux lama yang tidak kosong di `/var/lib/<nama-executable>/config.ini` tetap diprioritaskan agar key instalasi lama tidak berubah. Jika legacy tidak tersedia, file utama default digunakan.
- `DB.ConnectionFactory.GetConnection`: koneksi yang gagal diinisialisasi/dibuka selalu dibebaskan; koneksi sukses tetap milik request dan dikembalikan ke pool saat dibebaskan.
- `DelphiAPIStarterKit.dpr`: inisialisasi konfigurasi/security sebelum listener, cleanup startup exception, exit code gagal `1`, serta override native library melalui `[Database] VendorHome/VendorLib` atau `DELPHI_API_DB_VENDOR_HOME/DELPHI_API_DB_VENDOR_LIB`. Pesan listener aktif bukan pemeriksaan konektivitas DB.

## Validasi Lokal Terisolasi

Jalankan dari root proyek menggunakan PowerShell dan Node.js yang sudah terpasang:

```powershell
powershell -NoProfile -File sources/tests/run-config-regression.ps1
powershell -NoProfile -File sources/tests/run-core-regressions.ps1
powershell -NoProfile -File sources/tests/run-gzip-regression.ps1
```

Fixture Delphi dibangun ke direktori TEMP baru. Serializer memakai SQLite in-memory; kegagalan koneksi menggunakan definisi yang tidak tersedia; tidak memakai database, token, atau konfigurasi aplikasi nyata.

Fixture gzip memakai bridge Indy/WebBroker sebenarnya pada loopback sementara, lalu memeriksa wire headers/bytes dengan Node.js HTTP dan decoder gzip independen. Executable dibangun ke TEMP dengan config dummy; listener dihentikan setelah setiap kasus. Tidak memakai API/database aplikasi nyata.

## Batas request aktif

`DelphiAPIStarterKit.dpr:RunServer` membaca `[HTTP] MaxConcurrentRequests` (default 64, integer positif) dan menerapkannya pada `WebRequestHandler.MaxConnections` sebelum listener aktif. Startup menolak nilai invalid. Restart diperlukan. Batas ini adalah request/WebModule aktif, bukan jumlah koneksi TCP idle. Sesuaikan pool database dan kapasitas host jika menaikkan batas di atas beban yang sudah teruji.

## Timing kompresi respons

`App.WebModule.WebModuleAfterDispatch` kini mencatat `HTTP compression timing` hanya ketika `DELPHI_API_REQUEST_TIMING=1`. Field: route masked, status, compression_ms, content_encoding, content_bytes. Durasi mencakup Apply (negosiasi, encoding UTF-8, kompresi, penyiapan stream), bukan pengiriman socket. Timing ini terpisah dari pipeline `total_ms` sebelumnya; jangan menjumlahkan statistik persentil antar-fase.


## Customer partial update flag compatibility

Customer.Service.Update reads ftBoolean via AsBoolean/Ord, retaining AsInteger for numeric provider fields. The PUT response numeric 0/1 contract and transaction flow are preserved.

## Dataset response writer and Customer list index

`BFA.Core.Response.WriteResponseField` and the dataset overload of `THelperResponse.CreateResponse` use `TJsonTextWriter` to serialize directly into the response string, without retaining a JSON object tree for every row. Field order, nested-string normalization, numeric/leading-zero conversion, null/Boolean, date/unix fields, request_detail and error envelopes retain their existing semantics. Other response overloads remain unchanged. Regression: `sources/tests/unit/SerializerRegression.dpr` (on-demand EOF, typed fields, escaping, errors).


The optional one-time MySQL 8 migration `docs/databases/customer-list-order-mysql8.sql` adds `(deleted_at, created_at DESC, customer_name ASC)` and refreshes optimizer statistics. Apply once to the selected database after checking existing indexes; it changes no rows. Older MySQL/MariaDB require separate plan validation. Customer lists use SQL LIMIT 50; detail lookup and response fields remain unchanged.

## HTTP admission queue

`BFA.HTTP.Server.TBoundedHTTPWebBrokerBridge` gates dispatch before WebBroker activates a module. `RunServer` configures it from the existing positive `[HTTP] MaxConcurrentRequests`. It permits at most that many executing requests and the same number waiting; queued requests wait at most 5 seconds. Queue overflow/timeout returns the standard JSON HTTP 503 with Retry-After=1, never success. Worker/admission permits are released in finally, including handler exceptions. Indy routes non-GET commands through the virtual DoCommandGet method too, covering POST/PUT/DELETE. No per-request retry or DB connection sharing. Pool size still requires explicit configuration. Configure only once before listener startup; server teardown stops request threads before freeing semaphores.
