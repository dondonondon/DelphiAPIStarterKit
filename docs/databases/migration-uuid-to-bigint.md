# Database Migration: UUID PK → BIGINT Internal PK

> Generated: 2026-06-18 | Target: MySQL 5.7+ / MariaDB 10.3+ | Engine: InnoDB

---

## 1. Ringkasan Masalah

| Masalah | Tabel Terdampak |
|---|---|
| Primary key menggunakan `CHAR(36)` UUID | `users` (`user_id`), `user_session` (`session_id`) |
| Foreign key antar tabel mengarah ke kolom UUID, bukan internal PK | `access_token.session_id`, `user_session.user_id` |
| Tidak ada `updated_at` untuk audit perubahan | Semua tabel |
| Tidak ada `deleted_at` untuk soft delete | `users`, `user_session`, `access_token` |
| `ROW_FORMAT=COMPACT` pada beberapa tabel | `access_token`, `user_session`, `users` |
| Kolom boolean `revoked` menggunakan `TINYINT(1)` tapi tanpa konsistensi lebar display | `access_token`, `user_session` |

---

## 2. Rekomendasi Desain Final

### Prinsip

| Konsep | Internal PK | Public ID |
|---|---|---|
| Nama kolom | `id` | `user_id`, `session_id` (tetap) |
| Tipe | `BIGINT UNSIGNED NOT NULL AUTO_INCREMENT` | `CHAR(36) NOT NULL` |
| Index | `PRIMARY KEY` | `UNIQUE INDEX` |
| Digunakan untuk | FK internal, JOIN, referential integrity | API response, URL, QR code, integrasi eksternal |
| Terlihat di API | **Tidak** | **Ya** |

### Mapping Kolom Lama → Baru

| Tabel | PK Lama | Internal PK Baru | Public ID (tetap) |
|---|---|---|---|
| `users` | `user_id` CHAR(36) | `id` BIGINT UNSIGNED | `user_id` CHAR(36) |
| `user_session` | `session_id` CHAR(36) | `id` BIGINT UNSIGNED | `session_id` CHAR(36) |
| `access_token` | `token_id` BIGINT (sudah benar) | `id` rename dari `token_id` | — (tidak ada public UUID) |
| `m_role` | `role_id` INT (sudah benar) | `id` rename dari `role_id` | — (tidak ada public UUID) |

> **Catatan**: `access_token` dan `m_role` sudah memiliki PK numerik. Hanya di-rename dari `token_id` → `id` dan `role_id` → `id` untuk konsistensi, dengan tetap mempertahankan nama lama sebagai alias jika diperlukan backward compatibility.

---

## 3. Tabel Mapping ID Lama ke Baru

```
┌──────────────────────────────────────────────────────────────────┐
│ users                                                           │
│   OLD PK: user_id CHAR(36)                                      │
│   NEW PK: id BIGINT UNSIGNED AUTO_INCREMENT                     │
│   PUBLIC: user_id CHAR(36) UNIQUE                                │
├──────────────────────────────────────────────────────────────────┤
│ user_session                                                     │
│   OLD PK: session_id CHAR(36)                                    │
│   NEW PK: id BIGINT UNSIGNED AUTO_INCREMENT                      │
│   PUBLIC: session_id CHAR(36) UNIQUE                             │
│   OLD FK: user_id CHAR(36) → users.user_id                       │
│   NEW FK: user_internal_id BIGINT UNSIGNED → users.id            │
├──────────────────────────────────────────────────────────────────┤
│ access_token                                                     │
│   OLD PK: token_id BIGINT AUTO_INCREMENT                         │
│   NEW PK: id BIGINT UNSIGNED AUTO_INCREMENT (rename)             │
│   OLD FK: session_id CHAR(36) → user_session.session_id          │
│   NEW FK: session_internal_id BIGINT UNSIGNED → user_session.id  │
├──────────────────────────────────────────────────────────────────┤
│ m_role                                                           │
│   OLD PK: role_id INT AUTO_INCREMENT                             │
│   NEW PK: id INT AUTO_INCREMENT (rename, tetap INT karena kecil) │
│   OLD FK (users): role_id INT → m_role.role_id                   │
│   NEW FK (users): role_internal_id INT → m_role.id               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. Script ALTER TABLE Bertahap

### Tahap 1 — Tambah kolom `id` internal PK & `updated_at`/`deleted_at`

```sql
-- ============================================
-- TAHAP 1: Tambah kolom baru (tanpa hapus apapun)
-- Aplikasi tetap jalan, tidak ada breaking change
-- ============================================

