# Hasil WAVE-01 — 2026-10-01

Status **BLOCKED**. Implementation serial T01 → T02 → T03 serta semua checks independen pada resource yang tersedia telah dikerjakan. Acceptance mandatory Win32/Linux dan deployment/client/provider belum seluruhnya tersedia; tidak dihitung lulus. Tidak ada wave lain dijalankan.

Seluruh **82 predicate task** dan **13 acceptance tambahan auth-v2** mempunyai outcome/evidence atau blocker pada [matrix acceptance](evidence/wave-01/acceptance.md). Lampiran F01-F46 tetap baseline historis; checkbox finding yang ditutup tidak menggantikan gate kategori/platform/auth-v2.

## Identity dan baseline

- Repository `D:\Github\DelphiAPIStarterKit`, branch `main`, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`; working-tree implementation, tanpa commit baru.
- Baseline dirty `.gitignore`, DPR/DPROJ/RES, README/README.id, kedua SQL dan untracked orchestration/docs/maps/scripts/deployproj dipertahankan. Snapshot intake lokal `.ai/runs/wave-01/baseline-status.txt` dibuat sesudah containment awal dan safe-build slice; bukan klaim clean baseline. RES/DPROJ existing tidak di-reset.
- Tidak menjalankan reset/clean, tidak menulis `/temp-file/`, tidak mengubah runtime `bin/config.ini`, tidak memakai generated output sebagai source authority.
- Identity source dan artifact final: [SHA256 manifest](evidence/wave-01/manifest.json). Manifest berisi active source/config example/SQL/API/test/build inputs, bukan local secret fixtures. Binaries dan DB clone tetap lokal, tidak masuk deliverable Git.

## Perubahan dan dampak arsitektur

T01 mulai dengan containment F01, lalu memakai satu actor resolver dan `Auth.Policy`. Resolver membaca account/session/role/effective permissions dalam satu snapshot SQL; null/inactive/deleted/missing mapping deny by default, `is_superadmin` tidak bypass. Permission >100 ditolak, bukan dipotong menjadi grant parsial. User/Role service mengulang policy di dalam transaksi. Self ownership, delegation subset, recent reauthentication, self-escalation dan last qualified administrator dilindungi; security transactions memakai urutan policy row → user → session → credential.

T02 memakai OS CSPRNG 32 byte, canonical Base64URL43 dan SHA256 atas decoded credential bytes; UUID hanya identifier publik. Windows memakai BCryptGenRandom, Linux exact-read `/dev/urandom`; failure raise tanpa fallback lemah. Argon2id native provider absolute-path/pinned/self-tested menghasilkan PHC version19, salt16/hash32, m19456KiB/t2/p1. Legacy HMAC verifier hanya menerima format/deadline yang dinyatakan dan rehash setelah verifikasi benar, lalu restricted cutover; deadline default0.

Login/Refresh/Logout/Reauthenticate/LogoutAll/Me/Sessions/revoke-own/CompletePasswordReset, User ChangePassword/reset/provisioning dan Role catalog/grant telah diimplementasikan. Refresh rotation, old-access revoke, idle update dan successor satu transaction; reuse **commit family revocation sebelum401**. Password/recovery/disable/delete/privilege change mencabut credential atomik. Required audit failure rollback; denied audit best-effort tidak mengubah response. Shared DB counters account/origin/global dan KDF admission berlaku sebelum hashing. Observed metadata hanya direct peer/header; forwarded/body metadata tidak menjadi authority.

Admin bootstrap offline tanpa default credential/HTTP registration, explicit20 grants dan replay refusal. Initial-password session restricted900s tanpa refresh dan hanya ChangePassword/Logout. Recovery/setup hash-only, latest one-use/purpose/expiry, issuance tidak mengganti password target; redemption full revoke tanpa auto-login. Generic PUT password dan legacy session_id/device_id-only refresh/logout ditolak.

T03 memakai whitelist route/method/action/signature sebelum DB, Bearer parse hook yang hanya meneruskan header ke resolver, compatible access custom headers dengan conflict rejection. Safe boundary meliputi connection acquisition/allocation/dispatch/WebModule/Indy; logger tidak melempar. Error mengikuti HTTP status/messages/Unix string/data:[{}]. UTF8 bytes melalui owned stream, Content-Encoding kosong; image stream ditransfer sekali. App memiliki exact-origin CORS/preflight, actual request tetap ber-auth. Duplicate/framing/method-override/body-limit rejected sebelum allocation.

Feature-first flat modules tetap. DB access di repositories, business policy di services/policy; Core.Request/Response, TServerConfig, Crypto/Token/Transport dan BFA.Logger menjadi authority bersama. Public helper API dipertahankan kecuali intentional auth-v2 cutover terdokumentasi; tidak ada custom cipher/framework baru atau komentar Pascal baru.

## Finding outcome

| Owner | Finding | Outcome dan batas evidence |
|---|---|---|
| T01 | F01 | CLOSED historical authorization defect: SOURCE + Win64 actual listener/DB ordinary/admin/self/other, business CRUD grants/denials, role/default deny, delegation/last-admin races. Gate Linux kategori tetap B2 |
| T02 | F03 | SOURCE repaired: Linux UUID secret diganti OS RNG; Windows credential path tested. BLOCKED B2 untuk Linux actual RNG/failure/runtime |
| T02 | F04 | CLOSED historical lifecycle defect: rotation/reuse committed revocation/logout race/lost response/expiry E1/E2/E4 |
| T02 | F05 | SOURCE + Win64 salt/vector/legacy/benchmark PASS; BLOCKED B1/B2/B3 untuk kedua OS/provider deployment |
| T02 | F06 | CLOSED: password/redemption/disable/delete full revoke; actual DB failure rollback dan concurrent races E1/E4 |
| T02 | F43 | CLOSED pada consumer repository ini: tidak ada security callsite legacy obfuscation; deprecated prohibition dan strict token decoding E10. External consumers tidak diberikan, tidak diklaim migrated |
| T02 | F44 | CLOSED historical typed-input/metadata defect: N/N+1/type/null/Unicode/whitespace/missing/inactive/wrong password/observed peer E1/E2/E3 |
| T02 | F45 | App-owned direct-peer limiter/admission/retention PASS E1/E2/E5; BLOCKED B3 untuk actual trusted-proxy/deployment policy |
| T03 | F08 | Win64 Bearer/custom/Basic/conflict envelope PASS; BLOCKED B1/B2 untuk Win32/Linux listener mandatory |
| T03 | F09 | CLOSED historical acquisition leak/exposure: actual factory300 unavailable-schema +300 pool exhausted, allocated delta0/recovery; stopped DB300 HTTP safe500/recovery E7/E8 |
| T03 | F24 | CLOSED: unknown version/resource/case policy404 sebelum DB E1/E7 |
| T03 | F25 | CLOSED: explicit route shape/action/method/signature, malformed routes tidak mutasi; 404/405/Allow E1/E2 |
| T03 | F26 | CLOSED: raw UTF8/Unicode/emoji dan PNG bytes/MIME/no Content-Encoding E1/E3 |
| T03 | F37 | App CORS owner/allowlist/OPTIONS/error path PASS; BLOCKED B5/B3 untuk actual browser frontend staging |

9 dari14 finding historis ditutup dalam batas evidence di atas; 5 masih mempunyai gate wajib. **T01/T02/T03 dan wave tetap BLOCKED**, terutama additional auth-v2 production acceptance.

## Evidence per kategori/platform

Raw logs/config/fixtures di ignored `.ai/runs/wave-01`; salinan UTF8 yang disanitasi tersedia di `docs/bugs/evidence/wave-01`. Test scripts membaca secret fixture tanpa mencetak credential. Semua suite serial terhadap latest final Win64 binary; core harness memakai actual current Crypto/DBFactory, bukan mock. Prior/interrupted logs tidak dipakai sebagai final PASS.

| ID | Kategori | Actual check / outcome | Evidence |
|---|---|---|---|
| E1 | RUNTIME_WINDOWS Win64 + DATABASE | 33 main groups +3 positive business groups PASS: permission, credential/ownership/TTL, flags, Unicode, explicit grants, role mutation and stored state | [main](evidence/wave-01/runtime-win64-final.log), [business](evidence/wave-01/business-final.log); scripts/test-wave01.py and test-wave01-business.py |
| E2 | RUNTIME_WINDOWS Win64 + DATABASE | 9 boundary groups PASS: raw duplicate/framing/override, cap before allocation, business deny matrix, origin60/61/global300/301, audit rollback/logger failure, lost refresh response | [boundary](evidence/wave-01/boundary-final.log); scripts/test-wave01-boundary.py |
| E3 | RUNTIME_WINDOWS Win64 + DATABASE | 9 extra groups PASS: fresh CLI bootstrap/replay/different CWD, provider pin/profile failure, canonical token persistence, exact Unicode/body bounds, recovery race, inactive/deleted generic401, actual PNG ownership/bytes | [extra](evidence/wave-01/extra-final.log); scripts/test-wave01-extra.py |
| E4 | RUNTIME_WINDOWS Win64 + DATABASE | 6 race groups PASS: password vs refresh, disable vs refresh, redemption vs old login, reset vs disable, delegation vs privilege removal, permission101 fail closed | [races](evidence/wave-01/races-final.log); scripts/test-wave01-races.py |
| E5 | DATABASE MariaDB11.4.9 Win64/InnoDB | 7 groups PASS: fresh schemas equal numeric clone, no credential seeds, FK/CHECK/unique/cross-family constraints, restore/re-cutover, bootstrap refusal, bounded retention, legacy effective-key rehash | [database](evidence/wave-01/database-final.log); scripts/test-wave01-database.py |
| E6 | BUILD | RAD Studio37.0 Debug Win32/Win64/Linux64 PASS via safe compile.bat. Linux cross-build uses installed Ubuntu24.04 SDK; does not prove runtime | [Win32](evidence/wave-01/build-final-win32.log), [Win64](evidence/wave-01/build-final-win64.log), [Linux64](evidence/wave-01/build-final-linux64.log) |
| E7 | RUNTIME_WINDOWS + DATABASE | Actual own disposable MariaDB stopped: 300 safe HTTP500, no-store/allowed CORS, unknown route404; same listener login recovers. Latest numeric shadow migration driver PASS | [outage](evidence/wave-01/db-outage-final.log), [migration](evidence/wave-01/migration-final.log) |
| E8 | RUNTIME_WINDOWS Win64 native/core + DATABASE | Argon2 vector/salts/Unicode/wrong password PASS; verify mean24.45ms on host. 300 unavailable-schema and300 pool-exhausted actual FireDAC acquisition failures each live allocated delta0; DB/pool recovery PASS | [core](evidence/wave-01/core-tests.log); scripts/Wave01CoreTests.dpr |
| E9 | BUILD process safety | PID+absolute-path verified own same-name executable survived final three platform builds; latest Win32 refused Win64 provider with nonzero exit | [survival](evidence/wave-01/f34-process-survival.log), [bitness gate](evidence/wave-01/win32-provider-gate.log) |
| E10 | SOURCE / documentation | Active secret call-path/legacy consumer/Postman/comments audit, diff check, package validator, sanitized evidence scan and SHA256 identity | [source](evidence/wave-01/source-checks.log), [verification](evidence/wave-01/verification.log), [manifest](evidence/wave-01/manifest.json) |

Total **69 listener/database scenario groups** PASS termasuk outage/recovery, ditambah native/core checks; ini bukan69 unit tests atau Linux proof. Actual allocation0 adalah factory harness failure scope, bukan total HTTP-process heap assertion. Cost24.45ms adalah local Win64 verification benchmark, bukan throughput/production sizing.

Test DB hanya `wave01_*`, bind127.0.0.1:19306, dedicated fixture user, MariaDB11.4.9 official portable archive SHA256 `802f9f40a9dca774a3ba62f39c21093942954f178d6d7d458dc51453929bcdda`. Win64 listener port19001, configured origin `https://wave-client.example`, password-only/direct-peer test profile. Native provider adalah pinned official argon2-cffi-bindings `_ffi.pyd` beserta Python3.10 runtime dependencies untuk test saja; tidak dinyatakan package deployment.

