SET NAMES utf8mb4;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `access_token`;

DROP TABLE IF EXISTS `user_session`;

DROP TABLE IF EXISTS `users`;

DROP TABLE IF EXISTS `product`;

DROP TABLE IF EXISTS `customer`;

DROP TABLE IF EXISTS `category`;

DROP TABLE IF EXISTS `m_role`;

CREATE TABLE `m_role` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `role_id` CHAR(36) NOT NULL,
    `role_name` VARCHAR(50) NOT NULL,
    `description` VARCHAR(150) NULL DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `is_superadmin` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_role_public_id` (`role_id`),
    UNIQUE KEY `uq_role_name` (`role_name`),
    KEY `idx_role_active` (`deleted_at`, `is_active`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` CHAR(36) NOT NULL,
    `username` VARCHAR(50) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `fullname` VARCHAR(100) NULL DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `role_internal_id` INT UNSIGNED NULL DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_users_public_id` (`user_id`),
    UNIQUE KEY `uq_users_username` (`username`),
    KEY `idx_users_role` (`role_internal_id`),
    KEY `idx_users_active` (`deleted_at`, `is_active`),
    KEY `idx_users_created` (`created_at`),
    CONSTRAINT `fk_users_role` FOREIGN KEY (`role_internal_id`) REFERENCES `m_role` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `user_session` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `session_id` CHAR(36) NOT NULL,
    `user_internal_id` BIGINT UNSIGNED NOT NULL,
    `device_id` VARCHAR(100) NOT NULL,
    `device_name` VARCHAR(100) NULL DEFAULT NULL,
    `user_agent` VARCHAR(255) NULL DEFAULT NULL,
    `ip_address` VARCHAR(45) NULL DEFAULT NULL,
    `expires_at` DATETIME NOT NULL,
    `revoked` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_session_public_id` (`session_id`),
    KEY `idx_session_user` (`user_internal_id`),
    KEY `idx_session_active` (
        `user_internal_id`,
        `revoked`,
        `expires_at`,
        `deleted_at`
    ),
    KEY `idx_session_public_device` (`session_id`, `device_id`),
    CONSTRAINT `fk_session_user` FOREIGN KEY (`user_internal_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `access_token` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `token_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    `session_internal_id` BIGINT UNSIGNED NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `revoked` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_access_token_hash` (`token_hash`),
    KEY `idx_token_active` (
        `revoked`,
        `expires_at`,
        `deleted_at`
    ),
    KEY `idx_token_session` (`session_internal_id`),
    KEY `idx_token_session_active` (
        `session_internal_id`,
        `revoked`,
        `expires_at`,
        `deleted_at`
    ),
    CONSTRAINT `fk_token_session` FOREIGN KEY (`session_internal_id`) REFERENCES `user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `category` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category_id` CHAR(36) NOT NULL,
    `category_name` VARCHAR(50) NOT NULL,
    `description` VARCHAR(150) NULL DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_category_public_id` (`category_id`),
    UNIQUE KEY `uq_category_name` (`category_name`),
    KEY `idx_category_active` (`deleted_at`, `is_active`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `product` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `product_id` CHAR(36) NOT NULL,
    `product_name` VARCHAR(100) NOT NULL,
    `description` TEXT NULL DEFAULT NULL,
    `price` DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    `stock` INT NOT NULL DEFAULT 0,
    `category_internal_id` INT UNSIGNED NULL DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_product_public_id` (`product_id`),
    KEY `idx_product_category` (`category_internal_id`),
    KEY `idx_product_active` (`deleted_at`, `is_active`),
    CONSTRAINT `fk_product_category` FOREIGN KEY (`category_internal_id`) REFERENCES `category` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

CREATE TABLE `customer` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `customer_id` CHAR(36) NOT NULL,
    `customer_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(100) NULL DEFAULT NULL,
    `phone_number` VARCHAR(30) NULL DEFAULT NULL,
    `address_line1` VARCHAR(150) NULL DEFAULT NULL,
    `address_line2` VARCHAR(150) NULL DEFAULT NULL,
    `city` VARCHAR(100) NULL DEFAULT NULL,
    `state` VARCHAR(100) NULL DEFAULT NULL,
    `postal_code` VARCHAR(20) NULL DEFAULT NULL,
    `country` VARCHAR(100) NULL DEFAULT NULL,
    `notes` TEXT NULL DEFAULT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at` DATETIME NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_customer_public_id` (`customer_id`),
    KEY `idx_customer_email` (`email`),
    KEY `idx_customer_name` (`customer_name`),
    KEY `idx_customer_active` (`deleted_at`, `is_active`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;