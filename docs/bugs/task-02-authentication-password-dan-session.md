# T02 — Authentication, password, dan lifecycle session

Status: **BLOCKED**. Prioritas tertinggi: **P1**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F03, F04, F05, F06, F43, F44, F45** (5 CONFIRMED, 2 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-01](wave-01.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Implementasi WAVE-01 dan evidence saat ini tercatat di [hasil wave](wave-01-result.md). Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Pisahkan public identifier dari secret, perkuat password storage, dan jadikan login/refresh/logout/revoke satu lifecycle aman pada Windows/Linux.

**Cakupan:** Auth/User service-repository-validator, security infrastructure dan helper UUID/encoding. Schema delta khusus hashing/session dimiliki task ini; guide migration legacy F35 dimiliki T11.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [x] Jadikan kontrak auth-v2 authority: implementasikan Login/Refresh/Logout/Reauthenticate/LogoutAll/Me/Sessions/revoke-own-session/CompletePasswordReset sesuai method, credential, ownership dan response table. Endpoints baru belum tersedia hanya karena SQL telah ditulis. ([T02-S1](evidence/wave-01/acceptance.md))
- [ ] Argon2id provider tepercaya, PHC hash ASCII binary, salt >=16 byte, initial m=19456 KiB/t=2/p=1, known vectors dan cost benchmark Windows/Linux. Provider unavailable menjadi blocker; jangan fallback ke fast HMAC. Legacy verifier hanya selama versioned migration window. ([T02-S2](evidence/wave-01/acceptance.md))
- [x] CSPRNG 32 byte untuk access/refresh/setup/reset, Base64URL no-padding; store SHA-256 lowercase hex credential bytes secara konsisten. UUID/session_id/device_id bukan credential. Default access 900s, session absolute 604800s, idle 86400s, recovery 900s dan recent-auth 300s configurable. ([T02-S3](evidence/wave-01/acceptance.md))
- [x] Refresh consume/rotate/old-access revoke/idle update satu transaksi; user->session->credential lock order konsisten dengan logout/password mutation. Reuse COMMIT full family revoke sebelum 401. Client single-flight, lost response memerlukan login ulang; tidak ada legacy refresh fallback. ([T02-S4](evidence/wave-01/acceptance.md))
- [x] Self-change/reset redemption/disable/delete revoke seluruh credential atomik. Recovery issuance tidak mengganti password atau revoke session target; redemption valid one-use menetapkan hash/flag/time dan revoke pending recovery + sessions, tanpa auto-login. ([T02-S5](evidence/wave-01/acceptance.md))
- [x] Restrict must_change_password session ke ChangePassword/Logout. Create/setup/CLI bootstrap flow dan recent Reauthenticate wajib; password tidak di-trim, kebijakan length/blocklist/legacy bounds mengikuti kontrak. ([T02-S6](evidence/wave-01/acceptance.md))
- [x] Login/refresh rate limiter account + observed origin + global/admission sebelum KDF; active/deleted status generic 401. Metadata observed tidak dapat ditimpa body; cleanup refresh chain tidak menghapus reuse evidence session aktif. ([T02-S7](evidence/wave-01/acceptance.md))
- [ ] Dokumentasikan secure token storage FMX/browser profile. Integrasikan MFA provider/enrollment/challenge/recovery bila administrative deployment profile memerlukan MFA; profile yang belum diuji tidak boleh dinyatakan lulus. ([T02-S8](evidence/wave-01/acceptance.md))
- [x] Schema target baru tersedia; sediakan migration upgrade numeric schema/backfill/credential invalidation dan client/API cutover sebelum deployment. DDL import/FK/CHECK/unique/expiry/cross-session successor diuji pada MySQL/MariaDB clone; source/build bukan DB/runtime proof. ([T02-S9](evidence/wave-01/acceptance.md))

- [x] Validasi typed auth input/bounds, password Unicode/whitespace/legacy rules, observed proxy metadata dan generic auth failure sesuai kontrak; malformed/type-invalid input berhenti sebelum KDF/business execution. ([T02-S10](evidence/wave-01/acceptance.md))
- [x] Audit consumer Encrypt/Decrypt/Base64 legacy; larang obfuscation untuk secret dan beri strict error contract bila perlu. Jangan membuat custom cipher. ([T02-S11](evidence/wave-01/acceptance.md))

## 3. Dependensi dan koordinasi

- [T01](task-01-authorization-dan-permission.md) memiliki hak reset/self-service; [T06](task-06-database-transaksi-dan-validasi-domain.md) memiliki authoritative mutation outcome. Sepakati satu transaction scope password/revoke.
- [T05](task-05-request-response-json-dan-waktu.md) memiliki parser/no-echo, [T09](task-09-config-path-dan-persistence.md) secret config reader, [T04](task-04-logging-dan-observability.md) logging aman dan [T03](task-03-http-routing-dan-error-boundary.md) token transport. Perbaikan inti tidak menunggu refactor besar.
- Koordinasikan auth schema delta dengan [T11](task-11-schema-migration-dan-kompatibilitas.md); target migration final harus memuat delta ini.

## 4. Acceptance dan validasi kategori

- [x] Seluruh endpoint/lifecycle pada kontrak auth-v2 section 4/5 diuji: Reauthenticate/LogoutAll/Me/Sessions/revoke-own/recovery/setup selain Login/Refresh/Logout. One-use refresh/recovery serta replay-revocation commit/rollback/response-loss dipastikan. ([T02-A1](evidence/wave-01/acceptance.md))
- [ ] Idle/absolute/session restriction, secure bootstrap, Argon2 provider/legacy migration, limiter/client storage dan deployment profile MFA mengikuti acceptance kontrak, bukan schema/flag saja. ([T02-A2](evidence/wave-01/acceptance.md))

- [ ] Audit CSPRNG Windows/Linux dan failure path; uniqueness/statistik sampel bukan bukti entropy. Credential lama ditangani sesuai cutover. ([T02-A3](evidence/wave-01/acceptance.md))
- [ ] Password sama menghasilkan hash berbeda; wrong password ditolak; legacy direhash sesuai policy dan cost diukur pada kedua OS. ([T02-A4](evidence/wave-01/acceptance.md))
- [x] Refresh rotation/reuse, revoked/expired/inactive/deleted, logout-refresh race serta password rollback/revoke diuji terhadap DB nyata. ([T02-A5](evidence/wave-01/acceptance.md))
- [x] N/N+1, wrong type/null/IP/UUID, password whitespace serta missing/inactive/wrong-password menghasilkan validation/credential failure yang tepat tanpa account-status exposure sebelum authentication. ([T02-A6](evidence/wave-01/acceptance.md))
- [ ] Body IP tidak mengganti observed origin; trusted proxy dan limiter paralel diuji. Retention tidak menghapus credential aktif; log/response yang tidak memerlukan secret bebas credential. ([T02-A7](evidence/wave-01/acceptance.md))
- [ ] F43/F45 CONTEXT-DEPENDENT ditutup dengan consumer/gateway/policy actual; tidak applicable atau gateway protection memerlukan evidence spesifik. ([T02-A8](evidence/wave-01/acceptance.md))

## 5. Checklist penutupan temuan

- [ ] **F03 (P1, CONFIRMED)** — Token Linux memakai UUID berbasis waktu. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F1](evidence/wave-01/acceptance.md))
- [x] **F04 (P1, CONFIRMED)** — Lifecycle refresh belum aman dan konsisten. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F2](evidence/wave-01/acceptance.md))
- [ ] **F05 (P1, CONFIRMED)** — Password hashing terlalu cepat dan tidak versioned. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F3](evidence/wave-01/acceptance.md))
- [x] **F06 (P1, CONFIRMED)** — Password berubah tetapi credential lama tetap aktif. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F4](evidence/wave-01/acceptance.md))
- [x] **F43 (P3, CONTEXT-DEPENDENT)** — Nama helper kripto dapat menyesatkan. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F5](evidence/wave-01/acceptance.md))
- [x] **F44 (P2, CONFIRMED)** — Auth input dan metadata session belum mempunyai kontrak ketat. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F6](evidence/wave-01/acceptance.md))
- [ ] **F45 (P2, CONTEXT-DEPENDENT)** — Auth endpoint tidak mempunyai throttling aplikasi. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T02-F7](evidence/wave-01/acceptance.md))

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi. ([T02-D1](evidence/wave-01/acceptance.md))
- [x] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil. ([T02-D2](evidence/wave-01/acceptance.md))
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya. ([T02-D3](evidence/wave-01/acceptance.md))
- [x] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak. ([T02-D4](evidence/wave-01/acceptance.md))
- [x] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence. ([T02-D5](evidence/wave-01/acceptance.md))
- [x] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai. ([T02-D6](evidence/wave-01/acceptance.md))

