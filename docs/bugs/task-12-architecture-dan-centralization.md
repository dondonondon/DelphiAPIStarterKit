# T12 — Architecture dan pemusatan concern teknis

Status: **BELUM DIMULAI**. Prioritas tertinggi: **P3**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F40** (1 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-04](wave-04.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Implementasi belum dilakukan. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

## 1. Tujuan dan cakupan

Satu authority per technical concern lintas feature dengan service/repository bebas detail HTTP serta feature-first yang tetap dipertahankan.

**Cakupan:** TGlobalFunction, Core.Endpoint auth SQL, User.Repository token predicate, Core.Config, service/request/response coupling dan feature registration.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

**Dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md); schema target tidak menutup acceptance aplikasi.

- [ ] Reconcile satu authority auth-v2 actor/session repository-resolver, permission policy, Argon2 password hasher, CSPRNG generator, typed config, response mapper dan audit/limiter. Refactor menjaga refresh COMMIT reuse revoke, recent auth, restricted session, recovery ownership dan transaction lock order.

- [ ] Gunakan master bagian 3 untuk owner/dependency current-target. Pertahankan flat sources/modules/<feature-name> untuk RestAPI/Service/Repository/Validator/DTO.
- [ ] Pakailah authority config/path T09, logger T04, credential/hasher/session T02 dan policy T01; hapus duplicate lookup/predicate setelah regression proof.
- [ ] Ekstrak TGlobalFunction ke focused helpers/infrastructure; public facade delegate selama migration. Jangan mengganti dengan God class lain atau dependency framework yang tidak diperlukan.
- [ ] Typed request → validator/policy → service result → response mapper satu use case dulu, lalu lainnya. Service tidak menerima WebRequest/route parts atau membentuk JSON/status; repository tidak tahu HTTP.
- [ ] Ownership eksplisit: connection request scope, queries/results owned jelas, JSON/stream satu owner; background tidak menyimpan request/response setelah lifetime.
- [ ] Feature registration menjadi composition/bootstrap agar core tidak bergantung feature; unit baru eksplisit DPR, update existing structure/project map/API migration yang terdampak tanpa mass folder moves.

## 3. Dependensi dan koordinasi

- Dilakukan setelah containment/runtime regressions tersedia; bukan prasyarat P0/P1.
- [T01](task-01-authorization-dan-permission.md)/[T02](task-02-authentication-password-dan-session.md)/[T03](task-03-http-routing-dan-error-boundary.md)/[T04](task-04-logging-dan-observability.md)/[T05](task-05-request-response-json-dan-waktu.md)/[T08](task-08-storage-upload-dan-stream.md)/[T09](task-09-config-path-dan-persistence.md)/[T10](task-10-hosting-build-dan-deployment.md) menentukan authority yang dipakai ulang; [T06](task-06-database-transaksi-dan-validasi-domain.md)/[T07](task-07-collection-pagination-dan-kapasitas.md) contract data dan [T11](task-11-schema-migration-dan-kompatibilitas.md) compatibility schema.

## 4. Acceptance dan validasi kategori

- [ ] Integrated auth-v2 regression sesudah refactor membuktikan permission/session/recovery/refresh/config/no-secret behavior sama; tidak ada route RTTI atau facade legacy yang membuka bypass.

- [ ] Callsite inventory membuktikan satu active authority auth/config/path/logger; feature-first sesuai structure.md dan dependency arah controller/service/repository/database.
- [ ] Service result/repository bebas WebRequest/WebResponse dan ownership jelas; facade compatible serta unit registration lengkap.
- [ ] Build/regression moved-use-case lulus; routes/fields/envelope tidak berubah tanpa migration note dan maps mencerminkan composition.
- [ ] Pemusatan dibuktikan owner/call path, bukan seluruh service dipindah ke folder global.

## 5. Checklist penutupan temuan

- [ ] **F40 (P3, CONFIRMED)** — Tanggung jawab teknis belum terpusat sepenuhnya. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil:** belum ada implementasi/validasi task. Saat dikerjakan, isi status BERJALAN/SELESAI/BLOCKED, commit/working-tree identity, changed files, command/skenario/platform, outcome dan lokasi evidence. BLOCKED menyebut kondisi agar pekerjaan dapat dilanjutkan.

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F40 — P3 — CONFIRMED — Tanggung jawab teknis belum terpusat sepenuhnya

**Lokasi:** [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L18), class TGlobalFunction; [BFA.Core.Endpoint.pas](../../sources/core/BFA.Core.Endpoint.pas#L97), auth SQL; [User.Repository.pas](../../sources/modules/users/User.Repository.pas#L107), duplicated token query; [BFA.Core.Config.pas](../../sources/core/BFA.Core.Config.pas#L8), 8–15; services masing-masing module.

TGlobalFunction mencampur storage/path, config, encoding, password/token HMAC, obfuscation, UUID, file conversion, outbound HTTP. Config unit hanya berisi upload constant dan request counter. Logging mempunyai tiga writer. Token validation SQL di endpoint core dan User.Repository tidak identik (`u.is_active` hanya ada pada guard core).

Service menerima request/route parts/dataset, menyimpan HTTP status, dan menghasilkan JSON. Endpoint sudah tipis, tetapi parsing/presentation responsibility dipindahkan ke service, belum sepenuhnya dipisahkan. Registry endpoint juga berada dalam core Rest yang bergantung ke feature units.

**Perbaikan:** incremental extraction concern bersama, tanpa memindahkan semua feature ke folder global. Endpoint parse typed DTO → validator → service result → response mapper; repository tetap tidak mengenal HTTP. Actor/session resolver, policy, config, path, logger, password hasher, credential generator mempunyai satu authority. Registry feature menjadi composition concern.

**Acceptance:** lihat matrix arsitektur bagian 3; tidak ada duplikasi auth predicate/config path/logger; existing public helper delegate selama migration; unit registration/maps/docs diperbarui.
