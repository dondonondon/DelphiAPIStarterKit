# T06 — Database, transaksi, dan validasi domain

Status: **BERJALAN**. Prioritas tertinggi: **P2**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F18, F19, F20, F21, F42** (4 CONFIRMED, 1 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-02](wave-02.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Selaraskan validation, constraint, mutation outcome dan response dengan stored state, soft delete serta concurrency.

**Cakupan:** Users/Category/Product/Customer validator/DTO/service/repository serta constraint/schema policy domain terkait.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

**Dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md); schema target tidak menutup acceptance aplikasi.

- [ ] Reconcile auth-v2 numeric role reference/permission boundary, must_change_password/provisioning semantics dan transaction lock/revalidate password-revoke-recovery. Generic PUT password ditolak; temporary_password tidak dikembalikan. Lifecycle/security owner tetap T01/T02.

- [ ] Tetapkan reserved-name versus reuse-after-delete untuk username/category; selaraskan precheck/UNIQUE dan native unique violation menjadi 409. Precheck bukan concurrency protection.
- [ ] Koordinasikan check/write melalui transaction lock atau optimistic version. Gunakan mutation outcome/authoritative readback, bukan snapshot pra-transaksi ditimpa input.
- [ ] Pahami matched-versus-changed RowsAffected; update identik tidak dianggap missing dan delete-update race tidak memberi sukses palsu.
- [ ] Username/fullname 50/100, strict type/null/patch semantics, role positif/existing/active/not-deleted; permission role tetap terpisah.
- [ ] Price DECIMAL(15,2): nonnegative, maksimum 9999999999999.99, scale/reject/rounding policy eksplisit sebelum write dan invariant conversion.
- [ ] Nyatakan category-reference policy block delete/historical/detach; jangan menambah cascade product tanpa keputusan domain. Password/reset menggunakan one-time recovery flow auth-v2, bukan temporary_password response.
- [ ] Update schema delta, API/Postman, supported SQL modes dan driver behavior yang actual diuji.

## 3. Dependensi dan koordinasi

- [T05](task-05-request-response-json-dan-waktu.md) menjaga tipe/presisi; [T01](task-01-authorization-dan-permission.md) permission actor/role, [T02](task-02-authentication-password-dan-session.md) hash/revoke dalam satu transaction scope.
- [T04](task-04-logging-dan-observability.md)/[T03](task-03-http-routing-dan-error-boundary.md) logging/safe conflict mapping; [T11](task-11-schema-migration-dan-kompatibilitas.md) merekonsiliasi constraint/nullability target. F18/F42 domain policy tetap dimiliki task ini.

## 4. Acceptance dan validasi kategori

- [ ] Mutation helper/RowsAffected/domain validation changes tidak memutus atomisitas credential revoke atau mengizinkan privilege escalation; auth/domain race dan rollback teruji.

- [ ] Active/deleted duplicate, rename dan concurrent create memberi policy/status konsisten tanpa expected-conflict 500.
- [ ] Barrier SELECT-A → delete-B → update-A memberi 404/409, bukan 200 palsu; identical update valid dan concurrent update tidak memberi snapshot menyesatkan.
- [ ] Username 50/51, fullname 100/101, role negatif/nol/missing/inactive/deleted, wrong type/null ditolak tanpa mutation/truncation.
- [ ] Price 0/max/above/negative/1.234/1.235 sesuai policy; response dan GET readback identik pada dua OS/locale dan SQL modes supported.
- [ ] Category assign/delete concurrent serta product GET mengikuti satu policy tertulis untuk F42; commit/rollback dan password/revoke outcome authoritative.

## 5. Checklist penutupan temuan

- [ ] **F18 (P2, CONFIRMED)** — Conflict soft delete tidak selaras dengan UNIQUE. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F19 (P2, CONFIRMED)** — UPDATE melaporkan state yang tidak tersimpan. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F20 (P2, CONFIRMED)** — Validasi Users tidak mengikuti schema/reference. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F21 (P2, CONFIRMED)** — Price tidak mempunyai range/scale storage. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F42 (P3, CONTEXT-DEPENDENT)** — Product masih menampilkan category yang dihapus. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** Typed User bounds/reference validation, security transactions and authoritative mutation readback; Role known-active permission validation. Minimum business compatibility: Category/Customer/Product read is_active via AsBoolean; Product nullable category FK bound with explicit ftLargeint/Clear.

E1/E3/E4 + positive business E1 supplemental. Remaining all domain conflict/soft-delete/matched-vs-changed/price/concurrency/reference policies, including F18/F19/F20/F21/F42 final reconciliation. Owner tetap T06; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F18 — P2 — CONFIRMED — Conflict soft delete tidak selaras dengan UNIQUE

