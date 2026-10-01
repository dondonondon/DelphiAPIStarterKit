# Kontrak target sample Auth production — auth-v2

Revisi: **1 Oktober 2026, Asia/Jakarta**. Owner implementasi: [T01](task-01-authorization-dan-permission.md),
[T02](task-02-authentication-password-dan-session.md), [T03](task-03-http-routing-dan-error-boundary.md).
Owner migration: [T11](task-11-schema-migration-dan-kompatibilitas.md).

**Status: implementasi Pascal auth-v2, endpoint dan clone migration tersedia; acceptance production BLOCKED.** Dokumen ini tetap authority target; kontrak API implementasi berada di docs/api. Evidence dan gate terbuka ada di [hasil WAVE-01](wave-01-result.md).
Lampiran F01–F46 dan laporan lengkap tetap bukti historis source sebelum perbaikan.

## 1. Scope dan keputusan

- Baseline akun dikelola admin; tidak ada registrasi publik, email verification atau forgot-password publik.
  Schema saat ini tidak mempunyai email user terverifikasi. Penambahan layanan tersebut memerlukan scope,
  alamat terverifikasi, delivery provider, dan acceptance terpisah; jangan membuat endpoint sukses semu.
- Pertahankan feature-first, numeric internal PK/FK, public UUID, satu role nullable per user, dan public
  field legacy `role_id` integer. UUID role tidak menggantikan field integer tanpa migration kontrak.
- Stateful opaque access/refresh tokens; tidak menambah JWT/OAuth/SSO framework. Tidak mengklaim kepatuhan OAuth.
- Semua waktu auth dan connection DB memakai UTC. Semua token dibuat dari 32 byte CSPRNG OS lalu Base64URL
  tanpa padding (43 karakter); public UUID/session_id/device_id tidak menjadi credential.
- Access token default 900 detik; absolute session 604800 detik; idle session 86400 detik; recovery/setup
  token 900 detik; recent reauthentication 300 detik. Nilai configurable dan divalidasi saat startup.
  Expiry access/refresh selalu dibatasi expiry session/idle. Refresh memperbarui idle expiry dengan
  `min(now + idle_timeout, session.expires_at)`, tanpa memperpanjang absolute expiry.
- Access token lama dicabut dalam transaksi refresh sukses. Client harus melakukan satu refresh in-flight
  per session. Reuse token consumed mencabut seluruh keluarga session, termasuk access token baru; tidak
  ada fallback silent retry/legacy refresh atau grace window yang menerima credential lama.
- ChangePassword, recovery redemption, admin disable/delete dan security reset yang selesai mencabut
  seluruh session/credential target atomik; login kembali. Role/permission mutation divalidasi kembali
  pada request berikutnya; cabut session affected users pada perubahan privilege yang sensitif.

## 2. Schema authority dan import

Target DDL ada di [demo_delphirest.sql](../../assets/databases/demo_delphirest.sql); sample full import ada di
[demo_delphirest_withdatasample.sql](../../assets/databases/demo_delphirest_withdatasample.sql).
Keduanya alternatif instalasi pada database kosong, bukan dijalankan berurutan. Import berhenti pada error;
jangan gunakan client `--force`. Tidak ada DROP/IF NOT EXISTS/FOREIGN_KEY_CHECKS=0 yang menyembunyikan mismatch.
DDL MySQL melakukan implicit commit; jika import gagal, inspeksi database test dan recreate database test
secara eksplisit sebelum retry. Target provider MySQL 8.0.16+ / MariaDB 10.6+; enforcement CHECK dan FK wajib
diuji pada versi deployment. Firebird/SQL Server belum didukung oleh SQL ini.

