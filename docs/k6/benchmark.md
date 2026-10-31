# Benchmark Customer: Windows dan Linux

Pagination ditunda. Query dan envelope JSON dipertahankan. Profil bawaan skrip saat ini terdiri dari tujuh tahap, masing-masing 15 detik, menuju `5 -> 10 -> 15 -> 25 -> 30 -> 35 -> 0` VU (105 detik). Snapshot lima tahap/25 VU di `IMPROVEMENT.md` dan `compare.md` adalah hasil historis dengan profil berbeda.

## Format angka

Pengaturan `System.SysUtils.FormatSettings` pada `RunServer` mengatur format global sebelum listener aktif. Pengaturan itu tetap dipertahankan. `TValueValidator.IsNumber` di `sources/core/BFA.Core.Response.pas` memakai overload `TryStrToFloat` dengan konteks eksplisit; sebelumnya konteks `en-US` dibuat pada setiap pemanggilan.

Konteks khusus serializer sekarang dibuat sekali pada initialization unit, sebelum thread request berjalan, dan selanjutnya hanya dibaca. Ini mempertahankan perilaku angka sebelumnya serta menghindari ketergantungan parser JSON pada perubahan format global. Format tanggal, null, string dengan nol awal, dan normalisasi JSON tidak diubah.

## Timing server opsional

Set `DELPHI_API_CUSTOMER_TIMING=1` pada environment **proses server sebelum startup**. Nilai dibaca saat initialization unit; mengubah environment pada terminal lain tidak memengaruhi server yang sudah berjalan. Default timing nonaktif.

Contoh PowerShell untuk proses server yang akan dijalankan:

```powershell
$env:DELPHI_API_CUSTOMER_TIMING = '1'
```

Contoh shell Linux untuk proses server yang akan dijalankan:

```bash
export DELPHI_API_CUSTOMER_TIMING=1
```

Jika memakai service manager, pasang environment tersebut pada konfigurasi service yang menjalankan executable. Gunakan cara startup dan working directory proyek yang sudah ada.

`TCustomerService.Get` mencetak satu baris console untuk respons 200/404:

```text
Customer timing: route=/api/v1/Customer status=200 query_open_ms=... remaining_fetch_ms=... json_ms=... serialize_with_fetch_ms=... fetched_rows=... response_utf8_bytes=... remaining_fetch_count=...
```

| Field | Makna |
|---|---|
| `query_open_ms` | Pembuatan query dan `Open`, termasuk fetch awal yang dilakukan sebelum repository mengembalikan dataset |
| `remaining_fetch_ms` | Waktu di antara event `Command.BeforeFetch`/`AfterFetch` selama serialisasi; tidak mencakup fetch awal pada `Open` |
| `json_ms` | Durasi pembentukan dan pelepasan objek JSON, dikurangi `remaining_fetch_ms`; tetap mencakup akses field, navigasi dataset, dan alokasi objek di luar event fetch |
| `serialize_with_fetch_ms` | Durasi pemanggilan `CreateResponse`, termasuk fetch lanjutan |
| `fetched_rows` | `RecordCount` dataset setelah serialisasi; jumlah record yang telah tersedia pada dataset, bukan bukti semua baris tabel sudah dikembalikan |
| `response_utf8_bytes` | Ukuran UTF-8 JSON sebelum kompresi HTTP |
| `remaining_fetch_count` | Jumlah event fetch lanjutan setelah repository mengembalikan dataset |

Untuk perkiraan waktu query/fetch gabungan, gunakan `query_open_ms + remaining_fetch_ms`. Jangan menjumlahkan `remaining_fetch_ms` lagi ke `serialize_with_fetch_ms`, karena sudah termasuk di dalamnya. Timing service tidak mencakup autentikasi, pembukaan koneksi di WebModule, pengiriman HTTP, atau jaringan; gunakan k6 untuk durasi HTTP.

Event fetch dipasang hanya pada query milik request tersebut dan dilepas sebelum query dibebaskan. Timing tidak memanggil `FetchAll`, tidak menambahkan `LIMIT`, dan tidak mencatat isi record, parameter SQL, body respons, atau token. Pencetakan console dan perhitungan ukuran menambah overhead diagnostik; gunakan keadaan timing yang sama ketika membandingkan dua run.

Jumlah baris respons diperiksa secara opsional dengan `EXPECTED_USER_ROWS`, `EXPECTED_PRODUCT_ROWS`, `EXPECTED_CATEGORY_ROWS`, dan `EXPECTED_CUSTOMER_ROWS`. Isi dengan jumlah record aktif yang seharusnya dikembalikan fixture/database uji yang stabil; skrip memeriksanya pada preflight dan setiap respons list selama load. Nilai harus berupa integer positif yang aman untuk JavaScript. Nilai `0` ditolak karena layanan saat ini mengembalikan 404 untuk list kosong, sedangkan pengujian ini memerlukan HTTP 200 dan data untuk penemuan ID detail. Tanpa nilai tersebut, pemeriksaan lama tetap berlaku dan tidak membuktikan kelengkapan list.

