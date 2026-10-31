# Improvement: Serializer, Logging, dan Benchmark API

Tanggal pencatatan: 26 Oktober 2026.

Perubahan ini mengurangi pekerjaan berulang pada serializer JSON, menampilkan penyebab exception HTTP 500 pada server, dan menyediakan pengukuran untuk membandingkan performa Windows dengan Linux VM. Hasil benchmark Linux VM terakhir memenuhi seluruh threshold yang ditetapkan, termasuk threshold per endpoint.

## 1. Optimasi format angka pada serializer

File: [sources/core/BFA.Core.Response.pas](sources/core/BFA.Core.Response.pas).

Sebelumnya, `TValueValidator.IsNumber` membuat `TFormatSettings.Create('en-US')` pada setiap pemanggilan. Fungsi ini dipakai oleh `JSONValueFromString` saat mengubah nilai field menjadi JSON. Ketika respons berisi banyak record dan field, inisialisasi locale ikut berulang.

Sebelum:

```pascal
class function TValueValidator.IsNumber(AValue: string): Boolean;
var
  LDummy: Single;
  LFormatSettings: TFormatSettings;
begin
  LFormatSettings := TFormatSettings.Create('en-US');
  Result := (Pos(',', AValue) = 0) and
    TryStrToFloat(AValue, LDummy, LFormatSettings);
end;
```

Sesudah:

```pascal
var
  GJSONNumberFormatSettings: TFormatSettings;

class function TValueValidator.IsNumber(AValue: string): Boolean;
var
  LDummy: Single;
begin
  Result := (Pos(',', AValue) = 0) and
    TryStrToFloat(AValue, LDummy, GJSONNumberFormatSettings);
end;

initialization
  GJSONNumberFormatSettings := TFormatSettings.Create('en-US');
```

Konteks angka sekarang dibuat sekali pada initialization unit, sebelum thread request berjalan, dan selanjutnya hanya dibaca. Ini merupakan perubahan utama yang langsung mengurangi pekerjaan CPU pada serialisasi; peningkatan tidak bergantung pada aktivasi timing.

Pengaturan `FormatBr` dan `System.SysUtils.FormatSettings` pada `RunServer` adalah perubahan pemilik yang sudah ada dan tetap dipertahankan. Konteks serializer tetap eksplisit `en-US`, sehingga tidak bergantung pada perubahan format global saat runtime. Pemeriksaan koma, penggunaan `Single`, perlakuan null, string dengan nol awal, tanggal, dan normalisasi JSON mengikuti perilaku sebelumnya.

## 2. Timing Customer untuk diagnosis

File: [sources/modules/customers/Customer.Service.pas](sources/modules/customers/Customer.Service.pas).

Ditambahkan `TCustomerFetchTiming` dan pengukuran `TStopwatch` pada `TCustomerService.Get`. Timing aktif hanya jika environment proses server berisi `DELPHI_API_CUSTOMER_TIMING=1` sebelum aplikasi dimulai. Default nonaktif; nilai environment dibaca sekali pada initialization unit.

| Field log | Yang diukur |
|---|---|
| `query_open_ms` | Pembuatan query dan `Open` pada repository, termasuk fetch awal |
| `remaining_fetch_ms` | Fetch lanjutan selama serialisasi, melalui event `Command.BeforeFetch` dan `Command.AfterFetch` |
| `json_ms` | Durasi `CreateResponse` dikurangi fetch lanjutan; mencakup akses field, navigasi dataset, alokasi, serialisasi, dan pelepasan objek JSON di luar event fetch |
| `serialize_with_fetch_ms` | Durasi lengkap pemanggilan `CreateResponse`, termasuk fetch lanjutan |
| `fetched_rows` | `RecordCount` dataset setelah serialisasi |
| `response_utf8_bytes` | Ukuran JSON UTF-8 sebelum kompresi HTTP |
| `remaining_fetch_count` | Jumlah event fetch lanjutan yang tercatat |

