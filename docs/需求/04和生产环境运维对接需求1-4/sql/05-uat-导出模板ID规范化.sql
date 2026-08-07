-- =====================================================================
-- UAT：集采四页面导出模板 ID 规范化
-- 日期：2026-08-04
-- 目标库：scm_ubm_uat
-- 影响范围：4 条主模板、43 条模板明细
-- 重要：本文件默认不 COMMIT。执行后必须看到 ready_to_commit = 1，
--       再在同一个数据库会话中单独执行 COMMIT；否则执行 ROLLBACK。
-- =====================================================================

USE `scm_ubm_uat`;

DROP TEMPORARY TABLE IF EXISTS `_template_main_id_map`;
CREATE TEMPORARY TABLE `_template_main_id_map` (
  `old_id` varchar(32) NOT NULL,
  `new_id` varchar(32) NOT NULL,
  `template_code` varchar(32) NOT NULL,
  PRIMARY KEY (`old_id`),
  UNIQUE KEY `uk_new_id` (`new_id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

INSERT INTO `_template_main_id_map` (`old_id`, `new_id`, `template_code`) VALUES
('jcrje_daily_export_template',  '2084540332552220688', 'collection-daily-ledger-export'),
('jcplan_daily_export_template', '2084540332552220689', 'centralPurchaseStatistics'),
('jckk_daily_export_template',   '2084540332552220690', 'coal-pit-daily-export'),
('price_trend_export_template',  '2084540332552220691', 'priceTrend');

DROP TEMPORARY TABLE IF EXISTS `_template_sub_id_map`;
CREATE TEMPORARY TABLE `_template_sub_id_map` (
  `old_id` varchar(32) NOT NULL,
  `new_id` varchar(32) NOT NULL,
  `old_parent_id` varchar(32) NOT NULL,
  `new_parent_id` varchar(32) NOT NULL,
  PRIMARY KEY (`old_id`),
  UNIQUE KEY `uk_new_id` (`new_id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

INSERT INTO `_template_sub_id_map` (`old_id`, `new_id`, `old_parent_id`, `new_parent_id`) VALUES
('jcrje_daily_export_field_01', '2084540332552220692', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_02', '2084540332552220693', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_03', '2084540332552220694', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_04', '2084540332552220695', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_05', '2084540332552220696', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_06', '2084540332552220697', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_07', '2084540332552220698', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_08', '2084540332552220699', 'jcrje_daily_export_template', '2084540332552220688'),
('jcrje_daily_export_field_09', '2084540332552220700', 'jcrje_daily_export_template', '2084540332552220688'),
('jcplan_daily_export_field_01', '2084540332552220701', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_02', '2084540332552220702', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_03', '2084540332552220703', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_04', '2084540332552220704', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_05', '2084540332552220705', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_06', '2084540332552220706', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_07', '2084540332552220707', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_08', '2084540332552220708', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_09', '2084540332552220709', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_10', '2084540332552220710', 'jcplan_daily_export_template', '2084540332552220689'),
('jcplan_daily_export_field_11', '2084540332552220711', 'jcplan_daily_export_template', '2084540332552220689'),
('jckk_daily_export_field_01', '2084540332552220712', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_02', '2084540332552220713', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_03', '2084540332552220714', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_04', '2084540332552220715', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_05', '2084540332552220716', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_06', '2084540332552220717', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_07', '2084540332552220718', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_08', '2084540332552220719', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_09', '2084540332552220720', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_10', '2084540332552220721', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_11', '2084540332552220722', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_12', '2084540332552220723', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_13', '2084540332552220724', 'jckk_daily_export_template', '2084540332552220690'),
('jckk_daily_export_field_14', '2084540332552220725', 'jckk_daily_export_template', '2084540332552220690'),
('price_trend_export_field_01', '2084540332552220726', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_02', '2084540332552220727', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_03', '2084540332552220728', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_04', '2084540332552220729', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_05', '2084540332552220730', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_06', '2084540332552220731', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_07', '2084540332552220732', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_08', '2084540332552220733', 'price_trend_export_template', '2084540332552220691'),
('price_trend_export_field_09', '2084540332552220734', 'price_trend_export_template', '2084540332552220691');

-- 执行前硬校验：旧数据、模板编码和明细数必须与 2026-08-04 只读核查一致；新 ID 必须未占用。
-- 各项拆开查询，兼容目标环境 MySQL 8.0.18 对同一临时表在单条语句中重复打开的限制。
SELECT COUNT(*) INTO @old_main_count
FROM `scm_simple_template` t
JOIN `_template_main_id_map` m
  ON t.`template_id` = m.`old_id` AND t.`template_code` = m.`template_code`;

SELECT COUNT(*) INTO @template_code_count
FROM `scm_simple_template`
WHERE `template_code` IN ('collection-daily-ledger-export','centralPurchaseStatistics','coal-pit-daily-export','priceTrend');

SELECT COUNT(*) INTO @new_main_collision_count
FROM `scm_simple_template` t
JOIN `_template_main_id_map` m ON t.`template_id` = m.`new_id`;

SELECT COUNT(*) INTO @old_parent_sub_count
FROM `scm_simple_template_sub` s
JOIN `_template_main_id_map` m ON s.`template_id` = m.`old_id`;

SELECT COUNT(*) INTO @old_sub_count
FROM `scm_simple_template_sub` s
JOIN `_template_sub_id_map` m
  ON s.`tmp_id` = m.`old_id` AND s.`template_id` = m.`old_parent_id`;

SELECT COUNT(*) INTO @new_parent_collision_count
FROM `scm_simple_template_sub` s
JOIN `_template_main_id_map` m ON s.`template_id` = m.`new_id`;

SELECT COUNT(*) INTO @new_sub_collision_count
FROM `scm_simple_template_sub` s
JOIN `_template_sub_id_map` m ON s.`tmp_id` = m.`new_id`;

SET @precheck_ok = (
  @old_main_count = 4
  AND @template_code_count = 4
  AND @new_main_collision_count = 0
  AND @old_parent_sub_count = 43
  AND @old_sub_count = 43
  AND @new_parent_collision_count = 0
  AND @new_sub_collision_count = 0
);

SELECT @precheck_ok AS precheck_ok,
       '必须为 1；为 0 时后续 UPDATE 会保持 0 行，禁止提交' AS instruction;

START TRANSACTION;

UPDATE `scm_simple_template_sub` s
JOIN `_template_main_id_map` m ON s.`template_id` = m.`old_id`
SET s.`template_id` = m.`new_id`
WHERE @precheck_ok = 1;
SET @updated_sub_parent = ROW_COUNT();

UPDATE `scm_simple_template` t
JOIN `_template_main_id_map` m ON t.`template_id` = m.`old_id`
SET t.`template_id` = m.`new_id`
WHERE @precheck_ok = 1;
SET @updated_main = ROW_COUNT();

UPDATE `scm_simple_template_sub` s
JOIN `_template_sub_id_map` m ON s.`tmp_id` = m.`old_id`
SET s.`tmp_id` = m.`new_id`
WHERE @precheck_ok = 1;
SET @updated_sub_id = ROW_COUNT();

SELECT COUNT(*) INTO @new_main_count
FROM `scm_simple_template` t
JOIN `_template_main_id_map` m
  ON t.`template_id` = m.`new_id` AND t.`template_code` = m.`template_code`;

SELECT COUNT(*) INTO @new_parent_sub_count
FROM `scm_simple_template_sub` s
JOIN `_template_main_id_map` m ON s.`template_id` = m.`new_id`;

SELECT COUNT(*) INTO @new_sub_count
FROM `scm_simple_template_sub` s
JOIN `_template_sub_id_map` m ON s.`tmp_id` = m.`new_id`;

SELECT COUNT(*) INTO @remaining_old_main_count
FROM `scm_simple_template` t
JOIN `_template_main_id_map` m ON t.`template_id` = m.`old_id`;

SELECT COUNT(*) INTO @remaining_old_sub_count
FROM `scm_simple_template_sub` s
JOIN `_template_sub_id_map` m
  ON s.`template_id` = m.`old_parent_id` OR s.`tmp_id` = m.`old_id`;

SELECT COUNT(*) INTO @orphan_count
FROM `scm_simple_template_sub` s
LEFT JOIN `scm_simple_template` t ON t.`template_id` = s.`template_id`
JOIN `_template_main_id_map` m ON s.`template_id` = m.`new_id`
WHERE t.`template_id` IS NULL;

SET @ready_to_commit = (
  @precheck_ok = 1
  AND @updated_main = 4
  AND @updated_sub_parent = 43
  AND @updated_sub_id = 43
  AND @new_main_count = 4
  AND @new_parent_sub_count = 43
  AND @new_sub_count = 43
  AND @remaining_old_main_count = 0
  AND @remaining_old_sub_count = 0
  AND @orphan_count = 0
);

SELECT @updated_main AS updated_main,
       @updated_sub_parent AS updated_sub_parent,
       @updated_sub_id AS updated_sub_id,
       @ready_to_commit AS ready_to_commit;

SELECT t.`template_code`, t.`template_id`, t.`status`, t.`delete_sign`,
       COUNT(s.`tmp_id`) AS sub_count,
       COUNT(DISTINCT s.`template_id`) AS sub_parent_count,
       MIN(CAST(s.`sort_name` AS UNSIGNED)) AS min_sort,
       MAX(CAST(s.`sort_name` AS UNSIGNED)) AS max_sort
FROM `scm_simple_template` t
LEFT JOIN `scm_simple_template_sub` s ON s.`template_id` = t.`template_id`
WHERE t.`template_code` IN (
  'collection-daily-ledger-export',
  'centralPurchaseStatistics',
  'coal-pit-daily-export',
  'priceTrend'
)
GROUP BY t.`template_code`, t.`template_id`, t.`status`, t.`delete_sign`
ORDER BY t.`template_code`;

-- ready_to_commit = 1，且四个模板分别为 9 / 11 / 14 / 9 列、父 ID 各 1 个后，
-- 在同一个数据库会话中单独执行：
-- COMMIT;

-- 任一结果不符合时，在同一个数据库会话中执行：
-- ROLLBACK;
