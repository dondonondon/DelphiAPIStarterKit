# WAVE-01 — Authorization, authentication, dan HTTP boundary

Status: **BLOCKED**. Task utama: **T01, T02, T03**. Temuan utama: **14**. Tanggal: **1 Oktober 2026**.

Navigasi: [indeks wave](waves-windows-linux-2026-10-01.md) · [indeks task](review-tasks-windows-linux-2026-10-01.md) · [review lengkap](full-review-windows-linux-2026-10-01.md).

**Kontrak Auth tambahan:** [auth-v2](auth-production-contract-2026-10-01.md). Spesifikasi/SQL target sudah tersedia;

endpoint Pascal dan clone migration telah diterapkan; runtime/deployment acceptance per platform tercatat pada hasil wave. Baseline/sample adalah

alternatif fresh-empty import; tidak berisi credential bawaan dan bukan upgrade database existing.

## 1. Tujuan dan cakupan

Tutup akses tanpa permission, perkuat credential/password/session, lalu pastikan Bearer/routing/exception boundary aman pada listener.

Satu shot berarti satu prompt untuk seluruh scope wave, termasuk implementation, checks, status dan handoff. Bukti eksternal yang belum tersedia tetap BLOCKED; tidak diasumsikan lulus. Eksekusi serial dan evidence saat ini tersedia pada [hasil wave](wave-01-result.md); gate unavailable tetap BLOCKED.

| Task utama | Kategori | Finding owner utama | Status |

|---|---|---|---|

| [T01](task-01-authorization-dan-permission.md) | Authorization dan permission per action | F01 | BLOCKED |

| [T02](task-02-authentication-password-dan-session.md) | Authentication, password, dan lifecycle session | F03, F04, F05, F06, F43, F44, F45 | BLOCKED |

| [T03](task-03-http-routing-dan-error-boundary.md) | HTTP transport, routing, dan error boundary | F08, F09, F24, F25, F26, F37 | BLOCKED |

## 2. Urutan internal

**T01 → T02 → T03** setelah gate T10.a/F34 aman untuk build. Urutan internal boleh berbeda dari nomor task untuk mengikuti dependency.

- [ ] Mulai dengan containment F01 sebelum refactor besar. Tetapkan actor/policy yang dipakai T01/T02/T03, lalu kerjakan seluruh langkah dan acceptance ketiganya.

- [x] Audit secret generation Windows/Linux dan rancang versioned hashing/refresh migration serta revoke transaction. UUID identifier publik tetap terpisah dari secret.

- [x] Hubungkan Bearer parse hook ke resolver, whitelist route/method/action dan berikan safe error envelope termasuk connection-acquisition failure serta CORS owner.

## 3. Dependensi dan batas pekerjaan lintas wave

- [T10](task-10-hosting-build-dan-deployment.md) — T10.a / F34 harus aman sebelum build pertama. Ini pekerjaan prasyarat; sisa hosting tetap milik wave-04.

- [T04](task-04-logging-dan-observability.md) — Gunakan satu logger/fallback yang tidak melempar ke HTTP. Bila belum tersedia, buat minimum interface/behavior yang benar-benar diperlukan dan catat untuk wave-02.

- [T05](task-05-request-response-json-dan-waktu.md) — Koordinasikan typed auth parsing dan no secret echo. Jika alur password yang diubah masih menggemakan request, tutup F02 sebagai dependency slice dan catat pada T05; parsing/serializer lengkap tetap wave-02.

- [T06](task-06-database-transaksi-dan-validasi-domain.md) — Permission role milik T01; reference validation serta mutation outcome domain milik T06. Minimum checks/transaction integration yang diperlukan dicatat untuk wave-02.

- [T09](task-09-config-path-dan-persistence.md) — Credential/config harus memakai resolver secret yang konsisten. Jika minimum config/secret reader perlu diubah, catat contract/path untuk wave-03; jangan membuat resolver sementara yang berbeda.

- [T11](task-11-schema-migration-dan-kompatibilitas.md) — Auth schema delta dimiliki T02. Sediakan migration khususnya pada clone dan catat target schema untuk reconciliation wave-04; jangan menunggu legacy guide selesai untuk containment.

