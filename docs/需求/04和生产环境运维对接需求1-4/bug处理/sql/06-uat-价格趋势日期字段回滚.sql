-- UAT：回滚价格趋势导出发布时间字段修复。
-- 目标库：scm_ubm_uat
-- 保护：仅在第 8 列为本次修复结果时提交，否则回滚。

USE `scm_ubm_uat`;

SELECT COUNT(*) INTO @precheck_count
FROM `scm_simple_template_sub`
WHERE `tmp_id` = '2084540332552220733'
  AND `template_id` = '2084540332552220691'
  AND `template_code` = 'priceTrend'
  AND `sort_name` = '8'
  AND `field_name` = 'publishTimeStr'
  AND `field_type` = 'String'
  AND `status` = '1'
  AND `delete_sign` = 0;

START TRANSACTION;

UPDATE `scm_simple_template_sub`
SET `field_name` = 'publishTime',
    `field_type` = 'Date',
    `update_by` = 'system',
    `update_by_name` = '系统',
    `update_time` = '2026-07-30 10:41:01',
    `data_version` = 1
WHERE `tmp_id` = '2084540332552220733'
  AND @precheck_count = 1;
SET @updated_count = ROW_COUNT();

SELECT COUNT(*) INTO @restored_count
FROM `scm_simple_template_sub`
WHERE `tmp_id` = '2084540332552220733'
  AND `template_id` = '2084540332552220691'
  AND `template_code` = 'priceTrend'
  AND `sort_name` = '8'
  AND `field_name` = 'publishTime'
  AND `field_type` = 'Date'
  AND `status` = '1'
  AND `delete_sign` = 0;

SET @ready_to_commit = (
  @precheck_count = 1
  AND @updated_count = 1
  AND @restored_count = 1
);
SET @transaction_action = IF(@ready_to_commit = 1, 'COMMIT', 'ROLLBACK');
PREPARE transaction_statement FROM @transaction_action;
EXECUTE transaction_statement;
DEALLOCATE PREPARE transaction_statement;

SELECT @precheck_count AS precheck_count,
       @updated_count AS updated_count,
       @restored_count AS restored_count,
       @ready_to_commit AS ready_to_commit,
       @transaction_action AS transaction_action;
