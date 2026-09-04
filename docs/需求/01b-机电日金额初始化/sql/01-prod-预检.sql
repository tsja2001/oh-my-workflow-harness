-- ============================================================
-- 01b 机电日金额初始化 · PROD 预检（只读，灌库前执行）
-- 日期：2026-09-04 ｜ 生成：oc ｜ 数据源：机电公司导入模板2026.9.4全.xlsx
-- 期望结果见每节末尾「期望」注释。全部符合才可执行 02。
-- ============================================================

USE `scm_source_prod`;

-- ⓪ 库定位（只读 information_schema，任何连接实例跑都行）
--    作用：一次看清三张表/字典真实挂在哪个库，彻底消除"库名靠文档猜"的问题
--    期望：ubm_dict 和 ubm_organization 在同一个字典库（文档记载是 scm_ubm，以本查询结果为准）；
--         sc_collection_daily_amount_ledger 在 scm_source_prod（你的台账部署文档同款）
--    ⚠️ 若返回的 schema 名与 01~04 脚本里写的不一致：停下回传 cc，改好再执行
SELECT TABLE_SCHEMA, TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_NAME IN ('ubm_dict','ubm_organization','sc_collection_daily_amount_ledger')
ORDER BY TABLE_NAME, TABLE_SCHEMA;

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
--    期望：4 行；若只有 3 行说明 prod 也有脏码（uat 实锤过 " 2302" 前导空格），回传 cc 出修正脚本
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

-- ⑥ 驾驶舱开关 collectionShow（决定驾驶舱读实时台账还是旧缓存表）
--    期望：categoryAmount=1 且 situA=1（uat 实测为 1）
--    若 =0：驾驶舱四格会显示旧缓存（失真数），需产品/领导签字后执行
--          docs/需求/01台账/sql/99-cockpit-switch-PENDING.sql（执行库 scm_ubm）
--    注意：集采门户 procurementPortal 页走 overview 接口实时算 ES，不受此开关影响
SELECT `dict_code`,`dict_name`,`dict_default`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='collectionShow' AND `delete_sign`=0
ORDER BY `dict_code`;
