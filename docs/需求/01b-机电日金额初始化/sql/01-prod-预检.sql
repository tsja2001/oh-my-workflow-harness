-- ============================================================
-- 01b 机电日金额初始化 · PROD 预检（只读，灌库前执行）
-- 日期：2026-09-04 ｜ 生成：oc ｜ 数据源：机电公司导入模板2026.9.4全.xlsx
-- 期望结果见每节末尾「期望」注释。全部符合才可执行 02。
-- ============================================================

USE `scm_source_prod`;

-- ① 流水号撞号检查：8 个统计日中段在全表 ledger_no 的占用数
--    期望：8 行全部 = 0
SELECT '2026-02-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260201-%'
UNION ALL
SELECT '2026-03-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260301-%'
UNION ALL
SELECT '2026-04-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260401-%'
UNION ALL
SELECT '2026-05-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260501-%'
UNION ALL
SELECT '2026-06-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260601-%'
UNION ALL
SELECT '2026-07-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260701-%'
UNION ALL
SELECT '2026-08-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260801-%'
UNION ALL
SELECT '2026-09-01' AS 统计日, COUNT(*) AS 已占用数 FROM `sc_collection_daily_amount_ledger` WHERE `ledger_no` LIKE 'JCRJE-20260901-%';

-- ② 六家采购组织在本环境核验（org_name 按本环境实查值）
--    期望：6 行；belong_bu_code = BU002/BU004/BU005/BU006/BU008/BU010
SELECT `org_code`,`org_name`,`belong_bu_code`
FROM `scm_ubm`.`ubm_organization`
WHERE `org_code` IN ('10010000','10000000','18001000','18002000','18004000','18005059')
ORDER BY `org_code`;

-- ③ 板块短名字典核验（页面录入存的 bu_name 就是这个短名）
--    期望：6 行 = BU002水泥集团 / BU004冀东发展 / BU005新材产业化集团(注意尾部空白)
--               / BU006地产集团 / BU008天津建材集团 / BU010北京建研总院
SELECT `dict_code`,`dict_name`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='Owningplate' AND `delete_sign`=0 AND `dict_code`
  IN ('BU002','BU004','BU005','BU006','BU008','BU010')
ORDER BY `dict_code`;

-- ④ 类目字典干净码检查：四个类目必须能按干净码精确命中
--    期望：4 行（uat 已知只有 3 行——「电线电缆」存的是脏码" 2302"，见 05 修正脚本）
SELECT `dict_code`,`dict_name`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='collection_category' AND `delete_sign`=0 AND `dict_code`
  IN ('1501','1701','2302','2502')
ORDER BY `dict_code`;

-- ⑤ 灌库前基线（对账用「灌库前」数字）
--    期望：prod 无既有数据，实测为准（【推断】接近 0 行；若已有页面录入行，数字照抄回传 cc）
SELECT COUNT(*) AS 现有机电行数, SUM(`tax_amount`) AS 现有机电金额
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000';