Event dipasang pada query milik request tersebut dan dilepas sebelum query dibebaskan. Tidak ada pemaksaan `FetchAll`, perubahan SQL, atau penambahan pagination. Log memakai route umum `/{customer_id}`, tanpa menuliskan ID aktual, isi record, atau token.

Timing dicetak melalui `Writeln` untuk respons Customer GET 200/404. Waktu pembukaan koneksi pada WebModule, autentikasi, pengiriman HTTP, serta jaringan berada di luar pengukuran service ini. `remaining_fetch_ms` sudah termasuk dalam `serialize_with_fetch_ms`, sehingga tidak boleh dihitung dua kali. Pencetakan log dan perhitungan ukuran menambah overhead diagnostik di luar timing serialisasi.

Untuk merekam output saat menjalankan binary Linux secara manual:

```bash
cd /opt/DelphiAPIStarterKit
DELPHI_API_CUSTOMER_TIMING=1 ./DelphiAPIStarterKit 2>&1 \
  | tee "$HOME/DelphiAPIStarterKit-timing.log"
```

Lokasi file mengikuti akun yang menjalankan perintah. Jika dijalankan sebagai root, `$HOME` mengarah ke `/root`. Timing tidak otomatis ditulis ke `server-error.log`. Petunjuk lengkap tersedia di [docs/k6/benchmark.md](docs/k6/benchmark.md).

## 3. Exception logging pada console dan file

Sebelumnya, sebagian jalur exception hanya menghasilkan respons generik HTTP 500 atau menulis ke file. Perubahan berikut membuat detailnya tersedia bagi operator server:

| Unit | Perubahan |
|---|---|
| [BFA.Core.Endpoint.pas](sources/core/BFA.Core.Endpoint.pas) | `THelperEndpoint.WriteErrorLog` menulis timestamp, sumber, kelas exception, dan pesan ke console serta `server-error.log` di direktori executable |
| [BFA.Core.Rest.pas](sources/core/BFA.Core.Rest.pas) | `WriteCoreErrorLog` memakai logger bersama untuk kegagalan pemuatan request dan dispatch |
| [App.WebModule.pas](sources/app/App.WebModule.pas) | `WMapiAction` menangkap exception yang lolos sebelum/di luar core, termasuk kegagalan membuka koneksi, lalu membentuk respons JSON 500 generik |
| [Auth.Service.pas](sources/modules/auth/Auth.Service.pas) | `WriteAuthErrorLog` memakai logger bersama |
| [User.Service.pas](sources/modules/users/User.Service.pas) | Exception yang ditangkap diteruskan melalui `InternalServerError(E)` dan dicatat |
| [Product.Service.pas](sources/modules/products/Product.Service.pas) | Exception yang ditangkap diteruskan melalui `InternalServerError(E)` dan dicatat |
| [Category.Service.pas](sources/modules/category/Category.Service.pas) | Exception yang ditangkap diteruskan melalui `InternalServerError(E)` dan dicatat |
| [Customer.Service.pas](sources/modules/customers/Customer.Service.pas) | Exception yang ditangkap diteruskan melalui `InternalServerError(E)` dan dicatat |

Kegagalan output console/file ditangani secara terpisah agar tidak menggantikan respons error asli. Respons HTTP tetap menggunakan pesan `Internal server error.` dan envelope yang sudah ada. Detail internal berada pada log server; logger tidak menambahkan request body atau header autentikasi.

Melalui logging ini, kegagalan konfigurasi `DELPHI_API_HMAC_SECRET` dapat diidentifikasi. Algoritma HMAC dan mekanisme pencarian secret tidak diubah pada pekerjaan ini. Nilai secret/password/token tidak dicatat dalam dokumen ini.

## 4. Pengembangan skrip k6

File: [docs/k6/api-read-test-all.js](docs/k6/api-read-test-all.js).

