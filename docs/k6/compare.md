# Perbandingan Hasil Pengujian k6

## Baseline: PC Lenovo 3i i7

Tanggal pencatatan: 26 Oktober 2026.

Hasil berasal dari pengujian pada **PC pribadi Lenovo 3i i7**, sesuai informasi pemilik. Model CPU lengkap, generasi CPU, RAM, penyimpanan, dan lokasi database belum dicatat.

### Konfigurasi pengujian

- Sumber hasil: snapshot awal [result.txt](result.txt), saat target masih localhost. File tersebut kemudian diperbarui untuk pengujian lain; angka baseline dipertahankan di dokumen ini.
- Skrip: [api-read-test-all.js](api-read-test-all.js).
- Target: `http://127.0.0.1:9999` (localhost).
- Autentikasi: access token melalui header `x-api-token`; nilai token tidak dicatat.
- Cakupan: delapan endpoint GET, yaitu daftar dan detail User, Product, Category, dan Customer.
- Endpoint `/image` tidak diuji; operasi tulis dan Auth tidak termasuk beban pengujian.
- Profil beban: lima tahap, masing-masing 15 detik, menuju `5 -> 10 -> 15 -> 25 -> 0` VU.
- Satu iterasi menjalankan delapan request, dengan jeda 0,05 detik per endpoint dan 0,2 detik pada akhir iterasi.
- Preflight memeriksa delapan endpoint sebelum beban dijalankan. Statistik HTTP agregat mencakup preflight.

Perintah pengujian:

```powershell
k6 run -e BASE_URL=http://127.0.0.1:9999 docs/k6/api-read-test-all.js
```

### Hasil

| Metrik | Lenovo 3i i7 |
|---|---:|
| Durasi aktual | 75,2 detik |
| VU maksimum tercapai | 25 |
| Total request | 7.192 |
| Throughput rata-rata | 95,66 request/detik |
| Request gagal | 0 dari 7.192 (0%) |
| Checks berhasil | 61.132 dari 61.132 (100%) |
| Waktu respons minimum | 1,01 ms |
| Waktu respons rata-rata | 37,72 ms |
| Waktu respons median | 3,80 ms |
| Waktu respons p90 | 103,54 ms |
| Waktu respons p95 | 160,47 ms |
| Waktu respons maksimum | 1,68 detik |
| Iterasi selesai | 898 |
| Iterasi terputus | 0 |
| Durasi iterasi rata-rata, termasuk jeda | 913,43 ms |
| Durasi iterasi p95, termasuk jeda | 1,47 detik |
| Data diterima | 451 MB (6,0 MB/detik) |
| Data dikirim | 1,2 MB (17 kB/detik) |

### Threshold

| Threshold | Hasil aktual | Status |
|---|---:|---|
| `checks: rate==1` | 100% | LULUS |
| `http_req_failed: rate<0.01` | 0% | LULUS |
| `http_req_duration: p(95)<500` | 160,47 ms | LULUS |

### Kesimpulan dan batas penerapan

**Seluruh threshold lulus.** Delapan endpoint baca berhasil melayani profil beban bertahap hingga 25 VU tanpa kegagalan request atau validasi respons. Sekitar 95% request selesai dalam 160,47 ms, dengan throughput rata-rata 95,66 request/detik selama keseluruhan pengujian.

Terdapat lonjakan waktu respons hingga 1,68 detik. Ringkasan agregat belum menunjukkan endpoint atau tahap beban yang mengalami lonjakan; data CPU, RAM, dan beban database juga belum tersedia untuk menentukan penyebabnya.

Hasil ini merupakan baseline performa baca pada localhost dan data saat pengujian. Angka 25 VU adalah puncak beban yang tercapai; skrip langsung menurunkan beban setelah mencapai puncak, sehingga kapasitas berkelanjutan pada 25 VU belum terbukti. Throughput rata-rata bukan throughput khusus pada 25 VU ataupun kapasitas maksimum server.

Untuk membandingkan mesin lain, gunakan versi aplikasi dan skrip, isi database, konfigurasi server/database, profil beban, serta metode akses yang setara. Catat lokasi database dan apakah generator k6 berjalan pada mesin yang sama dengan API; hasil localhost tidak langsung setara dengan pengujian melalui LAN atau internet.

## Dell-Optiplex

Tanggal pencatatan: 26 Oktober 2026.

