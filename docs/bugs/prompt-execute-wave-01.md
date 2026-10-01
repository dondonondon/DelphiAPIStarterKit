Kerjakan WAVE-01 pada repository D:\Github\DelphiAPIStarterKit sampai seluruh pekerjaan yang dapat dieksekusi selesai dan setiap acceptance wajib memiliki evidence atau blocker konkret. Kerjakan serial dalam chat ini; langsung implementation, jangan berhenti pada rencana/proposal atau meminta konfirmasi rutin atas scope yang telah diberikan.

Scope utama:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-01-authorization-dan-permission.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-02-authentication-password-dan-session.md
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-03-http-routing-dan-error-boundary.md

Kontrak target tambahan yang wajib dibaca: D:\Github\DelphiAPIStarterKit\docs\bugs\auth-production-contract-2026-10-01.md.
Revisi auth-v2 supersedes pilihan policy ambigu pada lampiran historis, bukan bukti implementasi selesai.
SQL baseline dan withdatasample merupakan alternatif fresh-empty import tanpa credential bawaan;
tidak boleh dipakai sebagai migration upgrade atau diasumsikan kompatibel dengan source Pascal lama.

Finding owner utama wave ini: F01, F03, F04, F05, F06, F43, F44, F45, F08, F09, F24, F25, F26, F37.
Urutan internal: T01 → T02 → T03.
Fokus: Tutup akses tanpa permission, perkuat credential/password/session, lalu pastikan Bearer/routing/exception boundary aman pada listener.

Langkah awal:
1. Baca AGENTS.md, .github/copilot-instructions.md, .github/instructions/delphi.instructions.md, docs/information/structure.md, docs/bugs/review-tasks-windows-linux-2026-10-01.md dan file task utama di atas. Gunakan docs/bugs/full-review-windows-linux-2026-10-01.md sebagai baseline evidence; periksa ulang source karena snapshot/line numbers dapat berubah.
2. Periksa Git status dan source/toolchain actual. Preserve unrelated dirty work; tidak melakukan reset/clean atau menimpa perubahan yang tidak terkait. Tidak ada wave sebelumnya. Inventarisasi baseline source/toolchain/config sebelum implementation.
3. Sebelum build apa pun, verifikasi task-10 langkah T10.a/F34: compile.bat/CloseApp/dproj event tidak boleh force-kill process hanya karena nama sama. Jika belum aman, perbaiki dependency slice ini lebih dulu lalu jalankan build sesuai aturan repo. Catat F34 pada T10, bukan membuat owner baru.

Dependency lintas wave yang perlu dibaca/diterapkan hanya bila benar-benar dibutuhkan:
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-10-hosting-build-dan-deployment.md: T10.a / F34 harus aman sebelum build pertama. Ini pekerjaan prasyarat; sisa hosting tetap milik wave-04.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-04-logging-dan-observability.md: Gunakan satu logger/fallback yang tidak melempar ke HTTP. Bila belum tersedia, buat minimum interface/behavior yang benar-benar diperlukan dan catat untuk wave-02.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-05-request-response-json-dan-waktu.md: Koordinasikan typed auth parsing dan no secret echo. Jika alur password yang diubah masih menggemakan request, tutup F02 sebagai dependency slice dan catat pada T05; parsing/serializer lengkap tetap wave-02.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-06-database-transaksi-dan-validasi-domain.md: Permission role milik T01; reference validation serta mutation outcome domain milik T06. Minimum checks/transaction integration yang diperlukan dicatat untuk wave-02.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-09-config-path-dan-persistence.md: Credential/config harus memakai resolver secret yang konsisten. Jika minimum config/secret reader perlu diubah, catat contract/path untuk wave-03; jangan membuat resolver sementara yang berbeda.
- D:\Github\DelphiAPIStarterKit\docs\bugs\task-11-schema-migration-dan-kompatibilitas.md: Auth schema delta dimiliki T02. Sediakan migration khususnya pada clone dan catat target schema untuk reconciliation wave-04; jangan menunggu legacy guide selesai untuk containment.

Aturan dependency: gunakan implementation yang sudah benar; jika prerequisite belum tersedia, kerjakan slice minimum yang diperlukan dengan satu authority compatible. Jangan menjalankan seluruh task di luar scope secara otomatis. Catat changed files, finding/acceptance yang benar-benar tertutup, owner task serta sisa scope. Task luar yang baru sebagian dikerjakan berstatus BERJALAN, bukan SELESAI. Wave berikutnya harus memakai hasilnya dan tidak mengimplementasikan ulang. Jika prerequisite membutuhkan informasi/domain contract/external resource yang belum tersedia, catat blocker spesifik dan lanjutkan bagian independen.