- Melengkapi delapan endpoint GET daftar/detail User, Product, Category, dan Customer.
- Menghapus token dan ID fixture bawaan; token berasal dari environment `API_TOKEN`, sedangkan ID dapat ditemukan dari daftar atau diisi melalui environment.
- Memakai `x-api-token`, sesuai dukungan server saat ini. Pengujian langsung sebelumnya menunjukkan header Bearer ditolak Indy dengan `Unsupported authorization scheme` sebelum validasi token API.
- Menambahkan preflight daftar/detail, validasi envelope JSON, public ID, kecocokan ID detail, dan jumlah baris daftar pada console.
- Menambahkan `checks: rate==1` agar kegagalan validasi turut menggagalkan pengujian.
- Menambahkan tag `phase` dan `endpoint`, threshold per endpoint, minimal satu request per endpoint pada fase load, serta statistik p99.
- Menambahkan mode `SMOKE=1`, filter `RESOURCE`, beban tetap `FIXED_VUS`, durasi `TEST_DURATION`, dan pengujian gambar opsional `IMAGE_FILENAME`.
- Menormalkan URL, menambahkan timeout 30 detik dan menonaktifkan redirect agar respons endpoint asli diperiksa.
- Default URL menjadi `http://127.0.0.1:9999`, mengikuti port aplikasi. Profil bawaan tetap lima tahap 15 detik menuju `5 -> 10 -> 15 -> 25 -> 0` VU.

Throughput `http_reqs` global adalah gabungan semua endpoint, bukan throughput Customer saja atau kapasitas maksimum server. Threshold per endpoint memakai sampel `phase:load`, sedangkan statistik global mencakup preflight. Semua request dapat berhasil secara HTTP, tetapi tes tetap gagal jika p95 salah satu endpoint melewati 500 ms.

Contoh benchmark yang dipakai pada Linux VM:

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 docs/k6/api-read-test-all.js
```

Contoh diagnosis Customer dengan beban tetap:

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/api-read-test-all.js
```

## 5. Hasil benchmark Linux VM terakhir

Sumber: snapshot [docs/k6/result.txt](docs/k6/result.txt) dan [docs/k6/DelphiAPIStarterKit-timing.log](docs/k6/DelphiAPIStarterKit-timing.log) yang disediakan pemilik. Angka berikut dipertahankan sebagai snapshot pencatatan; file hasil dapat diperbarui pada pengujian berikutnya.

| Metrik k6 | Hasil |
|---|---:|
| Target | `192.168.0.110:9999` |
| Durasi aktual | 75,7 detik |
| VU maksimum tercapai | 25 |
| Total request | 7.272 |
| Throughput gabungan rata-rata | 96,07 request/detik |
| Request gagal | 0% |
| Checks berhasil | 61.812 dari 61.812 (100%) |
| Rata-rata HTTP keseluruhan | 33,61 ms |
| p95 HTTP keseluruhan | 185,56 ms |
| p99 HTTP keseluruhan | 388,26 ms |
| Rata-rata HTTP Customer list | 197,83 ms |
| p95 HTTP Customer list | 415,05 ms |
| p99 HTTP Customer list | 530,17 ms |
| Respons maksimum | 750,09 ms |
| Request Customer list selama load | 908, sekitar 12 request/detik |
| Iterasi selesai / terputus | 908 / 0 |
| Status threshold global dan per endpoint | LULUS |

Customer list berisi 100 baris. Dari 907 baris timing Customer list yang utuh:

| Bagian service | Rata-rata | p95 |
|---|---:|---:|
| Query/open, termasuk fetch awal | 32,99 ms | 46,21 ms |
| Fetch lanjutan | 0 ms | 0 ms |
| Pembentukan JSON | 19,41 ms | 28,04 ms |
| Gabungan query dan JSON | 52,40 ms | 71,27 ms |

Ukuran JSON Customer list adalah 492.335 byte, sekitar 481 KiB. Tidak ada fetch lanjutan yang tercatat untuk 100 baris pada run ini; biaya fetch awal sudah masuk query/open.