Identitas mesin menggunakan nama **Dell-Optiplex**, sesuai informasi pemilik. Model CPU, jumlah core, RAM, penyimpanan, dan lokasi database belum dikonfirmasi untuk hasil ini.

### Konfigurasi pengujian

- Sumber hasil: kolom **Terbaru** pada tabel yang dikonfirmasi pemilik (744 request, 6.324 checks), beserta snapshot run tersebut yang sebelumnya dibaca dari `result.txt`. File [result.txt](result.txt) diperbarui untuk pengujian berikutnya; angka run ini dipertahankan di dokumen ini.
- Skrip: [api-read-test-all.js](api-read-test-all.js).
- Target: `http://192.168.0.100:9999` (alamat LAN).
- Autentikasi: access token melalui header `x-api-token`; nilai token tidak dicatat.
- Cakupan: delapan endpoint GET daftar/detail User, Product, Category, dan Customer. Endpoint `/image`, operasi tulis, dan Auth tidak termasuk beban pengujian.
- Profil beban: lima tahap, masing-masing 15 detik, menuju `5 -> 10 -> 15 -> 25 -> 0` VU. Belum ada tahap mempertahankan 25 VU secara tetap.
- Preflight memeriksa delapan endpoint sebelum beban dijalankan. Statistik HTTP agregat mencakup preflight.

Perintah pengujian:

```powershell
k6 run -e BASE_URL=http://192.168.0.100:9999 docs/k6/api-read-test-all.js
```

### Hasil

| Metrik | Dell-Optiplex |
|---|---:|
| Durasi beban terjadwal | 75 detik |
| Durasi aktual, termasuk penyelesaian request | 80,8 detik |
| VU maksimum tercapai | 25 |
| Total request | 744 |
| Throughput rata-rata | 9,21 request/detik |
| Request gagal | 0 dari 744 (0%) |
| Checks berhasil | 6.324 dari 6.324 (100%) |
| Waktu respons minimum | 7,81 ms |
| Waktu respons rata-rata | 1,25 detik |
| Waktu respons median | 80,93 ms |
| Waktu respons p90 | 3,45 detik |
| Waktu respons p95 | 10,67 detik |
| Waktu respons maksimum | 17,46 detik |
| Iterasi selesai | 92 |
| Iterasi terputus | 0 |
| Durasi iterasi rata-rata, termasuk jeda | 10,72 detik |
| Durasi iterasi p95, termasuk jeda | 19,08 detik |
| Data diterima | 47 MB (577 kB/detik) |
| Data dikirim | 131 kB (1,6 kB/detik) |

### Threshold

| Threshold | Hasil aktual | Status |
|---|---:|---|
| `checks: rate==1` | 100% | LULUS |
| `http_req_failed: rate<0.01` | 0% | LULUS |
| `http_req_duration: p(95)<500` | 10.670 ms | GAGAL |

### Kesimpulan dan batas penerapan

**Pengujian gagal memenuhi threshold waktu respons.** Seluruh request dan pemeriksaan respons berhasil, tetapi p95 mencapai 10,67 detik, yaitu 21,34 kali batas 500 ms. Respons terlama mencapai 17,46 detik.

Median 80,93 ms menunjukkan banyak request masih cepat, sementara sebagian mengalami keterlambatan besar. Setiap VU menunggu respons sebelum melanjutkan; keterlambatan turut menurunkan throughput menjadi rata-rata 9,21 request/detik.

Log agregat ini belum mengidentifikasi endpoint, tahap beban, atau bagian kode penyebab perlambatan. CPU, RAM, dan aktivitas database untuk run ini tidak tercatat dalam `result.txt`. Durasi aktual melewati 75 detik karena penyelesaian iterasi yang masih berjalan; seluruh 92 iterasi selesai tanpa terputus.

Hasil ini belum membuktikan kapasitas berkelanjutan pada 25 VU atau kapasitas maksimum mesin. Pengujian beban tetap dan metrik per endpoint diperlukan untuk menentukan titik perlambatan.

## Beelink

Tanggal pencatatan: 26 Oktober 2026.

Identitas mesin menggunakan nama **Beelink**, sesuai informasi pemilik. Model CPU, jumlah core, RAM, penyimpanan, dan lokasi database belum dikonfirmasi untuk hasil ini.

Hasil Beelink menggunakan snapshot `result.txt` dengan 696 request dan p95 11,40 detik.