## Files changed dan owner

| Owner/slice | Files |
|---|---|
| T01/T02 feature auth | sources/modules/auth/Auth.Repository.pas, Auth.Service.pas, Auth.Validator.pas; new Auth.Policy.pas, Auth.Settings.pas, Auth.Bootstrap.pas |
| T01/T02 users | sources/modules/users/User.Service.pas, User.Repository.pas, User.Validator.pas, User.DTO.pas |
| T01 roles | new sources/modules/roles/RestAPI.Role.pas, Role.Service.pas, Role.Repository.pas, Role.Validator.pas |
| T03 security/core/app | new infrastructure/security/BFA.Security.Crypto.pas and BFA.Security.Transport.pas; BFA.Security.Token.pas; DB.ConnectionFactory.pas; Core.Endpoint/Helper/Rest; App.WebModule.pas/.dfm; DPR |
| T04 minimum | new sources/infrastructure/logging/BFA.Logger.pas; Auth.Repository audit helper and safe shared callers |
| T05 minimum | sources/core/BFA.Core.Request.pas, BFA.Core.Response.pas; User/Auth typed outputs; no request echo |
| T06 minimum | User/Role repositories/validators; sources/modules/category/Category.Service.pas, customers/Customer.Service.pas, products/Product.Service.pas and Product.Repository.pas boolean/nullable binding compatibility |
| T07/T08/T09 minimum | Auth/User/Role bounded queries; App image stream transfer; Core.Config and shared/helpers/BFA.Helper.Strings.pas consistent secret/config reader and legacy deprecation |
| T10.a | compile.bat and CloseApp.bat; existing DPROJ prebuild becomes harmless through wrapper. DPR minimum startup/provider fail-closed and CLI integration |
| T02 schema / T11 reconciliation | both assets/databases/demo_delphirest*.sql; new auth-v2-upgrade-numeric-20261001.sql; scripts/migrate-auth-v2-clone.py; docs/databases/auth-v2-cutover.md |
| Contracts/maps/checks | config.example.ini; README/README.id; docs/api/auth/users/roles/business/Postman; docs/information/structure.md; project-map.md; scripts/test-wave01*.py, Wave01CoreTests.dpr; task/dependency/index/wave/result/evidence docs |