**Lokasi:** [User.Repository.pas](../../sources/modules/users/User.Repository.pas#L148), 148–158; [Category.Repository.pas](../../sources/modules/category/Category.Repository.pas#L90), 90–103; [schema SQL](../../assets/databases/demo_delphirest.sql#L535), UNIQUE username 535 dan category name 72; [User.Service.pas](../../sources/modules/users/User.Service.pas#L239), 239–260.

Precheck username/category name mengecualikan deleted row, tetapi UNIQUE database tetap berlaku untuk semua row. Create dengan nama yang sudah soft-deleted lolos precheck, kemudian DB menolak dan service memberi generic 500. Dua concurrent create nama sama juga dapat lolos precheck dan menghasilkan native unique failure.

**Dampak:** conflict normal menjadi internal server error. Constraint tetap mencegah duplikasi; review tidak menyatakan database menyimpan duplicate row.

**Perbaikan:** tentukan reserved-name versus reuse-after-delete; selaraskan precheck/constraint; map unique violation menjadi 409. Precheck tetap hanya memberi pesan lebih cepat, bukan concurrency protection.

**Acceptance:** active duplicate, soft-deleted duplicate, rename conflict, concurrent create menghasilkan kebijakan/status yang konsisten; tidak ada 500 untuk expected conflict.

### F19 — P2 — CONFIRMED — UPDATE melaporkan state yang tidak tersimpan

**Lokasi:** [Product.Service.pas](../../sources/modules/products/Product.Service.pas#L244), 244–319; [Customer.Service.pas](../../sources/modules/customers/Customer.Service.pas#L223), 223–295; [Category.Service.pas](../../sources/modules/category/Category.Service.pas#L222), 222–275; [User.Service.pas](../../sources/modules/users/User.Service.pas#L373), 373–427, serta password flows 92–128/309–328.

Existence check dan response snapshot diambil sebelum transaction. UPDATE/UpdatePassword return value `RowsAffected` diabaikan. Request lain dapat soft-delete target setelah SELECT; write `deleted_at IS NULL` menyentuh nol row, tetapi response tetap sukses. Response dibuat dari snapshot lama yang ditimpa input, bukan readback state yang konsisten.

**Perbaikan:** koordinasikan check/write dalam transaction dengan lock atau optimistic version. Tangani mutation outcome, lalu bentuk result yang authoritative. Jangan menganggap semua nol affected row berarti missing: update identik mempunyai matched-versus-changed semantics yang perlu dipahami untuk driver terpilih.

**Acceptance:** barrier test SELECT-A → delete-B → update-A memberikan 404/409 sesuai kontrak, bukan 200 palsu; update identik tetap valid; dua update field berbeda tidak memberikan snapshot menyesatkan; reset tidak mengembalikan temporary password yang tidak tersimpan.

### F20 — P2 — CONFIRMED — Validasi Users tidak mengikuti schema/reference

**Lokasi:** [User.Validator.pas](../../sources/modules/users/User.Validator.pas#L60), 60–85 dan 144–174; [schema SQL](../../assets/databases/demo_delphirest.sql#L522), 522–539.

Username VARCHAR(50) dan fullname VARCHAR(100) tidak memiliki batas panjang validator yang sesuai. Role hanya diparse integer, tidak dibuktikan positif, existing, active, atau not-deleted sebelum assignment ke internal FK. String request juga berasal dari `AsString` yang bisa mengcoerce non-string JSON.

**Dampak:** strict SQL mode mengubah client validation failure menjadi 500; mode permissive dapat memotong data. FK existing tidak membuktikan role assignable. Ini terkait F01 tetapi merupakan defect validation tersendiri.

**Perbaikan:** batas panjang/tipe dan reference resolver yang mengikuti schema dan role policy; password dibaca tanpa trim otomatis; actor permission diperiksa terpisah dari existence role. Perjelas optional/null/clear behavior patch.

**Acceptance:** username 50/51, fullname 100/101; role negatif/nol/missing/inactive/deleted; wrong JSON type dan explicit null; semua invalid input memberi 400/404 sesuai kontrak tanpa persistence.

### F21 — P2 — CONFIRMED — Price tidak mempunyai range/scale storage

**Lokasi:** [Product.Validator.pas](../../sources/modules/products/Product.Validator.pas#L84), 84–106, 134–142, 231–239; [Product.DTO.pas](../../sources/modules/products/Product.DTO.pas#L67), 67–72; [schema SQL](../../assets/databases/demo_delphirest.sql#L337), 337.

Delphi Currency menerima range dan empat decimal places yang lebih luas daripada `DECIMAL(15,2)`. Validator hanya memeriksa nonnegative. Input `10000000000000` melebihi maximum `9999999999999.99` pada schema; nilai tiga/empat decimal diterima tanpa kebijakan rounding yang eksplisit.

**Dampak:** DB strict memberi 500; permissive dapat clamp/round sementara response berbasis input tidak sama dengan storage. Money tidak boleh bergantung implicit conversion/locale.

**Perbaikan:** range dan decimal scale menjadi kontrak; pilih reject atau rounding policy eksplisit sebelum persistence; gunakan formatter/parser invariant dan result storage yang benar.

**Acceptance:** 0, maximum, di atas maximum, negatif, 1.234/1.235; response dan GET readback sama; Windows/Linux dan SQL mode yang didukung diuji.

### F42 — P3 — CONTEXT-DEPENDENT — Product masih menampilkan category yang dihapus

**Lokasi:** [Category.Repository.pas](../../sources/modules/category/Category.Repository.pas#L147), 147–148; [Product.Repository.pas](../../sources/modules/products/Product.Repository.pas#L97), 97–98/119–120/130–131, bandingkan lookup 76–77.

Category soft-delete tidak mengubah referenced product. Product GET LEFT JOIN category tanpa deleted filter, sehingga category yang GET-nya sudah 404 masih terlihat di product. Foreign key ON DELETE RESTRICT tidak memblokir soft delete.

**Perbaikan:** tetapkan kebijakan: block delete ketika masih digunakan, historical reference dengan status jelas, atau detach terkelola jika bisnis menghendaki. Jangan menambahkan cascade delete product tanpa keputusan domain.

**Acceptance:** assignment/delete konkuren dan product read mengikuti satu kebijakan; reference yang dipaparkan dapat dijelaskan consumer; tidak ada side effect data yang tidak diminta.
