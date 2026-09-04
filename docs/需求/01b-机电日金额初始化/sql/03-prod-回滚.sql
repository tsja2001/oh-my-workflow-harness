-- ============================================================
-- 01b 机电日金额初始化 · PROD 回滚
-- 日期：2026-09-04 ｜ 生成：oc
-- 双保险定位：ledger_id INITJD 前缀 + 创建人=董杰
-- 回滚后必须重新触发一次 syncJd 同步（ES 是覆盖写，数字即回落）
-- ============================================================

USE `scm_source_prod`;

-- 方式一：逻辑删（推荐，可追溯）
UPDATE `sc_collection_daily_amount_ledger`
SET `delete_sign`=1, `update_time`=NOW()
WHERE `ledger_id` LIKE 'INITJD%' AND `create_by_name`='董杰' AND `delete_sign`=0;

-- 核验（期望：81）
SELECT COUNT(*) AS 已回滚行数
FROM `sc_collection_daily_amount_ledger`
WHERE `ledger_id` LIKE 'INITJD%' AND `create_by_name`='董杰' AND `delete_sign`=1;

-- 方式二：物理删（备用，删前先备份）
-- DELETE FROM `sc_collection_daily_amount_ledger`
-- WHERE `ledger_id` LIKE 'INITJD%' AND `create_by_name`='董杰';

-- 回滚的行明细（留档用）
SELECT `ledger_no`,`statistic_date`,`category_name`,`purchase_company_name`,`tax_amount`
FROM `sc_collection_daily_amount_ledger`
WHERE `ledger_id` LIKE 'INITJD%' AND `create_by_name`='董杰'
ORDER BY `statistic_date`,`ledger_no`;