Unrelated original `.gitignore`, RES/DPROJ/package files remain dirty. Change inventory is a scoped account of this execution, not attribution of every pre-existing diff to WAVE-01. Exact files/hashes are in manifest.

## Compatibility dan migration

- Standard envelope dan public User `role_id` integer/null dipertahankan; Role route memakai UUID publik dan catalog `legacy_role_id` numeric. Expiry integers/flags Boolean, no-store/no request echo intentional client cutover.
- Client harus mengganti legacy refresh/logout payload dengan explicit opaque credential, memakai refresh single-flight, login ulang setelah lost-response/reuse/full revoke, dan mendukung restricted initial password/recent auth/recovery one-use. Temporary-password response dan generic PUT password tidak disediakan sebagai fallback.
- Fresh baseline dan withdatasample adalah **alternatif import DB kosong**, tidak berisi user/credential bawaan, bukan migration, tidak compatible source Pascal auth lama.
- Dedicated shadow upgrade hanya untuk declared numeric legacy HEAD schema pada clone. Driver preflight schema/UUID/hash/collation/counts, backfill `role_code`/UTC/`idle_expires_at`/password metadata/restricted flag, revoke legacy credentials, swap atomik dan retain archives. Recovery/restore tidak menghidupkan credential lama. E5/E7 membuktikan synthetic MariaDB clone, bukan produksi.
- Auth schema delta wave ini `auth_rate_limit` shared counters dan nullable `auth_security_event.target_role_id`. Credential lifecycle/audit authority tetap Auth repository; full migration provider/legacy-guide reconciliation T11.

