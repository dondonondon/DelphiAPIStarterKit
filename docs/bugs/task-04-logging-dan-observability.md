# T04 — Logging, observability, dan preservasi exception

Status: **BERJALAN**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F10, F23** (2 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-02](wave-02.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Sediakan satu logger terkoordinasi yang menjaga safe response saat sink gagal dan tidak kehilangan alasan kegagalan CRUD/rollback.

**Cakupan:** Writer Core.Rest/Core.Endpoint/Auth.Service dan catch CRUD seluruh feature; logger infrastructure serta sink/config integration.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [ ] Integrasikan auth_security_event append-only allowlist event/outcome/actor/target/correlation/observed IP dengan satu logger. Token/password/hash/raw payload tidak boleh masuk tabel atau sink; audit IDs tidak dihapus cascading bersama akun.
- [ ] Tentukan least-privilege INSERT-only grant app, maintenance retention terpisah, bounded failure behavior dan evidence security audit bootstrap/role/reset/reuse. Audit failure tidak boleh membuka authorization atau menggagalkan safe response.

- [ ] Inventarisasi writer/catch yang membuang exception; pilih satu logger infrastructure dengan configurable writable log root terpisah dari binary.
- [ ] Koordinasikan thread, rotation/retention, UTC/correlation ID dan redaction password/token/authorization/key/raw sensitive payload.
- [ ] Sediakan fallback stderr/event sink yang tidak melempar ke safe response ketika file sink read-only/full/unavailable.
- [ ] Setelah rollback re-raise ke boundary atau log satu kali; tetapkan owner log per failure. Expected conflict dipetakan khusus; preserve exception awal bila rollback juga gagal.
- [ ] Dokumentasikan sink permissions, retention, fallback dan diagnosis correlation.

## 3. Dependensi dan koordinasi

- [T09](task-09-config-path-dan-persistence.md) menyediakan config/path log root; logger API/fallback dapat diselesaikan sebelum seluruh config-save task.
- [T03](task-03-http-routing-dan-error-boundary.md) mengonsumsi safe logger; [T06](task-06-database-transaksi-dan-validasi-domain.md) mengonsumsi transaction/conflict handling; [T12](task-12-architecture-dan-centralization.md) memakai ulang authority ini.

## 4. Acceptance dan validasi kategori

- [ ] auth_security_event bootstrap/permission/reuse/recovery menggunakan allowlist dan append-only grants; audit tidak mengandung secret serta retention tidak hilang melalui account cascade.

- [ ] Read-only/disk-full/missing/unavailable sink tetap memberi safe HTTP 500; binary directory boleh read-only.
- [ ] Ratusan failure paralel dan rotation tidak merusak koordinasi log; gunakan identity runtime Windows/Linux.
- [ ] Fault CRUD memberi satu useful log/correlation dan generic response; unique violation tetap 409.
- [ ] Rollback failure mempertahankan exception awal; recursive secret scan output/log tidak menemukan credential test.

## 5. Checklist penutupan temuan

- [ ] **F10 (P1, CONFIRMED)** — Logger dapat menggagalkan error handling. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.
- [ ] **F23 (P2, CONFIRMED)** — Exception service hilang dari log. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** BFA.Logger non-throwing shared sink/fallback; Auth.Repository.Audit append-only safe metadata (implemented inside Auth.Repository); best-effort denied audit and fail-closed security mutation on required audit failure.

E2 audit trigger failure + sink failure; SOURCE safe exception-class/context logging. Remaining: full exception context/redaction policy, correlation, concurrent sink stress, DB grants/retention and Linux/deployment; F10/F23 not closed globally. Owner tetap T04; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F10 — P1 — CONFIRMED — Logger dapat menggagalkan error handling

**Lokasi:** [BFA.Core.Rest.pas](../../sources/core/BFA.Core.Rest.pas#L98), 98–106, 215, 237; [BFA.Core.Endpoint.pas](../../sources/core/BFA.Core.Endpoint.pas#L139), 139–150 dan 85–89; [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L48), 48–59 dan 79–85.

Ada tiga writer yang append ke `<executable directory>/server-error.log`. Tidak ada fallback untuk permission/disk failure, lock/queue untuk writer paralel, redaction, atau rotation. Logger dipanggil di dalam exception handler sebelum response aman selesai dibuat.

**Pemicu:** binary di Program Files atau `/usr/local/bin` dengan service user tanpa write permission; disk penuh; beberapa exception simultan. RTL `TFile.AppendAllText` memakai open/seek/write terpisah dan sharing mode yang dapat bertabrakan, bukan sink lintas-thread yang dikoordinasikan.

**Dampak:** original exception digantikan filesystem/sharing exception; envelope 500 dapat gagal; error log hilang/tercampur; file tumbuh tanpa batas. Exception SQL dapat mengandung detail sensitif sehingga logging raw message juga perlu sanitization yang sesuai vendor.

**Perbaikan:** satu logger infrastructure dengan writable configurable sink, synchronization, rotation, UTC/correlation ID, redaction, dan fallback stderr/event sink. Kegagalan logging harus dicatat sebisa mungkin tanpa menghalangi safe HTTP response.

**Acceptance:** sink read-only/full/unavailable dan ratusan failure paralel tetap menghasilkan JSON 500 aman; baris log terkoordinasi; tidak ada credential/raw sensitive payload; binary directory boleh read-only.

### F23 — P2 — CONFIRMED — Exception service hilang dari log

**Lokasi:** [User.Service.pas](../../sources/modules/users/User.Service.pas#L121), 121–123, 258–260, 330–332, 402–404; [Product.Service.pas](../../sources/modules/products/Product.Service.pas#L190), 190–192/290–292; [Customer.Service.pas](../../sources/modules/customers/Customer.Service.pas#L166), 166–168/251–253; [Category.Service.pas](../../sources/modules/category/Category.Service.pas#L177), 177–179/254–256.

Service menangkap exception, rollback, lalu mengembalikan InternalServerError tanpa meneruskan `E` atau logging. Endpoint logger hanya berjalan ketika callback melempar exception, sehingga kegagalan DB yang sudah ditangkap tidak pernah sampai ke logger.

**Dampak:** failure timeout/deadlock/constraint/commit tidak mempunyai bukti internal yang cukup; HTTP response aman bukan bukti failure sudah tercatat. Rollback yang juga gagal dapat menutupi exception awal.

**Perbaikan:** setelah rollback re-raise ke satu safe boundary, atau log satu kali dengan shared logger dan correlation ID. Expected conflict dipetakan secara khusus; jangan duplikasi log setiap lapisan. Simpan exception awal bila rollback gagal.

**Acceptance:** fault injection menghasilkan satu log yang berguna dan response generic; native unique conflict menjadi 409; log tidak memuat password/token/raw payload; failure rollback tidak menghapus konteks error pertama.
