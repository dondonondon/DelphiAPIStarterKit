# k6 Customer: read, write, update, alur lengkap dan beban campuran

Skrip ini memakai kontrak Customer yang sudah ada. Tidak mengubah aplikasi atau schema dan tidak otomatis login. Berikan token lewat environment `API_TOKEN`; header yang digunakan `x-api-token`.

| Entry point | Perilaku |
|---|---|
| `customer-read-test.js` | GET list dan detail, tanpa mutasi termasuk setup/teardown. Memerlukan Customer aktif yang sudah ada. |
| `customer-write-test.js` | POST Customer unik, GET untuk memastikan semua nilai tersimpan, lalu cleanup bila aktif. |
| `customer-update-test.js` | Setup membuat satu record khusus per VU; setiap iterasi PUT record milik VU lalu GET untuk memverifikasi seluruh nilai dan field yang tidak diubah. |
| `customer-full-flow-test.js` | POST → GET verifikasi → PUT → GET verifikasi → DELETE dan GET 404 jika cleanup aktif. |
| `customer-mixed-test.js` | Default 70% operasi read, 20% insert, 10% update. Setiap VU memiliki record update sendiri. |

Implementasi bersama: `lib/customer-workload.js`. Existing `api-read-test-all.js` tetap tersedia untuk delapan endpoint baca User/Product/Category/Customer; skrip baru ini khusus Customer.

## Persiapan

Gunakan database/instance API khusus pengujian untuk write/update/full-flow/mixed. Buat backup database bila dibutuhkan. `ALLOW_WRITE=1` mengaktifkan operasi tulis; ini konfirmasi pemanggil, bukan deteksi otomatis bahwa database terisolasi. Tidak ada kredensial bawaan atau alamat server Dell yang tertanam.

Contoh PowerShell, isi nilai BASE_URL dan token di terminal sendiri:

```powershell
$env:BASE_URL = 'http://127.0.0.1:9999'
$env:API_TOKEN = '<token API aktif>'
```

Gunakan alamat yang sesuai lingkungan Anda. `FIXED_VUS` default 5, `TEST_DURATION` default 60s. Contoh 5 skenario, masing-masing dijalankan terpisah:

```powershell
k6 run -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/customer-read-test.js
k6 run -e ALLOW_WRITE=1 -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/customer-write-test.js
k6 run -e ALLOW_WRITE=1 -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/customer-update-test.js
k6 run -e ALLOW_WRITE=1 -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/customer-full-flow-test.js
k6 run -e ALLOW_WRITE=1 -e FIXED_VUS=5 -e TEST_DURATION=60s docs/k6/customer-mixed-test.js
```

Untuk 200 VU ganti `FIXED_VUS=200`, sesuaikan limit aktif aplikasi dan pool database berdasarkan target pengujian. Skrip tidak mengubah konfigurasi server. Jangan gunakan `--vus` untuk mengganti VU karena setup fixture menggunakan `FIXED_VUS`. Jalankan pada satu instance k6 lokal; distributed execution/execution segments dan perubahan executor secara eksternal tidak didukung oleh pemetaan fixture per VU ini.

## Smoke test dan parameter

```powershell
k6 run -e SMOKE=1 -e FIXED_VUS=1 docs/k6/customer-read-test.js
k6 run -e ALLOW_WRITE=1 -e SMOKE=1 -e FIXED_VUS=1 docs/k6/customer-full-flow-test.js
k6 run -e ALLOW_WRITE=1 -e SMOKE=1 -e FIXED_VUS=1 -e ITERATIONS_PER_VU=100 -e PAUSE_SECONDS=0 docs/k6/customer-mixed-test.js
```

| Parameter | Default | Arti |
|---|---|---|
| `BASE_URL` | `http://127.0.0.1:9999` | Target API |
| `API_TOKEN` | wajib | Token aktif melalui environment, tidak ditulis ke log |
| `ALLOW_WRITE` | nonaktif | Harus `1` untuk semua mode kecuali read |
| `FIXED_VUS` | `5` | Jumlah VU tetap dan fixture update |
| `TEST_DURATION` | `60s` | Durasi beban; format durasi divalidasi k6 |
| `SMOKE` | nonaktif | `1`: per-VU iterations, bukan durasi tetap |
| `ITERATIONS_PER_VU` | `1` | Iterasi per VU ketika smoke |
| `PAUSE_SECONDS` | `0.2` | Jeda akhir tiap operasi/alur |
| `RESPONSE_ENCODING` | `gzip` | `gzip`, `identity`, atau `auto` |
| `CLEANUP` | `1` | `0` untuk menyimpan record uji; `1` memakai DELETE soft-delete |
| `RUN_ID` | otomatis | Penanda run; jika diisi: 1–40 karakter huruf/angka/underscore/dash. Gunakan nilai unik tiap run. |
| `READ_PERCENT` | `70` | Proporsi operasi bisnis dalam mixed |
| `WRITE_PERCENT` | `20` | Proporsi insert dalam mixed |
| `UPDATE_PERCENT` | `10` | Proporsi update dalam mixed; jumlah ketiganya harus 100 |

Contoh mixed 60/25/15:

```powershell
k6 run -e ALLOW_WRITE=1 -e READ_PERCENT=60 -e WRITE_PERCENT=25 -e UPDATE_PERCENT=15 docs/k6/customer-mixed-test.js
```