| Tabel | Authority / aturan |
|---|---|
| users | Hash ASCII binary versioned, password_changed_at, must_change_password, status, role FK; username tetap unik termasuk soft-deleted, normalisasi username terdokumentasi mengikuti collation existing |
| m_role | Public UUID, role_code stabil, status. is_superadmin dipertahankan untuk kompatibilitas metadata; tidak memberi bypass permission/ownership/reauthentication |
| m_permission | Catalog permission_code case-sensitive dan status; tidak menerima permission arbitrary dari body |
| role_permission | Mapping eksplisit dengan composite PK dan FK; role/permission inactive tidak memberi akses |
| user_session | Public session ID, observed metadata, authenticated_at untuk recent-auth, last_seen_at, idle_expires_at, absolute expires_at, revoked_at/reason |
| access_token | Unique hash lookup, session FK, expiry/revocation; token mentah tidak disimpan |
| refresh_token | Unique hash, consumed_at, successor dalam session sama via composite self-FK, expiry/revocation; session adalah family identifier |
| password_reset_token | Hash sekali pakai, purpose password_reset/account_setup, target dan issuer, expiry/consumption/revocation |
| auth_security_event | Append-only event metadata allowlist, actor/target public IDs, correlation, observed IP, outcome; tanpa body/message bebas/secret. Tidak memakai cascading FK supaya audit bertahan setelah account cleanup |

Hash token baseline adalah SHA-256 hexadecimal lowercase atas credential CSPRNG yang sudah di-decode dan
divalidasi formatnya; service menggunakan satu format konsisten. Fast hash cocok untuk high-entropy token,
bukan password. Jika memakai keyed hash tambahan, key version/rotation harus dirancang eksplisit dahulu.
TTL/cross-table state, satu token aktif, UUID/token format, role delegation, dan audit append-only wajib
ditegakkan service/repository/DB grants; keberadaan kolom/index/CHECK bukan bukti policy sudah berjalan.
Revoke menulis revoked=1, revoked_at dan reason bersama; validator menggunakan revoked sebagai authority.
Invariant successor hanya untuk token consumed ditegakkan dalam transaction service. CHECK tidak mengacu
kolom foreign-key referential action untuk menghindari pembatasan MySQL; composite FK tetap membatasi
successor ke session yang sama. Uji invariant konsumsi token dan cleanup melalui repository nyata.

Baseline hanya DDL. Sample menyertakan role admin/user dan 20 permission eksplisit serta data business
demo existing; user hanya mendapat roles.read dan read products/customers/category. Tidak ada wildcard atau
superadmin bypass. Tidak ada users/access_token/user_session/refresh_token/password_reset_token seeded.
Permission catalog/role policy pada fresh baseline diprovision offline dari daftar versioned yang sama;
bootstrap admin pertama memakai input interaktif/environment aman tanpa password pada command line/log.
Bootstrap fail closed jika admin sudah ada dan tidak otomatis dibuka sebagai endpoint HTTP.

## 3. Password dan provisioning

Argon2id melalui provider/library terpelihara dengan known-answer tests Windows/Linux; minimum awal
m=19456 KiB, t=2, p=1, salt CSPRNG minimal 16 byte. Simpan PHC representation (algorithm, version, cost,
salt, hash) dalam password_hash. Benchmark biaya dan admission control pada target; tidak membuat custom
KDF/cipher. Jika provider belum tersedia, acceptance BLOCKED; jangan fallback otomatis ke HMAC cepat.
Legacy HMAC hanya verifier migration dengan old key yang aman dan deadline; rehash setelah autentikasi
benar. Jangan mengubah format hash melalui SQL dan jangan rehash password berdasarkan hash lama saja.

Password tidak di-trim/dipotong. Definisikan batas 15–128 Unicode codepoints untuk create/change/recovery
baseline tanpa MFA, max UTF-8 bytes/body terpisah, dan blocklist password umum/compromised; jangan
mensyaratkan pola komposisi yang menggantikan panjang/blocklist. Login legacy mempertahankan verifier
dan batas legacy selama migration window, tanpa diam-diam menerapkan normalisasi baru.

