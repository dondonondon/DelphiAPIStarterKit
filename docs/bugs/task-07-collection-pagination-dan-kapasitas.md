# T07 — Collection completeness, pagination, dan kapasitas

Status: **BERJALAN**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F12, F36** (2 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-03](wave-03.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Hilangkan truncation FireDAC dan batasi collection secara sengaja melalui query pagination stabil.

**Cakupan:** Core.Response iteration, DB.Helper.Query fetch behavior dan collection repository Users/Products/Customers/Category.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

**Dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md); schema target tidak menutup acceptance aplikasi.

- [ ] Cakup Auth/Sessions dan Role/User collection tambahan auth-v2; actor/permission predicate diterapkan di SQL sebelum pagination, bounded stable order dan typed response tanpa token/hash/internal IDs. Reconcile minimum limit slice dari T02/wave-01, jangan menunda query limit wajib.

- [ ] Ganti RecordCount-based loop dengan EOF iteration atau explicit fetched-all scope yang sesuai; RowsetSize bukan batas collection.
- [ ] Tetapkan validated page/cursor, default/max size dan stable ordering dengan unique tie-breaker; compatibility collection existing dijelaskan.
- [ ] Limit diterapkan pada query sebelum seluruh row dimuat, bukan memotong JSON; jangan memperbaiki truncation dengan unlimited FetchAll.
- [ ] Tambahkan pagination metadata tanpa merusak envelope utama; tetapkan query/host timeout dan ukur memory/latency.
- [ ] Update collection API docs/Postman seluruh feature dan traversal/invalid parameter examples.

## 3. Dependensi dan koordinasi

- [T05](task-05-request-response-json-dan-waktu.md) memiliki type/envelope serializer; fetch loop hanya punya satu implementasi owner.
- [T06](task-06-database-transaksi-dan-validasi-domain.md) query/domain constraints, [T03](task-03-http-routing-dan-error-boundary.md) invalid/timeout mapping, [T10](task-10-hosting-build-dan-deployment.md) config/host budget.

## 4. Acceptance dan validasi kategori

- [ ] Owned-session pagination, cross-user/cross-role probes, empty/bad/overflow parameters dan no-secret response diuji pada listener/DB; perubahan serializer tetap menjaga auth-v2 field types dan envelope.

- [ ] DB test 0/1/1000/1001/2500 rows dengan rowset kecil membuktikan count/page serta row terakhir sesuai contract.
- [ ] Static dataset traversal mengembalikan semua row sekali dengan stable order; behavior concurrent insert/delete sesuai page/cursor choice didokumentasikan.
- [ ] Bad/negative/overflow parameters 400, max size ditegakkan di SQL/query.
- [ ] Memory/latency/timeouts terukur melalui runtime Windows/Linux; metadata konsisten lintas collection. Compiler bukan bukti fetch behavior.

## 5. Checklist penutupan temuan

- [ ] **F12 (P1, CONFIRMED)** — GET collection dapat kehilangan row. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F36 (P2, CONFIRMED)** — Collection tidak mempunyai batas yang disengaja. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** Auth owned Sessions/User/Role collections SQL limit default50/max100, offset max100000; effective permission max100 fails closed on101.

E1/E3/E4. Remaining Product/Customer/Category collections cardinality/fetch/traversal/capacity and full F12/F36; role catalog over100 offline-corrupted mappings remains reconciliation scope. Owner tetap T07; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F12 — P1 — CONFIRMED — GET collection dapat kehilangan row

**Lokasi:** [BFA.Core.Response.pas](../../sources/core/BFA.Core.Response.pas#L258), 258–270; [DB.Helper.Query.pas](../../sources/infrastructure/database/DB.Helper.Query.pas#L25), 25–29.

Serializer menggunakan `for ... := 0 to RecordCount - 1`; upper bound ditentukan sebelum iterasi. Query memakai `RowsetSize=1000`. Source FireDAC RAD Studio 37 `FireDAC.Stan.Option.pas` 3706/3714 mempunyai default `fmOnDemand/cmVisible`; `FireDAC.Comp.DataSet.pas` 3835–3844 menunjukkan RecordCount atas row yang sudah terambil. Tidak ditemukan `FetchAll`/override fetch mode pada source aplikasi.

**Pemicu:** query collection yang melewati rowset awal, misalnya 1001/2500 row. `Next` dapat fetch lagi, tetapi jumlah iterasi tetap jumlah row saat loop dimulai.

**Dampak:** API mengembalikan HTTP 200 dengan collection parsial tanpa metadata pagination atau indikasi data terpotong.

**Perbaikan:** serialize dengan `while not Eof` atau fetched-all scope yang sengaja dipilih, lalu implementasikan pagination F36. `RowsetSize` bukan jumlah maksimum data yang harus dikembalikan.

**Acceptance:** 0/1/1000/1001/2500 row dan rowset kecil menghasilkan hasil sesuai kontrak, termasuk row terakhir; bandingkan dengan count query pada database test. Skenario DB ini belum dieksekusi dalam review.

### F36 — P2 — CONFIRMED — Collection tidak mempunyai batas yang disengaja

**Lokasi:** [User.Repository.pas](../../sources/modules/users/User.Repository.pas#L180), 180–181; [Product.Repository.pas](../../sources/modules/products/Product.Repository.pas#L127), 127–131; [Customer.Repository.pas](../../sources/modules/customers/Customer.Repository.pas#L107), 107–109; [Category.Repository.pas](../../sources/modules/category/Category.Repository.pas#L126), 126–127.

Query collection mengambil semua matching rows. Setelah F12 diperbaiki, serializer membangun seluruh array/string sehingga memory, worker dan pool usage membesar. Truncation yang terjadi sekarang bukan pagination yang sah.

**Perbaikan:** validated page/cursor parameters, maximum page size, stable ordering dengan unique tie-breaker, response metadata tanpa merusak envelope utama. Tetapkan max runtime/query timeout pada driver dan host.

**Acceptance:** bad/overflow pagination 400; maksimal page size ditegakkan; traversal stabil tidak duplikat/hilang; load data besar memory/latency terukur; record limit diterapkan di query, bukan hanya membuang array sesudah fetch.