### Konfigurasi pengujian

- Sumber hasil: [result.txt](result.txt), versi dengan target `192.168.0.110:9999` dan 696 request.
- Skrip: [api-read-test-all.js](api-read-test-all.js).
- Target: `http://192.168.0.110:9999` (alamat LAN).
- Autentikasi: access token melalui header `x-api-token`; nilai token tidak dicatat.
- Cakupan: delapan endpoint GET daftar/detail User, Product, Category, dan Customer. Endpoint `/image`, operasi tulis, dan Auth tidak termasuk beban pengujian.
- Profil beban: lima tahap, masing-masing 15 detik, menuju `5 -> 10 -> 15 -> 25 -> 0` VU. Belum ada tahap mempertahankan 25 VU secara tetap.
- Statistik HTTP agregat mencakup delapan request preflight.

Perintah pengujian:

```powershell
k6 run -e BASE_URL=http://192.168.0.110:9999 docs/k6/api-read-test-all.js
```

### Hasil

| Metrik | Beelink |
|---|---:|
| Durasi beban terjadwal | 75 detik |
| Durasi aktual, termasuk penyelesaian request | 81,2 detik |
| VU maksimum tercapai | 25 |
| Total request | 696 |
| Throughput rata-rata | 8,57 request/detik |
| Request gagal | 0 dari 696 (0%) |
| Checks berhasil | 5.916 dari 5.916 (100%) |
| Waktu respons minimum | 12,02 ms |
| Waktu respons rata-rata | 1,31 detik |
| Waktu respons median | 87,15 ms |
| Waktu respons p90 | 4,27 detik |
| Waktu respons p95 | 11,40 detik |
| Waktu respons maksimum | 16,88 detik |
| Iterasi selesai | 86 |
| Iterasi terputus | 0 |
| Durasi iterasi rata-rata, termasuk jeda | 11,25 detik |
| Durasi iterasi p95, termasuk jeda | 18,56 detik |
| Data diterima | 44 MB (537 kB/detik) |
| Data dikirim | 123 kB (1,5 kB/detik) |

### Threshold

| Threshold | Hasil aktual | Status |
|---|---:|---|
| `checks: rate==1` | 100% | LULUS |
| `http_req_failed: rate<0.01` | 0% | LULUS |
| `http_req_duration: p(95)<500` | 11.400 ms | GAGAL |

### Kesimpulan dan batas penerapan

**Snapshot yang dicatat gagal memenuhi threshold waktu respons.** Seluruh request dan pemeriksaan respons berhasil, tetapi p95 mencapai 11,40 detik, yaitu 22,8 kali batas 500 ms. Respons terlama mencapai 16,88 detik dan throughput rata-rata 8,57 request/detik.

Penyebab perlambatan dan kapasitas berkelanjutan pada 25 VU belum dapat ditentukan dari log agregat. Kesetaraan konfigurasi, data, dan kondisi pengujian antarmesin juga belum diverifikasi.

## MiniPCWindows

Tanggal pencatatan: 26 Oktober 2026.

Identitas mesin menggunakan nama **MiniPCWindows**, sesuai informasi pemilik. Model CPU, jumlah core, RAM, penyimpanan, versi Windows, dan lokasi database belum dikonfirmasi untuk hasil ini.

### Konfigurasi pengujian

- Sumber hasil: snapshot [result.txt](result.txt) dengan target `192.168.0.250:9999` dan 6.848 request. File tersebut dapat diperbarui untuk pengujian berikutnya; angka run ini dipertahankan di dokumen ini.
- Skrip: [api-read-test-all.js](api-read-test-all.js).
- Target: `http://192.168.0.250:9999` (alamat LAN).
- Autentikasi: access token melalui header `x-api-token`; nilai token tidak dicatat.
- Cakupan: delapan endpoint GET daftar/detail User, Product, Category, dan Customer. Endpoint `/image`, operasi tulis, dan Auth tidak termasuk beban pengujian.
- Profil beban: lima tahap, masing-masing 15 detik, menuju `5 -> 10 -> 15 -> 25 -> 0` VU. Belum ada tahap mempertahankan 25 VU secara tetap.
- Statistik HTTP agregat mencakup delapan request preflight.

Perintah pengujian:

```powershell
k6 run -e BASE_URL=http://192.168.0.250:9999 docs/k6/api-read-test-all.js
```

### Hasil

