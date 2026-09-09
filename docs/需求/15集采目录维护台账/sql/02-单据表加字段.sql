-- =============================================================
-- 15集采目录维护台账 · ② 六张单据表加列
-- 适用库：scm_source_test / scm_source_uat
-- 用法：  bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/02-单据表加字段.sql scm_source_test
--
-- 为什么六张（不是需求文档说的五张）：
--   sc_scheme_to_purchase_log 也有 is_collection / collection_supplier_code（2026-09-08 实测），
--   漏了它，待采购池的历史日志就跟主表对不上。
-- 为什么现在就提：新列全是 NULL、不影响任何现有逻辑，而 DDL 上环境要走流程——攒一次比分两次省事。
-- 幂等：同 01。
-- =============================================================

DROP PROCEDURE IF EXISTS p_add_col;
DELIMITER //
CREATE PROCEDURE p_add_col(IN tb VARCHAR(64), IN col VARCHAR(64), IN ddl VARCHAR(500))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=tb AND COLUMN_NAME=col)=0 THEN
    SET @s := CONCAT('ALTER TABLE ', tb, ' ADD COLUMN ', ddl);
    PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
    SELECT CONCAT('added  ', tb, '.', col) AS r;
  ELSE
    SELECT CONCAT('skip   ', tb, '.', col, ' 已存在') AS r;
  END IF;
END //
DELIMITER ;

-- ---------- 六张表都加：集采目录层级 + 是否强管控 ----------
CALL p_add_col('sc_plan',                   'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级 1集团 2二级集团 3区域企业''');
CALL p_add_col('sc_plan',                   'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控 1是 0否''');
CALL p_add_col('sc_plan_product',           'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级（行级）''');
CALL p_add_col('sc_plan_product',           'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控（行级）''');
CALL p_add_col('sc_scheme',                 'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级''');
CALL p_add_col('sc_scheme',                 'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控''');
CALL p_add_col('sc_scheme_to_purchase',     'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级''');
CALL p_add_col('sc_scheme_to_purchase',     'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控''');
CALL p_add_col('sc_scheme_to_purchase_log', 'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级''');
CALL p_add_col('sc_scheme_to_purchase_log', 'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控''');
CALL p_add_col('sc_supplier_green_channel', 'collection_level',  'collection_level VARCHAR(16) NULL COMMENT ''集采目录层级''');
CALL p_add_col('sc_supplier_green_channel', 'is_strong_control', 'is_strong_control TINYINT(1) NULL COMMENT ''是否强管控''');

-- ---------- 三张"有表头、能改是否集采"的再加：改成否的原因（13 §1 D18）----------
CALL p_add_col('sc_plan',                   'collection_change_reason', 'collection_change_reason VARCHAR(512) NULL COMMENT ''是否集采改为否的原因''');
CALL p_add_col('sc_scheme',                 'collection_change_reason', 'collection_change_reason VARCHAR(512) NULL COMMENT ''是否集采改为否的原因''');
CALL p_add_col('sc_supplier_green_channel', 'collection_change_reason', 'collection_change_reason VARCHAR(512) NULL COMMENT ''是否集采改为否的原因''');

DROP PROCEDURE IF EXISTS p_add_col;

-- ---------- 自检 ----------
SELECT '===== 自检：应该 15 行 =====' AS step;
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE()
   AND COLUMN_NAME IN ('collection_level','is_strong_control','collection_change_reason')
 ORDER BY TABLE_NAME, COLUMN_NAME;
