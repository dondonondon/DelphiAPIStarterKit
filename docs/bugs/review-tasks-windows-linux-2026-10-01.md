# Task hasil review DelphiAPIStarterKit — Windows dan Linux

Tanggal: **1 Oktober 2026**. Sumber: [full-review-windows-linux-2026-10-01.md](full-review-windows-linux-2026-10-01.md).

**46 temuan dibagi menjadi 12 task kategori**, dengan satu owner utama untuk setiap F01–F46. Distribusi: 1 P0, 13 P1, 28 P2, 4 P3; 39 CONFIRMED dan 7 CONTEXT-DEPENDENT. Semua task **BELUM DIMULAI**; pemecahan dokumen tidak berarti bug telah diperbaiki.

Master tetap baseline evidence lengkap. Setiap task berisi langkah perbaikan, dependencies, acceptance, checklist per ID dan salinan lengkap temuan kategori. Path/config Windows/Linux, inventory architecture, API/database matrix serta bukti build/harness tetap pada master bagian 2–7.

**Paket satu shot:** [indeks empat wave](waves-windows-linux-2026-10-01.md) — wave-01: T01–T03; wave-02: T04–T06; wave-03: T07–T09; wave-04: T10–T12.

**Revisi scope Auth (1 Oktober 2026):** [kontrak auth-v2](auth-production-contract-2026-10-01.md) menambahkan permission catalog,
refresh rotation, one-time recovery, endpoint self-service/session/role, dan bootstrap tanpa credential bawaan.
SQL baseline/sample target sudah diperbarui. T01–T07/T09–T12 mempunyai langkah Auth/dependency tambahan;
status BELUM DIMULAI tetap merujuk implementasi aplikasi/acceptance, bukan penulisan schema.
Jangan menganggap 46 temuan historis telah tertutup atau SQL ini sudah kompatibel dengan Pascal existing.

**Sinkronisasi paket Auth:** seluruh `wave-01.md`–`wave-04.md` dan
`prompt-execute-wave-01.md`–`prompt-execute-wave-04.md` kini memuat kontrak auth-v2 eksplisit,
scope/dependency/gate per wave serta salinan prompt yang sama. Wave-02 menjaga audit/typed IO/domain
transaction; wave-03 menjaga config/security settings/bounded session queries; wave-04 menjaga
readiness/migration/architecture. Status eksekusi dan owner utama 46 temuan tidak berubah.

## 1. Daftar task per kategori

Prioritas adalah severity tertinggi temuan kategori, bukan urutan wajib menyelesaikan seluruh task. Containment dapat mendahului hardening lain dalam kategori yang sama.

| Task | Kategori | Prioritas | Temuan utama | Status |
|---|---|---|---|---|
| [T01](task-01-authorization-dan-permission.md) | Authorization dan permission per action | P0 | F01 | BLOCKED |
| [T02](task-02-authentication-password-dan-session.md) | Authentication, password, dan lifecycle session | P1 | F03, F04, F05, F06, F43, F44, F45 | BLOCKED |
| [T03](task-03-http-routing-dan-error-boundary.md) | HTTP transport, routing, dan error boundary | P1 | F08, F09, F24, F25, F26, F37 | BLOCKED |
| [T04](task-04-logging-dan-observability.md) | Logging, observability, dan preservasi exception | P1 | F10, F23 | BERJALAN |
| [T05](task-05-request-response-json-dan-waktu.md) | Request/response JSON, tipe data, dan waktu | P1 | F02, F11, F15, F16, F17, F22, F27 | BERJALAN |
| [T06](task-06-database-transaksi-dan-validasi-domain.md) | Database, transaksi, dan validasi domain | P2 | F18, F19, F20, F21, F42 | BERJALAN |
| [T07](task-07-collection-pagination-dan-kapasitas.md) | Collection completeness, pagination, dan kapasitas | P1 | F12, F36 | BERJALAN |
| [T08](task-08-storage-upload-dan-stream.md) | Storage, upload/download, dan stream ownership | P1 | F07, F14, F38 | BERJALAN |
| [T09](task-09-config-path-dan-persistence.md) | Config path, load/save, dan secret persistence | P1 | F13, F28, F39, F46 | BERJALAN |
| [T10](task-10-hosting-build-dan-deployment.md) | Hosting, build, dan deployment Windows/Linux | P2 | F29, F30, F31, F32, F33, F34, F41 | BERJALAN |
| [T11](task-11-schema-migration-dan-kompatibilitas.md) | Schema migration dan kompatibilitas database | P2 | F35 | BERJALAN |
| [T12](task-12-architecture-dan-centralization.md) | Architecture dan pemusatan concern teknis | P3 | F40 | BELUM DIMULAI |

## 2. Urutan pengerjaan dan dependensi

