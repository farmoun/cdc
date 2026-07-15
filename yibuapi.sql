/*
 Navicat Premium Data Transfer

 Source Server         : yibu
 Source Server Type    : MySQL
 Source Server Version : 90701
 Source Host           : localhost:3306
 Source Schema         : yibuapi

 Target Server Type    : MySQL
 Target Server Version : 90701
 File Encoding         : 65001

 Date: 14/07/2026 17:22:36
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for abilities
-- ----------------------------
DROP TABLE IF EXISTS `abilities`;
CREATE TABLE `abilities`  (
  `group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `model` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `channel_id` bigint NOT NULL,
  `enabled` tinyint(1) NULL DEFAULT NULL,
  `priority` bigint NULL DEFAULT 0,
  `weight` bigint UNSIGNED NULL DEFAULT 0,
  `tag` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  PRIMARY KEY (`group`, `model`, `channel_id`) USING BTREE,
  INDEX `idx_abilities_channel_id`(`channel_id` ASC) USING BTREE,
  INDEX `idx_abilities_priority`(`priority` ASC) USING BTREE,
  INDEX `idx_abilities_weight`(`weight` ASC) USING BTREE,
  INDEX `idx_abilities_tag`(`tag` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for authz_roles
-- ----------------------------
DROP TABLE IF EXISTS `authz_roles`;
CREATE TABLE `authz_roles`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `key` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `built_in` tinyint(1) NULL DEFAULT NULL,
  `enabled` tinyint(1) NULL DEFAULT NULL,
  `sort` bigint NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_authz_roles_key`(`key` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for casbin_rule
-- ----------------------------
DROP TABLE IF EXISTS `casbin_rule`;
CREATE TABLE `casbin_rule`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `ptype` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v0` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v3` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v4` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `v5` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_casbin_rule_unique`(`ptype` ASC, `v0` ASC, `v1` ASC, `v2` ASC, `v3` ASC, `v4` ASC, `v5` ASC) USING BTREE,
  INDEX `idx_casbin_rule`(`ptype` ASC, `v0` ASC, `v1` ASC, `v2` ASC, `v3` ASC, `v4` ASC, `v5` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 22 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for channel_fingerprint_logs
-- ----------------------------
DROP TABLE IF EXISTS `channel_fingerprint_logs`;
CREATE TABLE `channel_fingerprint_logs`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `channel_id` bigint NULL DEFAULT NULL,
  `model_family` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `verified_at` bigint NULL DEFAULT NULL,
  `total_runs` bigint NULL DEFAULT NULL,
  `success_count` bigint NULL DEFAULT NULL,
  `p_hat` double NULL DEFAULT NULL,
  `ci_low` double NULL DEFAULT NULL,
  `ci_high` double NULL DEFAULT NULL,
  `verdict` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `hits_json` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `details_json` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `created_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_fp_ch_mdl_time`(`channel_id` ASC, `model_family` ASC, `verified_at` ASC) USING BTREE,
  INDEX `idx_channel_fingerprint_logs_created_at`(`created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for channel_fingerprint_states
-- ----------------------------
DROP TABLE IF EXISTS `channel_fingerprint_states`;
CREATE TABLE `channel_fingerprint_states`  (
  `channel_id` bigint NOT NULL,
  `model_family` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `last_verdict` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `last_p_hat` double NULL DEFAULT NULL,
  `last_ci_low` double NULL DEFAULT NULL,
  `last_ci_high` double NULL DEFAULT NULL,
  `last_total_runs` bigint NULL DEFAULT NULL,
  `last_success` bigint NULL DEFAULT NULL,
  `last_verified_at` bigint NULL DEFAULT NULL,
  `last_alert_at` bigint NULL DEFAULT NULL,
  `acknowledged_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`channel_id`, `model_family`) USING BTREE,
  INDEX `idx_channel_fingerprint_states_last_verdict`(`last_verdict` ASC) USING BTREE,
  INDEX `idx_channel_fingerprint_states_last_verified_at`(`last_verified_at` ASC) USING BTREE,
  INDEX `idx_channel_fingerprint_states_acknowledged_at`(`acknowledged_at` ASC) USING BTREE,
  INDEX `idx_channel_fingerprint_states_updated_at`(`updated_at` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for channels
-- ----------------------------
DROP TABLE IF EXISTS `channels`;
CREATE TABLE `channels`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `type` bigint NULL DEFAULT 0,
  `key` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `open_ai_organization` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `test_model` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `status` bigint NULL DEFAULT 1,
  `name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `weight` bigint UNSIGNED NULL DEFAULT 0,
  `created_time` bigint NULL DEFAULT NULL,
  `test_time` bigint NULL DEFAULT NULL,
  `response_time` bigint NULL DEFAULT NULL,
  `base_url` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `other` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `balance` double NULL DEFAULT NULL,
  `balance_updated_time` bigint NULL DEFAULT NULL,
  `models` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'default',
  `used_quota` bigint NULL DEFAULT 0,
  `model_mapping` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `status_code_mapping` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `priority` bigint NULL DEFAULT 0,
  `auto_ban` bigint NULL DEFAULT 1,
  `other_info` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `tag` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `setting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `param_override` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `header_override` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `channel_info` json NULL,
  `settings` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `fingerprint_enabled` tinyint(1) NULL DEFAULT 0,
  `fingerprint_models` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_channels_name`(`name` ASC) USING BTREE,
  INDEX `idx_channels_tag`(`tag` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1787 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for checkins
-- ----------------------------
DROP TABLE IF EXISTS `checkins`;
CREATE TABLE `checkins`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `checkin_date` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `quota_awarded` bigint NOT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_user_checkin_date`(`user_id` ASC, `checkin_date` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for custom_oauth_providers
-- ----------------------------
DROP TABLE IF EXISTS `custom_oauth_providers`;
CREATE TABLE `custom_oauth_providers`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `slug` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `icon` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `enabled` tinyint(1) NULL DEFAULT 0,
  `client_id` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `client_secret` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `authorization_endpoint` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `token_endpoint` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `user_info_endpoint` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `scopes` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'openid profile email',
  `user_id_field` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'sub',
  `username_field` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'preferred_username',
  `display_name_field` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'name',
  `email_field` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'email',
  `well_known` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `auth_style` bigint NULL DEFAULT 0,
  `access_policy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `access_denied_message` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `created_at` datetime(3) NULL DEFAULT NULL,
  `updated_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_custom_oauth_providers_slug`(`slug` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for logs
-- ----------------------------
DROP TABLE IF EXISTS `logs`;
CREATE TABLE `logs`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `type` bigint NULL DEFAULT NULL,
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `username` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `token_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `model_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `quota` bigint NULL DEFAULT 0,
  `prompt_tokens` bigint NULL DEFAULT 0,
  `completion_tokens` bigint NULL DEFAULT 0,
  `use_time` bigint NULL DEFAULT 0,
  `is_stream` tinyint(1) NULL DEFAULT NULL,
  `channel_id` bigint NULL DEFAULT NULL,
  `channel_name` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `token_id` bigint NULL DEFAULT 0,
  `group` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `other` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `ip` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `request_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `upstream_request_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_created_at_id`(`id` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_logs_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_created_at_type`(`created_at` ASC, `type` ASC) USING BTREE,
  INDEX `index_username_model_name`(`model_name` ASC, `username` ASC) USING BTREE,
  INDEX `idx_logs_token_name`(`token_name` ASC) USING BTREE,
  INDEX `idx_logs_model_name`(`model_name` ASC) USING BTREE,
  INDEX `idx_logs_channel_id`(`channel_id` ASC) USING BTREE,
  INDEX `idx_logs_username`(`username` ASC) USING BTREE,
  INDEX `idx_logs_token_id`(`token_id` ASC) USING BTREE,
  INDEX `idx_logs_group`(`group` ASC) USING BTREE,
  INDEX `idx_logs_ip`(`ip` ASC) USING BTREE,
  INDEX `idx_logs_request_id`(`request_id` ASC) USING BTREE,
  INDEX `idx_user_id_id`(`user_id` ASC, `id` ASC) USING BTREE,
  INDEX `idx_logs_upstream_request_id`(`upstream_request_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 183777251 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for midjourneys
-- ----------------------------
DROP TABLE IF EXISTS `midjourneys`;
CREATE TABLE `midjourneys`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` bigint NULL DEFAULT NULL,
  `user_id` bigint NULL DEFAULT NULL,
  `action` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `mj_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `prompt` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `prompt_en` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `description` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `state` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `submit_time` bigint NULL DEFAULT NULL,
  `start_time` bigint NULL DEFAULT NULL,
  `finish_time` bigint NULL DEFAULT NULL,
  `image_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `video_url` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `video_urls` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `progress` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `fail_reason` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `channel_id` bigint NULL DEFAULT NULL,
  `quota` bigint NULL DEFAULT NULL,
  `buttons` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `properties` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_midjourneys_submit_time`(`submit_time` ASC) USING BTREE,
  INDEX `idx_midjourneys_start_time`(`start_time` ASC) USING BTREE,
  INDEX `idx_midjourneys_finish_time`(`finish_time` ASC) USING BTREE,
  INDEX `idx_midjourneys_status`(`status` ASC) USING BTREE,
  INDEX `idx_midjourneys_progress`(`progress` ASC) USING BTREE,
  INDEX `idx_midjourneys_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_midjourneys_action`(`action` ASC) USING BTREE,
  INDEX `idx_midjourneys_mj_id`(`mj_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for models
-- ----------------------------
DROP TABLE IF EXISTS `models`;
CREATE TABLE `models`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `model_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `icon` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `tags` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `vendor_id` bigint NULL DEFAULT NULL,
  `endpoints` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `status` bigint NULL DEFAULT 1,
  `sync_official` bigint NULL DEFAULT 1,
  `created_time` bigint NULL DEFAULT NULL,
  `updated_time` bigint NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  `name_rule` bigint NULL DEFAULT 0,
  `description_en` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_model_name_delete_at`(`model_name` ASC, `deleted_at` ASC) USING BTREE,
  INDEX `idx_models_vendor_id`(`vendor_id` ASC) USING BTREE,
  INDEX `idx_models_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 165 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for options
-- ----------------------------
DROP TABLE IF EXISTS `options`;
CREATE TABLE `options`  (
  `key` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `value` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`key`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for passkey_credentials
-- ----------------------------
DROP TABLE IF EXISTS `passkey_credentials`;
CREATE TABLE `passkey_credentials`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `credential_id` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `public_key` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `attestation_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `aa_guid` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `sign_count` int UNSIGNED NULL DEFAULT 0,
  `clone_warning` tinyint(1) NULL DEFAULT NULL,
  `user_present` tinyint(1) NULL DEFAULT NULL,
  `user_verified` tinyint(1) NULL DEFAULT NULL,
  `backup_eligible` tinyint(1) NULL DEFAULT NULL,
  `backup_state` tinyint(1) NULL DEFAULT NULL,
  `transports` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `attachment` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `last_used_at` datetime(3) NULL DEFAULT NULL,
  `created_at` datetime(3) NULL DEFAULT NULL,
  `updated_at` datetime(3) NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_passkey_credentials_user_id`(`user_id` ASC) USING BTREE,
  UNIQUE INDEX `idx_passkey_credentials_credential_id`(`credential_id` ASC) USING BTREE,
  INDEX `idx_passkey_credentials_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for perf_metrics
-- ----------------------------
DROP TABLE IF EXISTS `perf_metrics`;
CREATE TABLE `perf_metrics`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `model_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `bucket_ts` bigint NULL DEFAULT NULL,
  `request_count` bigint NULL DEFAULT 0,
  `success_count` bigint NULL DEFAULT 0,
  `total_latency_ms` bigint NULL DEFAULT 0,
  `ttft_sum_ms` bigint NULL DEFAULT 0,
  `ttft_count` bigint NULL DEFAULT 0,
  `output_tokens` bigint NULL DEFAULT 0,
  `generation_ms` bigint NULL DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_perf_model_group_bucket`(`model_name` ASC, `group` ASC, `bucket_ts` ASC) USING BTREE,
  INDEX `idx_perf_bucket_ts`(`bucket_ts` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 20 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for prefill_groups
-- ----------------------------
DROP TABLE IF EXISTS `prefill_groups`;
CREATE TABLE `prefill_groups`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `items` json NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `created_time` bigint NULL DEFAULT NULL,
  `updated_time` bigint NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_prefill_name`(`name` ASC) USING BTREE,
  INDEX `idx_prefill_groups_type`(`type` ASC) USING BTREE,
  INDEX `idx_prefill_groups_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for quota_data
-- ----------------------------
DROP TABLE IF EXISTS `quota_data`;
CREATE TABLE `quota_data`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `model_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `created_at` bigint NULL DEFAULT NULL,
  `token_used` bigint NULL DEFAULT 0,
  `count` bigint NULL DEFAULT 0,
  `quota` bigint NULL DEFAULT 0,
  `cache_tokens` bigint NULL DEFAULT 0,
  `cache_creation_tokens` bigint NULL DEFAULT 0,
  `use_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `token_id` bigint NULL DEFAULT 0,
  `channel_id` bigint NULL DEFAULT 0,
  `node_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_quota_data_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_qdt_model_user_name`(`model_name` ASC, `username` ASC) USING BTREE,
  INDEX `idx_qdt_created_at`(`created_at` ASC) USING BTREE,
  INDEX `idx_quota_data_token_id`(`token_id` ASC) USING BTREE,
  INDEX `idx_quota_data_channel_id`(`channel_id` ASC) USING BTREE,
  INDEX `idx_quota_data_node_name`(`node_name` ASC) USING BTREE,
  INDEX `idx_quota_data_use_group`(`use_group` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 199594 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for redemptions
-- ----------------------------
DROP TABLE IF EXISTS `redemptions`;
CREATE TABLE `redemptions`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `key` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` bigint NULL DEFAULT 1,
  `name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `quota` bigint NULL DEFAULT 100,
  `created_time` bigint NULL DEFAULT NULL,
  `redeemed_time` bigint NULL DEFAULT NULL,
  `used_user_id` bigint NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  `expired_time` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_redemptions_key`(`key` ASC) USING BTREE,
  INDEX `idx_redemptions_name`(`name` ASC) USING BTREE,
  INDEX `idx_redemptions_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 6151 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for setups
-- ----------------------------
DROP TABLE IF EXISTS `setups`;
CREATE TABLE `setups`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `version` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `initialized_at` bigint NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sub_account_groups
-- ----------------------------
DROP TABLE IF EXISTS `sub_account_groups`;
CREATE TABLE `sub_account_groups`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `parent_id` bigint NOT NULL,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `manager_user_id` bigint NULL DEFAULT 0,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_sub_account_group_parent_name`(`parent_id` ASC, `name` ASC) USING BTREE,
  INDEX `idx_sub_account_groups_parent_id`(`parent_id` ASC) USING BTREE,
  INDEX `idx_sub_account_groups_manager_user_id`(`manager_user_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for subscription_orders
-- ----------------------------
DROP TABLE IF EXISTS `subscription_orders`;
CREATE TABLE `subscription_orders`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `plan_id` bigint NULL DEFAULT NULL,
  `money` double NULL DEFAULT NULL,
  `trade_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `payment_method` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `status` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `create_time` bigint NULL DEFAULT NULL,
  `complete_time` bigint NULL DEFAULT NULL,
  `provider_payload` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `payment_provider` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `trade_no`(`trade_no` ASC) USING BTREE,
  INDEX `idx_subscription_orders_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_subscription_orders_plan_id`(`plan_id` ASC) USING BTREE,
  INDEX `idx_subscription_orders_trade_no`(`trade_no` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for subscription_plans
-- ----------------------------
DROP TABLE IF EXISTS `subscription_plans`;
CREATE TABLE `subscription_plans`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `subtitle` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `price_amount` decimal(10, 6) NOT NULL DEFAULT 0.000000,
  `currency` varchar(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'USD',
  `duration_unit` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'month',
  `duration_value` bigint NOT NULL DEFAULT 1,
  `custom_seconds` bigint NOT NULL DEFAULT 0,
  `enabled` tinyint(1) NULL DEFAULT 1,
  `sort_order` bigint NULL DEFAULT 0,
  `stripe_price_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `creem_product_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `max_purchase_per_user` bigint NULL DEFAULT 0,
  `upgrade_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `total_amount` bigint NOT NULL DEFAULT 0,
  `quota_reset_period` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'never',
  `quota_reset_custom_seconds` bigint NULL DEFAULT 0,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  `subtitle_en` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `description_en` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
  `weekly_quota_limit` bigint NULL DEFAULT 0,
  `monthly_quota_limit` bigint NULL DEFAULT 0,
  `allow_balance_pay` tinyint(1) NULL DEFAULT NULL,
  `waffo_pancake_product_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `allow_wallet_overflow` tinyint(1) NULL DEFAULT NULL,
  `downgrade_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for subscription_pre_consume_records
-- ----------------------------
DROP TABLE IF EXISTS `subscription_pre_consume_records`;
CREATE TABLE `subscription_pre_consume_records`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `request_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `user_id` bigint NULL DEFAULT NULL,
  `user_subscription_id` bigint NULL DEFAULT NULL,
  `pre_consumed` bigint NOT NULL DEFAULT 0,
  `status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_subscription_pre_consume_records_request_id`(`request_id` ASC) USING BTREE,
  INDEX `idx_subscription_pre_consume_records_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_subscription_pre_consume_records_user_subscription_id`(`user_subscription_id` ASC) USING BTREE,
  INDEX `idx_subscription_pre_consume_records_status`(`status` ASC) USING BTREE,
  INDEX `idx_subscription_pre_consume_records_updated_at`(`updated_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for system_instances
-- ----------------------------
DROP TABLE IF EXISTS `system_instances`;
CREATE TABLE `system_instances`  (
  `node_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `info` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `started_at` bigint NULL DEFAULT NULL,
  `last_seen_at` bigint NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`node_name`) USING BTREE,
  INDEX `idx_system_instances_updated_at`(`updated_at` ASC) USING BTREE,
  INDEX `idx_system_instances_started_at`(`started_at` ASC) USING BTREE,
  INDEX `idx_system_instances_last_seen_at`(`last_seen_at` ASC) USING BTREE,
  INDEX `idx_system_instances_created_at`(`created_at` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for system_task_locks
-- ----------------------------
DROP TABLE IF EXISTS `system_task_locks`;
CREATE TABLE `system_task_locks`  (
  `type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `task_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `locked_by` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `locked_until` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`type`) USING BTREE,
  INDEX `idx_system_task_locks_task_id`(`task_id` ASC) USING BTREE,
  INDEX `idx_system_task_locks_locked_by`(`locked_by` ASC) USING BTREE,
  INDEX `idx_system_task_locks_locked_until`(`locked_until` ASC) USING BTREE,
  INDEX `idx_system_task_locks_updated_at`(`updated_at` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for system_tasks
-- ----------------------------
DROP TABLE IF EXISTS `system_tasks`;
CREATE TABLE `system_tasks`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `task_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `active_key` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `payload` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `state` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `result` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `error` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `locked_by` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_system_tasks_task_id`(`task_id` ASC) USING BTREE,
  UNIQUE INDEX `idx_system_tasks_active_key`(`active_key` ASC) USING BTREE,
  INDEX `idx_system_tasks_created_at`(`created_at` ASC) USING BTREE,
  INDEX `idx_system_tasks_updated_at`(`updated_at` ASC) USING BTREE,
  INDEX `idx_system_tasks_type`(`type` ASC) USING BTREE,
  INDEX `idx_system_tasks_status`(`status` ASC) USING BTREE,
  INDEX `idx_system_tasks_locked_by`(`locked_by` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 10 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for tasks
-- ----------------------------
DROP TABLE IF EXISTS `tasks`;
CREATE TABLE `tasks`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  `task_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `platform` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `user_id` bigint NULL DEFAULT NULL,
  `group` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `channel_id` bigint NULL DEFAULT NULL,
  `quota` bigint NULL DEFAULT NULL,
  `action` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `fail_reason` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `submit_time` bigint NULL DEFAULT NULL,
  `start_time` bigint NULL DEFAULT NULL,
  `finish_time` bigint NULL DEFAULT NULL,
  `progress` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `properties` json NULL,
  `private_data` json NULL,
  `data` json NULL,
  `space_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_tasks_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_tasks_submit_time`(`submit_time` ASC) USING BTREE,
  INDEX `idx_tasks_start_time`(`start_time` ASC) USING BTREE,
  INDEX `idx_tasks_finish_time`(`finish_time` ASC) USING BTREE,
  INDEX `idx_tasks_platform`(`platform` ASC) USING BTREE,
  INDEX `idx_tasks_channel_id`(`channel_id` ASC) USING BTREE,
  INDEX `idx_tasks_action`(`action` ASC) USING BTREE,
  INDEX `idx_tasks_status`(`status` ASC) USING BTREE,
  INDEX `idx_tasks_progress`(`progress` ASC) USING BTREE,
  INDEX `idx_tasks_created_at`(`created_at` ASC) USING BTREE,
  INDEX `idx_tasks_task_id`(`task_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 789 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for tokens
-- ----------------------------
DROP TABLE IF EXISTS `tokens`;
CREATE TABLE `tokens`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `key` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` bigint NULL DEFAULT 1,
  `name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `created_time` bigint NULL DEFAULT NULL,
  `accessed_time` bigint NULL DEFAULT NULL,
  `expired_time` bigint NULL DEFAULT -1,
  `remain_quota` bigint NULL DEFAULT 0,
  `unlimited_quota` tinyint(1) NULL DEFAULT NULL,
  `model_limits_enabled` tinyint(1) NULL DEFAULT NULL,
  `model_limits` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `allow_ips` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `used_quota` bigint NULL DEFAULT 0,
  `group` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `cross_group_retry` tinyint(1) NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  `groups` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_tokens_key`(`key` ASC) USING BTREE,
  UNIQUE INDEX `key`(`key` ASC) USING BTREE,
  INDEX `idx_tokens_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_tokens_name`(`name` ASC) USING BTREE,
  INDEX `idx_tokens_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 10814 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for top_up_transactions
-- ----------------------------
DROP TABLE IF EXISTS `top_up_transactions`;
CREATE TABLE `top_up_transactions`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `provider` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `external_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `trade_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `create_time` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `idx_topup_provider_external`(`provider` ASC, `external_id` ASC) USING BTREE,
  INDEX `idx_top_up_transactions_trade_no`(`trade_no` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for top_ups
-- ----------------------------
DROP TABLE IF EXISTS `top_ups`;
CREATE TABLE `top_ups`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `amount` bigint NULL DEFAULT NULL,
  `money` double NULL DEFAULT NULL,
  `trade_no` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `payment_method` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `create_time` bigint NULL DEFAULT NULL,
  `complete_time` bigint NULL DEFAULT NULL,
  `status` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `payment_provider` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '',
  `quota` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `trade_no`(`trade_no` ASC) USING BTREE,
  INDEX `idx_top_ups_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_top_ups_trade_no`(`trade_no` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2839 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for two_fa_backup_codes
-- ----------------------------
DROP TABLE IF EXISTS `two_fa_backup_codes`;
CREATE TABLE `two_fa_backup_codes`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `code_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `is_used` tinyint(1) NULL DEFAULT NULL,
  `used_at` datetime(3) NULL DEFAULT NULL,
  `created_at` datetime(3) NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_two_fa_backup_codes_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_two_fa_backup_codes_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 117 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for two_fas
-- ----------------------------
DROP TABLE IF EXISTS `two_fas`;
CREATE TABLE `two_fas`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `secret` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `is_enabled` tinyint(1) NULL DEFAULT NULL,
  `failed_attempts` bigint NULL DEFAULT 0,
  `locked_until` datetime(3) NULL DEFAULT NULL,
  `last_used_at` datetime(3) NULL DEFAULT NULL,
  `created_at` datetime(3) NULL DEFAULT NULL,
  `updated_at` datetime(3) NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_two_fas_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_two_fas_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 30 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_oauth_bindings
-- ----------------------------
DROP TABLE IF EXISTS `user_oauth_bindings`;
CREATE TABLE `user_oauth_bindings`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `provider_id` bigint NOT NULL,
  `provider_user_id` varchar(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `created_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `ux_user_provider`(`user_id` ASC, `provider_id` ASC) USING BTREE,
  UNIQUE INDEX `ux_provider_userid`(`provider_id` ASC, `provider_user_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_subscriptions
-- ----------------------------
DROP TABLE IF EXISTS `user_subscriptions`;
CREATE TABLE `user_subscriptions`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NULL DEFAULT NULL,
  `plan_id` bigint NULL DEFAULT NULL,
  `amount_total` bigint NOT NULL DEFAULT 0,
  `amount_used` bigint NOT NULL DEFAULT 0,
  `start_time` bigint NULL DEFAULT NULL,
  `end_time` bigint NULL DEFAULT NULL,
  `status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL,
  `source` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'order',
  `last_reset_time` bigint NULL DEFAULT 0,
  `next_reset_time` bigint NULL DEFAULT 0,
  `upgrade_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `prev_user_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `created_at` bigint NULL DEFAULT NULL,
  `updated_at` bigint NULL DEFAULT NULL,
  `weekly_used` bigint NULL DEFAULT 0,
  `weekly_reset_time` bigint NULL DEFAULT 0,
  `monthly_used` bigint NULL DEFAULT 0,
  `monthly_reset_time` bigint NULL DEFAULT 0,
  `downgrade_group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '',
  `allow_wallet_overflow` tinyint(1) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_subscriptions_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_sub_active`(`user_id` ASC, `status` ASC, `end_time` ASC) USING BTREE,
  INDEX `idx_user_subscriptions_plan_id`(`plan_id` ASC) USING BTREE,
  INDEX `idx_user_subscriptions_end_time`(`end_time` ASC) USING BTREE,
  INDEX `idx_user_subscriptions_status`(`status` ASC) USING BTREE,
  INDEX `idx_user_subscriptions_next_reset_time`(`next_reset_time` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `password` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `display_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `role` bigint NULL DEFAULT 1,
  `status` bigint NULL DEFAULT 1,
  `email` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `github_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `discord_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `oidc_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `wechat_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `telegram_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `access_token` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `quota` bigint NULL DEFAULT 0,
  `used_quota` bigint NULL DEFAULT 0,
  `request_count` bigint NULL DEFAULT 0,
  `group` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'default',
  `aff_code` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `aff_count` bigint NULL DEFAULT 0,
  `aff_quota` bigint NULL DEFAULT 0,
  `aff_history` bigint NULL DEFAULT 0,
  `inviter_id` bigint NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  `linux_do_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `setting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `stripe_customer` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `parent_id` bigint NULL DEFAULT 0,
  `google_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `created_at` bigint NULL DEFAULT NULL,
  `last_login_at` bigint NULL DEFAULT 0,
  `allow_ips` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `account_group_id` bigint NULL DEFAULT 0,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `username`(`username` ASC) USING BTREE,
  UNIQUE INDEX `idx_users_access_token`(`access_token` ASC) USING BTREE,
  UNIQUE INDEX `idx_users_aff_code`(`aff_code` ASC) USING BTREE,
  INDEX `idx_users_git_hub_id`(`github_id` ASC) USING BTREE,
  INDEX `idx_users_oidc_id`(`oidc_id` ASC) USING BTREE,
  INDEX `idx_users_parent_id`(`parent_id` ASC) USING BTREE,
  INDEX `idx_users_email`(`email` ASC) USING BTREE,
  INDEX `idx_users_discord_id`(`discord_id` ASC) USING BTREE,
  INDEX `idx_users_inviter_id`(`inviter_id` ASC) USING BTREE,
  INDEX `idx_users_linux_do_id`(`linux_do_id` ASC) USING BTREE,
  INDEX `idx_users_we_chat_id`(`wechat_id` ASC) USING BTREE,
  INDEX `idx_users_deleted_at`(`deleted_at` ASC) USING BTREE,
  INDEX `idx_users_username`(`username` ASC) USING BTREE,
  INDEX `idx_users_display_name`(`display_name` ASC) USING BTREE,
  INDEX `idx_users_telegram_id`(`telegram_id` ASC) USING BTREE,
  INDEX `idx_users_stripe_customer`(`stripe_customer` ASC) USING BTREE,
  INDEX `idx_users_google_id`(`google_id` ASC) USING BTREE,
  INDEX `idx_users_account_group_id`(`account_group_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8656 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for vendors
-- ----------------------------
DROP TABLE IF EXISTS `vendors`;
CREATE TABLE `vendors`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `icon` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` bigint NULL DEFAULT 1,
  `created_time` bigint NULL DEFAULT NULL,
  `updated_time` bigint NULL DEFAULT NULL,
  `deleted_at` datetime(3) NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_vendor_name_delete_at`(`name` ASC, `deleted_at` ASC) USING BTREE,
  INDEX `idx_vendors_deleted_at`(`deleted_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 136551 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;
