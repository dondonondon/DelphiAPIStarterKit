# WAVE-03 — Config, storage, dan collection pagination

Status: **BELUM DIMULAI**. Task utama: **T07, T08, T09**. Temuan utama: **9**. Tanggal: **1 Oktober 2026**.

Navigasi: [indeks wave](waves-windows-linux-2026-10-01.md) · [indeks task](review-tasks-windows-linux-2026-10-01.md) · [review lengkap](full-review-windows-linux-2026-10-01.md).

**Revisi dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md) wajib untuk task utama dan
regression lintas wave. SQL target sudah ditulis; endpoint Pascal/migration/runtime tetap acceptance
terpisah. Gunakan hasil prerequisite yang terbukti dan jangan memulihkan legacy insecure contract.

## 1. Tujuan dan cakupan

Tuntaskan config/path/load-save authority, stream/file/upload policy, dan collection yang lengkap serta bounded pada query.

Satu shot berarti satu prompt untuk seluruh scope wave, termasuk implementation, checks, status dan handoff. Bukti eksternal yang belum tersedia tetap BLOCKED; tidak diasumsikan lulus. File ini baru paket eksekusi, belum menjalankan task.

| Task utama | Kategori | Finding owner utama | Status |
|---|---|---|---|
| [T07](task-07-collection-pagination-dan-kapasitas.md) | Collection completeness, pagination, dan kapasitas | F12, F36 | BELUM DIMULAI |
| [T08](task-08-storage-upload-dan-stream.md) | Storage, upload/download, dan stream ownership | F07, F14, F38 | BELUM DIMULAI |
| [T09](task-09-config-path-dan-persistence.md) | Config path, load/save, dan secret persistence | F13, F28, F39, F46 | BELUM DIMULAI |

## 2. Urutan internal

**T09 → T08 → T07** setelah gate T10.a/F34 aman untuk build. Urutan internal boleh berbeda dari nomor task untuk mengikuti dependency.

- [ ] Urutan internal T09 → T08 → T07 karena storage/logger memakai resolved roots. F07 double-free yang belum ditutup boleh menjadi containment pertama sebelum perbaikan config panjang.
- [ ] Reconcile reader/logger/secret dependency slices dari wave-01/02. Seluruh DB/HMAC/helper load-save memakai file yang sama, secret whitespace dipertahankan dan runtime config lokal tetap tersedia.
- [ ] Tutup image ownership dan unauthenticated upload/quota sebelum file-helper hardening. Downloader yang belum dipakai tetap dicatat sebagai helper contract, bukan active SSRF.
- [ ] Perbaiki fetch completeness sekaligus query pagination/default/max size/stable order; jangan menggunakan unlimited FetchAll sebagai solusi final.

## 3. Dependensi dan batas pekerjaan lintas wave

- [T01](task-01-authorization-dan-permission.md) — Upload/image permission memakai actor/policy existing; filename validation bukan hak akses terhadap isi file.
- [T02](task-02-authentication-password-dan-session.md) — Config/HMAC/pepper/credential cutover harus menjaga auth contract wave-01; revalidasi credential flows setelah config reader berubah.
- [T03](task-03-http-routing-dan-error-boundary.md) — Pakai ingress/HTTP/MIME/error boundary yang sama; stream transfer ownership dan upload status tidak menduplikasi response builder.
- [T04](task-04-logging-dan-observability.md) — Redirect logger ke configured writable root; binary read-only dan sink fallback harus tetap berjalan.
- [T05](task-05-request-response-json-dan-waktu.md) — Gunakan typed parser/serializer/clock wave-02. Pagination tidak mengubah tipe string/number atau envelope API.
- [T06](task-06-database-transaksi-dan-validasi-domain.md) — Query/domain constraints tetap digunakan; jangan mengembalikan snapshot/mutation/soft-delete bugs.
- [T10](task-10-hosting-build-dan-deployment.md) — Nyatakan config/driver/storage/timeout contracts yang harus divalidasi readiness/stop di wave-04. T10.a tetap gate setiap build.

Prerequisite slice yang necessary boleh dikerjakan lebih awal dengan owner finding tetap pada task asal. Jangan otomatis menutup seluruh task dependency atau menggandakan owner. Catat scope/evidence agar wave berikutnya tinggal menyelesaikan sisa. Baca catatan hasil wave-01 sampai wave-02 yang sudah dijalankan. Validasi dependency yang dipakai dari source dan evidence actual; status BLOCKED yang tidak terkait tidak menghentikan pekerjaan independen.

## 4. Gate validasi dan deliverable