Eksekusi menggunakan empat file pada [indeks wave](waves-windows-linux-2026-10-01.md). Tabel berikut adalah tahap prioritas risiko/subpekerjaan, bukan nomor file wave. Dependency minimum boleh dikerjakan lebih awal dan dicatat pada task owner asal; containment tidak menunggu seluruh task dependency selesai.

| Tahap prioritas | Pekerjaan yang dimulai | Alasan/gate |
|---|---|---|
| 0 | [T10](task-10-hosting-build-dan-deployment.md) langkah **T10.a / F34** | Amankan build agar tidak force-kill instance lain; berlaku sebelum build code, bukan menunda analisis/dokumentasi. |
| 1 | [T01](task-01-authorization-dan-permission.md) F01; [T05](task-05-request-response-json-dan-waktu.md) F02; [T02](task-02-authentication-password-dan-session.md) F03–F06; [T08](task-08-storage-upload-dan-stream.md) F07/F14 | Containment authorization, secret echo, credential lifecycle, memory/storage exposure. |
| 2 | [T09](task-09-config-path-dan-persistence.md) F13/F28; [T04](task-04-logging-dan-observability.md); [T03](task-03-http-routing-dan-error-boundary.md) | Config/path, logger dan safe transport/error boundary; interfaces disepakati incremental. |
| 3 | [T05](task-05-request-response-json-dan-waktu.md) sisa typed IO; [T06](task-06-database-transaksi-dan-validasi-domain.md); [T07](task-07-collection-pagination-dan-kapasitas.md); [T02](task-02-authentication-password-dan-session.md) F44/F45 | Type/validation, transactions, complete paginated data, auth bounds/rate policy. |
| 4 | [T08](task-08-storage-upload-dan-stream.md) F38; [T09](task-09-config-path-dan-persistence.md) F39/F46; [T10](task-10-hosting-build-dan-deployment.md) sisa hosting; [T03](task-03-http-routing-dan-error-boundary.md) F37 | File/config hardening, tracking config, readiness/stop/native package, CORS deployment. |
| 5 | [T11](task-11-schema-migration-dan-kompatibilitas.md) final validation | Reconcile target schema auth/domain; analisis guide dapat dimulai sejak awal pada clone. |
| 6 | [T12](task-12-architecture-dan-centralization.md); [T02](task-02-authentication-password-dan-session.md) F43 bila belum selesai | Authority/facade/dependency setelah behavior regression; legacy helper audit boleh lebih awal. |

Area koordinasi tanpa duplicate ownership:

- **Role:** T01 permission, T06 reference/bounds, T05 public role_id name/type compatibility.
- **Password:** T01 hak actor/target, T02 hashing/revoke, T05 no echo, T06 mutation outcome.
- **JSON collection:** T05 type/envelope, T07 fetch/pagination; satu serializer tidak saling menimpa fix.
- **Path:** T09 config/data/log resolver, T08 persistence, T04 logger, T10 readiness/identity.
- **Schema:** T02 auth delta, T06 domain delta, T11 legacy migration/final reconciliation.
- **Routing:** T03 behavior guards, T12 composition/dependency cleanup.

## 3. Aturan eksekusi bersama

- Pertahankan feature-first flat modules sesuai [structure.md](../information/structure.md); tidak memindahkan semua service/repository ke global folders.
- Baca ulang actual source dan [AGENTS.md](../../AGENTS.md); snapshot/line references dapat berubah selama implementasi.
- Satu owner utama per finding; dependencies bukan duplikasi pekerjaan atau status.
- Public routes/fields/helpers tetap compatible kecuali versioned migration sengaja. Endpoint changes memperbarui API docs dan [Postman](../api/postman.collection.json).
- Unit baru eksplisit dalam DPR dan mapping existing di-update. Hindari custom cryptography/dependency yang tidak diperlukan.
- Code changes memakai build sesuai aturan setelah T10.a aman. **Linux64 cross-build bukan Linux runtime proof**; validation relevan mencakup Win32/Win64/Linux64.
- Regression menguji outcome/state berisiko; master build/harness hanya baseline, bukan bukti fix telah lulus.
- CONTEXT-DEPENDENT butuh actual consumer/deployment/policy evidence; not applicable memerlukan scope/batas yang terbukti.
- Migration hanya pada clone schema asal yang dinyatakan dalam task; dokumen ini tidak memberi instruksi production mutation.
- Preserve unrelated dirty work/runtime config lokal dan read-only `/temp-file/`; evidence tanpa password/key/token actual.

## 4. Matrix ownership seluruh temuan

Severity/label dipertahankan; semua F01–F46 memiliki satu owner utama dan tidak dinaikkan menjadi runtime verified.

