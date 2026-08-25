-- ============================================================
-- 价格趋势·钢材指标改名（UAT）
--   螺纹月成交价格   →  螺纹唐山出厂价
--   中厚板月成交价格 →  中厚板唐山出厂价
--
-- 日期 2026-08-24 ｜ 需求 19新需求 ｜ 表 sc_price_trend
-- 回滚：04-回滚-三环境通用.sql（一句话，照备份表还原）
--
-- ⚠️ 必须和后端代码在同一个发布窗口执行。
--    只改数据不发代码（或反过来），驾驶舱和集采门户的螺纹、
--    中厚板两条曲线会变空，而且不报错。
-- ============================================================

USE scm_source_uat;

-- 【0】确认库对不对，不对就别往下跑
SELECT DATABASE() AS current_db;


-- 【1】备份：把要改的行原样存一份
--     （本库是 Percona 集群，禁止 CREATE TABLE AS SELECT，所以拆成两句）
CREATE TABLE sc_price_trend_bak_20260824 LIKE sc_price_trend;

INSERT INTO sc_price_trend_bak_20260824
SELECT * FROM sc_price_trend
WHERE indicator_name IN ('螺纹月成交价格', '中厚板月成交价格');

-- 检查点①：备份行数应 > 0，uat 2026-08-24 实测为 24
SELECT COUNT(*) AS backup_rows FROM sc_price_trend_bak_20260824;


-- 【2】改名
UPDATE sc_price_trend SET indicator_name = '螺纹唐山出厂价'
WHERE indicator_name = '螺纹月成交价格';

UPDATE sc_price_trend SET indicator_name = '中厚板唐山出厂价'
WHERE indicator_name = '中厚板月成交价格';


-- 【3】核对：结果里不应再出现"螺纹月成交价格""中厚板月成交价格"
SELECT indicator_name, delete_sign, COUNT(*) AS cnt
FROM sc_price_trend
WHERE category_code = 'STEEL'
GROUP BY indicator_name, delete_sign
ORDER BY indicator_name;