Prerequisite slice yang necessary boleh dikerjakan lebih awal dengan owner finding tetap pada task asal. Jangan otomatis menutup seluruh task dependency atau menggandakan owner. Catat scope/evidence agar wave berikutnya tinggal menyelesaikan sisa. Tidak ada wave sebelumnya. Inventarisasi baseline source/toolchain/config sebelum implementation.

## 4. Gate validasi dan deliverable

- [ ] Auth-v2: seluruh endpoint/permission/credential lifecycle pada kontrak wajib diimplementasikan dan diuji, termasuk restricted first-password session, bootstrap, recent auth dan one-use recovery; SQL target tidak menutup acceptance aplikasi. (mandatory gate terbuka; lihat hasil/acceptance B1-B7)

- [x] Dependency minimum logger/parser/config/bounded Sessions diperlukan agar Auth wave-01 aman saat selesai; gunakan satu authority dan catat handoff ke T04/T05/T07/T09, jangan menunda guard/limit wajib sampai wave berikutnya.

- [ ] Seluruh task utama serta acceptance per finding dieksekusi; not-applicable memiliki evidence, unavailable wajib BLOCKED. (mandatory gate terbuka; lihat hasil/acceptance B1-B7)

- [x] Gate build T10.a terbukti aman dan target compiler relevan diuji setelah code changes.

- [ ] Permission matrix ordinary/admin/self/other; salt/legacy hash/CSPRNG audit; refresh reuse/revoke/logout race; bounds/observed metadata/throttling; Bearer/custom/conflict headers; invalid routes; DB unavailable/allocation recovery; raw headers/Unicode dan actual CORS/preflight. (mandatory gate terbuka; lihat hasil/acceptance B1-B7)

- [x] SOURCE/BUILD dipisahkan dari RUNTIME WINDOWS/LINUX, DATABASE dan DEPLOYMENT actual.

- [x] API/config/schema/README/maps yang terdampak serta status task/dependency/indeks/wave sudah diperbarui.

- [x] Laporan akhir disimpan sebagai `wave-01-result.md` saat wave dijalankan, berisi evidence/blocker/handoff.

Setelah wave ini, lanjutkan melalui wave-02.md dengan prompt terpisah dari user.

## 5. Prompt satu shot siap pakai

File prompt terpisah: [prompt-execute-wave-01.md](prompt-execute-wave-01.md). File tersebut berisi prompt lengkap dan dapat langsung diberikan sebagai instruksi eksekusi.

Salin blok berikut sebagai satu permintaan. Alternatif, minta agent menjalankan seluruh instruksi file ini.

```text

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

```

## 6. Perintah singkat untuk menjalankan

```text

Eksekusi seluruh instruksi pada D:\Github\DelphiAPIStarterKit\docs\bugs\wave-01.md dalam satu rangkaian kerja sampai scope selesai atau setiap acceptance yang tersisa mempunyai blocker konkret. Langsung implementasi, validasi, update status dan simpan hasil sesuai file wave.

```

## 7. Catatan eksekusi

Checkpoint berikut mencatat eksekusi; detail seluruh predicate tersedia pada [matrix](evidence/wave-01/acceptance.md). Format catatan:

- Source/commit/working-tree identity dan task/finding yang dikerjakan.

- Changed files, policy/contract/schema delta dan prerequisite slice beserta task owner.

- Check/command/skenario, platform, outcome dan lokasi evidence tanpa secret.

- Acceptance lulus/belum diuji/BLOCKED, blocker/reopening dan next concrete action.

- Dependency handoff serta regression yang wajib dilanjutkan wave berikutnya.

### 2026-10-01 — intake / containment

HEAD 358db33b95724f654db00e39fd4f35dc26c0d12c; dirty baseline preserved. F01 containment denies protected non-self actions until explicit policy lands. T10.a removed image-name taskkill from compile/CloseApp; DPROJ event now harmless. RAD37 toolchain present; Docker engine unavailable. No runtime/DB acceptance closed. Next: actor/policy and auth-v2 lifecycle. Evidence: .ai/runs/wave-01/RUN-STATE.md.

