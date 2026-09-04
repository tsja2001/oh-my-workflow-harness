-- ============================================================
-- 01b 机电日金额初始化 · TEST 对账 SQL（同步后执行，配合 20 文档）
-- 日期：2026-09-04 ｜ 生成：oc
-- ============================================================

USE `scm_source_test`;

-- ① 初始化行本身（期望：81 | 128740939.09）
SELECT COUNT(*) AS init_rows, SUM(`tax_amount`) AS init_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰';

-- ② 全部机电行（应等于 ES 里 dataSource=JD 的条数与金额；含 test 历史测试行）
SELECT COUNT(*) AS all_rows, SUM(`tax_amount`) AS all_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000';

-- ③ 初始化行按类目（= 驾驶舱/首页四格的增量，灌库前数字 + 下表 = 灌库后数字）
SELECT `category_code`,`category_name`,COUNT(*) AS cnt,SUM(`tax_amount`) AS amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰'
GROUP BY `category_code`,`category_name` ORDER BY `category_code`;

-- ④ 初始化行按板块×类目（明细核对用）
SELECT `bu_code`,`bu_name`,`category_name`,COUNT(*) AS cnt,SUM(`tax_amount`) AS amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰'
GROUP BY `bu_code`,`bu_name`,`category_name` ORDER BY `bu_code`,`category_name`;