**Catatan hasil:** Implementation serial T02 selesai untuk resource yang tersedia; mandatory Win32/Linux/deployment gates BLOCKED. Lihat [hasil](wave-01-result.md), [matrix seluruh predicate](evidence/wave-01/acceptance.md) dan [checkpoint](wave-01.md#7-catatan-eksekusi). Checkbox tidak mencakup gate platform lain yang belum diuji. Tidak ada commit baru; HEAD baseline tetap 358db33b95724f654db00e39fd4f35dc26c0d12c.

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F03 — P1 — CONFIRMED — Token Linux memakai UUID berbasis waktu

**Lokasi:** [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L135), 135–137 dan 222–223; [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L331), 331–342; [User.Service.pas](../../sources/modules/users/User.Service.pas#L220), 220–223.

`access_token` dan session identifier dibuat melalui `TGUID.NewGuid`. Pada RTL **RAD Studio 37 yang terpasang**, jalur POSIX `CreateGUID` memanggil `uuid_generate_time` dari `libuuid.so.1`: `System.SysUtils.pas` 5939–5964. `TGUIDHelper.NewGuid` pada 6214–6217 memanggil `CreateGUID`. Ini UUID berbasis waktu, bukan generator token rahasia dengan random cryptographic bytes.

Temporary password dibuat dari 24 karakter pertama gabungan dua compact UUID. Karena UUID pertama sudah sepanjang 32 karakter, UUID kedua tidak menyumbang karakter ke hasil. Pemotongan itu juga membuang sebagian struktur UUID; dua pemanggilan bukan bukti tambahan entropy.

**Dampak:** token/session/password Linux mempunyai struktur waktu/clock/node yang tidak memenuhi asumsi unguessable credential. Meng-hash token sebelum disimpan tidak memperbaiki entropy token yang dikirim ke client. Eksploitasi menebak token korban belum dijalankan; yang dikonfirmasi adalah desain generator dan jalur RTL.

**Perbaikan:** dedicated credential generator memakai CSPRNG OS pada Windows/Linux, misalnya 32 random bytes yang di-encode secara aman. Pisahkan generator public UUID dari generator secret. Periksa kegagalan RNG dan fail closed. Tetap gunakan UUID untuk identifier publik jika cocok.

**Acceptance:** audit call path menunjukkan secret tidak lagi berasal dari UUID/time/random biasa; verifikasi API RNG kedua platform dan handling failure; session/token lama dicabut saat cutover; validasi entropy tidak hanya mengandalkan tes statistik sampel. Lihat [OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) untuk prinsip token acak yang tidak dapat ditebak.

### F04 — P1 — CONFIRMED — Lifecycle refresh belum aman dan konsisten

**Lokasi:** [RestAPI.Auth.pas](../../sources/modules/auth/RestAPI.Auth.pas#L32), 32–57; [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L203), 203–240; [Auth.Repository.pas](../../sources/modules/auth/Auth.Repository.pas#L158), 158–183 dan 135–152.

Refresh menerima `session_id` dan `device_id`; session identifier secara efektif menjadi credential refresh. Ini bukan otomatis salah karena refresh boleh memakai credential terpisah dari access token. Namun credential tersebut dibuat dengan generator F03, tidak dirotasi saat refresh, dan tidak ada deteksi reuse. `CreateSession` pada Auth.Repository 61–85 menyimpan session_id/device_id secara langsung, sehingga snapshot DB read-only mengungkap pasangan credential refresh yang belum expired, walaupun access_token disimpan sebagai hash. `SessionExists` tidak JOIN user untuk memeriksa `is_active/deleted_at`.

Access token lama tetap aktif sampai expiry; perilaku ini memang dinyatakan [auth.md](../api/auth.md#L147) baris 147 dan bukan bug tersendiri. Yang perlu ditentukan adalah overlap/revoke policy bersama proteksi refresh credential, bukan kewajiban membatalkan setiap access token pada setiap refresh.

Pemeriksaan session berlangsung **sebelum** transaction pembuatan token. Request revoke/logout dapat commit di antara pemeriksaan dan insert, sehingga refresh melaporkan sukses untuk session yang sudah revoked; endpoint selanjutnya menolak token karena session guard.

**Dampak:** credential session bocor dapat digunakan berulang sampai tujuh hari; user nonaktif/deleted masih bisa memperoleh response token meskipun guard resource menolaknya; banyak token aktif dapat ditambahkan; refresh/logout konkuren menghasilkan hasil yang tidak konsisten. `device_id` yang dikirim client tidak merupakan faktor autentikasi rahasia.

**Perbaikan:** buat refresh credential khusus dari CSPRNG, simpan hash, rotasi dan deteksi reuse; validasi user/session dalam transaction yang sama dengan penerbitan token; tetapkan kebijakan overlap/revoke access token sebelumnya. Logout/revoke harus mengikat credential dengan session/actor yang berhak. Public session identifier boleh tetap tersimpan langsung jika sudah terpisah dari secret refresh.

**Acceptance:** credential refresh lama tidak dapat dipakai setelah rotasi; inactive/deleted/revoked/expired ditolak; logout dan refresh yang disinkronkan tidak menerbitkan sukses unusable token; reuse mencabut keluarga session sesuai kebijakan; jangan mengembalikan session credential pada response yang tidak membutuhkannya.

### F05 — P1 — CONFIRMED — Password hashing terlalu cepat dan tidak versioned

**Lokasi:** [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L241), 241–267; [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L118), 118; [User.Service.pas](../../sources/modules/users/User.Service.pas#L104), 104–109, 250, 324–326, dan 394.

Password disimpan sebagai satu HMAC-SHA256 memakai satu secret global, sama seperti token hashing. Tidak ada salt unik, work factor adaptif, atau algorithm version pada password representation. Password yang sama menghasilkan hash yang sama. Secret global menambah perlindungan jika hanya DB bocor, tetapi jika DB dan secret sama-sama didapat, percobaan password sangat murah.

**Perbaikan:** password-hashing service terpisah memakai implementasi tepercaya Argon2id atau PBKDF2 sesuai kemampuan dan kebutuhan deployment, dengan salt acak, parameter/version tersimpan, dan cost yang diukur. Jangan menulis kriptografi sendiri. Migrasi hash lama bertahap setelah verifikasi login, dengan strategi untuk akun yang belum login. Pisahkan key/password pepper dari key token hash dan tetapkan rotasi/version.

**Acceptance:** dua akun dengan password sama memiliki representasi hash berbeda; legacy hash bisa dimigrasi tanpa reset massal yang tidak direncanakan; wrong password ditolak; cost login terukur pada kedua platform; hash/pepper/token tidak masuk log. [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) merekomendasikan password hashing lambat, salt, dan work factor.

### F06 — P1 — CONFIRMED — Password berubah tetapi credential lama tetap aktif

**Lokasi:** [User.Service.pas](../../sources/modules/users/User.Service.pas#L115), 115–128, 322–343, 394–427; [User.Repository.pas](../../sources/modules/users/User.Repository.pas#L213), 213–226 dan 229–282.

ChangePassword, ResetPassword, serta Update yang menerima password hanya mengubah `password_hash`; tidak ada revoke session/access token milik target. Session dapat tetap berlaku sampai expiry yang sudah ditentukan.

**Dampak:** perubahan password setelah credential dicuri tidak menghentikan akses penyerang yang sudah memiliki token/session. Reset administratif bukan pemulihan akun yang lengkap. Penonaktifan user memang diperiksa guard resource, tetapi tidak menggantikan revoke credential ketika password berubah.

**Perbaikan:** kebijakan revoke dalam transaction yang sama dengan password update. Default aman untuk administrative reset: revoke seluruh session target. Untuk self-change, tentukan apakah session peminta dipertahankan dengan token baru atau semua session dicabut.

**Acceptance:** token dan refresh credential sebelum reset ditolak setelah commit; rollback password update juga rollback revoke; kebijakan current-device terdokumentasi dan diuji.

### F43 — P3 — CONTEXT-DEPENDENT — Nama helper kripto dapat menyesatkan

**Lokasi:** [BFA.Helper.Strings.pas](../../sources/shared/helpers/BFA.Helper.Strings.pas#L115), 115–159 dan konstanta 60.

Encrypt/Decrypt hanya menggeser ordinal karakter dengan konstanta yang ada di source; EncodeCrypt menambahkan Base64. DecodeBase64 menelan decoding error dan mengembalikan input. Tidak ditemukan active security/config callsite yang bergantung helper ini.

**Dampak jika dipakai untuk secret:** data mudah dikembalikan siapa pun yang mengetahui source; corrupted input dapat diterima sebagai teks asli. Ini bukan defect pada hash password yang memakai HMAC terpisah, tetapi reusable starter dapat memicu penggunaan keliru.

**Perbaikan:** deprecate/namai jelas sebagai legacy obfuscation bila kompatibilitas perlu; larang pemakaian untuk password/token/config secret dalam docs. Jika confidentiality dibutuhkan, gunakan reviewed authenticated encryption dengan key lifecycle dan format/version yang benar. Jangan membuat custom cipher baru.

**Acceptance:** semua security-sensitive callsite tidak memakai helper ini; invalid base64 mempunyai hasil error yang eksplisit pada parser yang membutuhkan strict input; migration data obfuscated direncanakan jika ada consumer di luar repo.

### F44 — P2 — CONFIRMED — Auth input dan metadata session belum mempunyai kontrak ketat

**Lokasi:** [Auth.Validator.pas](../../sources/modules/auth/Auth.Validator.pas#L37), 37–51 dan 63–68; [BFA.Helper.Validator.pas](../../sources/shared/helpers/BFA.Helper.Validator.pas#L62), 62–84; [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L113), 113–133; [schema SQL](../../assets/databases/demo_delphirest.sql#L487), 487–510.

Auth validator hanya memeriksa nonempty string, belum panjang/format sesuai kolom device_id/device_name 100, user_agent 255, dan ip_address 45. Generic GetRequiredString men-trim password dan mengcoerce field melalui AsString. Schema/user password policy belum menyatakan apakah whitespace dilarang atau dipertahankan.

`ip_address` dan `user_agent` body dipercaya bila nonempty; peer address/header hanya fallback. Akibatnya client dapat mengisi metadata session seolah berasal dari IP lain. Source tidak memakai metadata itu sebagai permission check, jadi ini defect integrity/semantics audit, bukan bukti bypass autentikasi melalui IP. Status user nonaktif juga diperiksa sebelum password, menghasilkan 403 berbeda sehingga username nonaktif dapat dikenali tanpa password yang benar.

**Perbaikan:** typed bounded input untuk seluruh auth fields; password dipertahankan atau whitespace ditolak secara eksplisit sesuai policy, jangan dinormalisasi diam-diam. Catat observed peer/IP hanya dari request/proxy tepercaya; simpan client-reported metadata pada field terpisah jika memang dibutuhkan. Credential failures eksternal harus generic; alasan inactive/wrong-password dicatat aman secara internal.

**Acceptance:** masing-masing panjang N/N+1, invalid IP/UUID/token type, password leading/trailing whitespace, serta account missing/inactive/wrong-password diuji; validation error 400 yang sesuai, bukan DB 500/truncation; body IP tidak mengganti observed address; response tidak memberi status akun sebelum authentication berhasil.

### F45 — P2 — CONTEXT-DEPENDENT — Auth endpoint tidak mempunyai throttling aplikasi

**Lokasi:** [Auth.Service.pas](../../sources/modules/auth/Auth.Service.pas#L88), Login 88–171 dan Refresh 203–247; [DelphiAPIStarterKit.dpr](../../DelphiAPIStarterKit.dpr#L197), host initialization 197–218; active request pipeline pada App.WebModule/Core.Endpoint.

Tidak ditemukan retry/rate-limit/backoff per akun/IP/device atau admission limit khusus auth pada source aplikasi. Login melakukan DB lookup/hashing; Refresh dapat menambah token berulang selama session valid. Limit mungkin disediakan gateway, tetapi konfigurasi gateway tidak ada dalam scope review.

**Dampak jika listener langsung terpapar:** credential guessing/credential stuffing serta pressure worker/pool/token table tidak mempunyai pembatas application-level. Ini berbeda dari body-size limit F15 dan quota upload F14.

**Perbaikan:** documented auth rate policy dengan per-account dan observed-origin limits, batas global/admission, reset/backoff dan 429/Retry-After yang konsisten. Jika gateway pemilik utama limiter, sertakan konfigurasi dan acceptance; aplikasi tetap perlu menghindari lockout yang dapat disalahgunakan dan jangan mempercayai IP body client. Token/session retention cleanup perlu kebijakan operasional.

**Acceptance:** repeated wrong login/refresh pada batas yang ditetapkan memberi 429 sesuai policy; akun/IP lain tidak ikut terblokir tanpa alasan; proxy source yang tepercaya diuji; parallel requests tidak melewati counter karena race; record token lama dibersihkan tanpa menghapus credential aktif.
