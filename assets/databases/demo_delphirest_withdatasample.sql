/*
 Navicat Premium Dump SQL

 Source Server         : Local-Root
 Source Server Type    : MySQL
 Source Server Version : 50744 (5.7.44)
 Source Host           : localhost:3306
 Source Schema         : demo_delphirest

 Target Server Type    : MySQL
 Target Server Version : 50744 (5.7.44)
 File Encoding         : 65001

 Date: 24/06/2026 12:14:13
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for access_token
-- ----------------------------
DROP TABLE IF EXISTS `access_token`;
CREATE TABLE `access_token`  (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `session_internal_id` bigint(20) UNSIGNED NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_access_token_hash`(`token_hash`) USING BTREE,
  INDEX `idx_token_active`(`revoked`, `expires_at`, `deleted_at`) USING BTREE,
  INDEX `idx_token_session`(`session_internal_id`) USING BTREE,
  INDEX `idx_token_session_active`(`session_internal_id`, `revoked`, `expires_at`, `deleted_at`) USING BTREE,
  CONSTRAINT `fk_token_session` FOREIGN KEY (`session_internal_id`) REFERENCES `user_session` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of access_token
-- ----------------------------

-- ----------------------------
-- Table structure for category
-- ----------------------------
DROP TABLE IF EXISTS `category`;
CREATE TABLE `category`  (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `category_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `category_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_category_public_id`(`category_id`) USING BTREE,
  UNIQUE INDEX `uq_category_name`(`category_name`) USING BTREE,
  INDEX `idx_category_active`(`deleted_at`, `is_active`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of category
-- ----------------------------

-- ----------------------------
-- Table structure for customer
-- ----------------------------
DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer`  (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `customer_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `phone_number` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `address_line1` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `address_line2` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `state` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `postal_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_customer_public_id`(`customer_id`) USING BTREE,
  INDEX `idx_customer_email`(`email`) USING BTREE,
  INDEX `idx_customer_name`(`customer_name`) USING BTREE,
  INDEX `idx_customer_active`(`deleted_at`, `is_active`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of customer
-- ----------------------------

-- ----------------------------
-- Table structure for m_role
-- ----------------------------
DROP TABLE IF EXISTS `m_role`;
CREATE TABLE `m_role`  (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `is_superadmin` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_role_public_id`(`role_id`) USING BTREE,
  UNIQUE INDEX `uq_role_name`(`role_name`) USING BTREE,
  INDEX `idx_role_active`(`deleted_at`, `is_active`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 12 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of m_role
-- ----------------------------
INSERT INTO `m_role` VALUES (1, '7b6ff436-36ff-400e-a1d0-c1e6da9a24b0', 'SUPER ADMIN', 'Full system access', 1, 1, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (2, '90477e4f-d90c-438b-ab9e-6d6264c05511', 'COSTRUCTION MANAGER', 'Final approval and warehouse control', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (3, 'd3838379-33ee-4d4b-851f-1c15373d70ee', 'QUALITY CONTROL STAFF', 'Quality inspection and approval', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (4, '6a51e637-962a-48f7-9fad-bfb777e51f9a', 'WAREHOUSE STAFF', 'Stock in/out operations', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (5, 'af5dad9d-c986-4cac-a371-7317a8fdb2a9', 'STOCK CONTROLLER', 'Stock monitoring and adjustment', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (6, '0933c3c5-1474-4d81-96be-56c00f223609', 'PROCUREMENT STAFF', 'Purchase and supplier handling', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (7, '72d18d41-70cc-411f-b71a-68ce8fa38e77', 'AUDITOR', 'Read-only audit access', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (8, '0b6a1e11-8d6a-42ad-9915-3ea82288080f', 'VIEWER', 'View-only access', 1, 0, '2026-02-27 08:59:04', NULL, NULL);
INSERT INTO `m_role` VALUES (11, 'df7e12a5-0309-4e5e-ad0a-6f5cdbf5debd', 'ADMIN', 'Access Master Data', 1, 0, '2026-05-04 21:14:32', '2026-06-18 05:44:21', NULL);

-- ----------------------------
-- Table structure for product
-- ----------------------------
DROP TABLE IF EXISTS `product`;
CREATE TABLE `product`  (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `product_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `product_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
  `price` decimal(15, 2) NOT NULL DEFAULT 0.00,
  `stock` int(11) NOT NULL DEFAULT 0,
  `category_internal_id` int(10) UNSIGNED NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_product_public_id`(`product_id`) USING BTREE,
  INDEX `idx_product_category`(`category_internal_id`) USING BTREE,
  INDEX `idx_product_active`(`deleted_at`, `is_active`) USING BTREE,
  CONSTRAINT `fk_product_category` FOREIGN KEY (`category_internal_id`) REFERENCES `category` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of product
-- ----------------------------

-- ----------------------------
-- Table structure for user_session
-- ----------------------------
DROP TABLE IF EXISTS `user_session`;
CREATE TABLE `user_session`  (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_internal_id` bigint(20) UNSIGNED NOT NULL,
  `device_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `user_agent` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `revoked` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_session_public_id`(`session_id`) USING BTREE,
  INDEX `idx_session_user`(`user_internal_id`) USING BTREE,
  INDEX `idx_session_active`(`user_internal_id`, `revoked`, `expires_at`, `deleted_at`) USING BTREE,
  INDEX `idx_session_public_device`(`session_id`, `device_id`) USING BTREE,
  CONSTRAINT `fk_session_user` FOREIGN KEY (`user_internal_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of user_session
-- ----------------------------

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `fullname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `role_internal_id` int(10) UNSIGNED NULL DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uq_users_public_id`(`user_id`) USING BTREE,
  UNIQUE INDEX `uq_users_username`(`username`) USING BTREE,
  INDEX `idx_users_role`(`role_internal_id`) USING BTREE,
  INDEX `idx_users_active`(`deleted_at`, `is_active`) USING BTREE,
  INDEX `idx_users_created`(`created_at`) USING BTREE,
  CONSTRAINT `fk_users_role` FOREIGN KEY (`role_internal_id`) REFERENCES `m_role` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 12 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Records of users
-- ----------------------------
INSERT INTO `users` VALUES (1, '46b98046-ce79-4a00-9e27-1353c8de401a', 'superadmin', '0b877b16021f29678488dac70abadff610eba4213f34626fc79029ce4b6f8058', 'SUPERADMIN', 1, 1, '2026-02-19 22:48:59', '2026-06-24 07:33:56', NULL);

SET FOREIGN_KEY_CHECKS = 1;
