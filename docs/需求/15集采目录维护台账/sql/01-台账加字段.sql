-- =============================================================
-- 15集采目录维护台账 · ① 台账表 DDL
-- 目标表：sc_plan_product_range   适用库：scm_source_test / scm_source_uat
-- 用法：  bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/01-台账加字段.sql scm_source_test
--         bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/01-台账加字段.sql scm_source_uat
--
-- 设计要点（为什么这么写）：
--   1. 全部幂等：每条 ALTER 先查 information_schema，跑第二遍不会报错。
--      dbq.sh 走 mysql 批处理、遇第一个错误即整体中止，不幂等就没法重跑。
--   2. 新列一律 NULL、不加 NOT NULL —— 先上表结构、再刷数据、最后开新逻辑，
--      中间任何一步停下来都不会卡住线上业务。
--   3. 唯一索引 range_product_idx：uat 有、test 没有（2026-09-08 实测）。
--      必须先查再删，不能裸 DROP INDEX（test 上会报 1091 中止整个脚本）。
--      删它的原因：需求 3.3「同一物料可以属于不同二级集团或区域」= 同一 (product_code, category_code) 必须能存多行。
--   4. 本脚本只改结构，不动一行数据。期初 UPDATE 在另一个文件，别混。
-- =============================================================

SELECT '===== 执行前快照 =====' AS step;
SELECT DATABASE() AS 当前库, COUNT(*) AS 台账行数 FROM sc_plan_product_range;

-- ---------- ① 四个业务列 ----------
SET @t := 'sc_plan_product_range';

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='collection_level')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN collection_level VARCHAR(16) NULL COMMENT ''集采目录层级 1集团集采 2二级集团集采 3区域企业集采''',
 'SELECT ''skip: collection_level 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='is_strong_control')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN is_strong_control TINYINT(1) NULL COMMENT ''是否强管控 1是 0否''',
 'SELECT ''skip: is_strong_control 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='status')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN status VARCHAR(8) NULL COMMENT ''状态 1生效 0失效''',
 'SELECT ''skip: status 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='invalid_time')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN invalid_time DATETIME NULL COMMENT ''失效时间''',
 'SELECT ''skip: invalid_time 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------- ② 标准审计列（这张表现在一个都没有，连"谁删的"都记不了）----------
SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='update_by')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN update_by VARCHAR(32) NULL COMMENT ''修改人ID''',
 'SELECT ''skip: update_by 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='update_by_name')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN update_by_name VARCHAR(64) NULL COMMENT ''修改人''',
 'SELECT ''skip: update_by_name 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='update_time')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN update_time DATETIME NULL COMMENT ''修改时间''',
 'SELECT ''skip: update_time 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- delete_sign：MyBatis-Plus @TableLogic 用的框架兜底（全仓 70 处在用同一套）
SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='delete_sign')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN delete_sign TINYINT(1) NOT NULL DEFAULT 0 COMMENT ''逻辑删除 0未删 1已删''',
 'SELECT ''skip: delete_sign 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='data_version')=0,
 'ALTER TABLE sc_plan_product_range ADD COLUMN data_version INT NOT NULL DEFAULT 1 COMMENT ''数据版本''',
 'SELECT ''skip: data_version 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------- ③ 影响范围放长（现在 256，'/' 分隔最多约 28 个码；区域码比板块码长）----------
SET @sql := (SELECT IF((SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='bu_code') < 2000,
 'ALTER TABLE sc_plan_product_range MODIFY COLUMN bu_code VARCHAR(2000) NULL COMMENT ''影响范围编码，/分隔（集团=全部；二级集团=板块码；区域=区域组织编码）''',
 'SELECT ''skip: bu_code 已够长'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF((SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND COLUMN_NAME='bu_name') < 4000,
 'ALTER TABLE sc_plan_product_range MODIFY COLUMN bu_name VARCHAR(4000) NULL COMMENT ''影响范围名称，/分隔''',
 'SELECT ''skip: bu_name 已够长'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------- ④ 删唯一索引（uat 有 / test 没有，先查再删）----------
SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND INDEX_NAME='range_product_idx')>0,
 'DROP INDEX range_product_idx ON sc_plan_product_range',
 'SELECT ''skip: range_product_idx 本库没有（test 就是这样，正常）'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------- ⑤ 补普通索引（判定引擎会按 类目/物料 高频查）----------
SET @sql := (SELECT IF((SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=@t AND INDEX_NAME='idx_range_lookup')=0,
 'CREATE INDEX idx_range_lookup ON sc_plan_product_range (category_code, product_code, status)',
 'SELECT ''skip: idx_range_lookup 已存在'''));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------- 执行后自检 ----------
SELECT '===== 执行后自检（应该 9 个新列全部 present、唯一索引没了）=====' AS step;
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_COMMENT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='sc_plan_product_range'
   AND COLUMN_NAME IN ('collection_level','is_strong_control','status','invalid_time',
                       'update_by','update_by_name','update_time','delete_sign','data_version','bu_code','bu_name')
 ORDER BY ORDINAL_POSITION;

SELECT INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) 列, NON_UNIQUE
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='sc_plan_product_range'
 GROUP BY INDEX_NAME, NON_UNIQUE;
