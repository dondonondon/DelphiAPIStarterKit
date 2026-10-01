# WAVE-02 — Logging, typed JSON, dan correctness database

Status: **BERJALAN**. Task utama: **T04, T05, T06**. Temuan utama: **14**. Tanggal: **1 Oktober 2026**.

Navigasi: [indeks wave](waves-windows-linux-2026-10-01.md) · [indeks task](review-tasks-windows-linux-2026-10-01.md) · [review lengkap](full-review-windows-linux-2026-10-01.md).

**Revisi dependency Auth:** [kontrak auth-v2](auth-production-contract-2026-10-01.md) wajib untuk task utama dan
regression lintas wave. SQL target sudah ditulis; endpoint Pascal/migration/runtime tetap acceptance
terpisah. Gunakan hasil prerequisite yang terbukti dan jangan memulihkan legacy insecure contract.

## 1. Tujuan dan cakupan

Satukan logger, tutup password echo dan kerusakan tipe/nilai JSON, lalu selaraskan validation/transaksi/constraint dengan stored state.

Satu shot berarti satu prompt untuk seluruh scope wave, termasuk implementation, checks, status dan handoff. Bukti eksternal yang belum tersedia tetap BLOCKED; tidak diasumsikan lulus. File ini baru paket eksekusi, belum menjalankan task.

| Task utama | Kategori | Finding owner utama | Status |
|---|---|---|---|
| [T04](task-04-logging-dan-observability.md) | Logging, observability, dan preservasi exception | F10, F23 | BELUM DIMULAI |
| [T05](task-05-request-response-json-dan-waktu.md) | Request/response JSON, tipe data, dan waktu | F02, F11, F15, F16, F17, F22, F27 | BELUM DIMULAI |
| [T06](task-06-database-transaksi-dan-validasi-domain.md) | Database, transaksi, dan validasi domain | F18, F19, F20, F21, F42 | BELUM DIMULAI |

## 2. Urutan internal

**T04 → T05 → T06** setelah gate T10.a/F34 aman untuk build. Urutan internal boleh berbeda dari nomor task untuk mengikuti dependency.

- [ ] Reconcile dependency slices dari wave-01 terlebih dahulu. Jangan menimpa actor/auth/error behavior yang sudah diperbaiki; sempurnakan logger T04.
- [ ] Tutup F02 lebih dahulu bila belum selesai, lalu kerjakan parser/serializer typed, field role_id compatible serta clock UTC T05.
- [ ] Kerjakan T06 setelah nilai input dijaga: unique conflicts, authoritative mutation outcomes, role bounds/references, DECIMAL(15,2) dan category soft-delete policy.

## 3. Dependensi dan batas pekerjaan lintas wave

- [T01](task-01-authorization-dan-permission.md) — Gunakan permission policy hasil wave-01; jangan menganggap reference role existing sudah cukup untuk authorization.
- [T02](task-02-authentication-password-dan-session.md) — Pertahankan hash/revoke/refresh contract dan satu transaction scope password. Revalidasi auth bila parser/mutation helpers berubah.
- [T03](task-03-http-routing-dan-error-boundary.md) — Pakai safe HTTP boundary dan envelope yang sama; parser hanya satu kali dan logger failure tidak mengganti status/body.
- [T09](task-09-config-path-dan-persistence.md) — Logger memakai satu resolved log root/config contract; minimum sink/path dependency dicatat untuk wave-03 tanpa membuat authority tandingan.
- [T07](task-07-collection-pagination-dan-kapasitas.md) — Serializer dipakai pagination/fetch pada wave-03; typed serializer tidak boleh mengandalkan RecordCount atau merusak fix row completeness yang mungkin telah ada.
- [T11](task-11-schema-migration-dan-kompatibilitas.md) — Catat schema delta UNIQUE/reference/nullability serta target name/type untuk final migration reconciliation wave-04.

Prerequisite slice yang necessary boleh dikerjakan lebih awal dengan owner finding tetap pada task asal. Jangan otomatis menutup seluruh task dependency atau menggandakan owner. Catat scope/evidence agar wave berikutnya tinggal menyelesaikan sisa. Baca catatan hasil wave-01 yang sudah dijalankan. Validasi dependency yang dipakai dari source dan evidence actual; status BLOCKED yang tidak terkait tidak menghentikan pekerjaan independen.

## 4. Gate validasi dan deliverable

- [ ] Auth-v2: audit allowlist/append-only/retention/grants, typed expiry/Boolean/credential issuance/no-store/no-echo serta UTC diuji tanpa mengembalikan HMAC password lama/temporary_password/request echo.
- [ ] Perubahan domain/mutation helpers mempertahankan password/revoke/recovery transaction, default must_change_password restriction, role reference/delegation dan last-admin protection; auth regressions terdampak dijalankan kembali.