### 2026-10-01 — auth-v2 implementation / Windows integration

Actor/policy, restricted sessions, User/Role delegation, Argon2/CSPRNG, refresh/recovery/revoke, typed auth IO, offline bootstrap and safe HTTP/CORS implemented. New schema auth_rate_limit provides shared DB counters; policy transactions serialize on users.assign_role catalog row before user/session/credential locks. Source SQL extracted into feature repositories.

Win64 Debug builds PASS. 18 Win64 listener/DB groups PASS against isolated MariaDB 11.4.9; latest source extraction requires rerun. Fresh baseline/sample imports and numeric shadow migration PASS; archive credentials revoked. No Linux runtime: Docker/WSL/staging unavailable. Pinned argon2-cffi provider is test-only Win64, not deployment packaging. Next: expanded races/rollback/retention/DB failure/allocation/constraints/restore, other builds and complete evidence/blocker mapping. Raw evidence .ai/runs/wave-01; final durable evidence will be wave-01-result.md.

### Checkpoint — cross-build, transaction and boundary reconciliation

Win64 listener/DB 33 groups, boundary 9 groups, DB/cutover 7 groups PASS on disposable MariaDB 11.4.9.
Core harness: 300 unavailable-schema and 300 pool-exhausted acquisition failures, live allocated delta 0;
actual Argon2 verification mean ~30ms on this Windows host. Actual stopped MariaDB: 300 safe HTTP500,
allowed CORS on error, unknown route404 without DB; same listener recovers after restart.
Win32 Debug and Linux64 Debug cross-build PASS; Linux handle type repaired. Same-name process survived build.
Native Argon2 test dependency is Win64-only; secure DLL dependency search now explicit provider directory/System32.
Schema delta: auth_rate_limit counters and auth_security_event.target_role_id for accurate role audit.
Late audit/validation/ownership edits require final rebuild and rerun before evidence is locked.
API/Auth/User/Role/Postman, config example, migration guide, maps/READMEs updated for intentional cutover.
Next: fresh bootstrap/profile/bounds/recovery race; final source checks, status/evidence matrix/result.
Linux runtime, Win32 native provider, actual client storage/MFA/TLS staging and production migration unavailable.
These remain concrete blockers. Full dependency tasks remain partial and retain existing ownership.

### Checkpoint final — 2026-10-01

Status WAVE-01/T01/T02/T03 **BLOCKED**: semua implementation dan checks independen pada resource tersedia selesai; B1-B7 di hasil wave menyebut reopening spesifik. Tidak ada wave selanjutnya dieksekusi.

Resolver actor/permission kini satu snapshot SQL, >100 permission fail closed; role-code invalid menjadi400. Latest numeric clone migration dan schema equality/restore/re-cutover PASS. Dependency T06 minimum menangani boolean dataset flag dan typed nullable Product FK; positive business create/read/update/delete PASS. Semua unit baru eksplisit DPR; feature-first tetap.

Latest Win32/Win64/Linux64 Debug builds PASS. Win64 listener 33 utama +9 boundary +9 tambahan +6 race +3 business, DB/cutover7, serta DB outage/recovery2 tercatat pada hasil. Core harness300 unavailable-schema +300 pool-exhausted acquisition allocated delta0; cost Argon2 Win64 ~24.45ms. Cross-build tidak menutup runtime Linux. F34 same-name own process survived final builds; wrong-bitness provider startup refused.

API/Postman/config/README/migration/maps, main/dependency task statuses dan indeks direconcile. 82 task predicates +13 auth-v2 acceptance mapped ke evidence/blocker. Artifact/source SHA256 dan sanitized logs di docs/bugs/evidence/wave-01; raw private fixtures tetap ignored .ai/runs/wave-01, bukan deliverable. Baseline dirty preserved, temp-file read-only.

Next/reopening: sediakan matching Win32 native provider/client; host Linux actual; trusted production provider/TLS/proxy/audit grants/retention; actual MFA/client secure storage; production clone inventory/key/timezone/backup; compromised dictionary profile. Jalankan ulang gate terkait tanpa menghidupkan legacy insecure flows. Dependency owner/handoff rinci di [hasil](wave-01-result.md).
