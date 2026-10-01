# T01 — Authorization dan permission per action

Status: **BLOCKED**. Prioritas tertinggi: **P0**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F01** (1 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-01](wave-01.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Implementasi WAVE-01 dan evidence saat ini tercatat di [hasil wave](wave-01-result.md). Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Tutup akses administrasi lintas user dan privilege escalation dengan actor context serta policy sebelum membaca data sensitif atau memutasi DB.

**Cakupan:** Guard endpoint, session/actor resolver dan Users service/validator/repository; policy akses feature yang sudah tersedia. Pertahankan route publik dan struktur feature-first.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [x] Terapkan schema m_permission/role_permission serta role_code dari auth-v2; satu role nullable per user tetap cukup. Role/permission inactive dan missing mapping deny by default; is_superadmin bukan bypass. ([T01-S1](evidence/wave-01/acceptance.md))
- [x] Satu actor resolver membawa user/session/role/effective permissions. Own Me/Sessions/ChangePassword memakai ownership; Users CRUD dan business CRUD mengikuti matrix permission pada kontrak auth-v2. ([T01-S2](evidence/wave-01/acceptance.md))
- [x] Implementasikan GET /Role dan PUT /Role/{public_role_uuid}/Permissions; integer role_id pada User DTO tetap compatible. Validasi delegation dan grant boundary, recent reauthentication, self-escalation serta last-admin protection atomik. ([T01-S3](evidence/wave-01/acceptance.md))
- [x] Admin provisioning offline tanpa password bawaan/HTTP bootstrap; initial password session restricted sampai change. Generic PUT password ditolak 400; ResetPassword memakai permission, recent auth dan one-time recovery credential, bukan temporary password. ([T01-S4](evidence/wave-01/acceptance.md))
- [x] Uji ordinary/admin/self/other, null/inactive/deleted role/permission, last-admin/delegation race dan credential revocation pada disable/delete/privilege mutation. Schema/seed saja tidak menutup F01. ([T01-S5](evidence/wave-01/acceptance.md))

- [x] Inventarisasi matrix action/target/permission: list/detail user, create/delete, reset/change password, update password, is_active, serta assignment role; pisahkan self-service dari administrasi. ([T01-S6](evidence/wave-01/acceptance.md))
- [x] Hasilkan actor context dari credential dan status akun/session yang valid. Jangan menurunkan privilege dari body request; policy dijalankan sebelum query sensitif/mutation. ([T01-S7](evidence/wave-01/acceptance.md))
- [x] Cegah user biasa menaikkan role sendiri, mengubah akun lain atau memakai custom action untuk melewati guard CRUD. Self-change memerlukan password lama; administrative reset memerlukan permission terhadap target. ([T01-S8](evidence/wave-01/acceptance.md))
- [x] Nyatakan policy CRUD Product/Customer/Category sesuai kebutuhan starter tanpa mengarang role bisnis. Audit action/actor/target/outcome menggunakan logger bersama tanpa credential. ([T01-S9](evidence/wave-01/acceptance.md))
- [x] Update users/auth docs, Postman dan project mapping untuk matrix permission serta response 401/403. ([T01-S10](evidence/wave-01/acceptance.md))

## 3. Dependensi dan koordinasi

- Containment F01 didahulukan; [T12](task-12-architecture-dan-centralization.md) bukan prasyarat. Resolver credential berkoordinasi dengan [T02](task-02-authentication-password-dan-session.md), header transport dengan [T03](task-03-http-routing-dan-error-boundary.md). Guard harus tetap melindungi x-api-token.
- [T06](task-06-database-transaksi-dan-validasi-domain.md) memiliki reference/bounds validation role; task ini memiliki permission assignment. [T04](task-04-logging-dan-observability.md) menyediakan audit logger, [T05](task-05-request-response-json-dan-waktu.md) menutup secret echo.

## 4. Acceptance dan validasi kategori

- [x] Matrix permission auth-v2 (termasuk Role mapping dan semua business CRUD), ownership, restricted initial-password session, bootstrap, delegation dan last-admin concurrent protection mempunyai evidence; is_superadmin tidak memberi bypass. ([T01-A1](evidence/wave-01/acceptance.md))
- [x] Admin reset/grant/delete memerlukan policy dan recent auth; ordinary denied request tidak memutasi user/role/credential/audit secara menyesatkan. ([T01-A2](evidence/wave-01/acceptance.md))

- [x] Ordinary user mendapat 403 pada reset target lain, role/is_active update, create/delete administratif dan read yang dilarang; stored state tidak berubah. ([T01-A3](evidence/wave-01/acceptance.md))
- [x] Admin dengan permission sesuai berhasil; actor tanpa permission action/target ditolak. UUID target/token valid bukan permission. ([T01-A4](evidence/wave-01/acceptance.md))
- [x] Self-change menolak password lama salah; custom dispatch tidak melewati guard service. Missing/invalid/revoked/inactive credential tidak menghasilkan actor berprivilege. ([T01-A5](evidence/wave-01/acceptance.md))
- [ ] Uji listener Windows/Linux lewat custom header dan Bearer setelah F08 diperbaiki; audit/response bebas password/token dan sesuai matrix akses. ([T01-A6](evidence/wave-01/acceptance.md))

## 5. Checklist penutupan temuan

- [x] **F01 (P0, CONFIRMED)** — Operasi administrasi user tanpa otorisasi. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik. ([T01-F1](evidence/wave-01/acceptance.md))

## 6. Definition of done dan catatan hasil

- [x] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi. ([T01-D1](evidence/wave-01/acceptance.md))
- [x] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil. ([T01-D2](evidence/wave-01/acceptance.md))
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya. ([T01-D3](evidence/wave-01/acceptance.md))
- [x] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak. ([T01-D4](evidence/wave-01/acceptance.md))
- [x] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence. ([T01-D5](evidence/wave-01/acceptance.md))
- [x] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai. ([T01-D6](evidence/wave-01/acceptance.md))

**Catatan hasil:** Implementation serial T01 selesai untuk resource yang tersedia; mandatory Win32/Linux/deployment gates BLOCKED. Lihat [hasil](wave-01-result.md), [matrix seluruh predicate](evidence/wave-01/acceptance.md) dan [checkpoint](wave-01.md#7-catatan-eksekusi). Checkbox tidak mencakup gate platform lain yang belum diuji. Tidak ada commit baru; HEAD baseline tetap 358db33b95724f654db00e39fd4f35dc26c0d12c.

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F01 — P0 — CONFIRMED — Operasi administrasi user tanpa otorisasi

**Lokasi:** [RestAPI.User.pas](../../sources/modules/users/RestAPI.User.pas#L32), baris 32–58; [BFA.Core.Endpoint.pas](../../sources/core/BFA.Core.Endpoint.pas#L58), 58–61 dan 97–137; [User.Service.pas](../../sources/modules/users/User.Service.pas#L294), 294–343 dan 368–400; [User.Validator.pas](../../sources/modules/users/User.Validator.pas#L144), 144–174.

Guard endpoint hanya memeriksa apakah access token valid. Guard tidak membawa actor context atau permission ke use case. `ResetPassword` memastikan requester mempunyai identitas, lalu mengganti password target yang diberikan pada route. Create, delete, update password, perubahan `is_active`, dan assignment `role_id` juga tidak memiliki pemeriksaan kewenangan. Dokumentasi [users.md](../api/users.md#L310), 310–312, menyebut reset sebagai operasi admin.

**Pemicu:** akun biasa yang aktif mengirim request memakai token valid ke `/api/v1/User/{user_id_lain}/ResetPassword`, atau PUT user lain dengan password/role baru. Token melalui `x-api-token` dapat mencapai guard, walaupun dukungan Bearer mempunyai defect terpisah pada F08.

**Dampak:** pengambilalihan akun, privilege escalation, perubahan/penghapusan akun lain, dan pengungkapan daftar user. UUID target bukan pengganti permission. Endpoint Product/Customer/Category juga hanya memeriksa validitas token; kebijakan hak akses CRUD masing-masing belum dinyatakan atau ditegakkan.

**Perbaikan:** satu authentication resolver menghasilkan actor dan status session; policy authorization terpisah memeriksa action/target sebelum mutation. Pisahkan self-service password dari administrasi akun. Terapkan privilege minimum pada role assignment. Pertahankan route/field publik yang ada ketika mengencangkan guard.

**Acceptance:** user biasa menerima 403 untuk reset target lain, role update, create/delete administratif; admin dengan permission sesuai berhasil; denied request tidak memutasi DB; self-service memerlukan password lama; log audit tidak berisi password/token.