| Metrik | MiniPCWindows |
|---|---:|
| Durasi beban terjadwal | 75 detik |
| Durasi aktual | 75,8 detik |
| VU maksimum tercapai | 25 |
| Total request | 6.848 |
| Throughput rata-rata | 90,39 request/detik |
| Request gagal | 0 dari 6.848 (0%) |
| Checks berhasil | 58.208 dari 58.208 (100%) |
| Waktu respons minimum | 2,04 ms |
| Waktu respons rata-rata | 35,43 ms |
| Waktu respons median | 16,26 ms |
| Waktu respons p90 | 89,21 ms |
| Waktu respons p95 | 150,32 ms |
| Waktu respons maksimum | 476,15 ms |
| Iterasi selesai | 855 |
| Iterasi terputus | 0 |
| Durasi iterasi rata-rata, termasuk jeda | 962,27 ms |
| Durasi iterasi p95, termasuk jeda | 1,24 detik |
| Data diterima | 429 MB (5,7 MB/detik) |
| Data dikirim | 1,2 MB (16 kB/detik) |

### Threshold

| Threshold | Hasil aktual | Status |
|---|---:|---|
| `checks: rate==1` | 100% | LULUS |
| `http_req_failed: rate<0.01` | 0% | LULUS |
| `http_req_duration: p(95)<500` | 150,32 ms | LULUS |

### Kesimpulan dan batas penerapan

**Seluruh threshold lulus.** Delapan endpoint baca berhasil melayani profil beban bertahap hingga 25 VU tanpa kegagalan request atau validasi respons. Throughput rata-rata mencapai 90,39 request/detik dan p95 sebesar 150,32 ms. Durasi request maksimum yang terukur adalah 476,15 ms, sehingga seluruh sampel `http_req_duration` pada run ini berada di bawah 500 ms.

Pada hasil yang dicatat, MiniPCWindows menghasilkan throughput mendekati baseline Lenovo dan waktu respons p95 lebih rendah. Throughput juga lebih tinggi serta p95 lebih rendah dibandingkan hasil Dell-Optiplex dan Beelink. Kesetaraan hardware, versi binary, konfigurasi, data, dan kondisi jaringan belum diverifikasi; selisih ini belum dapat diatribusikan hanya kepada mesin atau sistem operasi.

Run ini belum membuktikan kapasitas berkelanjutan pada 25 VU atau kapasitas maksimum server. Log agregat belum menyediakan rincian latensi per endpoint, penggunaan CPU/RAM, atau aktivitas database.

## Ringkasan Perbandingan

| Metrik | Lenovo 3i i7 (localhost) | Dell-Optiplex (alamat LAN) | Beelink (alamat LAN) | MiniPCWindows (alamat LAN) |
|---|---:|---:|---:|---:|
| Target | `127.0.0.1:9999` | `192.168.0.100:9999` | `192.168.0.110:9999` | `192.168.0.250:9999` |
| VU maksimum tercapai | 25 | 25 | 25 | 25 |
| Total request | 7.192 | 744 | 696 | 6.848 |
| Throughput rata-rata | 95,66 request/detik | 9,21 request/detik | 8,57 request/detik | 90,39 request/detik |
| Respons rata-rata | 37,72 ms | 1,25 detik | 1,31 detik | 35,43 ms |
| Median | 3,80 ms | 80,93 ms | 87,15 ms | 16,26 ms |
| p95 | 160,47 ms | 10,67 detik | 11,40 detik | 150,32 ms |
| Respons maksimum | 1,68 detik | 17,46 detik | 16,88 detik | 476,15 ms |
| Request gagal | 0% | 0% | 0% | 0% |
| Checks berhasil | 100% (61.132) | 100% (6.324) | 100% (5.916) | 100% (58.208) |
| Status seluruh threshold | LULUS | GAGAL pada waktu respons | GAGAL pada waktu respons | LULUS |

Dell-Optiplex menggunakan hasil 744 request yang dikonfirmasi pemilik; Beelink menggunakan snapshot 696 request; MiniPCWindows menggunakan snapshot 6.848 request. Angka setiap run dipertahankan di dokumen ini saat `result.txt` diperbarui.

Jalur akses localhost dan alamat LAN berbeda, sedangkan kesetaraan hardware, versi binary, konfigurasi, dan isi database belum diverifikasi. Selisih performa belum dapat diatribusikan hanya kepada jenis mesin atau jaringan.
