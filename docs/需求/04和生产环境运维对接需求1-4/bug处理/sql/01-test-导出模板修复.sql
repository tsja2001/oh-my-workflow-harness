-- =====================================================================
-- test：修复集采日计划和价格趋势导出模板
-- 日期：2026-08-05
-- 目标库：scm_ubm_test
-- 影响范围：
--   1. centralPurchaseStatistics：用完整 11 列替换原错误 4 列
--   2. priceTrend：新增 1 条主模板和 9 条明细
-- 保护：执行前状态或新 ID 冲突时不会提交；执行后校验不通过自动回滚。
-- =====================================================================

USE `scm_ubm_test`;

DROP TEMPORARY TABLE IF EXISTS `_new_export_template_ids`;
CREATE TEMPORARY TABLE `_new_export_template_ids` (
  `id` varchar(32) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

INSERT INTO `_new_export_template_ids` (`id`) VALUES
('2084849556041154561'),
('2084849556057931778'),
('2084849556070514689'),
('2084849556087291906'),
('2084849556104069121'),
('2084849556120846338'),
('2084849556137623553'),
('2084849556154400770'),
('2084849556171177985'),
('2084849556187955202'),
('2084849556204732417'),
('2084849556548665346'),
('2084849556578025473'),
('2084849556594802690'),
('2084849556611579905'),
('2084849556628357122'),
('2084849556645134337'),
('2084849556661911554'),
('2084849556678688769'),
('2084849556695465986'),
('2084849556712243201');

-- 旧数据必须与调查时完全一致。
SELECT COUNT(*) INTO @central_main_count
FROM `scm_simple_template`
WHERE `template_id` = '2076476381372792834'
  AND `template_code` = 'centralPurchaseStatistics'
  AND `delete_sign` = 0;

SELECT COUNT(*) INTO @central_old_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834';

SELECT COUNT(*) INTO @central_old_exact_count
FROM `scm_simple_template_sub`
WHERE (`tmp_id` = '2076476381427318785' AND `sort_name` = '1' AND `field_name` = 'serialNumber' AND `field_val` = '流水号')
   OR (`tmp_id` = '2076476381439901698' AND `sort_name` = '2' AND `field_name` = 'executeUnitName' AND `field_val` = '集团集采类目名称')
   OR (`tmp_id` = '2076476381456678913' AND `sort_name` = '3' AND `field_name` = 'categoryCode' AND `field_val` = '集团集采类目编码')
   OR (`tmp_id` = '2076476381469261826' AND `sort_name` = '4' AND `field_name` = 'categoryName' AND `field_val` = '集团集采类目名称');

SELECT COUNT(*) INTO @price_main_count
FROM `scm_simple_template`
WHERE `template_code` = 'priceTrend';

SELECT COUNT(*) INTO @price_sub_count
FROM `scm_simple_template_sub`
WHERE `template_code` = 'priceTrend';

SELECT COUNT(*) INTO @new_main_collision_count
FROM `scm_simple_template` t
JOIN `_new_export_template_ids` n ON n.`id` = t.`template_id`;

SELECT COUNT(*) INTO @new_sub_collision_count
FROM `scm_simple_template_sub` s
JOIN `_new_export_template_ids` n ON n.`id` = s.`tmp_id`;

SET @precheck_ok = (
  @central_main_count = 1
  AND @central_old_sub_count = 4
  AND @central_old_exact_count = 4
  AND @price_main_count = 0
  AND @price_sub_count = 0
  AND @new_main_collision_count = 0
  AND @new_sub_collision_count = 0
);

SELECT @central_main_count AS central_main_count,
       @central_old_sub_count AS central_old_sub_count,
       @central_old_exact_count AS central_old_exact_count,
       @price_main_count AS price_main_count,
       @price_sub_count AS price_sub_count,
       @new_main_collision_count AS new_main_collision_count,
       @new_sub_collision_count AS new_sub_collision_count,
       @precheck_ok AS precheck_ok;

START TRANSACTION;

DELETE FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834'
  AND @precheck_ok = 1;
SET @deleted_central_sub = ROW_COUNT();

INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
SELECT * FROM (
  SELECT '2084849556041154561' AS tmp_id,'2076476381372792834' AS template_id,'centralPurchaseStatistics' AS template_code,'1' AS group_code,'1' AS sort_name,'serialNumber' AS field_name,'流水号' AS field_val,'String' AS field_type,'1' AS status,'system' AS create_by,'系统' AS create_by_name,'2026-08-05 11:50:43' AS create_time,'system' AS update_by,'系统' AS update_by_name,'2026-08-05 11:50:43' AS update_time,0 AS delete_sign,1 AS data_version
  UNION ALL SELECT '2084849556057931778','2076476381372792834','centralPurchaseStatistics','1','2','executeUnitName','集采执行单位','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556070514689','2076476381372792834','centralPurchaseStatistics','1','3','categoryName','集采类目','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556087291906','2076476381372792834','centralPurchaseStatistics','1','4','statisticsDate','统计日期','Date','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556104069121','2076476381372792834','centralPurchaseStatistics','1','5','planQuantity','当月计划总数量','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556120846338','2076476381372792834','centralPurchaseStatistics','1','6','responseQuantity','当月响应数量','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556137623553','2076476381372792834','centralPurchaseStatistics','1','7','executingQuantity','当月执行中数量','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556154400770','2076476381372792834','centralPurchaseStatistics','1','8','completedQuantity','当月已完成数量','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556171177985','2076476381372792834','centralPurchaseStatistics','1','9','delayedQuantity','当月已滞后数量','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556187955202','2076476381372792834','centralPurchaseStatistics','1','10','createTime','发布时间','Date','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556204732417','2076476381372792834','centralPurchaseStatistics','1','11','createByName','操作人','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
) AS central_rows
WHERE @precheck_ok = 1;
SET @inserted_central_sub = ROW_COUNT();

INSERT INTO `scm_simple_template`
(`template_id`,`template_code`,`template_desc`,`group_code`,`group_name`,`status`,`check_code`,
 `enable_check_code`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,
 `delete_sign`,`data_version`,`file_name`,`data_scan_limit`)
SELECT '2084849556548665346','priceTrend','价格趋势维护导出','source','寻源模块','1','',
       'false','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1,'价格趋势维护',NULL
WHERE @precheck_ok = 1;
SET @inserted_price_main = ROW_COUNT();

INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
SELECT * FROM (
  SELECT '2084849556578025473' AS tmp_id,'2084849556548665346' AS template_id,'priceTrend' AS template_code,'source' AS group_code,'1' AS sort_name,'serialNumber' AS field_name,'近12个月价格趋势流水号' AS field_val,'String' AS field_type,'1' AS status,'system' AS create_by,'系统' AS create_by_name,'2026-08-05 11:50:43' AS create_time,'system' AS update_by,'系统' AS update_by_name,'2026-08-05 11:50:43' AS update_time,0 AS delete_sign,1 AS data_version
  UNION ALL SELECT '2084849556594802690','2084849556548665346','priceTrend','source','2','executeUnitName','集采执行单位','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556611579905','2084849556548665346','priceTrend','source','3','year','年度','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556628357122','2084849556548665346','priceTrend','source','4','month','月份','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556645134337','2084849556548665346','priceTrend','source','5','categoryName','类目','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556661911554','2084849556548665346','priceTrend','source','6','indicatorName','指标','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556678688769','2084849556548665346','priceTrend','source','7','price','价格（元）','BigDecimal','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556695465986','2084849556548665346','priceTrend','source','8','publishTimeStr','发布时间','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
  UNION ALL SELECT '2084849556712243201','2084849556548665346','priceTrend','source','9','createByName','创建人','String','1','system','系统','2026-08-05 11:50:43','system','系统','2026-08-05 11:50:43',0,1
) AS price_rows
WHERE @precheck_ok = 1;
SET @inserted_price_sub = ROW_COUNT();

SELECT COUNT(*) INTO @central_new_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834'
  AND `template_code` = 'centralPurchaseStatistics'
  AND `status` = '1'
  AND `delete_sign` = 0;

SELECT COUNT(*) INTO @central_new_exact_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834'
  AND ((`sort_name` = '1' AND `field_name` = 'serialNumber')
    OR (`sort_name` = '2' AND `field_name` = 'executeUnitName')
    OR (`sort_name` = '3' AND `field_name` = 'categoryName')
    OR (`sort_name` = '4' AND `field_name` = 'statisticsDate')
    OR (`sort_name` = '5' AND `field_name` = 'planQuantity')
    OR (`sort_name` = '6' AND `field_name` = 'responseQuantity')
    OR (`sort_name` = '7' AND `field_name` = 'executingQuantity')
    OR (`sort_name` = '8' AND `field_name` = 'completedQuantity')
    OR (`sort_name` = '9' AND `field_name` = 'delayedQuantity')
    OR (`sort_name` = '10' AND `field_name` = 'createTime')
    OR (`sort_name` = '11' AND `field_name` = 'createByName'));

SELECT COUNT(*) INTO @price_new_main_count
FROM `scm_simple_template`
WHERE `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend'
  AND `status` = '1'
  AND `delete_sign` = 0;

SELECT COUNT(*) INTO @price_new_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend'
  AND `status` = '1'
  AND `delete_sign` = 0;

SELECT COUNT(DISTINCT `sort_name`) INTO @price_sort_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2084849556548665346'
  AND CAST(`sort_name` AS UNSIGNED) BETWEEN 1 AND 9;

SET @ready_to_commit = (
  @precheck_ok = 1
  AND @deleted_central_sub = 4
  AND @inserted_central_sub = 11
  AND @inserted_price_main = 1
  AND @inserted_price_sub = 9
  AND @central_new_sub_count = 11
  AND @central_new_exact_count = 11
  AND @price_new_main_count = 1
  AND @price_new_sub_count = 9
  AND @price_sort_count = 9
);

SET @transaction_action = IF(@ready_to_commit = 1, 'COMMIT', 'ROLLBACK');
PREPARE transaction_statement FROM @transaction_action;
EXECUTE transaction_statement;
DEALLOCATE PREPARE transaction_statement;

SELECT @deleted_central_sub AS deleted_central_sub,
       @inserted_central_sub AS inserted_central_sub,
       @inserted_price_main AS inserted_price_main,
       @inserted_price_sub AS inserted_price_sub,
       @central_new_sub_count AS central_new_sub_count,
       @central_new_exact_count AS central_new_exact_count,
       @price_new_main_count AS price_new_main_count,
       @price_new_sub_count AS price_new_sub_count,
       @price_sort_count AS price_sort_count,
       @ready_to_commit AS ready_to_commit,
       @transaction_action AS transaction_action;

SELECT t.`template_code`, t.`template_id`, COUNT(s.`tmp_id`) AS sub_count,
       MIN(CAST(s.`sort_name` AS UNSIGNED)) AS min_sort,
       MAX(CAST(s.`sort_name` AS UNSIGNED)) AS max_sort
FROM `scm_simple_template` t
LEFT JOIN `scm_simple_template_sub` s
  ON s.`template_id` = t.`template_id` AND s.`delete_sign` = 0
WHERE t.`template_code` IN ('centralPurchaseStatistics','priceTrend')
  AND t.`delete_sign` = 0
GROUP BY t.`template_code`, t.`template_id`
ORDER BY t.`template_code`;

DROP TEMPORARY TABLE IF EXISTS `_new_export_template_ids`;