Selisih rata-rata HTTP Customer list dengan waktu service sekitar 145 ms. Ini perkiraan dari dua kumpulan sampel yang tidak dipasangkan per request; belum dapat diatribusikan ke jaringan saja. Pembukaan koneksi, autentikasi, antrean pemrosesan, encoding/pengiriman respons, dan jaringan belum diukur terpisah.

Hasil menunjukkan performa baca yang memenuhi target pada skenario ini. Cache locale adalah perubahan yang langsung mengurangi pekerjaan serializer, tetapi besarnya kontribusi tunggalnya memerlukan perbandingan dengan data, binary, instrumentasi, dan kondisi beban yang setara. Hasil ini belum membuktikan kapasitas maksimum atau ketahanan jangka panjang pada 25 VU tetap.

## 6. Validasi yang telah dilakukan

- Build Win64 Release dan Linux64 Release lulus pada salinan proyek terisolasi.
- Respons sebelum/sesudah optimasi dibandingkan pada fixture; hasil identik setelah mengabaikan timestamp `servertime` yang memang berubah.
- Fixture mencakup null, Unicode, tipe angka, string dengan nol awal, tanggal beserta field Unix, dan JSON bertingkat pada dataset 2.500 baris.
- Sebanyak 16.000 pemeriksaan parsing concurrent lulus.
- Customer list/detail/404 diuji memakai SQLite terisolasi; timing aktif/nonaktif mempertahankan respons yang sama dan event fetch lanjutan terdeteksi.
- Tujuh skenario k6 fixture lulus: delapan endpoint, Customer smoke, Customer beban tetap, gambar opsional, penolakan envelope rusak, resource tidak valid, dan jumlah VU tidak valid. Kasus negatif lulus ketika skrip mengembalikan kegagalan yang diharapkan.
- Penanganan exception service dan kegagalan output file log diuji secara lokal dengan respons 500 tetap sesuai envelope.
- Benchmark Linux VM di atas dijalankan pemilik dan lognya dianalisis; ini merupakan bukti runtime untuk run tersebut. Pemeriksaan SSH dilakukan tanpa mengubah konfigurasi atau me-restart server oleh asisten.

## 7. Batasan dan pekerjaan tertunda

1. **Kondisi snapshot sebelum perbaikan lanjutan:** log timing menunjukkan beberapa baris tercampur/terpotong pada request paralel. Analisis hanya menggunakan 1.811 baris timing yang utuh: 907 list dan 904 detail. Sinkronisasi logger telah ditambahkan pada bagian 9; snapshot log dan statistik HTTP lama tetap dipertahankan.
2. **Pagination ditunda sesuai arahan pemilik.** Query, fetch options, serta kontrak jumlah hasil tidak diubah pada optimasi ini.
3. **Bug `RecordCount` pada snapshot lama:** pada fixture 2.300 Customer dengan rowset 1.000, serializer hanya mengembalikan 1.000 baris, sementara dataset sudah memuat 2.000 baris. Bagian 9 memperbaiki iterasi sampai `Eof`; respons besar sekarang lengkap dan dapat memiliki ukuran/waktu lebih tinggi daripada respons lama yang terpotong.
4. **Sebagian request Customer list masih lebih dari 500 ms.** p95 lulus, sedangkan p99 530,17 ms dan maksimum 750,09 ms. Threshold p95 tidak mensyaratkan setiap request di bawah 500 ms.
5. **Pengukuran belum mencakup seluruh jalur HTTP.** Pemisahan waktu koneksi/auth, antrean, encoding/send, dan transfer jaringan belum tersedia. Beban tetap 25 VU dan soak test jangka panjang belum terbukti oleh run lima tahap ini.

## 8. Dokumen pendamping dan kepemilikan perubahan