Gunakan jumlah record dari sumber fixture/database yang terpisah, bukan angka `list_rows` dari respons yang sedang diuji. Perbaikan serializer yang menelusuri dataset sampai `Eof` menghindari batas `RecordCount` awal; versi lama dapat mengembalikan hanya 1.000 dari fixture 2.300 baris. Perbedaan jumlah hasil itu harus diperhitungkan ketika membandingkan performa. `fetched_rows` tetap merupakan jumlah yang tersedia dalam dataset setelah serialisasi; gunakan pemeriksaan expected count untuk memverifikasi jumlah record respons terhadap fixture.

## Timing pipeline API opsional

Aktifkan `DELPHI_API_REQUEST_TIMING=1` pada environment proses server sebelum startup untuk menambah satu baris per request API:

```text
API request timing: request_id=... route=/api/v1/Customer status=200 connection_ms=... dispatch_ms=... response_prepare_ms=... total_ms=...
```

- `connection_ms`: pembuatan/peminjaman koneksi, termasuk pembukaan koneksi jika diperlukan.
- `dispatch_ms`: dispatch core, autentikasi, query resource, dan serialisasi service.
- `response_prepare_ms`: penetapan status/content pada respons WebBroker; bukan transfer HTTP.
- `total_ms`: sejak masuk `SendToCoreAPI` sampai cleanup objek/koneksi, sebelum pencetakan log. Ini juga mencakup parsing route dan overhead yang tidak masuk tiga fase di atas.

`request_id` unik per proses. Route memakai nama resource yang dikenal dan `/{id}`; nilai ID, query, token, dan body tidak dicetak. Request yang melempar exception dicatat sebagai status `500`; pembentukan respons error oleh handler luar berada setelah timing ini. HTTP send, antrean sebelum masuk handler, dan jaringan berada di luar `total_ms`.

Kompresi gzip dijalankan pada `AfterDispatch`, setelah `SendToCoreAPI` selesai, sehingga waktu kompresi juga berada di luar `total_ms`. Gunakan durasi HTTP k6 untuk membandingkan jalur lengkap.

Timing default nonaktif; kondisi nonaktif tidak mengambil stopwatch atau increment counter. Baris timing dan error memakai lock output yang sama. Logger tetap sinkron, sehingga console/pipe lambat bisa menambah latensi setelah timing berhenti. Gunakan timing untuk diagnosis dan matikan kedua flag timing saat membandingkan throughput utama. Timing Customer tetap menyediakan rincian query/fetch/JSON di dalam dispatch; jangan menjumlahkannya kembali ke dispatch/total.

## Urutan sebelum dan sesudah

1. Simpan binary baseline yang sedang dipakai, versi source, konfigurasi Release, platform, hardware/core, lokasi database, jumlah data, dan kondisi jaringan. Jangan mengganti binary selama run berlangsung.
2. Jalankan skrip k6 yang sama terhadap binary baseline. Selanjutnya jalankan terhadap binary hasil optimasi di mesin Linux yang sama, dengan database dan kondisi beban yang sama.
3. Isi `EXPECTED_<RESOURCE>_ROWS` dari fixture yang sama untuk kedua run. Bandingkan jumlah `list_rows` pada preflight, jumlah request, throughput, p95/p99 per endpoint, serta CPU/RAM. Respons Customer list dan detail harus tetap lolos validasi. Jika jumlah baris/payload berbeda, hasil performa perlu diperiksa sebelum dinilai sebagai peningkatan.
4. Gunakan timing untuk diagnosis pada binary yang sudah mendukungnya. Untuk perbandingan throughput dengan binary lama tanpa timing, biarkan timing nonaktif pada binary baru. Untuk perbandingan murni waktu query/JSON, kedua binary harus memiliki instrumentasi yang sama.

Smoke Customer (dua endpoint: daftar dan detail):

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e EXPECTED_CUSTOMER_ROWS=100 -e SMOKE=1 docs/k6/api-read-test-all.js
```

Beban tetap 5 VU selama 60 detik, sesuaikan URL dengan mesin yang diuji. `API_TOKEN` tetap berasal dari environment terminal k6:

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s --summary-export docs/k6/customer-before.json docs/k6/api-read-test-all.js
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s --summary-export docs/k6/customer-after.json docs/k6/api-read-test-all.js
```

Angka `100` pada contoh hanya sesuai fixture 100 Customer; ganti sesuai jumlah record aktif fixture sendiri. Jalankan perintah `before` sebelum mengganti binary dan `after` setelah binary optimasi aktif. Ulangi dengan 10, 15, 25, dan 35 VU bila diperlukan; gunakan nama file berbeda per level. Pemilihan `RESOURCE=Customer` dengan `ENDPOINT=all` bawaan menjalankan daftar dan detail Customer dalam setiap iterasi. Angka throughputnya tidak langsung setara dengan run delapan endpoint.

