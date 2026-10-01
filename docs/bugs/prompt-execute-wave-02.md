Kerjakan WAVE-02 pada repository D:\Github\DelphiAPIStarterKit sampai seluruh pekerjaan yang dapat dieksekusi selesai dan setiap acceptance wajib memiliki evidence atau blocker konkret. Kerjakan serial dalam chat ini; langsung implementation, jangan berhenti pada rencana/proposal atau meminta konfirmasi rutin atas scope yang telah diberikan.

Scope utama:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-04-logging-dan-observability.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-05-request-response-json-dan-waktu.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-06-database-transaksi-dan-validasi-domain.md

Kontrak target tambahan yang wajib dibaca: D:\Github\DelphiAPIStarterKit\docs\bugs\auth-production-contract-2026-10-01.md.
Auth-v2 menjadi authority untuk schema/credential/permission dan intentional client cutover; lampiran
temuan merupakan baseline historis. SQL target dan status wave tidak membuktikan runtime sudah selesai.
Baseline/sample SQL alternatif fresh-empty import, bukan migration upgrade database existing.

Finding owner utama wave ini: F10, F23, F02, F11, F15, F16, F17, F22, F27, F18, F19, F20, F21, F42.
Urutan internal: T04 → T05 → T06.
Fokus: Satukan logger, tutup password echo dan kerusakan tipe/nilai JSON, lalu selaraskan validation/transaksi/constraint dengan stored state.

Langkah awal:
1. Baca AGENTS.md, .github/copilot-instructions.md, .github/instructions/delphi.instructions.md, docs/information/structure.md, docs/bugs/review-tasks-windows-linux-2026-10-01.md dan file task utama di atas. Gunakan docs/bugs/full-review-windows-linux-2026-10-01.md sebagai baseline evidence; periksa ulang source karena snapshot/line numbers dapat berubah.
2. Periksa Git status dan source/toolchain actual. Preserve unrelated dirty work; tidak melakukan reset/clean atau menimpa perubahan yang tidak terkait. Baca catatan hasil wave-01 yang sudah dijalankan. Validasi dependency yang dipakai dari source dan evidence actual; status BLOCKED yang tidak terkait tidak menghentikan pekerjaan independen.
3. Sebelum build apa pun, verifikasi task-10 langkah T10.a/F34: compile.bat/CloseApp/dproj event tidak boleh force-kill process hanya karena nama sama. Jika belum aman, perbaiki dependency slice ini lebih dulu lalu jalankan build sesuai aturan repo. Catat F34 pada T10, bukan membuat owner baru.

Dependency lintas wave yang perlu dibaca/diterapkan hanya bila benar-benar dibutuhkan:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-01-authorization-dan-permission.md: Gunakan permission policy hasil wave-01; jangan menganggap reference role existing sudah cukup untuk authorization.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-02-authentication-password-dan-session.md: Pertahankan hash/revoke/refresh contract dan satu transaction scope password. Revalidasi auth bila parser/mutation helpers berubah.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-03-http-routing-dan-error-boundary.md: Pakai safe HTTP boundary dan envelope yang sama; parser hanya satu kali dan logger failure tidak mengganti status/body.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-09-config-path-dan-persistence.md: Logger memakai satu resolved log root/config contract; minimum sink/path dependency dicatat untuk wave-03 tanpa membuat authority tandingan.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-07-collection-pagination-dan-kapasitas.md: Serializer dipakai pagination/fetch pada wave-03; typed serializer tidak boleh mengandalkan RecordCount atau merusak fix row completeness yang mungkin telah ada.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-11-schema-migration-dan-kompatibilitas.md: Catat schema delta UNIQUE/reference/nullability serta target name/type untuk final migration reconciliation wave-04.

Aturan dependency: gunakan implementation yang sudah benar; jika prerequisite belum tersedia, kerjakan slice minimum yang diperlukan dengan satu authority compatible. Jangan menjalankan seluruh task di luar scope secara otomatis. Catat changed files, finding/acceptance yang benar-benar tertutup, owner task serta sisa scope. Task luar yang baru sebagian dikerjakan berstatus BERJALAN, bukan SELESAI. Wave berikutnya harus memakai hasilnya dan tidak mengimplementasikan ulang. Jika prerequisite membutuhkan informasi/domain contract/external resource yang belum tersedia, catat blocker spesifik dan lanjutkan bagian independen.