-- 1a. users: tambah internal id + timestamp audit
ALTER TABLE `users`
  ADD COLUMN `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  ADD UNIQUE INDEX `uq_users_public_id` (`user_id`),
  ROW_FORMAT=DYNAMIC;

-- 1b. user_session: tambah internal id + timestamp audit
ALTER TABLE `user_session`
  ADD COLUMN `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  ADD UNIQUE INDEX `uq_session_public_id` (`session_id`),
  ROW_FORMAT=DYNAMIC;

-- 1c. access_token: rename token_id → id, tambah timestamp audit
ALTER TABLE `access_token`
  CHANGE COLUMN `token_id` `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  ROW_FORMAT=DYNAMIC;

-- 1d. m_role: rename role_id → id, tambah timestamp audit
ALTER TABLE `m_role`
  CHANGE COLUMN `role_id` `id` INT NOT NULL AUTO_INCREMENT,
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  DROP INDEX `role_name`,
  ADD UNIQUE INDEX `uq_role_name` (`role_name`),
  ROW_FORMAT=DYNAMIC;
```

### Tahap 2 — Tambah kolom FK internal baru (parallel dengan FK lama)

```sql
-- ============================================
-- TAHAP 2: Tambah kolom foreign key internal
-- FK lama MASIH aktif, FK baru nullable dulu
-- ============================================

-- 2a. user_session: tambah kolom FK internal ke users.id
ALTER TABLE `user_session`
  ADD COLUMN `user_internal_id` BIGINT UNSIGNED NULL AFTER `user_id`,
  ADD INDEX `idx_session_user_internal` (`user_internal_id`);

-- 2b. access_token: tambah kolom FK internal ke user_session.id
ALTER TABLE `access_token`
  ADD COLUMN `session_internal_id` BIGINT UNSIGNED NULL AFTER `session_id`,
  ADD INDEX `idx_token_session_internal` (`session_internal_id`);

-- 2c. users: tambah kolom FK internal ke m_role.id
ALTER TABLE `users`
  ADD COLUMN `role_internal_id` INT NULL AFTER `role_id`,
  ADD INDEX `idx_user_role_internal` (`role_internal_id`);
```

### Tahap 3 — Populasi FK internal dari FK UUID lama

```sql
-- ============================================
-- TAHAP 3: Isi kolom FK internal berdasarkan join
-- ============================================

-- 3a. Isi user_session.user_internal_id dari users
UPDATE `user_session` us
INNER JOIN `users` u ON us.`user_id` = u.`user_id`
SET us.`user_internal_id` = u.`id`;

-- 3b. Isi access_token.session_internal_id dari user_session
UPDATE `access_token` at
INNER JOIN `user_session` us ON at.`session_id` = us.`session_id`
SET at.`session_internal_id` = us.`id`;

-- 3c. Isi users.role_internal_id dari m_role
UPDATE `users` u
INNER JOIN `m_role` r ON u.`role_id` = r.`id`
SET u.`role_internal_id` = r.`id`;
```

### Tahap 4 — Verifikasi data FK internal (harus 0 row)

```sql
-- ============================================
-- TAHAP 4: Verifikasi tidak ada FK internal yang NULL
-- Jika ada row, data corrupt — perbaiki dulu
-- ============================================

SELECT COUNT(*) AS 'null_user_internal' FROM `user_session` WHERE `user_internal_id` IS NULL;
SELECT COUNT(*) AS 'null_session_internal' FROM `access_token` WHERE `session_internal_id` IS NULL;
SELECT COUNT(*) AS 'null_role_internal' FROM `users` WHERE `role_id` IS NOT NULL AND `role_internal_id` IS NULL;
```

### Tahap 5 — Set FK internal NOT NULL & drop FK lama

```sql
-- ============================================
-- TAHAP 5: Ganti FK lama dengan FK baru
-- ⚠️ DOWNTIME MUNGKIN DIPERLUKAN (short lock)
-- ============================================

-- 5a. user_session: drop FK lama, set FK baru NOT NULL, tambah FK baru
ALTER TABLE `user_session`
  DROP FOREIGN KEY `fk_session_user`,
  MODIFY COLUMN `user_internal_id` BIGINT UNSIGNED NOT NULL,
  ADD CONSTRAINT `fk_session_user` FOREIGN KEY (`user_internal_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT;

-- 5b. access_token: drop FK lama, set FK baru NOT NULL, tambah FK baru
ALTER TABLE `access_token`
  DROP FOREIGN KEY `fk_token_session`,
  DROP INDEX `fk_token_session`,
  MODIFY COLUMN `session_internal_id` BIGINT UNSIGNED NOT NULL,
  ADD CONSTRAINT `fk_token_session` FOREIGN KEY (`session_internal_id`) REFERENCES `user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT;

-- 5c. users: drop FK lama, set FK baru NOT NULL, tambah FK baru
ALTER TABLE `users`
  DROP FOREIGN KEY `fk_user_role`,
  DROP INDEX `fk_user_role`,
  MODIFY COLUMN `role_internal_id` INT NOT NULL,
  ADD CONSTRAINT `fk_user_role` FOREIGN KEY (`role_internal_id`) REFERENCES `m_role` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
```