Eksekusi dan kualitas:
4. Implementasikan seluruh langkah task utama, termasuk validation, business rules, repository/transaction, ownership dan error handling yang terdampak. Nyatakan singkat dampak arsitektur bila auth/config/routing/response/connection lifecycle berubah, lalu lanjutkan scope yang sudah authorized.
5. Pertahankan feature-first flat modules; jangan mass-move semua service/repository ke global folder. Gunakan helpers/services/repositories yang focused, no duplicate config/logger/auth predicate, no custom cryptography dan no unnecessary dependencies. Unit baru eksplisit dalam DPR; ikuti style/instruksi Delphi dan jangan menambah komentar Pascal/TODO/pseudocode.
6. Preserve public routes/fields/helper API kecuali migration intentional yang didokumentasikan. Standard error envelope mengikuti actual HTTP status, messages, Unix servertime string dan data:[{}]. Parser/serializer/clock/log/security memakai satu authority sesuai hasil task sebelumnya.
7. Update API docs/Postman bila endpoint/contract berubah, config examples/README/schema/migration/maps hanya bila terdampak. Runtime config lokal/secret tetap terjaga; jangan mencetak password/key/hash/token aktual. /temp-file/ tetap read-only dan generated directories yang dilarang tidak dipakai sebagai source authority.
8. Jalankan checks/tests yang membuktikan risiko terkait dan iterasi fix sampai lulus. Build platform/config relevan mengikuti compile.bat yang sudah aman. Pisahkan bukti SOURCE, BUILD, RUNTIME WINDOWS, RUNTIME LINUX, DATABASE dan DEPLOYMENT; Linux64 cross-build tidak membuktikan runtime Linux, dan baseline build/harness bukan acceptance fix baru.
9. Fokus validasi wave: Permission matrix ordinary/admin/self/other; salt/legacy hash/CSPRNG audit; refresh reuse/revoke/logout race; bounds/observed metadata/throttling; Bearer/custom/conflict headers; invalid routes; DB unavailable/allocation recovery; raw headers/Unicode dan actual CORS/preflight. Semua acceptance rinci pada task utama tetap wajib; daftar fokus ini tidak menggantikannya. CONTEXT-DEPENDENT hanya ditutup dengan actual consumer/deployment/policy evidence, termasuk batas not-applicable bila benar-benar terbukti.
10. Migration/state-changing DB tests menggunakan clone/test dengan schema/provider/versi yang jelas; jangan mengubah produksi. Bila runtime/DB/tool/device/deployment unavailable, selesaikan source/build/checks independen dan catat BLOCKED beserta kondisi reopening. Jangan menyatakan acceptance belum diuji sebagai lulus.

Checkpoint dan penyelesaian:
11. Setelah setiap task atau perubahan contract penting, update bagian Catatan eksekusi pada docs/bugs/wave-01.md: task/finding yang dikerjakan, changed files, policy/contract/schema delta, checks/platform/outcome, evidence dan pekerjaan berikutnya. Saat context berganti, baca checkpoint, verifikasi source/evidence lalu lanjutkan tanpa mengulang closed work.
12. Update finding checklist dan status file task utama/affected dependency serta indeks task secara konsisten. Update status wave ini dan docs/bugs/waves-windows-linux-2026-10-01.md. SELESAI hanya jika seluruh acceptance wajib scope terpenuhi; jika ada gate wajib unavailable, wave/task terkait BLOCKED dengan sisa independen tetap dikerjakan.
13. Simpan laporan akhir ke docs/bugs/wave-01-result.md: source identity, task/finding outcome, files changed, compatibility/migration, evidence per platform, residual risks, blocker/reopening dan handoff ke wave berikutnya. Ringkas hasil dalam bahasa Indonesia. Jangan mengeksekusi wave lain otomatis setelah scope ini selesai.

Khusus wave ini:
- Mulai dengan containment F01 sebelum refactor besar. Tetapkan actor/policy yang dipakai T01/T02/T03, lalu kerjakan seluruh langkah dan acceptance ketiganya.
- Audit secret generation Windows/Linux dan rancang versioned hashing/refresh migration serta revoke transaction. UUID identifier publik tetap terpisah dari secret.
- Hubungkan Bearer parse hook ke resolver, whitelist route/method/action dan berikan safe error envelope termasuk connection-acquisition failure serta CORS owner.

Target Auth wajib wave ini:
- Implementasikan seluruh endpoint/policy table auth-v2: actor/permission, role catalog/mapping, opaque CSPRNG 32-byte tokens, Argon2id PHC hash, session idle/absolute, refresh rotation/reuse committed revocation, recent reauth, session self-service dan one-time setup/reset redemption.
- Baseline akun admin-managed tanpa public registration/email recovery semu. Admin bootstrap offline tanpa default credential; initial-password session restricted. Generic PUT password ditolak; ResetPassword tidak mengembalikan temporary password. Preserve legacy public role_id integer/envelope, dokumentasikan intentional auth-v2 client cutover.
- Response expiry typed integer/no-store/no request echo; deny legacy session_id/device_id-only refresh/logout. Resolve T04/T05/T09 dependency slices yang diperlukan agar auth aman sekarang, tanpa menduplikasi authority.
- SQL target belum runtime proof. Implementasikan/backfill/migration numeric schema pada clone, FK/CHECK/reuse/locking/cleanup tests, credential invalidation dan docs/API/Postman/client cutover. Source existing belum mengisi required idle_expires_at/role_code.
- Uji gate MFA provider/client storage untuk deployment profile yang dipilih; faktor kedua tidak dianggap lulus dari flag atau authenticated_at saja. Provider/clone/runtime unavailable menjadi blocker eksplisit, tidak fallback insecure.

Gate lintas wave Auth-v2:
Periksa kontrak target dan prerequisite actual, bukan hanya status checklist. Feature/endpoint/field baru
memerlukan validation/permission/ownership/bounded query/security/error handling pada wave yang membuatnya.
Minimum dependency yang dibutuhkan dikerjakan dan dicatat pada owner task asal; wave berikutnya
mereconcile sisa dan regression, tidak menghidupkan kembali legacy insecure contract atau menutup
acceptance yang belum diuji. Temuan utama F01-F46 dan ownership wave tetap; tambahan scope auth-v2
tidak otomatis ditutup hanya karena semua finding historis telah diberi checklist.