- [docs/k6/benchmark.md](docs/k6/benchmark.md): cara menjalankan benchmark, environment timing, serta interpretasi metrik.
- [docs/information/information.md](docs/information/information.md): peta logger, serializer, dan alur timing untuk navigasi source.
- [docs/k6/compare.md](docs/k6/compare.md): snapshot perbandingan mesin yang sebelumnya dicatat atas permintaan pemilik; tidak diperbarui oleh penulisan dokumen ini.
- `DelphiAPIStarterKit.dpr`: pengaturan format global, port, dan konfigurasi library Linux milik pemilik dipertahankan pada tahap optimasi ini; tidak diklaim sebagai perubahan asisten.

Penulisan `IMPROVEMENT.md` ini hanya mendokumentasikan implementasi dan bukti yang sudah ada. Tidak sekaligus memperbaiki sinkronisasi logger, mengubah API/database, menambahkan pagination, atau menjalankan benchmark/deployment baru.

## 9. Perbaikan lanjutan setelah review Windows/Linux

Pekerjaan lanjutan pada 26 Oktober 2026 memperbaiki source berdasarkan review berikutnya. Bagian 1-8 dan hasil benchmark di atas merupakan snapshot pekerjaan sebelumnya; angka tersebut bukan pengukuran binary hasil perbaikan bagian ini.

### Serializer dan locale

- `BFA.Core.Response`: iterasi dataset sampai `Eof` agar seluruh batch FireDAC dikembalikan. Referensi field disiapkan sekali per array, dengan urutan field lama dipertahankan; tidak ada penambahan pagination, perubahan SQL, atau perubahan inferensi tipe JSON.
- `Product.DTO` dan `Product.Validator`: konteks `en-US` dibuat sekali saat initialization, sehingga create/update Product tidak mengulang inisialisasi locale setiap pemanggilan. Fallback parsing harga lama tetap berlaku.
- Pemeriksaan RTL Delphi 13 terpasang menunjukkan jalur Linux ICU melakukan pencarian seluruh daftar locale dan membuat formatter angka/tanggal/kalender. Itu menjelaskan risiko penggunaan `TFormatSettings.Create` per field. Jalur ICU/native yang benar-benar dipakai binary Linux sebelumnya dan kontribusi persis terhadap selisih RPS belum diukur secara A/B.

### Konfigurasi dan resource

- `TServerConfig` menjadi resolver DB/security bersama: `DELPHI_API_CONFIG` absolut dan harus merujuk file yang ada; tanpa override, file di samping executable diprioritaskan, lalu current directory saat startup. Environment setting tetap prioritas; konfigurasi env-only tetap didukung.
- `TGlobalFunction.InitializeSecurity` memvalidasi dan menyimpan HMAC secret sebelum listener aktif. Hashing request tidak lagi membaca environment/INI atau memeriksa direktori. Restart diperlukan setelah secret berubah. Tanpa konfigurasi eksplisit atau secret environment, secret Linux lama yang tidak kosong tetap diprioritaskan agar key instalasi lama tidak berubah; pembacaan tidak membuat direktori. `TIniFile` dipertahankan untuk kompatibilitas nilai INI berpetik di Windows.
- `TDBConnectionFactory.GetConnection` membebaskan objek bila connect gagal. Cleanup WebModule dan startup juga melindungi kegagalan constructor berikutnya.
- Lokasi native MySQL client dapat diatur melalui `[Database] VendorHome/VendorLib` atau environment yang sesuai. Default Windows mengikuti direktori executable; Linux mempertahankan path `.so.21` yang lama jika tersedia dan memakai lookup FireDAC bila tidak tersedia.
- Startup configuration/storage exceptions tidak lagi ditelan; proses keluar dengan kode `1`. Listener aktif tetap bukan bukti konektivitas database.

### Logging dan benchmark

