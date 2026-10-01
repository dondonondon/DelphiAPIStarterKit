Kerjakan WAVE-04 pada repository D:\Github\DelphiAPIStarterKit sampai seluruh pekerjaan yang dapat dieksekusi selesai dan setiap acceptance wajib memiliki evidence atau blocker konkret. Kerjakan serial dalam chat ini; langsung implementation, jangan berhenti pada rencana/proposal atau meminta konfirmasi rutin atas scope yang telah diberikan.

Scope utama:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-10-hosting-build-dan-deployment.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-11-schema-migration-dan-kompatibilitas.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-12-architecture-dan-centralization.md

Kontrak target tambahan yang wajib dibaca: D:\Github\DelphiAPIStarterKit\docs\bugs\auth-production-contract-2026-10-01.md.
Revisi auth-v2 supersedes pilihan policy ambigu pada lampiran historis, bukan bukti implementasi selesai.
SQL baseline dan withdatasample merupakan alternatif fresh-empty import tanpa credential bawaan;
tidak boleh dipakai sebagai migration upgrade atau diasumsikan kompatibel dengan source Pascal lama.

Finding owner utama wave ini: F29, F30, F31, F32, F33, F34, F41, F35, F40.
Urutan internal: T10 → T11 → T12.
Fokus: Tuntaskan host/build/deployment kedua OS, validasi migration pada clone, dan rapikan satu authority per concern setelah behavior stabil.

Langkah awal:
1. Baca AGENTS.md, .github/copilot-instructions.md, .github/instructions/delphi.instructions.md, docs/information/structure.md, docs/bugs/review-tasks-windows-linux-2026-10-01.md dan file task utama di atas. Gunakan docs/bugs/full-review-windows-linux-2026-10-01.md sebagai baseline evidence; periksa ulang source karena snapshot/line numbers dapat berubah.
2. Periksa Git status dan source/toolchain actual. Preserve unrelated dirty work; tidak melakukan reset/clean atau menimpa perubahan yang tidak terkait. Baca catatan hasil wave-01 sampai wave-03 yang sudah dijalankan. Validasi dependency yang dipakai dari source dan evidence actual; status BLOCKED yang tidak terkait tidak menghentikan pekerjaan independen.
3. Sebelum build apa pun, verifikasi task-10 langkah T10.a/F34: compile.bat/CloseApp/dproj event tidak boleh force-kill process hanya karena nama sama. Jika belum aman, perbaiki dependency slice ini lebih dulu lalu jalankan build sesuai aturan repo. Catat F34 pada T10, bukan membuat owner baru.

Dependency lintas wave yang perlu dibaca/diterapkan hanya bila benar-benar dibutuhkan:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-01-authorization-dan-permission.md: Policy/actor tidak dipindah menjadi generic string helper atau hilang pada registry/composition refactor.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-02-authentication-password-dan-session.md: Auth hashing/session/schema migration/cutover menjadi bagian target T11 dan required config T10.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-03-http-routing-dan-error-boundary.md: Listener/Bearer/routing/safe error behavior tetap terlindungi pada bootstrap/stop/registration changes.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-04-logging-dan-observability.md: Logger fallback/sink/rotation memakai authority existing dan diuji dengan service identity.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-05-request-response-json-dan-waktu.md: Typed IO/role/time contract tetap compatible saat schema/result/service refactor.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-06-database-transaksi-dan-validasi-domain.md: UNIQUE/reference/nullability/domain policy direkonsiliasi ke schema migration; no destructive cascade tanpa domain evidence.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-07-collection-pagination-dan-kapasitas.md: Pagination/fetch/load budget tetap berlaku pada pool/driver/host changes.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-08-storage-upload-dan-stream.md: Storage/stream cleanup berintegrasi dengan drain/timeout; jangan kehilangan root/permission policy.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-09-config-path-dan-persistence.md: Startup snapshot/config/data/log/library paths tetap satu authority dan tidak tergantung WorkingDirectory.

Aturan dependency: gunakan implementation yang sudah benar; jika prerequisite belum tersedia, kerjakan slice minimum yang diperlukan dengan satu authority compatible. Jangan menjalankan seluruh task di luar scope secara otomatis. Catat changed files, finding/acceptance yang benar-benar tertutup, owner task serta sisa scope. Task luar yang baru sebagian dikerjakan berstatus BERJALAN, bukan SELESAI. Wave berikutnya harus memakai hasilnya dan tidak mengimplementasikan ulang. Jika prerequisite membutuhkan informasi/domain contract/external resource yang belum tersedia, catat blocker spesifik dan lanjutkan bagian independen.