- [ ] Auth-v2: satu startup config snapshot memvalidasi access/session idle/absolute/recovery/reauth TTL, Argon2 provider/cost, limiter/trusted-proxy/security profile; invalid configuration fail closed, tanpa fallback insecure.
- [ ] Sessions/Role/User collections yang ditambahkan wave-01 tetap bounded di query, stable, typed, ownership/permission filtered sebelum pagination; config/storage changes tidak membocorkan credential atau memberi business access pada restricted session.

- [ ] Seluruh task utama serta acceptance per finding dieksekusi; not-applicable memiliki evidence, unavailable wajib BLOCKED.
- [ ] Gate build T10.a terbukti aman dan target compiler relevan diuji setelah code changes.
- [ ] Different CWD/absolute config/binary rename/env unset-empty/secret whitespace; save concurrency/restart/error/permissions; Git tracking runtime config; stream memory/disconnect/concurrency; upload auth/quota/limits; root containment/OS filenames/symlink/partial writes; 0/1/1000/1001/2500 rows, small rowset, stable pagination/query limits dan capacity.
- [ ] SOURCE/BUILD dipisahkan dari RUNTIME WINDOWS/LINUX, DATABASE dan DEPLOYMENT actual.
- [ ] API/config/schema/README/maps yang terdampak serta status task/dependency/indeks/wave sudah diperbarui.
- [ ] Laporan akhir disimpan sebagai `wave-03-result.md` saat wave dijalankan, berisi evidence/blocker/handoff.

Setelah wave ini, lanjutkan melalui wave-04.md dengan prompt terpisah dari user.

## 5. Prompt satu shot siap pakai

File prompt terpisah: [prompt-execute-wave-03.md](prompt-execute-wave-03.md). File tersebut berisi prompt lengkap dan dapat langsung diberikan sebagai instruksi eksekusi.

Salin blok berikut sebagai satu permintaan. Alternatif, minta agent menjalankan seluruh instruksi file ini.