- Error dan timing memakai satu kunci output agar setiap baris utuh. Kegagalan console/file tetap tidak mengubah respons. Logger tetap sinkron; timing default nonaktif dan sink lambat masih dapat menambah latensi ketika logging aktif.
- `DELPHI_API_REQUEST_TIMING=1` menambahkan request ID, route tersamarkan, waktu koneksi, dispatch, penyiapan respons, dan total sampai cleanup pada WebModule. HTTP send, antrean sebelum handler, output console, serta pembentukan respons exception oleh handler luar berada di luar pengukuran ini. Default nonaktif melewati stopwatch/counter/logging.
- k6 mendukung `EXPECTED_USER_ROWS`, `EXPECTED_PRODUCT_ROWS`, `EXPECTED_CATEGORY_ROWS`, dan `EXPECTED_CUSTOMER_ROWS` untuk memeriksa jumlah fixture pada preflight dan setiap respons list saat load. Respons terpotong kini menggagalkan tes bila jumlah yang diharapkan diberikan.
- `ENDPOINT=all|list|detail` memungkinkan isolasi beban. Default terkini tetap tujuh tahap `5 -> 10 -> 15 -> 25 -> 30 -> 35 -> 0` selama 105 detik, berbeda dari snapshot lima tahap di atas. `FIXED_VUS` dan parameter identik perlu dipakai untuk A/B.
- Snapshot terbaru `result.txt` memuat 123,85 RPS pada profil 35 VU dengan Customer list p95 761,33 ms, sehingga threshold endpoint gagal. Hasil ini mendahului perbaikan bagian 9. Tidak ada klaim peningkatan RPS baru dari fixture atau cross-compile.

Validasi dan workflow fixture dipetakan di `docs/information/information.md`. Pengukuran ulang dengan MySQL/native client dan runtime Linux tetap diperlukan untuk menentukan dampak performa akhir; query Customer tanpa pagination tetap memiliki biaya yang bertambah mengikuti jumlah/ukuran data.

### Validasi perbaikan lanjutan

- Build aplikasi lengkap Win64 Release dan Linux64 Release dengan Delphi 13/Studio 37.0 serta SDK Ubuntu 24.04: lulus. Build final dilakukan pada salinan terisolasi; resource `.res` asli proyek dipertahankan. Tidak ada deployment atau restart server.
- Serializer SQLite in-memory, 2.305 record dengan `fmOnDemand`/rowset 1.000: 119.890 pemeriksaan lulus, termasuk seluruh jalur JSON, urutan, null, Unicode, nol awal, nested JSON, currency/boolean/date/Unix, request detail, dan array kosong. Kontrol negatif dengan loop lama gagal pada kelengkapan record sesuai harapan.
- Infrastructure: 4.458 pemeriksaan lulus; 200 kegagalan koneksi tanpa objek tertinggal, 960 baris console dan 480 baris file lengkap dari delapan thread, serta kegagalan console/file yang terisolasi. Kontrol negatif factory lama menunjukkan leak sesuai harapan.
- Konfigurasi/security: 13 skenario subprocess Win64 dan 16.000 hash concurrent lulus; termasuk prioritas path/environment, path eksplisit invalid, cache tetap setelah perubahan INI/environment, dan kompatibilitas nilai berpetik. Fixture juga lulus cross-compile Linux64; fallback file legacy Linux belum diuji runtime.
- Binary aplikasi lengkap Win64 diuji dengan path konfigurasi eksplisit yang hilang dan secret yang kosong: kedua kasus berhenti dengan exit code `1` sebelum pembuatan DataModule/listener, tanpa akses database.
- k6: 12 skenario fixture HTTP loopback lulus, termasuk 2.300 record, default delapan endpoint, isolasi list/detail, jumlah salah pada preflight/load, serta konfigurasi invalid. Ini bukan benchmark aplikasi/DB sebenarnya.
- Timing API: 10 pemeriksaan lokal dari fungsi source aktual dengan dependency palsu lulus untuk default off, masking route, cleanup, multipart, dan propagasi exception ketika diagnostik gagal. Ini bukan pengujian HTTP/WebBroker/native DB lengkap.

## 10. Kompresi gzip pada respons WebBroker

