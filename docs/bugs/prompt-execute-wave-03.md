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