Eksekusi dan kualitas:
4. Implementasikan seluruh langkah task utama, termasuk validation, business rules, repository/transaction, ownership dan error handling yang terdampak. Nyatakan singkat dampak arsitektur bila auth/config/routing/response/connection lifecycle berubah, lalu lanjutkan scope yang sudah authorized.
5. Pertahankan feature-first flat modules; jangan mass-move semua service/repository ke global folder. Gunakan helpers/services/repositories yang focused, no duplicate config/logger/auth predicate, no custom cryptography dan no unnecessary dependencies. Unit baru eksplisit dalam DPR; ikuti style/instruksi Delphi dan jangan menambah komentar Pascal/TODO/pseudocode.
6. Preserve public routes/fields/helper API kecuali migration intentional yang didokumentasikan. Standard error envelope mengikuti actual HTTP status, messages, Unix servertime string dan data:[{}]. Parser/serializer/clock/log/security memakai satu authority sesuai hasil task sebelumnya.
7. Update API docs/Postman bila endpoint/contract berubah, config examples/README/schema/migration/maps hanya bila terdampak. Runtime config lokal/secret tetap terjaga; jangan mencetak password/key/hash/token aktual. /temp-file/ tetap read-only dan generated directories yang dilarang tidak dipakai sebagai source authority.
8. Jalankan checks/tests yang membuktikan risiko terkait dan iterasi fix sampai lulus. Build platform/config relevan mengikuti compile.bat yang sudah aman. Pisahkan bukti SOURCE, BUILD, RUNTIME WINDOWS, RUNTIME LINUX, DATABASE dan DEPLOYMENT; Linux64 cross-build tidak membuktikan runtime Linux, dan baseline build/harness bukan acceptance fix baru.
9. Fokus validasi wave: Failing/concurrent/rotating logger; safe exception/rollback context dan secret scan; strict JSON/string/Int64/decimal/null/array/input limits; UTC/Jakarta; role_id name/type; duplicate/concurrent create dan update-delete barrier; role/money boundaries serta reference policy. Semua acceptance rinci pada task utama tetap wajib; daftar fokus ini tidak menggantikannya. CONTEXT-DEPENDENT hanya ditutup dengan actual consumer/deployment/policy evidence, termasuk batas not-applicable bila benar-benar terbukti.
10. Migration/state-changing DB tests menggunakan clone/test dengan schema/provider/versi yang jelas; jangan mengubah produksi. Bila runtime/DB/tool/device/deployment unavailable, selesaikan source/build/checks independen dan catat BLOCKED beserta kondisi reopening. Jangan menyatakan acceptance belum diuji sebagai lulus.

Checkpoint dan penyelesaian:
11. Setelah setiap task atau perubahan contract penting, update bagian Catatan eksekusi pada docs/bugs/wave-02.md: task/finding yang dikerjakan, changed files, policy/contract/schema delta, checks/platform/outcome, evidence dan pekerjaan berikutnya. Saat context berganti, baca checkpoint, verifikasi source/evidence lalu lanjutkan tanpa mengulang closed work.
12. Update finding checklist dan status file task utama/affected dependency serta indeks task secara konsisten. Update status wave ini dan docs/bugs/waves-windows-linux-2026-10-01.md. SELESAI hanya jika seluruh acceptance wajib scope terpenuhi; jika ada gate wajib unavailable, wave/task terkait BLOCKED dengan sisa independen tetap dikerjakan.
13. Simpan laporan akhir ke docs/bugs/wave-02-result.md: source identity, task/finding outcome, files changed, compatibility/migration, evidence per platform, residual risks, blocker/reopening dan handoff ke wave berikutnya. Ringkas hasil dalam bahasa Indonesia. Jangan mengeksekusi wave lain otomatis setelah scope ini selesai.

Khusus wave ini:
- Reconcile dependency slices dari wave-01 terlebih dahulu. Jangan menimpa actor/auth/error behavior yang sudah diperbaiki; sempurnakan logger T04.
- Tutup F02 lebih dahulu bila belum selesai, lalu kerjakan parser/serializer typed, field role_id compatible serta clock UTC T05.
- Kerjakan T06 setelah nilai input dijaga: unique conflicts, authoritative mutation outcomes, role bounds/references, DECIMAL(15,2) dan category soft-delete policy.

Reconciliation Auth wajib wave ini:
- Baca kontrak auth-v2 dan evidence wave-01 sebelum mengubah logger/parser/transaction helpers. Actor/session/password/recovery endpoints yang sudah diimplementasikan tetap menggunakan authority yang sama; jangan mengimplementasikan ulang lifecycle T02.
- T04: auth_security_event memakai metadata allowlist/append-only app grants, actor/target/correlation/observed origin, tanpa password/token/hash/raw payload. Sink DB/file failing dan retention teruji; audit tidak hilang melalui account cleanup.
- T05: expiry integer, flag Boolean, token/session string, success empty [], error [{}], UTC dan no-store; initial-password restricted response tanpa refresh_token. Credential baru hanya di-allow pada issuance berwenang; generic PUT password/legacy refresh/logout/temporary_password tidak dihidupkan kembali.
- T06: validasi role reference terpisah dari permission/delegation T01; generic mutation tidak melewati password-change/recovery flow. Pertahankan revoke atomik, must_change_password restriction, matched-versus-changed outcome dan lock/check-revalidate policy auth-v2.
- Uji ulang auth endpoints terdampak: secret echo/typed JSON, role/ref concurrent update, password/reset/revoke rollback, audit failing dan recent-auth/restricted-session enforcement. Client/API/Postman mengikuti intentional cutover, bukan schema-only proof.

Gate lintas wave Auth-v2:
Periksa kontrak target dan prerequisite actual, bukan hanya status checklist. Feature/endpoint/field baru
memerlukan validation/permission/ownership/bounded query/security/error handling pada wave yang membuatnya.
Minimum dependency yang dibutuhkan dikerjakan dan dicatat pada owner task asal; wave berikutnya
mereconcile sisa dan regression, tidak menghidupkan kembali legacy insecure contract atau menutup
acceptance yang belum diuji. Temuan utama F01-F46 dan ownership wave tetap; tambahan scope auth-v2
tidak otomatis ditutup hanya karena semua finding historis telah diberi checklist.