- [ ] Seluruh task utama serta acceptance per finding dieksekusi; not-applicable memiliki evidence, unavailable wajib BLOCKED.
- [ ] Gate build T10.a terbukti aman dan target compiler relevan diuji setelah code changes.
- [ ] Failing/concurrent/rotating logger; safe exception/rollback context dan secret scan; strict JSON/string/Int64/decimal/null/array/input limits; UTC/Jakarta; role_id name/type; duplicate/concurrent create dan update-delete barrier; role/money boundaries serta reference policy.
- [ ] SOURCE/BUILD dipisahkan dari RUNTIME WINDOWS/LINUX, DATABASE dan DEPLOYMENT actual.
- [ ] API/config/schema/README/maps yang terdampak serta status task/dependency/indeks/wave sudah diperbarui.
- [ ] Laporan akhir disimpan sebagai `wave-02-result.md` saat wave dijalankan, berisi evidence/blocker/handoff.

Setelah wave ini, lanjutkan melalui wave-03.md dengan prompt terpisah dari user.

## 5. Prompt satu shot siap pakai

File prompt terpisah: [prompt-execute-wave-02.md](prompt-execute-wave-02.md). File tersebut berisi prompt lengkap dan dapat langsung diberikan sebagai instruksi eksekusi.

Salin blok berikut sebagai satu permintaan. Alternatif, minta agent menjalankan seluruh instruksi file ini.

```text
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
```

## 6. Perintah singkat untuk menjalankan

```text
Eksekusi seluruh instruksi pada D:\Github\DelphiAPIStarterKit\docs\bugs\wave-02.md dalam satu rangkaian kerja sampai scope selesai atau setiap acceptance yang tersisa mempunyai blocker konkret. Langsung implementasi, validasi, update status dan simpan hasil sesuai file wave.
```

## 7. Catatan eksekusi

Belum ada eksekusi atau evidence wave. Saat dijalankan, catat setelah setiap task:

- Source/commit/working-tree identity dan task/finding yang dikerjakan.
- Changed files, policy/contract/schema delta dan prerequisite slice beserta task owner.
- Check/command/skenario, platform, outcome dan lokasi evidence tanpa secret.
- Acceptance lulus/belum diuji/BLOCKED, blocker/reopening dan next concrete action.
- Dependency handoff serta regression yang wajib dilanjutkan wave berikutnya.

### Checkpoint T04 - 2 Oktober 2026

T04 F10/F23 implementation: single Config.LogFile root, logger UTC/correlation/rotation/retention/fallback, endpoint owner failure log, rollback preserves initial exception, Audit allowlist and same correlation. Changed Config/Logger/Clock/Transaction/Auth.Repository/App.WebModule/business Service/DPR/config example plus observability docs/tests. T09 minimum resolved-root slice, T10 F34 reverified; owners retained.

BUILD Win64 Debug RAD37 PASS; actual native600 concurrent logger + rollback fault PASS. Actual Win64/MariaDB11.4.9 listener200 parallel failures/read-only sink safe500, one log per correlation, required audit rollback, INSERT-only app grant and bounded separate90d audit maintenance PASS. Raw evidence `.ai/runs/wave-02/build-t04-win64.log`, `core-t04.log`, `logging-t04.log`. Actual quota-full volume, Linux/runtime identity and production ACL/retention/collector remain BLOCKED; no closure inferred. Next T05 strict single parser/typed dataset and UTC field policy; no auth lifecycle rewrite.

### Checkpoint T05 - 2 Oktober 2026

T05 preserves F02 no-echo/no-store and auth-v2. Core.Request is one bounded strict parser (single DOM parse, pre-allocation depth scan, field/duplicate/Unicode validation), structured400/413/415. Business object bodies are converted directly to typed dataset once. Int64/BCD preserve exact values; unsupported exponent/overflow/precision explicitly rejected. Generic strings never inferred as JSON/numbers. Array helper uses name union, missing/null/type-conflict policy. Typed FieldValue shared by Auth.JSONRows and Response; EOF loop preserves real incremental fetch. Category/Product typed DTO methods preserve older helper signatures; FireDAC WideString binding fixes actual emoji corruption. DATETIME UTC ISO8601 + string unix, date-only no epoch; singleClock UTC.

BUILD Win64 PASS; native en-US/id-ID strict Int64/decimal/string/null/array/UTC/DST + actual SQLite/FireDAC2500 rows rowset7 PASS (`core-t05.log`). Actual Win64/MariaDB typed business CRUD/invalid body and no mutation/role_id integer-null/restricted session415/413 PASS (`json-t05.log`). Client integration/LINUX/actual second host timezone remain BLOCKED; runtime source claims bounded. T07 minimum EOF slice remains owner T07 BERJALAN; T03 status/media propagation dependency reused. Next T06 reserved names, lock/revalidate/readback, DECIMAL15,2 and category reference policy; then full affected auth regression and final platform builds.
