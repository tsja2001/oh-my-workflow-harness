-- ============================================================
-- 【彩排】看看 UPDATE 会改成什么样，但一个字都不真的落库
--
-- 日期：2026-08-24 ｜ 工具：cc
-- 用途：第一次手动跑 SQL 时先跑这个，心里有底了再跑 01。
--
-- 原理：整段包在一个事务里。
--   START TRANSACTION  = 「开始记账，先别当真」
--   UPDATE             = 真的改了，但只在本次连接里可见
--   SELECT             = 看改完长什么样
--   ROLLBACK           = 「刚才那些不算」，全部撤销，数据库回到原样
-- 所以跑完之后表还是原来的表，别人查也查不到任何变化。
--
-- ⚠️ 必须整个文件一次性执行（bash scripts/dbq.sh 这个文件路径）。
--    分几次执行会断连接，事务自动回滚或不成立，达不到预演效果。
-- ============================================================

USE scm_source_test;

START TRANSACTION;

UPDATE sc_price_trend
SET indicator_name = '螺纹唐山出厂价'
WHERE indicator_name = '螺纹月成交价格';

UPDATE sc_price_trend
SET indicator_name = '中厚板唐山出厂价'
WHERE indicator_name = '中厚板月成交价格';

-- 这就是真跑之后会看到的样子
SELECT indicator_name, delete_sign, COUNT(*) AS cnt
FROM sc_price_trend
WHERE indicator_name IN ('螺纹月成交价格', '中厚板月成交价格', '螺纹唐山出厂价', '中厚板唐山出厂价')
GROUP BY indicator_name, delete_sign;

-- 撤销，什么都没发生过
ROLLBACK;

-- 回滚后复查：应该又变回旧名字，新名字 0 行
SELECT indicator_name, delete_sign, COUNT(*) AS cnt
FROM sc_price_trend
WHERE indicator_name IN ('螺纹月成交价格', '中厚板月成交价格', '螺纹唐山出厂价', '中厚板唐山出厂价')
GROUP BY indicator_name, delete_sign;