Create user admin dapat menerima initial password terkontrol (tidak di-echo), atau menerbitkan credential
account_setup: simpan hash password acak CSPRNG yang tidak dikirim/disimpan mentah untuk akun pending.
must_change_password default 1. Login dengan initial password hanya memberi session terbatas untuk
ChangePassword/Logout; tidak boleh mendapat business/admin access sampai password diganti. Session
terbatas ini maksimal 900 detik dan tidak menerbitkan refresh token; refresh_expires_in=0 dan refresh_token
tidak hadir pada response. Client memakai password_change_required=true untuk membuka change flow. Redemption
account_setup/password_reset menetapkan hash baru, must_change_password=0, password_changed_at=now dan
revoke seluruh credential target dalam satu transaksi; tidak auto-login. Normal self-change menyetel
flag 0. Bootstrap admin memilih password sendiri dan secara eksplisit menyetel flag 0.

## 4. Endpoint target dan permission

Semua route di bawah berada di `/api/v1`; implementasi/docs/API Postman wajib di-update bersama ketika
endpoint benar-benar diimplementasikan. Seluruh error mempertahankan status/messages/servertime/data:[{}],
status JSON = HTTP. Empty success data = []; expires_in/refresh_expires_in adalah JSON integer detik,
token_type = Bearer. Credential responses memakai Cache-Control: no-store; tidak ada request_detail echo.

| Method / route | Credential / request penting | Policy / result |
|---|---|---|
| POST /Auth/Login | username, password, device_id; device_name optional | Generic 401 untuk missing account/inactive/deleted/wrong password; 400 untuk bentuk invalid; 429 limiter. Success access_token, refresh_token, token_type, expires_in, refresh_expires_in, session_id, password_change_required; restricted session tidak mendapat refresh_token |
| POST /Auth/Refresh | refresh_token string; tidak memerlukan access token expired | Consume/rotate atomik; active account/session/idle/absolute checks; success pasangan token baru dan metadata yang sama; invalid/reuse 401, reuse revokes family |
| POST /Auth/Logout | Access token untuk current session, atau refresh credential milik session saat access expired | Tidak menerima session_id/device_id sebagai bukti. Credential/hash yang dikenal dapat memberi revoke idempotent 200; unknown credential generic 401; tidak mengungkap pemilik |
| POST /Auth/Reauthenticate | Access token + current password, dan faktor tambahan sesuai profile | Verifikasi ulang actor; jangan membuat session baru atau memperpanjang absolute TTL; update authenticated_at; no password/token echo |
| POST /Auth/LogoutAll | Access token + recent authentication | Revoke seluruh session actor termasuk session saat ini; 200 empty |
| GET /Auth/Me | Access token | Identitas actor, role legacy identifier dan permission efektif; bukan credential/hash |
| GET /Auth/Sessions | Access token; pagination bounded | Session actor saja, metadata observed dan expiry; tidak mengembalikan hash/token/internal IDs |
| DELETE /Auth/Sessions/{session_id} | Access token | Ownership; unknown/other session 404, own revoke idempotent 200; boleh revoke current session |
| POST /User/ChangePassword | Access token + old_password + new_password | Self actor dari resolver; tidak menerima target privilege dari body; transaction hash update + full revoke; 200 empty |
| POST /User/{user_id}/ResetPassword | Access token + recent auth + confirm_reset=true | users.reset_password + target/delegation policy; issue reset_token satu kali, expires_in, public target ID; bukan temporary_password; belum mengubah password/revoke target saat issue |
| POST /Auth/CompletePasswordReset | reset_token + new_password | Credential terbatas sesuai purpose; consume atomik, set password, revoke sesi/token dan recovery outstanding, 200 empty; tanpa login otomatis |
| GET /User[/{user_id}] | Access token | users.read; paginated collection; ordinary user memakai /Auth/Me untuk dirinya |
| POST /User | Access token + validated create DTO | users.create; role assignment juga users.assign_role dan batas delegation; initial password tidak di-echo |
| PUT /User/{user_id} | Access token + fullname/status/role DTO | users.update; role membutuhkan users.assign_role; generic password mutation ditolak 400 dan diarahkan ke ChangePassword/recovery |
| DELETE /User/{user_id} | Access token + recent auth | users.delete + target policy; soft-delete dan full revoke atomik; lindungi admin terakhir |
| GET /Role | Access token | roles.read; catalog tanpa privilege mutation otomatis |
| PUT /Role/{role_id}/Permissions | Access token + recent auth + bounded permission codes | roles.manage + delegation; role_id path UUID publik. Tidak boleh self-escalation, grant di luar delegable permissions, atau menghapus admin terakhir |