Mixed menggunakan siklus deterministik 100 slot berdasarkan nomor iterasi global, tanpa offset per VU agar rasio tidak terpengaruh perbedaan kecepatan tiap VU. Rasio aktual pada run singkat dapat berbeda karena slot belum selesai. Rasio adalah pemilihan **operasi/alur**, bukan persentase HTTP request: read melakukan list+detail, insert/update menambahkan GET verifikasi, dan cleanup menambah request. Counter `workload_operations{kind:...}` menunjukkan distribusi operasi. Untuk smoke mixed dengan semua jenis operasi, gunakan minimal 100 iterasi pada satu VU agar tidak gagal karena suatu jenis belum dijalankan.

## Data dan pembersihan

- Record insert memiliki nama `k6-<run_id>-...`, email unik dan `notes=k6-owned:<run_id>`. Nama penanda run dicetak di awal, tanpa ID pelanggan/token/body.
- Update tidak menerima ID eksternal: hanya record yang dibuat setup pada run tersebut. Tidak menguji contention pada satu record bersama.
- Cleanup mengecek kembali ID dan marker kepemilikan sebelum DELETE, lalu memeriksa GET menghasilkan 404. Tidak menyapu seluruh tabel atau menghapus record lama.
- DELETE Customer adalah **soft-delete**: baris tetap berada di database walau tidak lagi muncul dalam GET. Table/index tetap dapat bertambah. Untuk hasil uji write yang setara, gunakan snapshot database uji yang sama pada setiap run.
- `CLEANUP=0` menyisakan record aktif dengan sengaja. Run terputus paksa, token kedaluwarsa, setup timeout, POST berhasil tetapi respons/ID hilang, atau cleanup gagal juga bisa menyisakan record. Jangan mengandalkan teardown sebagai jaminan cleanup seluruh kasus.
- Setup mencoba membersihkan fixture yang sudah terbuat bila langkah berikutnya gagal. Teardown membersihkan seed update yang dibagikan melalui setup; record yang dibuat VU dibersihkan pada iterasinya sendiri karena data VU tidak kembali ke teardown.
- Full-flow tanpa cleanup berhenti setelah verifikasi update; tidak ada DELETE/GET-404. Jangan bandingkan angka ini dengan full-flow yang cleanup-nya aktif tanpa menyebut perbedaannya.

## Metrik dan threshold

- `checks`: 100%; `workload_success`: 100%; HTTP error <1%.
- p95 **fase load** agregat dan per operasi terpilih <500 ms. Setiap operasi load wajib punya sampel.
- Tag `phase=load`: read_list/read_detail/create/update. `phase=setup`: fixture/preflight. `phase=verify`: readback persistensi. `phase=cleanup`: cek kepemilikan, DELETE, dan konfirmasi 404.
- HTTP summary global mencakup setup, verifikasi dan cleanup. Gunakan submetric fase load untuk membandingkan operasi utama. GET 404 yang memang diharapkan saat cleanup dikategorikan sukses; status/error lain tetap menggagalkan pemeriksaan.
- Kesalahan hanya mencetak operasi, phase dan status. Respons, token, ID dan data Customer tidak dicetak.

Jangan membandingkan throughput request/alur baru langsung dengan skrip read-only delapan endpoint; jumlah request, pacing, volume data dan mutasi berbeda.

## Hasil hanya lokal

```powershell
New-Item -ItemType Directory -Force docs/k6/results | Out-Null
k6 run -e ALLOW_WRITE=1 -e FIXED_VUS=5 -e TEST_DURATION=60s --summary-export docs/k6/results/customer-full-flow.json docs/k6/customer-full-flow-test.js *> docs/k6/results/customer-full-flow.txt
```

Folder `docs/k6/results/` harus tetap di-ignore. Jangan commit token, config runtime atau hasil run. Skrip tidak otomatis membuat file hasil dan tidak melakukan hard-delete database.

## Verifikasi skrip

```powershell
node sources/tests/integration/k6-customer-workload-fixture.mjs
```

Fixture menjalankan k6 sebenarnya terhadap HTTP loopback tiruan dengan token dummy. Meliputi lima mode, multi-VU, mixed seluruh cabang, penolakan konfigurasi/write tanpa opt-in, update yang berbohong tentang persistensi, ID POST salah, dan cleanup gagal. Tidak menjalankan SQL atau API Dell. Hasil fixture bukan acceptance backend Delphi/MySQL.

## Local test operation policy

Customer list reads are capped at 50 rows in SQL. Mixed runs keep the 70/20/10 business-operation weights and existing latency thresholds. For cleanup **after** the measured load without adding DELETE traffic during it, use a unique RUN_ID and CLEANUP=0 during k6, then soft-delete only that exact run's `notes=k6-owned:<RUN_ID>` records on the isolated test database. Include setup seeds and run inserts, verify zero active rows remain for the marker, and record before/after counts locally. This policy intentionally retains the rows as soft-deleted history; it does not restore updated data or delete fixtures from earlier runs. If execution fails, perform the same scoped post-run cleanup. Do not run a broad cleanup based on name prefixes or remove historical datasets.

The script's default CLEANUP=1 remains an alternative that performs ownership-checked HTTP cleanup during iterations and teardown; its HTTP counts and workload overhead differ from post-run cleanup. State the mode in every report. Test results remain local.