## Blocker mandatory dan reopening

| ID | Resource/acceptance yang belum tersedia | Kondisi reopening konkret |
|---|---|---|
| B1 | Matching trusted native Argon2 + client package Win32 unavailable; build PASS dan wrong64 provider refusal, tanpa Win32 auth listener integration | Supply pinned reviewed x86 provider/runtime + x86 MariaDB client; jalankan seluruh Bearer/policy/lifecycle/DB matrix pada Win32 |
| B2 | Actual Linux runtime host/provider/client unavailable: Docker engine pipe absent, WSL not installed, tidak ada staging Linux supplied | Supply accessible Linux host dengan compatible pinned Argon2/libmariadb/UTC/schema; uji RNG/failure/Argon cost/listener/CORS/concurrency/recovery, bukan cross-build |
| B3 | Production package/provider ABI/pins/ACL/TLS/proxy/service DB grants/limiter/audit retention policy belum diberikan; direct-peer local profile saja tested | Supply chosen actual deployment/identity/origin/proxy configuration dan native dependency manifest; verifikasi resolution/TLS/trust/source-spoofing/grants/retention/readiness |
| B4 | MFA provider/enrollment/challenge/recovery/administrative deployment policy belum tersedia. Unsupported MFA profile startup ditolak; authenticated_at bukan faktor kedua | Supply chosen provider + enrollment/challenge/recovery/client integration pada staging; no full token sebelum required factor succeeds |
| B5 | Actual FMX/browser client secure storage/refresh single-flight/CSRF/HTTPS/frontend staging tidak supplied | Supply actual clients/storage implementation dan staged frontend; uji token storage/refresh loss/logout/recent flow dan browser allowed/disallowed CORS |
| B6 | Production legacy inventory/effective HMAC key/timezone/backups/source-version/DB provider clone tidak supplied | Supply disposable representative production clone + declared versions/effective key/UTC policy/backup restore evidence; run supported versioned cutover/regression/restore. Tidak menjalankan migration produksi |
| B7 | Configured maintained compromised-password dictionary/deployment password policy belum supplied. Built-in common blocklist/bounds tested; optional absolute UTF8 dictionary reader tersedia | Provision reviewed common/compromised dataset/path/ACL/update policy, benchmark bounded validation/dependency failure dan credential-policy integration pada chosen deployment |