Eksekusi dan kualitas:
4. Implementasikan seluruh langkah task utama, termasuk validation, business rules, repository/transaction, ownership dan error handling yang terdampak. Nyatakan singkat dampak arsitektur bila auth/config/routing/response/connection lifecycle berubah, lalu lanjutkan scope yang sudah authorized.
5. Pertahankan feature-first flat modules; jangan mass-move semua service/repository ke global folder. Gunakan helpers/services/repositories yang focused, no duplicate config/logger/auth predicate, no custom cryptography dan no unnecessary dependencies. Unit baru eksplisit dalam DPR; ikuti style/instruksi Delphi dan jangan menambah komentar Pascal/TODO/pseudocode.
6. Preserve public routes/fields/helper API kecuali migration intentional yang didokumentasikan. Standard error envelope mengikuti actual HTTP status, messages, Unix servertime string dan data:[{}]. Parser/serializer/clock/log/security memakai satu authority sesuai hasil task sebelumnya.
7. Update API docs/Postman bila endpoint/contract berubah, config examples/README/schema/migration/maps hanya bila terdampak. Runtime config lokal/secret tetap terjaga; jangan mencetak password/key/hash/token aktual. /temp-file/ tetap read-only dan generated directories yang dilarang tidak dipakai sebagai source authority.
8. Jalankan checks/tests yang membuktikan risiko terkait dan iterasi fix sampai lulus. Build platform/config relevan mengikuti compile.bat yang sudah aman. Pisahkan bukti SOURCE, BUILD, RUNTIME WINDOWS, RUNTIME LINUX, DATABASE dan DEPLOYMENT; Linux64 cross-build tidak membuktikan runtime Linux, dan baseline build/harness bukan acceptance fix baru.
9. Fokus validasi wave: Safe build and coexisting artifacts; native client bitness/TLS/SQL staging; readiness/nonzero failure exit; Ctrl+C Windows/SIGTERM Linux/drain/repeated start-stop; actual clone migration/count/UUID/FK/nullability/app/restore; dependency/callsite/ownership/facade/registration maps serta moved-use-case regression. Semua acceptance rinci pada task utama tetap wajib; daftar fokus ini tidak menggantikannya. CONTEXT-DEPENDENT hanya ditutup dengan actual consumer/deployment/policy evidence, termasuk batas not-applicable bila benar-benar terbukti.
10. Migration/state-changing DB tests menggunakan clone/test dengan schema/provider/versi yang jelas; jangan mengubah produksi. Bila runtime/DB/tool/device/deployment unavailable, selesaikan source/build/checks independen dan catat BLOCKED beserta kondisi reopening. Jangan menyatakan acceptance belum diuji sebagai lulus.

Checkpoint dan penyelesaian:
11. Setelah setiap task atau perubahan contract penting, update bagian Catatan eksekusi pada docs/bugs/wave-04.md: task/finding yang dikerjakan, changed files, policy/contract/schema delta, checks/platform/outcome, evidence dan pekerjaan berikutnya. Saat context berganti, baca checkpoint, verifikasi source/evidence lalu lanjutkan tanpa mengulang closed work.
12. Update finding checklist dan status file task utama/affected dependency serta indeks task secara konsisten. Update status wave ini dan docs/bugs/waves-windows-linux-2026-10-01.md. SELESAI hanya jika seluruh acceptance wajib scope terpenuhi; jika ada gate wajib unavailable, wave/task terkait BLOCKED dengan sisa independen tetap dikerjakan.
13. Simpan laporan akhir ke docs/bugs/wave-04-result.md: source identity, task/finding outcome, files changed, compatibility/migration, evidence per platform, residual risks, blocker/reopening dan handoff ke wave berikutnya. Ringkas hasil dalam bahasa Indonesia. Jangan mengeksekusi wave lain otomatis setelah scope ini selesai.

Khusus wave ini:
- T10: reconcile T10.a/F34 yang mungkin sudah selesai sejak wave-01; tuntaskan artifact paths, native libraries, readiness/exit/stop dan runtime/default docs.
- T11: reconcile auth/domain schema delta dari wave sebelumnya, pilih schema asal/target eksplisit dan uji end-to-end/failure/restore pada clone.
- T12 dikerjakan setelah regression terkait tersedia; preserve feature-first, pakai ulang resolver/logger/security/policy yang telah dibuat dan ekstrak facade secara incremental.
- Jalankan integrated regression untuk perubahan yang benar-benar terdampak refactor/migration/hosting; closure wajib berdasarkan evidence actual, bukan checklist lama.

Reconciliation Auth wajib wave ini:
- Gunakan kontrak auth-v2 dan schema baseline/sample aktual; T11 harus menyediakan migration versioned dari numeric legacy schema yang dinyatakan, bukan menjalankan ulang fresh CREATE script.
- Rekonsiliasi role_code/permission grant policy, ASCII password representation/legacy rehash, UTC/idle/absolute/revoked metadata, refresh same-session self-FK/retention, one-time recovery/audit dan credential invalidation pada cutover.
- Buktikan fresh baseline/sample tidak berisi login credential, schema migration sama, invalid FK/CHECK/unique/cross-session successor ditolak, cleanup chain aman dan aplikasi client auth-v2 berjalan; schema-only edits tidak menutup gate production/MFA/runtime.

Gate lintas wave Auth-v2:
Periksa kontrak target dan prerequisite actual, bukan hanya status checklist. Feature/endpoint/field baru
memerlukan validation/permission/ownership/bounded query/security/error handling pada wave yang membuatnya.
Minimum dependency yang dibutuhkan dikerjakan dan dicatat pada owner task asal; wave berikutnya
mereconcile sisa dan regression, tidak menghidupkan kembali legacy insecure contract atau menutup
acceptance yang belum diuji. Temuan utama F01-F46 dan ownership wave tetap; tambahan scope auth-v2
tidak otomatis ditutup hanya karena semua finding historis telah diberi checklist.
