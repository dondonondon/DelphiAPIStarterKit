# Authentication API — auth-v2

Kontrak aktif source WAVE-01. Bukti Win64/MariaDB dan gate yang belum tersedia ada di [hasil wave](../bugs/wave-01-result.md).
Base URL development `http://127.0.0.1:9000/api/v1`; deployment wajib HTTPS. Tidak ada public registration/email recovery/HTTP bootstrap.
Akun dikelola admin. Tidak ada seeded username/password pada kedua fresh SQL alternatif.

## Credential, headers dan envelope

Access/refresh/setup/reset berasal dari 32 byte OS CSPRNG, Base64URL canonical 43 karakter tanpa padding. Database menyimpan SHA-256
lowercase hex dari decoded credential bytes; UUID user/session/device bukan credential. Access memakai `Authorization: Bearer <runtime credential>`.
`x-api-token` dan legacy `access-token` kompatibel untuk access saja. Header berbeda ditolak 400; header identik diterima. Basic/unknown/malformed
scheme ditolak 401; duplicate credential/framing headers ditolak 400. Credential query string tidak mengautentikasi.

Semua JSON memakai actual UTF-8 `application/json; charset=utf-8`, tanpa Content-Encoding untuk uncompressed body, dan `Cache-Control: no-store`.
Envelope mempunyai HTTP-matching integer `status`, string `messages`, Unix UTC string `servertime`, array `data`.
Error memakai `data:[{}]`; empty success memakai `data:[]`. Tidak ada request echo, hash, password atau internal ID pada response.
Credential hanya muncul pada issuance yang membutuhkannya. `expires_in`/`refresh_expires_in` adalah integer detik.

## Endpoint

| Method / route | Request dan credential | Success / policy |
|---|---|---|
| POST /Auth/Login | JSON username, password, device_id; device_name optional. Tidak membutuhkan access credential | 200 access_token, refresh_token, token_type=Bearer, expires_in, refresh_expires_in, session_id, password_change_required |
| POST /Auth/Refresh | JSON refresh_token saja | 200 pasangan token baru; access sebelumnya revoked. Restricted/inactive/deleted/revoked/expired ditolak |
| POST /Auth/Logout | Access header tanpa body, atau JSON refresh_token tanpa access header | 200 data:[]; seluruh session family revoked. Credential dikenal idempotent termasuk revoked/expired; unknown 401. Conflict access+refresh body 400 |
| POST /Auth/Reauthenticate | Access header + JSON password saat ini | 200 data:[]; authenticated_at di-update setelah verification. Absolute TTL tetap |
| POST /Auth/LogoutAll | Access actor + recent authentication | 200 data:[]; seluruh session actor termasuk current revoked |
| GET /Auth/Me | Access actor | user_id, username, fullname, role_id integer/null, role_code, effective permissions |
| GET /Auth/Sessions | Access actor; limit 1–100 default 50; offset 0–100000 | Session actor saja: public session_id, metadata observed, UTC ISO expiry/activity, revoked state/reason. Tidak ada token/hash/internal ID |
| DELETE /Auth/Sessions/{session_id} | Access actor; UUID lowercase milik actor | 200 data:[]; own revoke idempotent. Other/unknown 404. Revoke current diperbolehkan |
| POST /Auth/CompletePasswordReset | JSON reset_token + new_password | One-use password_reset/account_setup credential saja; hash/flag/time update + full revoke atomik, 200 data:[], tanpa login otomatis |
| POST /User/ChangePassword | Access actor + JSON old_password, new_password | Self only; wrong old password 401. Password update + full revoke termasuk current/recovery, 200 data:[]; login kembali |
| POST /User/{user_id}/ResetPassword | Access + recent + users.reset_password + target policy; JSON confirm_reset:true | 200 public user_id, reset_token sekali, expires_in integer. Tidak mengganti password/revoke saat issue; bukan temporary_password |

Username 1–50 ASCII `[A-Za-z0-9_.-]`. Device ID required string 1–100 Unicode codepoints, bukan wajib UUID; device_name maksimal 100.
Observed User-Agent header maksimal 255; observed IP hanya peer listener maksimal 45. Body ip_address/user_agent ditolak; forwarded headers diabaikan.
Baseline memilih direct-peer profile. Deployment proxy harus menguji topology/TLS/rate policy; belum ada trusted-forwarded-IP resolver.
Password dipertahankan persis (whitespace/Unicode), tanpa trim/normalization. New password 15–128 codepoints, maksimal 512 UTF-8 bytes,
common-password blocklist plus optional absolute UTF-8 PasswordBlocklist. Legacy login/reauth/old password 1–128 selama cutover.
JSON object satu root, depth maksimal 4, maksimal 32 members, exact allowed fields; null/coercion/duplicates/unknown field invalid.
Auth/User/Role body maksimal 16 KiB sebelum stream allocation (413); JSON media/body validation 400. Chunked/transfer encoding dan method override
belum didukung; ditolak 400. Other listener body cap 4 MiB. Route case-insensitive; UUID lowercase; trailing/double/extra slash atau arbitrary action 404;
unsupported method 405 dengan Allow.

