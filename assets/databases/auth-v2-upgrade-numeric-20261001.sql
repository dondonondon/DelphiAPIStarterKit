-- Auth-v2 numeric upgrade SHADOW phase, not a fresh-baseline import.

-- Run only via scripts/migrate-auth-v2-clone.py after its preflight and backup.

SET SESSION time_zone = '+00:00';

CREATE TABLE `auth_v2_m_role` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `role_code` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `role_name` varchar(50) NOT NULL,
  `description` varchar(150) NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `is_superadmin` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  `deleted_at` datetime(6) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_role_public_id` (`role_id`),
  UNIQUE KEY `uq_role_code` (`role_code`),
  UNIQUE KEY `uq_role_name` (`role_name`),
  KEY `idx_role_active` (`deleted_at`, `is_active`),
  CONSTRAINT `v2_ck_role_flags` CHECK (`is_active` IN (0, 1) AND `is_superadmin` IN (0, 1))
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_m_permission` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `permission_code` varchar(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `description` varchar(150) NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_permission_code` (`permission_code`),
  CONSTRAINT `v2_ck_permission_active` CHECK (`is_active` IN (0, 1))
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_role_permission` (
  `role_internal_id` int UNSIGNED NOT NULL,
  `permission_internal_id` int UNSIGNED NOT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`role_internal_id`, `permission_internal_id`),
  KEY `idx_role_permission_permission` (`permission_internal_id`),
  CONSTRAINT `v2_fk_role_permission_role` FOREIGN KEY (`role_internal_id`) REFERENCES `auth_v2_m_role` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `v2_fk_role_permission_permission` FOREIGN KEY (`permission_internal_id`) REFERENCES `auth_v2_m_permission` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_users` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `username` varchar(50) NOT NULL,
  `password_hash` varchar(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `password_changed_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `must_change_password` tinyint(1) NOT NULL DEFAULT 1,
  `fullname` varchar(100) NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `role_internal_id` int UNSIGNED NULL DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  `deleted_at` datetime(6) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_public_id` (`user_id`),
  UNIQUE KEY `uq_users_username` (`username`),
  KEY `idx_users_role` (`role_internal_id`),
  KEY `idx_users_active` (`deleted_at`, `is_active`),
  KEY `idx_users_created` (`created_at`),
  CONSTRAINT `v2_fk_users_role` FOREIGN KEY (`role_internal_id`) REFERENCES `auth_v2_m_role` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `v2_ck_users_flags` CHECK (`is_active` IN (0, 1) AND `must_change_password` IN (0, 1)),
  CONSTRAINT `v2_ck_users_hash_present` CHECK (CHAR_LENGTH(`password_hash`) > 0)
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_user_session` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `user_internal_id` bigint UNSIGNED NOT NULL,
  `device_id` varchar(100) NOT NULL,
  `device_name` varchar(100) NULL DEFAULT NULL,
  `user_agent` varchar(255) NULL DEFAULT NULL,
  `ip_address` varchar(45) NULL DEFAULT NULL,
  `authenticated_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `last_seen_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `idle_expires_at` datetime(6) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `revoked_at` datetime(6) NULL DEFAULT NULL,
  `revocation_reason` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  `deleted_at` datetime(6) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_session_public_id` (`session_id`),
  KEY `idx_session_active` (`user_internal_id`, `revoked`, `expires_at`, `deleted_at`),
  KEY `idx_session_device` (`user_internal_id`, `device_id`, `revoked`),
  KEY `idx_session_cleanup` (`expires_at`, `id`),
  CONSTRAINT `v2_fk_session_user` FOREIGN KEY (`user_internal_id`) REFERENCES `auth_v2_users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `v2_ck_session_revoked` CHECK (`revoked` IN (0, 1)),
  CONSTRAINT `v2_ck_session_expiry` CHECK (`idle_expires_at` <= `expires_at` AND `expires_at` > `created_at` AND `idle_expires_at` > `created_at`)
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_access_token` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `session_internal_id` bigint UNSIGNED NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `revoked_at` datetime(6) NULL DEFAULT NULL,
  `revocation_reason` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  `deleted_at` datetime(6) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_access_token_hash` (`token_hash`),
  KEY `idx_token_session_active` (`session_internal_id`, `revoked`, `expires_at`, `deleted_at`),
  KEY `idx_token_cleanup` (`expires_at`, `id`),
  CONSTRAINT `v2_fk_token_session` FOREIGN KEY (`session_internal_id`) REFERENCES `auth_v2_user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `v2_ck_token_revoked` CHECK (`revoked` IN (0, 1)),
  CONSTRAINT `v2_ck_token_expiry` CHECK (`expires_at` > `created_at`)
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_refresh_token` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `session_internal_id` bigint UNSIGNED NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `consumed_at` datetime(6) NULL DEFAULT NULL,
  `replaced_by_internal_id` bigint UNSIGNED NULL DEFAULT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `revoked_at` datetime(6) NULL DEFAULT NULL,
  `revocation_reason` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_refresh_token_hash` (`token_hash`),
  UNIQUE KEY `uq_refresh_session_id` (`session_internal_id`, `id`),
  KEY `idx_refresh_session_state` (`session_internal_id`, `revoked`, `consumed_at`, `expires_at`),
  KEY `idx_refresh_replacement` (`session_internal_id`, `replaced_by_internal_id`),
  KEY `idx_refresh_cleanup` (`expires_at`, `id`),
  CONSTRAINT `v2_fk_refresh_session` FOREIGN KEY (`session_internal_id`) REFERENCES `auth_v2_user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `v2_fk_refresh_replacement` FOREIGN KEY (`session_internal_id`, `replaced_by_internal_id`) REFERENCES `auth_v2_refresh_token` (`session_internal_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `v2_ck_refresh_revoked` CHECK (`revoked` IN (0, 1)),
  CONSTRAINT `v2_ck_refresh_expiry` CHECK (`expires_at` > `created_at`),
  CONSTRAINT `v2_ck_refresh_consumed_time` CHECK (`consumed_at` IS NULL OR `consumed_at` >= `created_at`)
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_password_reset_token` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `user_internal_id` bigint UNSIGNED NOT NULL,
  `issued_by_user_internal_id` bigint UNSIGNED NULL DEFAULT NULL,
  `purpose` varchar(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'password_reset',
  `expires_at` datetime(6) NOT NULL,
  `consumed_at` datetime(6) NULL DEFAULT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `revoked_at` datetime(6) NULL DEFAULT NULL,
  `revocation_reason` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_password_reset_hash` (`token_hash`),
  KEY `idx_password_reset_user` (`user_internal_id`, `revoked`, `consumed_at`, `expires_at`),
  KEY `idx_password_reset_issuer` (`issued_by_user_internal_id`),
  KEY `idx_password_reset_cleanup` (`expires_at`, `id`),
  CONSTRAINT `v2_fk_password_reset_user` FOREIGN KEY (`user_internal_id`) REFERENCES `auth_v2_users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `v2_fk_password_reset_issuer` FOREIGN KEY (`issued_by_user_internal_id`) REFERENCES `auth_v2_users` (`id`) ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT `v2_ck_password_reset_revoked` CHECK (`revoked` IN (0, 1)),
  CONSTRAINT `v2_ck_password_reset_expiry` CHECK (`expires_at` > `created_at`),
  CONSTRAINT `v2_ck_password_reset_purpose` CHECK (`purpose` IN ('password_reset', 'account_setup'))
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;



CREATE TABLE `auth_v2_auth_security_event` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_code` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `outcome` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `actor_user_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `target_user_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `target_role_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `session_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `correlation_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `observed_ip_address` varchar(45) NULL DEFAULT NULL,
  `reason_code` varchar(64) CHARACTER SET ascii COLLATE ascii_bin NULL DEFAULT NULL,
  `occurred_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_auth_event_actor` (`actor_user_id`, `occurred_at`),
  KEY `idx_auth_event_target` (`target_user_id`, `occurred_at`),
  KEY `idx_auth_event_correlation` (`correlation_id`),
  KEY `idx_auth_event_retention` (`occurred_at`, `id`),
  CONSTRAINT `v2_ck_auth_event_outcome` CHECK (`outcome` IN ('success', 'denied', 'failure'))
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;




CREATE TABLE `auth_v2_auth_rate_limit` (
  `bucket_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `window_start` bigint UNSIGNED NOT NULL,
  `attempts` int UNSIGNED NOT NULL,
  PRIMARY KEY (`bucket_hash`),
  KEY `idx_auth_rate_window` (`window_start`),
  CONSTRAINT `v2_ck_auth_rate_attempts` CHECK (`attempts` BETWEEN 1 AND 100000)
) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