### Tahap 6 — Bersihkan kolom FK UUID lama (opsional, bisa ditunda)

```sql
-- ============================================
-- TAHAP 6: Drop kolom FK UUID lama
-- Tunda sampai aplikasi 100%% sudah pakai FK internal
-- ============================================

-- Hanya jalankan setelah semua aplikasi sudah di-deploy ulang
-- dan tidak ada query yang menggunakan kolom-kolom ini:

-- ALTER TABLE `user_session` DROP COLUMN `user_id`;
-- ALTER TABLE `access_token` DROP COLUMN `session_id`;
-- ALTER TABLE `users` DROP COLUMN `role_id`;
```

---

## 5. Script CREATE TABLE Versi Final

```sql
-- ============================================
-- STRUKTUR FINAL — Setelah semua migration
-- ============================================

-- ----------------------------
-- Table: users
-- ----------------------------
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` CHAR(36) NOT NULL,
  `username` VARCHAR(50) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `fullname` VARCHAR(100) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NULL DEFAULT 1,
  `role_internal_id` INT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_users_public_id` (`user_id`),
  UNIQUE INDEX `uq_users_username` (`username`),
  INDEX `idx_users_role` (`role_internal_id`),
  CONSTRAINT `fk_users_role` FOREIGN KEY (`role_internal_id`) REFERENCES `m_role` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table: user_session
-- ----------------------------
CREATE TABLE `user_session` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` CHAR(36) NOT NULL,
  `user_internal_id` BIGINT UNSIGNED NOT NULL,
  `device_id` VARCHAR(100) NOT NULL,
  `device_name` VARCHAR(100) NULL DEFAULT NULL,
  `user_agent` VARCHAR(255) NULL DEFAULT NULL,
  `ip_address` VARCHAR(45) NULL DEFAULT NULL,
  `expires_at` DATETIME NOT NULL,
  `revoked` TINYINT(1) NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_session_public_id` (`session_id`),
  INDEX `idx_session_user` (`user_internal_id`),
  INDEX `idx_session_active` (`user_internal_id`, `revoked`, `expires_at`),
  CONSTRAINT `fk_session_user` FOREIGN KEY (`user_internal_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table: access_token