## Residual risks dan handoff

| Owner berikut | Implementation yang wajib dipakai | Sisa scope |
|---|---|---|
| T04 / wave-02 | Non-throwing BFA.Logger + required Auth audit transaction | Full exception context/redaction/correlation, sink concurrency, least DB grants/retention/deployment; F10/F23 masih terbuka globally |
| T05 / wave-02 | Core.Request typed Auth/User/Role + typed JSON/no-store/no echo; **F02 closed** | Generic dataset number/string/array serializer/parser dan full locale/date-only clock matrix; jangan kembali request echo atau heuristic auth types |
| T06 / wave-02 | User/Role validation/security transaction/readback; business Boolean flag and typed nullable Product FK | Full domain soft-delete/unique/authoritative concurrent mutation/price/reference tests; slice minimum tidak menutup seluruh task |
| T07 / wave-03 | Owned Sessions/User/Role bounded pages dan permission101 deny | Business large collections/fetch/traversal/capacity and offline-overbound Role catalog completeness |
| T08 / wave-03 | Image stream transfer ownership/MIME | F07 memory-manager concurrent/error/disconnect remains; `/test` unauthenticated upload F14 and F38 storage/path/download remain. Whole repository belum production-ready |
| T09 / wave-03 | Single TServerConfig path/raw secret authority + typed security config | Concurrent save/ACL/provider paths/full strict config/dictionary; tracked bin/config.ini **F46 remains**, local file deliberately preserved |
| T10 / wave-04 | **F34 closed**, safe compile; minimum startup provider failure/nonzero/port/VendorLib | Native production packages/readiness/schema/TLS/supervisor/graceful drain/platform artifact separation F41. Test artifacts isolated manually; repo output policy belum selesai |
| T11 / wave-04 | Versioned numeric shadow clone migration + auth schema delta + retained revoked archive restore | Full declared legacy/provider/production clone/guide reconciliation and operational cutover; fresh SQL tidak boleh dianggap upgrade |
| T12 / wave-04 | Existing shared authorities + feature-first modules | Facade/registry/dependency review sesuai actual consumers; jangan menduplikasi parser/config/logger/auth predicate |

Dependency T04-T11 berstatus **BERJALAN**, bukan SELESAI; finding owner tidak dipindah. Gates eksternal di atas tidak diberi insecure fallback. Review terakhir dilakukan serial oleh agent yang sama: resolver snapshot, unknown permission400, typed nullable fields, transaction revocation, ownership dan platform builds direconcile; tidak diklaim independent review. Tidak ada blocking defect executable baru tersisa pada perubahan auth/transport yang ditinjau; limitation platform/deployment dan residual task lain tetap seperti tabel di atas.

Tidak ada production DB/state/deployment diubah. Fixtures dan test DB tersedia lokal untuk reopening; proses test milik chat dihentikan dengan PID+absolute-path verification setelah evidence dikunci. Langkah berikutnya adalah membuka gate B1-B7 dengan resource actual, kemudian menjalankan regression terkait; wave lain memerlukan instruksi tersendiri.
