# T11 — Schema migration dan kompatibilitas database

Status: **BERJALAN**. Prioritas tertinggi: **P2**. Tanggal pemecahan: **1 Oktober 2026**.

Temuan utama: **F35** (1 CONFIRMED, 0 CONTEXT-DEPENDENT).

Navigasi: [indeks task](review-tasks-windows-linux-2026-10-01.md) · [laporan lengkap](full-review-windows-linux-2026-10-01.md) · [wave-04](wave-04.md).

Baseline: review working tree 1 Oktober 2026, HEAD `358db33b95724f654db00e39fd4f35dc26c0d12c`. Slice minimum WAVE-01 telah diterapkan; sisa task belum dieksekusi. Lokasi/nomor baris lampiran adalah snapshot; baca ulang source sebelum perubahan. Build/harness laporan bukan bukti acceptance task ini.

**Revisi auth-v2 (1 Oktober 2026):** spesifikasi dan SQL target telah diperbarui; status di atas adalah status implementasi aplikasi/acceptance, bukan status penulisan schema. Ikuti [kontrak target Auth](auth-production-contract-2026-10-01.md); lampiran temuan tetap bukti baseline historis.

## 1. Tujuan dan cakupan

Satu prosedur versioned dari schema asal tertentu ke schema tujuan yang sesuai repository final menggantikan migration guide yang bertentangan.

**Cakupan:** docs/databases/migration-uuid-to-bigint.md, assets/databases/demo_delphirest.sql, PK/FK/nullability dan migration artefacts yang diperlukan; execution hanya pada clone/test.

ID di atas dimiliki utama task ini. Dependency merupakan koordinasi; tidak menggandakan owner/status temuan.

## 2. Langkah pengerjaan

- [ ] Baseline/sample SQL auth-v2 tersedia sebagai alternatif fresh-empty import tanpa DROP/IF NOT EXISTS/disabled FK dan tanpa login/session/token seed; jangan pakai sebagai upgrade. Schema data business existing dipertahankan; role/permission catalog baru eksplisit.
- [ ] Target mencakup m_permission/role_permission, role_code, binary versioned password hash/flags/time, session idle/authenticated/revoked metadata, refresh chain composite self-FK, recovery credential dan append-only auth audit.
- [ ] Tambahkan migration terpisah dari numeric schema aktual 1 Oktober 2026: preflight UUID/ASCII/collation, backfill role_code/password/UTC metadata, constraint/index dependency order, revoke legacy credential pada maintenance cutover; password hash direhash aplikasi setelah verifikasi, bukan SQL.
- [ ] Selaraskan kedua DDL dan buktikan import baseline/sample serta invalid FK/CHECK/duplicate/cross-session successor/retention pada MySQL 8.0.16+ dan MariaDB 10.6+ yang dipilih. Versi target adalah requirement, bukan klaim telah dites.

- [ ] Nyatakan schema asal/versi/provider dan target; inventarisasi PK/FK/public UUID/internal IDs, token_id/role_id names dan akun tanpa role.
- [ ] Rekonsiliasi repository/schema delta auth/domain; pisahkan historical discussion dari recommended SQL.
- [ ] Susun add/backfill/constraint/PK/FK/cutover valid tanpa multiple primary keys; tangani legacy null sebelum NOT NULL.
- [ ] Preflight/backup/maintenance/cutover/rollback/recovery dan count/UUID/relationship checks mengikuti actual DDL transaction capabilities.
- [ ] Uji end-to-end/failure/restore pada clone asal yang sama; selaraskan fresh baseline, guide, final schema dan app queries.

## 3. Dependensi dan koordinasi

- Final target membutuhkan [T02](task-02-authentication-password-dan-session.md) auth delta, [T06](task-06-database-transaksi-dan-validasi-domain.md) UNIQUE/reference policy dan [T05](task-05-request-response-json-dan-waktu.md) public role contract.
- Analisis guide dapat segera dimulai; final execution menunggu target disepakati dan clone tersedia. [T10](task-10-hosting-build-dan-deployment.md) memiliki native/provider deployment; guide selesai bukan instruksi production migration.

## 4. Acceptance dan validasi kategori

- [ ] Fresh baseline/sample auth-v2 dengan 12 tabel/import enforced FK/CHECK serta credential-free seed diuji pada provider target; source parser proof saja tidak menutup DB acceptance.
- [ ] Migration numeric-schema->auth-v2 benar-benar diuji pada clone/backfill/credential invalidation/recovery/restore; import baseline tidak digunakan untuk upgrade dan endpoint lama tidak dianggap kompatibel.

