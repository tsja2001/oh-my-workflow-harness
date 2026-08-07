-- test：价格趋势导出改用接口已经格式化好的发布时间字段。
-- 目标库：scm_ubm_test
-- 保护：仅在第 8 列仍为 publishTime/Date 时提交，否则回滚。

USE `scm_ubm_test`;

SELECT COUNT(*) INTO @precheck_count
FROM `scm_simple_template_sub`
WHERE `tmp_id` = '2084849556695465986'
  AND `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend'
  AND `sort_name` = '8'
  AND `field_name` = 'publishTime'
  AND `field_type` = 'Date'
  AND `status` = '1'
  AND `delete_sign` = 0;

START TRANSACTION;

UPDATE `scm_simple_template_sub`
SET `field_name` = 'publishTimeStr',
    `field_type` = 'String',
    `update_by` = 'system',
    `update_by_name` = '系统',
    `update_time` = NOW()
WHERE `tmp_id` = '2084849556695465986'
  AND @precheck_count = 1;
SET @updated_count = ROW_COUNT();

SELECT COUNT(*) INTO @fixed_count
FROM `scm_simple_template_sub`
WHERE `tmp_id` = '2084849556695465986'
  AND `template_id` = '2084849556548665346'
  AND `template_code` = 'priceTrend'
  AND `sort_name` = '8'
  AND `field_name` = 'publishTimeStr'
  AND `field_type` = 'String'
  AND `status` = '1'
  AND `delete_sign` = 0;

SET @ready_to_commit = (
  @precheck_count = 1
  AND @updated_count = 1
  AND @fixed_count = 1
);
SET @transaction_action = IF(@ready_to_commit = 1, 'COMMIT', 'ROLLBACK');
PREPARE transaction_statement FROM @transaction_action;
EXECUTE transaction_statement;
DEALLOCATE PREPARE transaction_statement;

SELECT @precheck_count AS precheck_count,
       @updated_count AS updated_count,
       @fixed_count AS fixed_count,
       @ready_to_commit AS ready_to_commit,
       @transaction_action AS transaction_action;

SELECT `tmp_id`,`template_id`,`template_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
       `status`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`
FROM `scm_simple_template_sub`
WHERE `tmp_id` = '2084849556695465986';