-- ----------------------------
CREATE TABLE `access_token` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` CHAR(64) NOT NULL,
  `session_internal_id` BIGINT UNSIGNED NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `revoked` TINYINT(1) NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_token_hash` (`token_hash`),
  INDEX `idx_token_active` (`revoked`, `expires_at`),
  INDEX `idx_token_session` (`session_internal_id`),
  CONSTRAINT `fk_token_session` FOREIGN KEY (`session_internal_id`) REFERENCES `user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table: m_role
-- ----------------------------
CREATE TABLE `m_role` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `role_name` VARCHAR(50) NOT NULL,
  `description` VARCHAR(150) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NULL DEFAULT 1,
  `is_superadmin` TINYINT(1) NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_role_name` (`role_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;
```

---

## 6. Catatan Perubahan di Aplikasi/Backend

### 6.1 Query JOIN — Perlu Diupdate

**Sebelum:**
```sql
SELECT * FROM access_token at
INNER JOIN user_session us ON us.session_id = at.session_id
INNER JOIN users u ON u.user_id = us.user_id
```

**Sesudah (FK internal untuk JOIN, public UUID untuk WHERE):**
```sql
SELECT u.user_id, us.session_id, at.token_hash
FROM access_token at
INNER JOIN user_session us ON us.id = at.session_internal_id
INNER JOIN users u ON u.id = us.user_internal_id
WHERE u.user_id = :public_user_id
  AND us.session_id = :public_session_id;
```

### 6.2 Repository Pascal — Perubahan Minimal

Karena public UUID tetap ada di kolom `user_id` dan `session_id`, **kode API hampir tidak berubah**. Yang perlu disesuaikan:

1. **Semua JOIN internal** — ganti dari `ON UUID` ke `ON internal_id`
2. **INSERT** — tetap insert `user_id` UUID, `id` auto-increment otomatis
3. **SELECT by UUID** — query `WHERE user_id = :uid` tetap jalan karena ada UNIQUE INDEX
4. **Response API** — tidak ada perubahan, `user_id` dan `session_id` tetap muncul di JSON

### 6.3 Repository Pascal — Contoh Perubahan

```pascal
// Sebelum — JOIN via UUID
QueryFunction.SQLAdd(Result,
  'SELECT us.user_id ' +
  'FROM access_token at ' +
  'INNER JOIN user_session us ON us.session_id = at.session_id ' +
  'WHERE at.token_hash = :hash',
  True
);

// Sesudah — JOIN via internal id
QueryFunction.SQLAdd(Result,
  'SELECT u.user_id ' +
  'FROM access_token at ' +
  'INNER JOIN user_session us ON us.id = at.session_internal_id ' +
  'INNER JOIN users u ON u.id = us.user_internal_id ' +
  'WHERE at.token_hash = :hash',
  True
);
```

### 6.4 Yang Tidak Berubah

| Komponen | Status |
|---|---|
| Kolom `user_id` di response API | **Tidak berubah** |
| Kolom `session_id` di response API | **Tidak berubah** |
| Header `x-api-token` / `access-token` / `Authorization` | **Tidak berubah** |
| Endpoint URL (`/api/v1/User/{user_id}`) | **Tidak berubah** |
| Logic validasi UUID | **Tidak berubah** |
| Postman collection | **Tidak berubah** |

---

## 7. Catatan Risiko Migration

| Risiko | Level | Mitigasi |
|---|---|---|
| ALTER TABLE pada tabel besar bisa lock lama | **MEDIUM** | Jalankan saat maintenance window; gunakan `pt-online-schema-change` untuk production besar |
| Foreign key baru gagal karena data orphans | **LOW** | Tahap 4 memverifikasi tidak ada NULL sebelum Tahap 5 |
| Aplikasi masih query pakai kolom FK lama | **MEDIUM** | Jangan jalankan Tahap 6 sebelum semua aplikasi deploy ulang |
| UUID `user_id` kosong pada row baru | **LOW** | Tahap 1 hanya tambah kolom, data existing tidak disentuh |
| `token_id` diganti jadi `id` — kode aplikasi referensi `token_id` | **HIGH** | Jangan rename `token_id` dulu. Alternatif: tetap `token_id` sebagai nama, atau tambah `id` lalu deprecate `token_id` |

### Rekomendasi Khusus untuk `access_token`

Karena `access_token.token_id` sudah dipakai di aplikasi, **jangan rename ke `id`**. Cukup rename `role_id` di `m_role` karena itu table master kecil. Untuk `access_token`, biarkan `token_id` tetap sebagai PK.

**Revisi Tahap 1c — lebih aman:**
```sql
-- JANGAN rename token_id. Biarkan sebagai internal PK.
-- Hanya tambah timestamp audit.
ALTER TABLE `access_token`
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  ROW_FORMAT=DYNAMIC;
```

### Rekomendasi Khusus untuk `m_role`

`m_role.role_id` disebut di foreign key `fk_user_role`. Jika rename ke `id`, pastikan Tahap 5c berhasil dulu sebelum rename. Atau lebih aman: **jangan rename `role_id`**, biarkan sebagai PK internal. Tidak ada public UUID untuk role. Cukup tambah `updated_at`/`deleted_at`.

**Revisi Tahap 1d — lebih aman:**
```sql
ALTER TABLE `m_role`
  ADD COLUMN `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`,
  ADD COLUMN `deleted_at` DATETIME NULL DEFAULT NULL AFTER `updated_at`,
  ROW_FORMAT=DYNAMIC;
```

---

## 8. Rekomendasi Final yang Direvisi (Backward Compatible)

Setelah mempertimbangkan backward compatibility, **hanya 2 tabel yang benar-benar perlu perubahan struktur PK**:

| Tabel | PK Sekarang | PK Baru | Public ID | Catatan |
|---|---|---|---|---|
| `users` | `user_id` CHAR(36) | `id` BIGINT UNSIGNED | `user_id` CHAR(36) | Perlu migration |
| `user_session` | `session_id` CHAR(36) | `id` BIGINT UNSIGNED | `session_id` CHAR(36) | Perlu migration |
| `access_token` | `token_id` BIGINT | **tetap** `token_id` | — | Aman, tidak diubah |
| `m_role` | `role_id` INT | **tetap** `role_id` | — | Aman, tidak diubah |

FK yang perlu diubah:
| FK | Dari | Ke |
|---|---|---|
| `user_session` → `users` | `user_id` CHAR(36) | `user_internal_id` BIGINT → `users.id` |
| `access_token` → `user_session` | `session_id` CHAR(36) | `session_internal_id` BIGINT → `user_session.id` |
| `users` → `m_role` | `role_id` INT | **tetap** (sudah integer FK) |