| Temuan | Severity | Bukti | Owner utama | Ringkasan |
|---|---|---|---|---|
| F01 | P0 | CONFIRMED | [T01](task-01-authorization-dan-permission.md) | Operasi administrasi user tanpa otorisasi |
| F02 | P1 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Password plaintext muncul pada response |
| F03 | P1 | CONFIRMED | [T02](task-02-authentication-password-dan-session.md) | Token Linux memakai UUID berbasis waktu |
| F04 | P1 | CONFIRMED | [T02](task-02-authentication-password-dan-session.md) | Lifecycle refresh belum aman dan konsisten |
| F05 | P1 | CONFIRMED | [T02](task-02-authentication-password-dan-session.md) | Password hashing terlalu cepat dan tidak versioned |
| F06 | P1 | CONFIRMED | [T02](task-02-authentication-password-dan-session.md) | Password berubah tetapi credential lama tetap aktif |
| F07 | P1 | CONFIRMED | [T08](task-08-storage-upload-dan-stream.md) | Double free pada pengiriman gambar |
| F08 | P1 | CONFIRMED | [T03](task-03-http-routing-dan-error-boundary.md) | Bearer token tidak melewati transport |
| F09 | P1 | CONFIRMED | [T03](task-03-http-routing-dan-error-boundary.md) | DB exception keluar ke HTTP dan connection bocor |
| F10 | P1 | CONFIRMED | [T04](task-04-logging-dan-observability.md) | Logger dapat menggagalkan error handling |
| F11 | P1 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Response JSON invalid dan tipe string berubah |
| F12 | P1 | CONFIRMED | [T07](task-07-collection-pagination-dan-kapasitas.md) | GET collection dapat kehilangan row |
| F13 | P1 | CONFIRMED | [T09](task-09-config-path-dan-persistence.md) | Path config/load/save tidak tunggal |
| F14 | P1 | CONFIRMED | [T08](task-08-storage-upload-dan-stream.md) | Upload `/test` aktif tanpa autentikasi/quota |
| F15 | P2 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | JSON invalid tidak ditolak pada boundary |
| F16 | P2 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Presisi number request hilang |
| F17 | P2 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Array schema mengikuti posisi property |
| F18 | P2 | CONFIRMED | [T06](task-06-database-transaksi-dan-validasi-domain.md) | Conflict soft delete tidak selaras dengan UNIQUE |
| F19 | P2 | CONFIRMED | [T06](task-06-database-transaksi-dan-validasi-domain.md) | UPDATE melaporkan state yang tidak tersimpan |
| F20 | P2 | CONFIRMED | [T06](task-06-database-transaksi-dan-validasi-domain.md) | Validasi Users tidak mengikuti schema/reference |
| F21 | P2 | CONFIRMED | [T06](task-06-database-transaksi-dan-validasi-domain.md) | Price tidak mempunyai range/scale storage |
| F22 | P2 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Nama field role berbeda antar-operasi |
| F23 | P2 | CONFIRMED | [T04](task-04-logging-dan-observability.md) | Exception service hilang dari log |
| F24 | P2 | CONFIRMED | [T03](task-03-http-routing-dan-error-boundary.md) | Unknown route class menjadi 500 |
| F25 | P2 | CONFIRMED | [T03](task-03-http-routing-dan-error-boundary.md) | Route shape tidak dibatasi ketat |
| F26 | P2 | CONFIRMED | [T03](task-03-http-routing-dan-error-boundary.md) | Content-Encoding bukan charset |
| F27 | P2 | CONFIRMED | [T05](task-05-request-response-json-dan-waktu.md) | Unix time bergeser sesuai timezone host |
| F28 | P2 | CONFIRMED | [T09](task-09-config-path-dan-persistence.md) | Config reader mengubah secret |
| F29 | P2 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Ready diumumkan sebelum dependensi tervalidasi |
| F30 | P2 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Exit code startup failure terlihat sukses |
| F31 | P2 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Shutdown belum terkelola |
| F32 | P2 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Port dokumentasi berbeda dari server |
| F33 | P2 | CONTEXT-DEPENDENT | [T10](task-10-hosting-build-dan-deployment.md) | Native library path terlalu spesifik |
| F34 | P2 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Build script mematikan process berdasarkan nama |
| F35 | P2 | CONFIRMED | [T11](task-11-schema-migration-dan-kompatibilitas.md) | Migration guide tidak authoritative |
| F36 | P2 | CONFIRMED | [T07](task-07-collection-pagination-dan-kapasitas.md) | Collection tidak mempunyai batas yang disengaja |
| F37 | P2 | CONTEXT-DEPENDENT | [T03](task-03-http-routing-dan-error-boundary.md) | Browser preflight/CORS belum tersedia |
| F38 | P2 | CONTEXT-DEPENDENT | [T08](task-08-storage-upload-dan-stream.md) | Helper file/path/download belum aman sebagai API umum |
| F39 | P2 | CONTEXT-DEPENDENT | [T09](task-09-config-path-dan-persistence.md) | Config save dapat kehilangan perubahan concurrent |
| F40 | P3 | CONFIRMED | [T12](task-12-architecture-dan-centralization.md) | Tanggung jawab teknis belum terpusat sepenuhnya |
| F41 | P3 | CONFIRMED | [T10](task-10-hosting-build-dan-deployment.md) | Artifact Windows dapat saling tertimpa |
| F42 | P3 | CONTEXT-DEPENDENT | [T06](task-06-database-transaksi-dan-validasi-domain.md) | Product masih menampilkan category yang dihapus |
| F43 | P3 | CONTEXT-DEPENDENT | [T02](task-02-authentication-password-dan-session.md) | Nama helper kripto dapat menyesatkan |
| F44 | P2 | CONFIRMED | [T02](task-02-authentication-password-dan-session.md) | Auth input dan metadata session belum mempunyai kontrak ketat |
| F45 | P2 | CONTEXT-DEPENDENT | [T02](task-02-authentication-password-dan-session.md) | Auth endpoint tidak mempunyai throttling aplikasi |
| F46 | P2 | CONFIRMED | [T09](task-09-config-path-dan-persistence.md) | Ignore rule belum melindungi runtime config yang sudah tracked |