Actor dibentuk dari satu resolver auth repository: user/session/token status, expiry, role status, dan
effective permission. Repository tidak mengenal HTTP; endpoint memilih action/policy whitelist sebelum
sensitive query/mutation. Own profile/session actions tetap memerlukan ownership walaupun memiliki role admin.
Product/Customer/Category CRUD mengikuti permission `<resource>.<read|create|update|delete>` yang sama.
Perubahan mapping/role assignment dan proteksi admin terakhir diserialisasi di transaction agar dua request
bersamaan tidak menghilangkan semua administrator. is_superadmin tidak memberi pengecualian aturan ini.

Reset/setup credential hanya ditampilkan sekali kepada admin berwenang lewat no-store HTTPS untuk
penyerahan melalui saluran terkontrol setelah identitas penerima diperiksa. Jangan masukkan credential ke
URL/log/Postman saved values/audit. Tidak mengirim email seolah integrasi tersedia. Pending token terbaru
mencabut recovery token pending sebelumnya untuk target/purpose yang sama, tanpa mengganti password atau
mencabut session target sebelum redemption valid. Token tidak dapat digunakan sebagai normal access token.

## 5. Transaksi, concurrency, dan retention

Urutan lock bersama: user -> session -> credential. Verifikasi password mahal dilakukan di luar lock,
kemudian versi/hash/password_changed_at dan status diperiksa kembali di transaction sebelum issuance.
Role/policy sensitive mutations menggunakan lock authority yang sama agar check tidak terpisah dari write.
Refresh lock/consume/insert/revoke access/update idle/commit satu transaction. Logout, disable, password
mutation dan refresh memakai urutan lock sama. Reuse detection harus COMMIT revoke family sebelum
return 401; jangan rollback revocation karena response error. Dua refresh paralel dengan token sama:
satu dapat melakukan rotation, request kedua mendeteksi reuse dan mencabut family; tidak ada dua chain aktif.

Response token hanya dikirim setelah commit. Jika response refresh hilang, client login kembali; jangan
menerbitkan ulang secret successor dari hash. Startup/random/hash/DB failure fail closed dan menghasilkan
safe error. Logging failure tidak merusak response dan tidak membuka akses.

Retention refresh chain dipertahankan sampai session absolute expiry plus audit/replay retention policy.
Cleanup dibatasi batch/index dan tidak menghapus token consumed dari session aktif. Composite self-FK
memerlukan detach successor hanya untuk family expired/revoked yang memenuhi retention, lalu delete
credential/session menurut dependency dalam maintenance transaction; uji cleanup tanpa FK_CHECKS disable.
Auth audit retention dan access INSERT-only untuk app/DELETE terpisah untuk maintenance terdokumentasi.

## 6. Hosting/client security dan profile MFA

Bearer diteruskan Indy ke resolver; custom x-api-token boleh tetap compatible untuk access saja. Dua
header credential berbeda ditolak; token tidak diterima dari URL. Rate limits akun + observed origin +
global/admission berlaku sebelum expensive KDF; storage limiter lintas worker/instance konsisten dan
429/Retry-After tanpa account enumeration. Jangan mempercayai IP/user-agent body untuk observed metadata.
Trust proxy allowlist, TLS, CORS whitelist, no-store, secret/config readiness, pool limits dan error boundary
merupakan gate production, bukan hanya schema.