```text
Kerjakan WAVE-03 pada repository D:\Github\DelphiAPIStarterKit sampai seluruh pekerjaan yang dapat dieksekusi selesai dan setiap acceptance wajib memiliki evidence atau blocker konkret. Kerjakan serial dalam chat ini; langsung implementation, jangan berhenti pada rencana/proposal atau meminta konfirmasi rutin atas scope yang telah diberikan.

Scope utama:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-07-collection-pagination-dan-kapasitas.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-08-storage-upload-dan-stream.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-09-config-path-dan-persistence.md

Kontrak target tambahan yang wajib dibaca: D:\Github\DelphiAPIStarterKit\docs\bugs\auth-production-contract-2026-10-01.md.
Auth-v2 menjadi authority untuk schema/credential/permission dan intentional client cutover; lampiran
temuan merupakan baseline historis. SQL target dan status wave tidak membuktikan runtime sudah selesai.
Baseline/sample SQL alternatif fresh-empty import, bukan migration upgrade database existing.

Finding owner utama wave ini: F12, F36, F07, F14, F38, F13, F28, F39, F46.
Urutan internal: T09 → T08 → T07.
Fokus: Tuntaskan config/path/load-save authority, stream/file/upload policy, dan collection yang lengkap serta bounded pada query.

Langkah awal:
1. Baca AGENTS.md, .github/copilot-instructions.md, .github/instructions/delphi.instructions.md, docs/information/structure.md, docs/bugs/review-tasks-windows-linux-2026-10-01.md dan file task utama di atas. Gunakan docs/bugs/full-review-windows-linux-2026-10-01.md sebagai baseline evidence; periksa ulang source karena snapshot/line numbers dapat berubah.
2. Periksa Git status dan source/toolchain actual. Preserve unrelated dirty work; tidak melakukan reset/clean atau menimpa perubahan yang tidak terkait. Baca catatan hasil wave-01 sampai wave-02 yang sudah dijalankan. Validasi dependency yang dipakai dari source dan evidence actual; status BLOCKED yang tidak terkait tidak menghentikan pekerjaan independen.
3. Sebelum build apa pun, verifikasi task-10 langkah T10.a/F34: compile.bat/CloseApp/dproj event tidak boleh force-kill process hanya karena nama sama. Jika belum aman, perbaiki dependency slice ini lebih dulu lalu jalankan build sesuai aturan repo. Catat F34 pada T10, bukan membuat owner baru.

Dependency lintas wave yang perlu dibaca/diterapkan hanya bila benar-benar dibutuhkan:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-01-authorization-dan-permission.md: Upload/image permission memakai actor/policy existing; filename validation bukan hak akses terhadap isi file.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-02-authentication-password-dan-session.md: Config/HMAC/pepper/credential cutover harus menjaga auth contract wave-01; revalidasi credential flows setelah config reader berubah.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-03-http-routing-dan-error-boundary.md: Pakai ingress/HTTP/MIME/error boundary yang sama; stream transfer ownership dan upload status tidak menduplikasi response builder.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-04-logging-dan-observability.md: Redirect logger ke configured writable root; binary read-only dan sink fallback harus tetap berjalan.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-05-request-response-json-dan-waktu.md: Gunakan typed parser/serializer/clock wave-02. Pagination tidak mengubah tipe string/number atau envelope API.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-06-database-transaksi-dan-validasi-domain.md: Query/domain constraints tetap digunakan; jangan mengembalikan snapshot/mutation/soft-delete bugs.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-10-hosting-build-dan-deployment.md: Nyatakan config/driver/storage/timeout contracts yang harus divalidasi readiness/stop di wave-04. T10.a tetap gate setiap build.

Aturan dependency: gunakan implementation yang sudah benar; jika prerequisite belum tersedia, kerjakan slice minimum yang diperlukan dengan satu authority compatible. Jangan menjalankan seluruh task di luar scope secara otomatis. Catat changed files, finding/acceptance yang benar-benar tertutup, owner task serta sisa scope. Task luar yang baru sebagian dikerjakan berstatus BERJALAN, bukan SELESAI. Wave berikutnya harus memakai hasilnya dan tidak mengimplementasikan ulang. Jika prerequisite membutuhkan informasi/domain contract/external resource yang belum tersedia, catat blocker spesifik dan lanjutkan bagian independen.

Eksekusi dan kualitas:
4. Implementasikan seluruh langkah task utama, termasuk validation, business rules, repository/transaction, ownership dan error handling yang terdampak. Nyatakan singkat dampak arsitektur bila auth/config/routing/response/connection lifecycle berubah, lalu lanjutkan scope yang sudah authorized.
5. Pertahankan feature-first flat modules; jangan mass-move semua service/repository ke global folder. Gunakan helpers/services/repositories yang focused, no duplicate config/logger/auth predicate, no custom cryptography dan no unnecessary dependencies. Unit baru eksplisit dalam DPR; ikuti style/instruksi Delphi dan jangan menambah komentar Pascal/TODO/pseudocode.
6. Preserve public routes/fields/helper API kecuali migration intentional yang didokumentasikan. Standard error envelope mengikuti actual HTTP status, messages, Unix servertime string dan data:[{}]. Parser/serializer/clock/log/security memakai satu authority sesuai hasil task sebelumnya.
7. Update API docs/Postman bila endpoint/contract berubah, config examples/README/schema/migration/maps hanya bila terdampak. Runtime config lokal/secret tetap terjaga; jangan mencetak password/key/hash/token aktual. /temp-file/ tetap read-only dan generated directories yang dilarang tidak dipakai sebagai source authority.
8. Jalankan checks/tests yang membuktikan risiko terkait dan iterasi fix sampai lulus. Build platform/config relevan mengikuti compile.bat yang sudah aman. Pisahkan bukti SOURCE, BUILD, RUNTIME WINDOWS, RUNTIME LINUX, DATABASE dan DEPLOYMENT; Linux64 cross-build tidak membuktikan runtime Linux, dan baseline build/harness bukan acceptance fix baru.
9. Fokus validasi wave: Different CWD/absolute config/binary rename/env unset-empty/secret whitespace; save concurrency/restart/error/permissions; Git tracking runtime config; stream memory/disconnect/concurrency; upload auth/quota/limits; root containment/OS filenames/symlink/partial writes; 0/1/1000/1001/2500 rows, small rowset, stable pagination/query limits dan capacity. Semua acceptance rinci pada task utama tetap wajib; daftar fokus ini tidak menggantikannya. CONTEXT-DEPENDENT hanya ditutup dengan actual consumer/deployment/policy evidence, termasuk batas not-applicable bila benar-benar terbukti.
10. Migration/state-changing DB tests menggunakan clone/test dengan schema/provider/versi yang jelas; jangan mengubah produksi. Bila runtime/DB/tool/device/deployment unavailable, selesaikan source/build/checks independen dan catat BLOCKED beserta kondisi reopening. Jangan menyatakan acceptance belum diuji sebagai lulus.

Checkpoint dan penyelesaian:
11. Setelah setiap task atau perubahan contract penting, update bagian Catatan eksekusi pada docs/bugs/wave-03.md: task/finding yang dikerjakan, changed files, policy/contract/schema delta, checks/platform/outcome, evidence dan pekerjaan berikutnya. Saat context berganti, baca checkpoint, verifikasi source/evidence lalu lanjutkan tanpa mengulang closed work.
12. Update finding checklist dan status file task utama/affected dependency serta indeks task secara konsisten. Update status wave ini dan docs/bugs/waves-windows-linux-2026-10-01.md. SELESAI hanya jika seluruh acceptance wajib scope terpenuhi; jika ada gate wajib unavailable, wave/task terkait BLOCKED dengan sisa independen tetap dikerjakan.
13. Simpan laporan akhir ke docs/bugs/wave-03-result.md: source identity, task/finding outcome, files changed, compatibility/migration, evidence per platform, residual risks, blocker/reopening dan handoff ke wave berikutnya. Ringkas hasil dalam bahasa Indonesia. Jangan mengeksekusi wave lain otomatis setelah scope ini selesai.

Khusus wave ini:
- Urutan internal T09 → T08 → T07 karena storage/logger memakai resolved roots. F07 double-free yang belum ditutup boleh menjadi containment pertama sebelum perbaikan config panjang.
- Reconcile reader/logger/secret dependency slices dari wave-01/02. Seluruh DB/HMAC/helper load-save memakai file yang sama, secret whitespace dipertahankan dan runtime config lokal tetap tersedia.
- Tutup image ownership dan unauthenticated upload/quota sebelum file-helper hardening. Downloader yang belum dipakai tetap dicatat sebagai helper contract, bukan active SSRF.
- Perbaiki fetch completeness sekaligus query pagination/default/max size/stable order; jangan menggunakan unlimited FetchAll sebagai solusi final.

Reconciliation Auth wajib wave ini:
- Baca kontrak auth-v2/evidence wave-01/02; minimum config/security/bounded-session slices yang sudah tersedia dipakai ulang, bukan diganti resolver atau key policy sementara.
- T09: typed startup config/snapshot untuk access 900s, absolute session 604800s, idle 86400s, recovery 900s dan recent reauth 300s; validasi integer/range/relasi TTL dan provider Argon2 parameters/cost/admission sesuai kontrak. Bedakan legacy HMAC verification key (hanya migration window), optional pepper/MFA secrets dan SHA-256 new token hash tanpa mewajibkan HMAC key baru yang tidak digunakan.
- Secret native/provider path, trusted-proxy allowlist, rate-limit backend/limits dan MFA/deployment profile yang dipilih harus eksplisit/validated. CWD/rename/env unset-empty tidak mengubah secret bytes atau policy; tidak ada fallback Argon2->fast HMAC atau session_id/device_id-only refresh.
- T07: bounded Sessions/Role/User collections memakai filter actor/permission di SQL sebelum pagination, stable ordering/unique tie-breaker, query page/max limits dan serializer typed. Session lists tidak pernah berisi token/hash/internal numeric IDs; validasi pagination/revoked/session metadata tetap sesuai auth-v2.
- T08: restricted must_change_password session tidak mendapatkan storage/business permission; penggunaan actor/permission untuk file tetap authority T01. Upload/file/config helper tidak menyimpan credential dalam public root dan perubahan path tidak membocorkan secret.
- Uji konfigurasi invalid/missing provider, different CWD/env whitespace, owned-session pagination/cross-user probes, no credential leak, idle/absolute TTL dan limiter/trusted-proxy regressions pada kedua OS; handoff readiness/native dependencies ke T10.

Gate lintas wave Auth-v2:
Periksa kontrak target dan prerequisite actual, bukan hanya status checklist. Feature/endpoint/field baru
memerlukan validation/permission/ownership/bounded query/security/error handling pada wave yang membuatnya.
Minimum dependency yang dibutuhkan dikerjakan dan dicatat pada owner task asal; wave berikutnya
mereconcile sisa dan regression, tidak menghidupkan kembali legacy insecure contract atau menutup
acceptance yang belum diuji. Temuan utama F01-F46 dan ownership wave tetap; tambahan scope auth-v2
tidak otomatis ditutup hanya karena semua finding historis telah diberi checklist.
```

## 6. Perintah singkat untuk menjalankan

```text
Eksekusi seluruh instruksi pada D:\Github\DelphiAPIStarterKit\docs\bugs\wave-03.md dalam satu rangkaian kerja sampai scope selesai atau setiap acceptance yang tersisa mempunyai blocker konkret. Langsung implementasi, validasi, update status dan simpan hasil sesuai file wave.
```

## 7. Catatan eksekusi

Belum ada eksekusi atau evidence wave. Saat dijalankan, catat setelah setiap task:

- Source/commit/working-tree identity dan task/finding yang dikerjakan.
- Changed files, policy/contract/schema delta dan prerequisite slice beserta task owner.
- Check/command/skenario, platform, outcome dan lokasi evidence tanpa secret.
- Acceptance lulus/belum diuji/BLOCKED, blocker/reopening dan next concrete action.
- Dependency handoff serta regression yang wajib dilanjutkan wave berikutnya.