Implementasi 26 Oktober 2026 menambahkan `sources/infrastructure/http/BFA.HTTP.Compression.pas`, dipanggil dari event `App.WebModule.AfterDispatch`. Unit didaftarkan pada DPR/DPROJ dan event dihubungkan pada DFM. Service/repository tetap menghasilkan JSON yang sama; kompresi diterapkan sebelum pengiriman HTTP.

```ini
[HTTP]
GzipEnabled=True
GzipMinimumBytes=1024
GzipLevel=1
```

| Setting | Fungsi |
|---|---|
| `GzipEnabled` | Mengaktifkan kompresi JSON untuk client yang menerima gzip. `False` mempertahankan respons identity. |
| `GzipMinimumBytes` | Batas ukuran body UTF-8 sebelum kompresi dalam byte; 1024 = 1 KiB. Nilai 0 menonaktifkan batas minimum, tetapi body kosong/output yang membesar tetap dilewati. |
| `GzipLevel` | Level zlib 1-9. Level 1 mengutamakan kecepatan dan CPU rendah; level lebih tinggi biasanya memperkecil transfer dengan biaya CPU lebih besar. |

Default jika section/setting belum ada sama dengan contoh. Nilai dimuat sekali melalui resolver konfigurasi bersama sebelum listener aktif, divalidasi, dan memerlukan restart untuk berubah. File konfigurasi/secret lokal tidak diedit; template root dan `bin` diperbarui.

JSON kini mendeklarasikan `charset=utf-8` pada `Content-Type`, bukan `Content-Encoding`. Gzip menghasilkan wrapper sebenarnya (header dan CRC trailer), `Content-Encoding: gzip`, serta `Vary: Accept-Encoding` yang digabung tanpa menghapus nilai sebelumnya. `Content-Length` mengikuti compressed stream. Indy memprioritaskan `ContentText`, sehingga text dikosongkan setelah gzip selesai; stream ditransfer ke ownership WebBroker dengan cleanup/rollback saat pemasangan gagal.

Kompresi menghormati `gzip;q=0`, bobot valid dan wildcard. Identity digunakan bila client tidak menerima gzip, body kurang dari minimum, atau kompresi memperbesar payload. JSON berupa stream/existing coding, gambar, HEAD/CONNECT, status tanpa body/partial, range, `no-transform`, serta validator/digest lama dilewati. Tidak ada kompresi request/upload, cache respons, perubahan SQL, atau pagination.

`RESPONSE_ENCODING=auto|gzip|identity` pada k6 memudahkan A/B tanpa mengganti konfigurasi server. Pemeriksaan optional expected-count juga menangani `null` setelah serialisasi hasil setup k6. Petunjuk ada di `docs/k6/benchmark.md`; timing `SendToCoreAPI.total_ms` tidak mencakup gzip di `AfterDispatch`.

Validasi:

- Build aplikasi lengkap Win64 Release dan cross-compile Linux64 Release: lulus pada salinan terisolasi.
- 138 pemeriksaan HTTP menggunakan bridge Indy/WebBroker lokal dan decoder gzip Node.js: lulus. Mencakup Unicode, byte identik setelah dekompresi, 2.305 record, batas 1023/1024 byte, level 1-9, 32 request paralel, Vary, negosiasi q/wildcard, status/body/stream skip, ukuran membesar, konfigurasi invalid, dan cache hingga restart.
- Fixture repetitif 247.872 byte menghasilkan gzip level 1 sebesar 7.019 byte. Ini ukuran fixture, bukan benchmark throughput/payload Customer produksi.
- 15 skenario fixture k6 lulus, termasuk gzip/identity dan parsing JSON gzip; 13 skenario konfigurasi dengan 16.000 hash concurrent serta 124.348 pemeriksaan core sebelumnya juga lulus ulang.
- Tidak menjalankan runtime Linux atau benchmark server nyata, deployment, maupun restart service. Rasio kompresi, CPU, dan p95/RPS Linux memerlukan A/B pada data/beban yang sama.
