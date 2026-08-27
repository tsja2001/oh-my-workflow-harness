-- ============================================================
-- 价格趋势·钢材指标改名  回滚（test / uat / 生产 通用）
--
-- 日期 2026-08-24 ｜ 需求 19新需求 ｜ 表 sc_price_trend
--
-- 原理：照 01/02/03 建的备份表 sc_price_trend_bak_20260824，
--       按主键把指标名抄回去。备份表里装的就是"改名前确实叫旧名字"的那些行，
--       所以只会还原它们，不会误伤改名之后新录入的数据。
--
-- ⚠️ 回滚数据的同时，后端和前端代码也要一起回退，否则曲线照样是空的。
-- ============================================================

-- 执行前先切到对应的库：
-- USE scm_source_test;  /  USE scm_source_uat;  /  USE <生产库名>;

-- 【0】确认库对不对
SELECT DATABASE() AS current_db;


-- 【1】预览：将被还原的行（先看一眼再动手）
SELECT t.trend_id, t.serial_number, t.year, t.month,
       t.indicator_name AS current_name,
       b.indicator_name AS restore_to
FROM sc_price_trend t
JOIN sc_price_trend_bak_20260824 b ON t.trend_id = b.trend_id
WHERE t.indicator_name <> b.indicator_name;


-- 【2】还原
UPDATE sc_price_trend t
JOIN sc_price_trend_bak_20260824 b ON t.trend_id = b.trend_id
SET t.indicator_name = b.indicator_name;


-- 【3】核对：【1】那条查询现在应该一行都查不出来（下面的数应为 0）
SELECT COUNT(*) AS mismatch_rows
FROM sc_price_trend t
JOIN sc_price_trend_bak_20260824 b ON t.trend_id = b.trend_id
WHERE t.indicator_name <> b.indicator_name;
