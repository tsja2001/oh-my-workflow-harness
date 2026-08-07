-- =====================================================================
-- test：回滚 2026-08-05 集采日计划和价格趋势导出模板修复
-- 目标库：scm_ubm_test
-- 结果：恢复日计划原 4 列，删除本次新增的 priceTrend 模板。
-- 保护：当前数据与本次修复结果不一致时不会提交。
-- =====================================================================

USE `scm_ubm_test`;

SELECT COUNT(*) INTO @central_main_count
FROM `scm_simple_template`
WHERE `template_id` = '2076476381372792834'
  AND `template_code` = 'centralPurchaseStatistics'
  AND `delete_sign` = 0;

SELECT COUNT(*) INTO @central_fixed_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834'
  AND `tmp_id` IN (
    '2084849556041154561','2084849556057931778','2084849556070514689','2084849556087291906',
    '2084849556104069121','2084849556120846338','2084849556137623553','2084849556154400770',
    '2084849556171177985','2084849556187955202','2084849556204732417'
  );

SELECT COUNT(*) INTO @central_all_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834';

SELECT COUNT(*) INTO @old_central_id_collision_count
FROM `scm_simple_template_sub`
WHERE `tmp_id` IN (
  '2076476381427318785','2076476381439901698','2076476381456678913','2076476381469261826'
);

SELECT COUNT(*) INTO @price_main_count
FROM `scm_simple_template`
WHERE `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend';

SELECT COUNT(*) INTO @price_fixed_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2084849556548665346'
  AND `tmp_id` IN (
    '2084849556578025473','2084849556594802690','2084849556611579905',
    '2084849556628357122','2084849556645134337','2084849556661911554',
    '2084849556678688769','2084849556695465986','2084849556712243201'
  );

SELECT COUNT(*) INTO @price_all_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2084849556548665346';

SET @precheck_ok = (
  @central_main_count = 1
  AND @central_fixed_sub_count = 11
  AND @central_all_sub_count = 11
  AND @old_central_id_collision_count = 0
  AND @price_main_count = 1
  AND @price_fixed_sub_count = 9
  AND @price_all_sub_count = 9
);

SELECT @central_main_count AS central_main_count,
       @central_fixed_sub_count AS central_fixed_sub_count,
       @central_all_sub_count AS central_all_sub_count,
       @old_central_id_collision_count AS old_central_id_collision_count,
       @price_main_count AS price_main_count,
       @price_fixed_sub_count AS price_fixed_sub_count,
       @price_all_sub_count AS price_all_sub_count,
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
  SELECT '2076476381427318785' AS tmp_id,'2076476381372792834' AS template_id,'centralPurchaseStatistics' AS template_code,'1' AS group_code,'1' AS sort_name,'serialNumber' AS field_name,'流水号' AS field_val,'String' AS field_type,'1' AS status,'10930002' AS create_by,'张雨' AS create_by_name,'2026-07-13 09:18:43' AS create_time,'10930002' AS update_by,'张雨' AS update_by_name,'2026-07-13 09:18:43' AS update_time,0 AS delete_sign,1 AS data_version
  UNION ALL SELECT '2076476381439901698','2076476381372792834','centralPurchaseStatistics','1','2','executeUnitName','集团集采类目名称','String','1','10930002','张雨','2026-07-13 09:18:43','10930002','张雨','2026-07-13 09:18:43',0,1
  UNION ALL SELECT '2076476381456678913','2076476381372792834','centralPurchaseStatistics','1','3','categoryCode','集团集采类目编码','String','1','10930002','张雨','2026-07-13 09:18:43','10930002','张雨','2026-07-13 09:18:43',0,1
  UNION ALL SELECT '2076476381469261826','2076476381372792834','centralPurchaseStatistics','1','4','categoryName','集团集采类目名称','String','1','10930002','张雨','2026-07-13 09:18:43','10930002','张雨','2026-07-13 09:18:43',0,1
) AS old_central_rows
WHERE @precheck_ok = 1;
SET @inserted_old_central_sub = ROW_COUNT();

DELETE FROM `scm_simple_template_sub`
WHERE `template_id` = '2084849556548665346'
  AND @precheck_ok = 1;
SET @deleted_price_sub = ROW_COUNT();

DELETE FROM `scm_simple_template`
WHERE `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend'
  AND @precheck_ok = 1;
SET @deleted_price_main = ROW_COUNT();

SELECT COUNT(*) INTO @restored_central_sub_count
FROM `scm_simple_template_sub`
WHERE `template_id` = '2076476381372792834'
  AND `tmp_id` IN (
    '2076476381427318785','2076476381439901698','2076476381456678913','2076476381469261826'
  );

SELECT COUNT(*) INTO @remaining_price_main_count
FROM `scm_simple_template`
WHERE `template_code` = 'priceTrend';

SELECT COUNT(*) INTO @remaining_price_sub_count
FROM `scm_simple_template_sub`
WHERE `template_code` = 'priceTrend';

SET @ready_to_commit = (
  @precheck_ok = 1
  AND @deleted_central_sub = 11
  AND @inserted_old_central_sub = 4
  AND @deleted_price_sub = 9
  AND @deleted_price_main = 1
  AND @restored_central_sub_count = 4
  AND @remaining_price_main_count = 0
  AND @remaining_price_sub_count = 0
);

SET @transaction_action = IF(@ready_to_commit = 1, 'COMMIT', 'ROLLBACK');
PREPARE transaction_statement FROM @transaction_action;
EXECUTE transaction_statement;
DEALLOCATE PREPARE transaction_statement;

SELECT @deleted_central_sub AS deleted_central_sub,
       @inserted_old_central_sub AS inserted_old_central_sub,
       @deleted_price_sub AS deleted_price_sub,
       @deleted_price_main AS deleted_price_main,
       @restored_central_sub_count AS restored_central_sub_count,
       @remaining_price_main_count AS remaining_price_main_count,
       @remaining_price_sub_count AS remaining_price_sub_count,
       @ready_to_commit AS ready_to_commit,
       @transaction_action AS transaction_action;