FMX/mobile menyimpan refresh credential pada keystore/keychain/OS credential store melalui mekanisme
terpercaya; access token di memory sebisa mungkin. Browser profile harus memilih BFF/HttpOnly secure
cookie plus CSRF policy atau mekanisme yang telah direview; jangan menyimpan refresh token di localStorage.

Baseline SQL tidak menyimpan TOTP secret/recovery codes MFA. Untuk deployment administrative yang
memerlukan MFA, T02 wajib mengintegrasikan provider MFA terpercaya (termasuk factor enrollment/recovery,
challenge single-use/expiry/rate limit) dan mendokumentasikan endpoint/model tambahan; Login tidak boleh
menerbitkan full token sebelum factor selesai. Jangan mengklaim profile MFA lulus atau menganggap
authenticated_at sebagai bukti faktor kedua hanya karena password telah diverifikasi.

## 7. Compatibility dan acceptance wajib

Ini cutover auth-v2 terencana pada maintenance window. Refresh/Logout berbasis session_id/device_id dan
temporary_password response serta password pada generic PUT tidak dipertahankan sebagai jalur bypass.
Public envelope/route existing dipertahankan sejauh aman; contract baru dan perubahan integer expires_in
harus diperbarui di docs/API/Postman/client sebelum cutover. Source Pascal existing belum kompatibel
dengan required idle_expires_at/role_code dan belum menegakkan policy baru. Jangan deploy SQL sendiri.

Upgrade DB existing membutuhkan migration versioned T02/T11 dari schema numeric aktual yang dipilih,
preflight UUID/ASCII/hash/collation/nullability, backup/restore, backfill role_code/UTC/password metadata,
credential invalidation saat cutover, dan legacy hash verification. SQL baseline tidak dipakai untuk upgrade.

- [x] DDL baseline dan sample import pada DB kosong dengan FK/CHECK enforcement; kedua DDL identik. ([AUTHV2-A01](evidence/wave-01/acceptance.md))
- [x] Duplicate hash/mapping, orphan FK, cross-session refresh successor, invalid flag/expiry ditolak DB. ([AUTHV2-A02](evidence/wave-01/acceptance.md))
- [x] Tidak ada seeded login/credential; bootstrap admin aman, replay ditolak; baseline dan migration menghasilkan schema sama. ([AUTHV2-A03](evidence/wave-01/acceptance.md))
- [ ] Argon2 known vectors/salt berbeda/wrong password/legacy migration/whitespace/Unicode/cost pada Windows/Linux. ([AUTHV2-A04](evidence/wave-01/acceptance.md))
- [ ] CSPRNG audit dan failure fail closed; tidak memakai UUID/random biasa untuk secret. ([AUTHV2-A05](evidence/wave-01/acceptance.md))
- [x] Permission ordinary/admin/self/other/null/inactive role dan last-admin/delegation races; denied write tidak mengubah DB. ([AUTHV2-A06](evidence/wave-01/acceptance.md))
- [x] Login/refresh/logout/reuse/password/reset/disable concurrent dan rollback/commit-disconnect terhadap DB nyata. ([AUTHV2-A07](evidence/wave-01/acceptance.md))
- [x] Session idle/absolute limits dan token expiry; recovery one-use/expired/wrong-purpose/unknown actor; no auto-login. ([AUTHV2-A08](evidence/wave-01/acceptance.md))
- [x] Restricted initial-password session tidak mempunyai business/privilege access; generic PUT password ditolak. ([AUTHV2-A09](evidence/wave-01/acceptance.md))
- [x] Rate limit account/origin/global paralel; proxy spoofing; bounds/type/null/media/body limits dan generic auth failure. ([AUTHV2-A10](evidence/wave-01/acceptance.md))
- [ ] HTTP Bearer/custom/conflict/no-store/envelope/secret scan pada listener Win32/Win64/Linux64. ([AUTHV2-A11](evidence/wave-01/acceptance.md))
- [ ] Retention, audit/log failing, DB unavailable/recovery; provider dependency/UTC/native library sesuai deployment. ([AUTHV2-A12](evidence/wave-01/acceptance.md))
- [ ] Profile MFA/client storage yang dipilih memiliki integration evidence, bukan flag/configuration saja. ([AUTHV2-A13](evidence/wave-01/acceptance.md))

