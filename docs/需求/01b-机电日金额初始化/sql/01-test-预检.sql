-- ============================================================
-- 01b 机电日金额初始化 · TEST 预检（只读，灌库前执行）
-- 日期：2026-09-04 ｜ 生成：oc ｜ 数据源：机电公司导入模板2026.9.4全.xlsx
-- 期望结果见每节末尾「期望」注释。全部符合才可执行 02。
-- ============================================================

USE `scm_source_test`;

-- ① 流水号撞号检查：8 个统计日中段在全表 ledger_no 的占用数
--    期望：8 行全部 = 0（我们的流水号 JCRJE-统计日-001~NNN 才能安全落库）
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

-- ② 六家采购组织在 test 库核验
--    期望：6 行；org_name/belong_bu_code 与下列一致
--    10010000 冀东水泥股份有限公司 BU002（注意：test 是旧名，uat/prod 名为金隅冀东水泥集团股份有限公司）
--    10000000 冀东发展集团有限责任公司 BU004
--    18001000 北京金隅新型建材产业化集团有限公司 BU005
--    18002000 北京金隅地产开发集团有限公司 BU006
--    18004000 天津市建筑材料集团（控股）有限公司 BU008
--    18005059 北京建筑材料科学研究总院有限公司 BU010
SELECT `org_code`,`org_name`,`belong_bu_code`,`belong_bu_name`
FROM `scm_ubm_test`.`ubm_organization`
WHERE `org_code` IN ('10010000','10000000','18001000','18002000','18004000','18005059')
ORDER BY `org_code`;

-- ③ 板块短名字典核验（页面录入存的 bu_name 就是这个短名）
--    期望：6 行 = BU002水泥集团 / BU004冀东发展集团 / BU005新材产业化集团
--               / BU006地产集团 / BU008天津建材集团 / BU010北京建研总院
SELECT `dict_code`,`dict_name`
FROM `scm_ubm_test`.`ubm_dict`
WHERE `dict_type_code`='Owningplate' AND `delete_sign`=0 AND `dict_code`
  IN ('BU002','BU004','BU005','BU006','BU008','BU010')
ORDER BY `dict_code`;

-- ④ 灌库前基线（对账时要用「灌库前」数字做差）
--    期望：约 16 行 / 约 433,923.93 元（历史测试数据，创建人张雨，含 1 行已删不算）
SELECT COUNT(*) AS 现有机电行数, SUM(`tax_amount`) AS 现有机电金额
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000';
