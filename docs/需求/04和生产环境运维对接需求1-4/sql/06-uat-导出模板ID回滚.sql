-- =====================================================================
-- UAT：集采四页面导出模板 ID 回滚
-- 日期：2026-08-04
-- 仅在 05-uat-导出模板ID规范化.sql 已提交后使用。
-- 本文件默认不 COMMIT；ready_to_commit = 1 后再单独提交。
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
('2084540332552220688', 'jcrje_daily_export_template',  'collection-daily-ledger-export'),
('2084540332552220689', 'jcplan_daily_export_template', 'centralPurchaseStatistics'),
('2084540332552220690', 'jckk_daily_export_template',   'coal-pit-daily-export'),
('2084540332552220691', 'price_trend_export_template',  'priceTrend');

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
('2084540332552220692', 'jcrje_daily_export_field_01', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220693', 'jcrje_daily_export_field_02', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220694', 'jcrje_daily_export_field_03', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220695', 'jcrje_daily_export_field_04', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220696', 'jcrje_daily_export_field_05', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220697', 'jcrje_daily_export_field_06', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220698', 'jcrje_daily_export_field_07', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220699', 'jcrje_daily_export_field_08', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220700', 'jcrje_daily_export_field_09', '2084540332552220688', 'jcrje_daily_export_template'),
('2084540332552220701', 'jcplan_daily_export_field_01', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220702', 'jcplan_daily_export_field_02', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220703', 'jcplan_daily_export_field_03', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220704', 'jcplan_daily_export_field_04', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220705', 'jcplan_daily_export_field_05', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220706', 'jcplan_daily_export_field_06', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220707', 'jcplan_daily_export_field_07', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220708', 'jcplan_daily_export_field_08', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220709', 'jcplan_daily_export_field_09', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220710', 'jcplan_daily_export_field_10', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220711', 'jcplan_daily_export_field_11', '2084540332552220689', 'jcplan_daily_export_template'),
('2084540332552220712', 'jckk_daily_export_field_01', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220713', 'jckk_daily_export_field_02', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220714', 'jckk_daily_export_field_03', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220715', 'jckk_daily_export_field_04', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220716', 'jckk_daily_export_field_05', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220717', 'jckk_daily_export_field_06', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220718', 'jckk_daily_export_field_07', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220719', 'jckk_daily_export_field_08', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220720', 'jckk_daily_export_field_09', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220721', 'jckk_daily_export_field_10', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220722', 'jckk_daily_export_field_11', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220723', 'jckk_daily_export_field_12', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220724', 'jckk_daily_export_field_13', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220725', 'jckk_daily_export_field_14', '2084540332552220690', 'jckk_daily_export_template'),
('2084540332552220726', 'price_trend_export_field_01', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220727', 'price_trend_export_field_02', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220728', 'price_trend_export_field_03', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220729', 'price_trend_export_field_04', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220730', 'price_trend_export_field_05', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220731', 'price_trend_export_field_06', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220732', 'price_trend_export_field_07', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220733', 'price_trend_export_field_08', '2084540332552220691', 'price_trend_export_template'),
('2084540332552220734', 'price_trend_export_field_09', '2084540332552220691', 'price_trend_export_template');

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
);

SELECT @updated_main AS updated_main,
       @updated_sub_parent AS updated_sub_parent,
       @updated_sub_id AS updated_sub_id,
       @ready_to_commit AS ready_to_commit;

SELECT t.`template_code`, t.`template_id`, COUNT(s.`tmp_id`) AS sub_count,
       COUNT(DISTINCT s.`template_id`) AS sub_parent_count
FROM `scm_simple_template` t
LEFT JOIN `scm_simple_template_sub` s ON s.`template_id` = t.`template_id`
WHERE t.`template_code` IN (
  'collection-daily-ledger-export',
  'centralPurchaseStatistics',
  'coal-pit-daily-export',
  'priceTrend'
)
GROUP BY t.`template_code`, t.`template_id`
ORDER BY t.`template_code`;

-- ready_to_commit = 1 且四个模板分别为 9 / 11 / 14 / 9 列后，在同一会话单独执行：
-- COMMIT;
-- 任一结果不符合时执行：
-- ROLLBACK;