- [ ] Declared legacy clone berhasil sampai akhir tanpa multiple PK/SQL invalid; counts/UUID/FK cocok dan final schema sesuai repository.
- [ ] Null role dan legacy naming ditangani tanpa coercion/reference loss; fresh baseline/migration menghasilkan target konsisten.
- [ ] Risk-stage failure dan backup restore/recovery mempunyai bukti; final app login/refresh/CRUD berjalan terhadap migrated clone.
- [ ] Jika clone/tool unavailable, status BLOCKED menyebut schema/version/tool yang diperlukan; SQL tertulis saja tidak menutup F35.

## 5. Checklist penutupan temuan

- [ ] **F35 (P2, CONFIRMED)** — Migration guide tidak authoritative. Acceptance lampiran terpenuhi atau relevansi context ditutup dengan evidence spesifik.

## 6. Definition of done dan catatan hasil

- [ ] Acceptance per temuan/kategori memiliki evidence; CONTEXT-DEPENDENT diselesaikan lewat consumer/deployment/policy actual, bukan asumsi.
- [ ] Jika code berubah, build target relevan sesuai aturan repo. Amankan T10.a sebelum `compile.bat`; catat platform/config/toolchain/hasil.
- [ ] Runtime Windows/Linux, DB/memory/supervisor acceptance relevan mempunyai hasil tersendiri; compiler pass bukan penggantinya.
- [ ] API docs/Postman di-update bila contract berubah; README/config/schema/project mapping hanya bila terdampak.
- [ ] Unrelated dirty work dipertahankan dan tidak ada password/key/token actual di commit/log/evidence.
- [ ] Files changed, hasil regression, compatibility/migration, residual risk dan blocker dicatat. BLOCKED tidak dihitung selesai.

**Catatan hasil WAVE-01 (2026-10-01):** Auth target adds auth_rate_limit and auth_security_event.target_role_id; dedicated numeric shadow clone migration/backfill UTC/role_code/restricted flag/legacy credential revoke + archive restore/re-cutover; fresh baseline/sample remain alternatives, never upgrade.

E5 MariaDB11.4.9 numeric HEAD clone and E7 migration-final.log. Remaining declared production source inventory/key/timezone/backup/restore/cutover/app regression and broader legacy-guide/provider reconciliation; F35 not globally closed. Owner tetap T11; status BERJALAN, bukan SELESAI. Gunakan implementation ini pada wave berikutnya. Detail [hasil WAVE-01](wave-01-result.md) dan [evidence](evidence/wave-01/acceptance.md).

## 7. Temuan sumber lengkap

Isi severity, label, lokasi, risiko, rekomendasi dan acceptance dipertahankan dari master. Relative source links tetap valid karena folder sama. Matrix lintas kategori dan bukti build/harness awal tersedia pada bagian 2–7 laporan lengkap.

### F35 — P2 — CONFIRMED — Migration guide tidak authoritative

**Lokasi:** [migration-uuid-to-bigint.md](../databases/migration-uuid-to-bigint.md#L88), 11/34–39, 88–100, 175–177/205, 237–311, dan 394–436; [schema aktual](../../assets/databases/demo_delphirest.sql#L182), 27/182–195/529.

Schema asal di dokumen sudah mempunyai PK UUID, tetapi tahap awal menambah `AUTO_INCREMENT PRIMARY KEY` tanpa mengganti/drop PK lama: MySQL menolak multiple primary key. Rancangan awal mengganti token_id/role_id ke id, revisi akhir mempertahankannya, sementara baseline/source terkini memakai access_token.id dan m_role.id plus role UUID publik.

Verifikasi memperbolehkan user role lama NULL, lalu tahap berikut memaksa role baru NOT NULL. Baseline aktual user role nullable. Dokumen memuat beberapa desain yang saling bertentangan sebagai langkah operasional.

**Dampak:** upgrade gagal/parsial, executable tidak cocok schema, operator tidak mempunyai satu prosedur benar. Script baseline yang menggunakan DROP TABLE tidak boleh dipakai sebagai upgrade data produksi.

**Perbaikan:** satu prosedur versioned dengan schema asal/tujuan eksplisit, pemeriksaan constraint, backfill, transisi PK/FK berurutan, nullability policy, backup/rollback dan cutover aplikasi. Pisahkan diskusi historis dari perintah yang direkomendasikan.

**Acceptance:** clone legacy schema tertentu dimigrasi sampai akhir; count/UUID/relasi tidak berubah; schema final cocok dengan repository; akun tanpa role ditangani; migration failure/recovery diuji. Tidak ada SQL migration yang dijalankan pada review ini.
