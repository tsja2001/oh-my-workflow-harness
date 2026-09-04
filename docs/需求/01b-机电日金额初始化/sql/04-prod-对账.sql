-- ============================================================
-- 01b 机电日金额初始化 · PROD 对账 SQL（同步后执行，配合 20 执行手册）
-- 日期：2026-09-04 ｜ 生成：oc
-- ============================================================

USE `scm_source_prod`;

-- ① 初始化行本身（期望：81 | 128740939.09）
SELECT COUNT(*) AS init_rows, SUM(`tax_amount`) AS init_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰';

-- ② 全部机电行（应等于 ES dataSource=JD 的条数与金额；含历史测试行）
--    期望：81 行 + 预检⑤实测基线（prod 基线未知，执行后以实测为准）
SELECT COUNT(*) AS all_rows, SUM(`tax_amount`) AS all_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000';

-- ③ 初始化行按类目（= 驾驶舱/首页四格的增量）
SELECT `category_code`,`category_name`,COUNT(*) AS cnt,SUM(`tax_amount`) AS amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰'
GROUP BY `category_code`,`category_name` ORDER BY `category_code`;

-- ④ 初始化行按板块×类目（明细核对用）
SELECT `bu_code`,`bu_name`,`category_name`,COUNT(*) AS cnt,SUM(`tax_amount`) AS amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰'
GROUP BY `bu_code`,`bu_name`,`category_name` ORDER BY `bu_code`,`category_name`;
