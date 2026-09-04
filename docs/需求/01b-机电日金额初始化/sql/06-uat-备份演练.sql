-- ============================================================
-- 01b 机电日金额初始化 · 备份语句演练（UAT）
-- 日期：2026-09-04 ｜ 生成：cc
-- 目的：prod 灌库前要执行的 Section 0 备份，先在 uat 演练确认无坑
--   本文件 = 02-prod-初始化.sql 的 Section 0 原样（仅库名换 uat）
-- 可重复执行：CREATE IF NOT EXISTS + INSERT IGNORE，跑十遍结果一样
-- ============================================================

USE `scm_source_uat`;

-- ① 建快照表（结构/主键/唯一键/索引与主表完全一致）
CREATE TABLE IF NOT EXISTS `sc_collection_daily_amount_ledger_bak_20260904`
  LIKE `sc_collection_daily_amount_ledger`;

-- ② 拷贝"灌库前"状态（排除 INITJD 行，重跑不会把初始化数据混进备份）
INSERT IGNORE INTO `sc_collection_daily_amount_ledger_bak_20260904`
SELECT * FROM `sc_collection_daily_amount_ledger`
WHERE `ledger_id` NOT LIKE 'INITJD%';

-- ③ 核对
--    uat 期望：主表 85 ｜ 备份 4 ｜ 差 = 81（即我们的初始化行，本就不进备份）
SELECT (SELECT COUNT(*) FROM `sc_collection_daily_amount_ledger`)              AS 主表行数,
       (SELECT COUNT(*) FROM `sc_collection_daily_amount_ledger_bak_20260904`) AS 备份行数,
       (SELECT COUNT(*) FROM `sc_collection_daily_amount_ledger`) -
       (SELECT COUNT(*) FROM `sc_collection_daily_amount_ledger_bak_20260904`) AS 差_应为81;

-- ④ 备份内容抽查（应只有张雨/郭小华那 2 行机电 + 其他执行单位 2 行，无董杰 INITJD 行）
SELECT `ledger_id`,`ledger_no`,`create_by_name`,`tax_amount`
FROM `sc_collection_daily_amount_ledger_bak_20260904`
ORDER BY `ledger_id`;

-- ⑤ 演练完清理（uat 里这张表没用了，prod 上不执行这句）
-- DROP TABLE IF EXISTS `sc_collection_daily_amount_ledger_bak_20260904`;