## 8. Referensi desain

- [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [OWASP Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [OWASP Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
- [RFC 9700 refresh token protection](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14)
- [MySQL CHECK constraints](https://dev.mysql.com/doc/refman/8.0/en/create-table-check-constraints.html)

## 9. Validasi revisi dokumen/SQL

Pemeriksaan revisi 1 Oktober 2026 (SOURCE/static, bukan live DATABASE):

- PASS grammar MySQL via sqlglot 30.21.0: baseline 14 statements, sample 32 statements; tidak ada fallback unsupported Command.
- PASS kedua DDL identik: 12 tabel, 15 CHECK per file, 10 FK per file; parent order, referenced unique keys dan FK column types cocok. CHECK tidak memakai kolom AUTO_INCREMENT/foreign-key referential action.
- PASS baseline DDL-only; sample 2 role, 20 permission, 24 grant, 13 business demo rows; tidak ada seeded user/password/session/access/refresh/recovery credential. FK seed business serta grants konsisten.
- PASS prompt wave-01 sampai wave-04 identik dengan blok prompt pada masing-masing file wave; local Markdown links dan diff whitespace diperiksa.
- PASS package validator: 5 skills, local links, PowerShell syntax dan ignore behavior. Catatan bin/config.ini yang sudah tracked merupakan F46 existing dan tidak ditutup oleh revisi ini.
- NOT_RUN live MySQL/MariaDB import/enforcement/concurrency/migration: tidak ada server/client test lokal yang ditemukan; Docker CLI tersedia tetapi engine tidak dapat dihubungi (named pipe dockerDesktopLinuxEngine tidak ada). Tidak memakai database proyek lain untuk pengujian ini.
- NOT_RUN Pascal build/runtime/deployment: perubahan hanya SQL/dokumen, source Pascal tidak diubah; compiler bukan validator DDL. Seluruh checklist implementasi/production di atas tetap terbuka.

SQL identity untuk pemeriksaan di atas:

- `demo_delphirest.sql` SHA-256: `c47e34a4296f7ab32211262184bbdc1231e185b7a8efc43d5f8e91789c63ae65`.
- `demo_delphirest_withdatasample.sql` SHA-256: `66630198e16bbe2cf0ee954b88fc010dea28e7fa839adc3e9c9e76df4d664175`.

## 10. Mapping kewajiban per wave

| Wave | Implementasi/regression terkait Auth | Owner |
|---|---|---|
| 01 | Endpoint, actor/policy, KDF/CSPRNG, refresh/session/recovery/bootstrap dan safe HTTP; minimum logger/parser/config/query limits wajib sebelum Auth dianggap aman | T01/T02/T03; prerequisite slices dicatat pada owner asal |
| 02 | Audit sink/grants/retention, typed IO/no-store/no-echo/UTC dan domain mutation/role reference tetap menjaga auth-v2 transactions | T04/T05/T06 |
| 03 | Typed auth/security config, provider/secret/proxy/limiter policy, bounded owned-session/role/user collections dan storage authority | T09/T08/T07; lifecycle tetap T02 |
| 04 | Native/provider readiness, profile security/MFA yang dipilih, versioned migration/backfill/cutover/restore dan facade/authority regression | T10/T11/T12 |

Setiap wave membaca [kontrak ini](auth-production-contract-2026-10-01.md). Salinan prompt pada bagian 5
file wave disinkronkan dengan prompt terpisah. Query limits/config/logger/input validation yang diperlukan
untuk fitur baru bukan alasan menunda gate keamanan wajib ke wave berikutnya; minimum slice langsung
dikerjakan saat fitur dibuat dan handoff/evidence dicatat. Tahap berikutnya menyelesaikan sisa owner scope.