Untuk memisahkan list dan detail saat load:

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e ENDPOINT=list -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s --summary-export docs/k6/customer-list.json docs/k6/api-read-test-all.js
k6 run -e BASE_URL=http://192.168.0.110:9999 -e RESOURCE=Customer -e ENDPOINT=detail -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s --summary-export docs/k6/customer-detail.json docs/k6/api-read-test-all.js
```

`ENDPOINT` menerima `all`, `list`, atau `detail`. Detail-only tetap membaca list sekali pada preflight untuk memvalidasi expected count dan menemukan ID; hanya detail yang masuk fase load. List-only tidak melakukan request detail. `IMAGE_FILENAME`, jika diisi, tetap menambahkan endpoint gambar; kosongkan untuk isolasi resource. Threshold per endpoint hanya dibuat untuk endpoint yang dipilih pada load.

Tanpa `FIXED_VUS`, profil tujuh tahap bawaan tetap berlaku. Tanpa `RESOURCE`, semua empat resource tetap diuji. Tanpa `ENDPOINT`, delapan GET daftar/detail tetap dijalankan. `SMOKE=1` mengambil prioritas sebagai 1 VU/1 iterasi.

Setiap VU menjalankan endpoint secara berurutan, dengan jeda 50 ms per endpoint dan 200 ms setelah iterasi. Dalam profil delapan GET, jeda totalnya 600 ms per iterasi. Throughput global adalah gabungan endpoint dengan pacing tersebut; angka 90 RPS tidak mengukur kapasitas maksimum. Request list yang lambat turut menahan iterasi seluruh resource. Bandingkan p95/p99 per endpoint pada beban tetap yang sama, karena p95 global dapat lulus ketika Customer list gagal.

k6 menampilkan submetric berdasarkan tag `phase:load,endpoint:Customer_list` dan `Customer_detail` beserta endpoint lain yang dipilih. Threshold per endpoint tetap p95 <500 ms, kegagalan <1%, dan minimal satu request selama fase load. Preflight tidak masuk submetric load; statistik global tetap mencakup preflight. Summary juga menampilkan p99.

File hasil dan `compare.md` tidak diperbarui otomatis. Pengujian Windows/fixture membuktikan kompatibilitas lokal; peningkatan performa Linux harus dibuktikan dari run sebelum/sesudah pada server Linux.

## Perbandingan gzip dan identity

Konfigurasi server:

```ini
[HTTP]
GzipEnabled=True
GzipMinimumBytes=1024
GzipLevel=1
```

`GzipEnabled` mengaktifkan kompresi untuk client yang menerima gzip. `GzipMinimumBytes` adalah ukuran body UTF-8 sebelum kompresi, dalam byte (1024 = 1 KiB); respons kecil dilewati agar overhead kompresi tidak mendominasi. `GzipLevel` menerima 1-9: 1 mengutamakan kecepatan/CPU rendah, 6 merupakan kompromi umum zlib, dan 9 mengutamakan rasio kompresi dengan pekerjaan CPU lebih besar. Output level tinggi tidak dijamin selalu lebih kecil untuk setiap payload. Default server tanpa `[HTTP]` sama dengan contoh; perubahan memerlukan restart.

Body kosong, gambar/stream, respons dengan existing content coding, HEAD/range/partial, `no-transform`, dan respons ber-validator/digest dilewati. Jika gzip tidak memperkecil body, respons identity dipertahankan. Detail kecil dapat tetap identity walaupun request menerima gzip.

Untuk A/B, gunakan binary/data/client/jaringan dan jumlah VU yang sama, dengan kedua flag timing nonaktif. `API_TOKEN` tetap di environment terminal k6:

```powershell
k6 run -e RESOURCE=Customer -e ENDPOINT=list -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s -e RESPONSE_ENCODING=identity --summary-export docs/k6/customer-identity.json docs/k6/api-read-test-all.js
k6 run -e RESOURCE=Customer -e ENDPOINT=list -e EXPECTED_CUSTOMER_ROWS=100 -e FIXED_VUS=5 -e TEST_DURATION=60s -e RESPONSE_ENCODING=gzip --summary-export docs/k6/customer-gzip.json docs/k6/api-read-test-all.js
```

Tambahkan `BASE_URL` untuk target Linux dan ganti expected count sesuai fixture. `RESPONSE_ENCODING` menerima `auto` (default, perilaku k6 biasa), `gzip`, atau `identity`; nilai eksplisit mengirim `Accept-Encoding` yang sesuai. Fixture memverifikasi client k6 dapat mem-parsing respons gzip. Bandingkan `data_received`, p95/p99 Customer list, RPS, dan CPU server; rasio penghematan fixture lokal bukan proyeksi data produksi.

## Fixture skrip lokal

Dengan Node.js dan k6 yang tersedia di `PATH`, jalankan:

```powershell
node sources/tests/integration/k6-read-fixture.mjs
```

Fixture membuka server HTTP pada port loopback acak dan memakai token dummy. Pengujian memeriksa delapan endpoint bawaan, list/detail terpisah, fixture 2.300 baris, kegagalan jumlah baris saat preflight/load, dan penolakan konfigurasi tidak valid. Listener dan file sementara ditutup/dihapus setelah selesai. Ini memvalidasi skrip k6; bukan koneksi database, aplikasi Delphi, atau throughput Windows/Linux.
