-- =============================================================
-- 15集采目录维护台账 · ⑤r 回滚：把台账整表还原成 2026-09-09 改动前的样子
-- 用法：bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/05r-回滚到备份.sql scm_source_test
--       bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/05r-回滚到备份.sql scm_source_uat
--
-- 依赖备份表 sc_plan_product_range_bak_20260909（01/05 执行前建的，行数：test 5 / uat 7343）。
-- 备份表被清了的话，用文件恢复：
--   mysql <连接参数> scm_source_uat < ai-docs/db-backup/scm_source_uat.sc_plan_product_range.20260909.sql
--
-- 注意：本脚本只还原【数据】。01 加的 9 个列不会退回去（新列全是 NULL 或有默认值，
--       留着不影响任何老逻辑）。真要连列一起退，用 03-回滚.sql。
--       ⚠️ uat 的唯一索引 range_product_idx 是 01 删掉的，本脚本不会重建 —— 3.2 要求它必须没有。
-- =============================================================

SELECT '########## 回滚前 ##########' AS step;
SELECT DATABASE() 库,
       (SELECT COUNT(*) FROM sc_plan_product_range) 现表,
       (SELECT COUNT(*) FROM sc_plan_product_range_bak_20260909) 备份表;

-- 只留备份表里有的列；新列回到"没刷过"的状态
DELETE FROM sc_plan_product_range;

INSERT INTO sc_plan_product_range
 (range_id, product_code, product_name, category_code, category_name,
  bu_code, bu_name, supplier_id, supplier_code, supplier_name,
  create_by, create_by_name, create_time)
SELECT range_id, product_code, product_name, category_code, category_name,
       bu_code, bu_name, supplier_id, supplier_code, supplier_name,
       create_by, create_by_name, create_time
  FROM sc_plan_product_range_bak_20260909;

SELECT '########## 回滚后 ##########' AS step;
SELECT COUNT(*) 行数,
       SUM(collection_level IS NOT NULL) 层级非空_应为0,
       SUM(create_by='TESTDATA')          造的行_应为0
  FROM sc_plan_product_range;
