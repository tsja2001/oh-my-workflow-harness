-- =============================================================
-- 15集采目录维护台账 · ③ 回滚（只回滚 01 和 02 的结构改动）
-- ⚠️ 只在"新功能还没上线、没有任何业务数据写进新列"时才可以直接跑。
--    已经有数据了就别跑这个 —— DROP COLUMN 会连数据一起没，先导出备份。
-- 用法：bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/03-回滚.sql scm_source_test
-- =============================================================

SELECT '===== 回滚前先看一眼：新列里有没有已经写进去的数据 =====' AS step;
SELECT COUNT(*) 台账总行,
       SUM(collection_level  IS NOT NULL) 已写层级,
       SUM(is_strong_control IS NOT NULL) 已写强管控,
       SUM(status            IS NOT NULL) 已写状态
  FROM sc_plan_product_range;
SELECT '⚠️ 上面三个"已写"任意一个不为 0，就不要继续跑下面的 DROP —— 先备份' AS warn;

DROP PROCEDURE IF EXISTS p_drop_col;
DELIMITER //
CREATE PROCEDURE p_drop_col(IN tb VARCHAR(64), IN col VARCHAR(64))
BEGIN
  IF (SELECT COUNT(*) FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=tb AND COLUMN_NAME=col)>0 THEN
    SET @s := CONCAT('ALTER TABLE ', tb, ' DROP COLUMN ', col);
    PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
    SELECT CONCAT('dropped ', tb, '.', col) AS r;
  ELSE
    SELECT CONCAT('skip    ', tb, '.', col, ' 本来就没有') AS r;
  END IF;
END //
DELIMITER ;

-- 台账（注意：update_by / update_time / delete_sign / data_version 是本仓库标准审计列，
--       就算回滚也建议留着，所以默认不删。真要删就把下面三行的注释去掉。）
CALL p_drop_col('sc_plan_product_range','collection_level');
CALL p_drop_col('sc_plan_product_range','is_strong_control');
CALL p_drop_col('sc_plan_product_range','status');
CALL p_drop_col('sc_plan_product_range','invalid_time');
-- CALL p_drop_col('sc_plan_product_range','delete_sign');
-- CALL p_drop_col('sc_plan_product_range','data_version');
-- CALL p_drop_col('sc_plan_product_range','update_by');

-- 六张单据表
CALL p_drop_col('sc_plan','collection_level');                   CALL p_drop_col('sc_plan','is_strong_control');
CALL p_drop_col('sc_plan_product','collection_level');           CALL p_drop_col('sc_plan_product','is_strong_control');
CALL p_drop_col('sc_scheme','collection_level');                 CALL p_drop_col('sc_scheme','is_strong_control');
CALL p_drop_col('sc_scheme_to_purchase','collection_level');     CALL p_drop_col('sc_scheme_to_purchase','is_strong_control');
CALL p_drop_col('sc_scheme_to_purchase_log','collection_level'); CALL p_drop_col('sc_scheme_to_purchase_log','is_strong_control');
CALL p_drop_col('sc_supplier_green_channel','collection_level'); CALL p_drop_col('sc_supplier_green_channel','is_strong_control');
CALL p_drop_col('sc_plan','collection_change_reason');
CALL p_drop_col('sc_scheme','collection_change_reason');
CALL p_drop_col('sc_supplier_green_channel','collection_change_reason');

DROP PROCEDURE IF EXISTS p_drop_col;

-- ⚠️ 唯一索引 range_product_idx 不自动恢复：
--    恢复它之前必须先确认表里没有重复的 (product_code, category_code)，否则建索引会失败。
--    需要的话手动跑：
--    CREATE UNIQUE INDEX range_product_idx ON sc_plan_product_range (product_code, category_code);