## Session, rotation dan limiting

Default access 900s; absolute session 604800s; idle 86400s; recovery 900s; recent authentication 300s. Actual access/refresh TTL dibatasi idle/absolute
session yang tersisa. Idle activity diperbarui pada refresh, absolute TTL tidak diperpanjang. Client refresh sebelum access expire.
Initial-password session maksimal 900s, hanya ChangePassword/Logout, password_change_required=true, tanpa refresh_token dan refresh_expires_in=0.

Client wajib single-flight refresh dan mengganti pasangan credential atomik. Consume, successor, revoke old access dan idle update satu transaksi.
Consumed credential replay COMMIT revoke seluruh family sebelum 401. Lost response tidak boleh retry old credential: login kembali.
Logout/password/recovery/disable/delete/grant diserialisasi pada shared policy lock lalu user, session, credential. Password/revoke gagal rollback bersama.
Reset baru mencabut pending credential untuk target/purpose sama; issuance tidak mengubah password/session. Redemption membatalkan seluruh pending recovery.

Limiter DB-shared fixed UTC minute: account 10, observed origin 60, global 300 request/minute; KDF admission 4 shared DB named-lock slots.
Login/known refresh memakai canonical account; unknown credential memakai hash bucket, tetap origin/global dibatasi. 429 + Retry-After:60.
Counter atomic lintas worker; expiry cleanup bounded. Boundary menit dapat mengizinkan dua jendela berdekatan; ini bukan sliding window/lockout.
Maintenance CLI `--auth-cleanup` batch maksimal 100 membuang family dengan absolute expiry lebih dari 7 hari, recovery expired lebih dari 7 hari;
consumed refresh chain session aktif dipertahankan untuk reuse detection. Audit retention/grants operasional milik T04/T10.

## Provisioning, hashing dan security profile

[Config example](../../config.example.ini) memerlukan absolute Argon2Library dan lowercase SHA-256 pin. Native ABI harus mengekspor
argon2id_hash_encoded/argon2id_verify cdecl untuk OS/bitness yang sama; library/dependencies dipasang dari provider terpercaya pada protected directory.
Windows loader hanya mencari dependency pada explicit library directory/System32. Linux memakai absolute dlopen RTLD_NOW/LOCAL.
Startup menjalankan known-answer vector dan CSPRNG serta dummy hash; failure exit nonzero, tanpa fast-hash fallback.
New hashes PHC Argon2id v19 m=19456 KiB t=2 p=1, random salt 16 byte, hash 32 byte. Legacy HMAC64 hanya dengan original HMACSecret dan
explicit future LegacyHashDeadline Unix UTC; setelah successful login rehash PHC. Default deadline 0 menolak legacy. Tidak memakai legacy obfuscation helpers.

Fresh bootstrap offline: isi process-only DELPHI_API_BOOTSTRAP_USERNAME/PASSWORD melalui secret injection, jalankan executable `--bootstrap-admin`
dengan config/provider/DB yang tervalidasi, lalu hapus env dari sesi. Password dipilih operator sesuai policy, tidak disediakan default/command-line.
Command menolak nonempty users/replay; provisioning admin memberi 20 permission eksplisit, bukan is_superadmin bypass. Tidak mencetak credential.
Schema baseline/sample tidak boleh dijalankan sebagai upgrade. Ikuti [clone migration guide](../databases/auth-v2-cutover.md).

Profile source `password-only` adalah baseline integration test. Profile selain itu fail closed karena provider MFA belum terintegrasi.
Ini tidak membuktikan administrative production profile memenuhi MFA. Dibutuhkan provider, enrollment/challenge/recovery/client dan staging acceptance.
FMX refresh harus memakai keystore/keychain/OS credential store; access sebaiknya memory. Browser membutuhkan reviewed BFF/HttpOnly Secure cookie+CSRF
atau mekanisme yang direview; jangan localStorage. Implementasi client tidak ada di repository ini: secure storage integration BLOCKED.
Application memiliki CORS allowlist origin `;` separated, tanpa wildcard/credentials, method/header whitelist. OPTIONS sebelum actor/DB; actual tetap auth.
Default allowlist kosong. Proxy tidak boleh menambahkan wildcard credential CORS atau mereintroduksi session_id-only contract.

401 credential failures generic; 403 permission/recent/restriction; 404 ownership/resource; 409 conflict/last admin; 429 limiter; 500 safe internal error.
Lihat [User](users.md), [Role](roles.md) dan [kontrak target](../bugs/auth-production-contract-2026-10-01.md).