## 5. Matrix validasi Windows/Linux

| Area | Validasi minimum | Owner |
|---|---|---|
| Permission/auth | Ordinary/admin/self/other, invalid/revoked/expired, refresh reuse/logout race/reset, limiter/proxy metadata | T01/T02/T03 |
| Secret/logging | Recursive response/log scan, failing/concurrent sink, safe 500/rollback context | T02/T04/T05 |
| JSON/clock | Strict parser, string/Int64/decimal/null/array limits, Unicode bytes, UTC/Jakarta epoch | T03/T05 |
| DB mutations | Conflict/soft-delete, matched-vs-changed, concurrent update/delete, role/price bounds, authoritative response | T06 |
| Collection | 0/1/1000/1001/2500, small rowset, query page limits, stable traversal, memory/latency | T07 |
| Storage | Ownership normal/error/disconnect, auth/quota, containment, partial write/disk-full, OS names/symlink | T08 |
| Config | Different CWD/absolute override/renamed binary, secret whitespace/env precedence, save concurrency/restart, Git tracking | T09 |
| Host | Native bitness/library/TLS, readiness/exit, Ctrl+C Windows/SIGTERM Linux, bounded drain, safe build/artifacts | T10 |
| Migration | Declared legacy clone → target, counts/UUID/FK/nullability, app regression/restore | T11 |
| Architecture | One authority, clean dependency, facade/registry/map compatibility, moved-use-case regression | T12 |

Runtime cases memakai actual OS/identity deployment. Nyatakan MySQL/MariaDB versions diuji; reusable FireDAC pattern bukan bukti operational support Firebird/SQL Server.

## 6. Pelacakan dan penutupan

Update indeks/file task bersamaan. Finding checklist dicentang setelah acceptance evidence. Status: BELUM DIMULAI, BERJALAN, SELESAI, atau BLOCKED dengan blocker konkret.

Catatan hasil task mencakup source/commit/working tree, changed files, IDs/policy/compatibility/migration, build/runtime/DB scenarios/platform/outcome, evidence paths, residual risks/blocker/reopening conditions dan API/config/schema/README/map updates.

**Siap publik belum dinyatakan lulus.** Gate wajib master bagian 7.1 dinilai setelah implementation. BLOCKED tidak dihitung selesai; context tidak applicable harus terbukti secara eksplisit.

## 7. Jejak pemecahan dokumen

- SHA-256 sumber sebelum navigasi: `0a6f1a29fc3b4b31e89009bbab4edbf285ffb7b73194abc504aa86abbd973147`.
- Isi F01–F46/severity/label lengkap dipertahankan pada task owner masing-masing.
- Master tetap disimpan dan diberi link indeks.
- Pekerjaan ini dokumentasi saja; tidak memperbaiki code/runtime config, menjalankan migration atau build baru.

## Eksekusi WAVE-01 — 2026-10-01

T01/T02/T03 BLOCKED hanya pada gate mandatory yang tidak tersedia; implementation/checks independen selesai. Dependency T04-T11 BERJALAN untuk slice minimum dengan owner tetap. F02 dan F34 ditutup; F07 ownership diperbaiki tetapi memory/disconnect gate task asal tetap terbuka. Wave lain tidak dijalankan. Lihat [hasil](wave-01-result.md) dan [matrix seluruh acceptance](evidence/wave-01/acceptance.md).
