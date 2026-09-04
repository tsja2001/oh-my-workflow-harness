-- ============================================================
-- 01b 机电日金额初始化 · PROD 导入后审计（只读，无任何写操作）
-- 日期：2026-09-04 ｜ 生成：cc
-- 背景：02 灌库已执行（自检 81/128,740,939.09），预检未跑——本脚本把
--       被跳过的预检全部补查 + 增加"覆盖检测"。结果整段原样回传 cc。
-- 结论口径：A~D 全部符合 → 灌库干净，可进入同步；任何一节异常 → 停，
--       按风险 1~4 处理（见 20-prod 手册 §3），必要时 03 回滚。
-- ============================================================

USE `scm_source_prod`;

-- A. 我们的 81 行完整性
--    期望：81 ｜ 128740939.09
SELECT COUNT(*) AS init_rows, SUM(`tax_amount`) AS init_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `ledger_id` LIKE 'INITJD%' AND `delete_sign`=0;

-- B. 覆盖检测（核心！预检①跳过的代价就在这查）
--    我们的流水号中段是 8 个月初日期。若存在【不属于 INITJD】却占着这些
--    流水号的行，说明灌库时 ON DUPLICATE 覆盖了既有行——期望：0 行
SELECT `ledger_no`,`ledger_id`,`create_by_name`,`create_time`,`tax_amount`
FROM `sc_collection_daily_amount_ledger`
WHERE ( `ledger_no` LIKE 'JCRJE-20260201-%' OR `ledger_no` LIKE 'JCRJE-20260301-%'
     OR `ledger_no` LIKE 'JCRJE-20260401-%' OR `ledger_no` LIKE 'JCRJE-20260501-%'
     OR `ledger_no` LIKE 'JCRJE-20260601-%' OR `ledger_no` LIKE 'JCRJE-20260701-%'
     OR `ledger_no` LIKE 'JCRJE-20260801-%' OR `ledger_no` LIKE 'JCRJE-20260901-%' )
  AND `ledger_id` NOT LIKE 'INITJD%';

-- C. 灌库前基线（从 02 自动生成的快照取，补上被跳过的预检⑤）
--    照抄回传：这组数字就是对账的"灌库前"基数 + 判断日期是否重叠的依据
SELECT COUNT(*) AS 灌库前基线行数, SUM(`tax_amount`) AS 灌库前基线金额
FROM `sc_collection_daily_amount_ledger_bak_20260904`;

-- D. 快照交集复核（B 的加强版：快照里若本来就有这些段的流水号 = 确认覆盖）
--    期望：0 行
SELECT `ledger_no`,`ledger_id`,`create_by_name`,`tax_amount`
FROM `sc_collection_daily_amount_ledger_bak_20260904`
WHERE `ledger_no` LIKE 'JCRJE-20260201-%' OR `ledger_no` LIKE 'JCRJE-20260301-%'
   OR `ledger_no` LIKE 'JCRJE-20260401-%' OR `ledger_no` LIKE 'JCRJE-20260501-%'
   OR `ledger_no` LIKE 'JCRJE-20260601-%' OR `ledger_no` LIKE 'JCRJE-20260701-%'
   OR `ledger_no` LIKE 'JCRJE-20260801-%' OR `ledger_no` LIKE 'JCRJE-20260901-%';

-- E. 组织名核对（补预检②）：prod 实名 vs 02 里已写入的名称
--    期望：org_name 与下列完全一致；不一致 → 名称列要修，回传 cc 出修正 UPDATE
--    10010000=金隅冀东水泥集团股份有限公司 10000000=冀东发展集团有限责任公司
--    18001000=北京金隅新型建材产业化集团有限公司 18002000=北京金隅地产开发集团有限公司
--    18004000=天津市建筑材料集团（控股）有限公司 18005059=北京建筑材料科学研究总院有限公司
SELECT `org_code`,`org_name`,`belong_bu_code`
FROM `scm_ubm`.`ubm_organization`
WHERE `org_code` IN ('10010000','10000000','18001000','18002000','18004000','18005059')
ORDER BY `org_code`;

-- F. 板块短名核对（补预检③）：prod Owningplate vs 02 已写入的 bu_name
--    期望：BU002水泥集团/BU004冀东发展/BU005新材产业化集团/BU006地产集团/BU008天津建材集团/BU010北京建研总院
--    （若 prod 的写法不同——比如 BU004 是"冀东发展集团"——回传，cc 出修正 UPDATE）
SELECT `dict_code`,`dict_name`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='Owningplate' AND `delete_sign`=0 AND `dict_code`
  IN ('BU002','BU004','BU005','BU006','BU008','BU010')
ORDER BY `dict_code`;

-- G. 类目字典干净码（补预检④）
--    期望：4 行。本次 81 行写死的是标准干净码，脏不脏都不影响本次数据；
--    这节只关系【以后页面录入】的行会不会带脏码（uat 实锤过 " 2302"）
SELECT `dict_code`,`dict_name`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='collection_category' AND `delete_sign`=0 AND `dict_code`
  IN ('1501','1701','2302','2502')
ORDER BY `dict_code`;

-- H. 驾驶舱开关（补预检⑥）
--    期望：categoryAmount=1 且 situA=1
--    =0 时驾驶舱走旧缓存（失真数），本次数据不体现在驾驶舱；门户 procurementPortal 页不受影响
SELECT `dict_code`,`dict_name`,`dict_default`
FROM `scm_ubm`.`ubm_dict`
WHERE `dict_type_code`='collectionShow' AND `delete_sign`=0
ORDER BY `dict_code`;

-- I. 库定位留档（补预检⓪，顺手确认字典库确实叫 scm_ubm）
SELECT TABLE_SCHEMA, TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_NAME IN ('ubm_dict','ubm_organization','sc_collection_daily_amount_ledger')
ORDER BY TABLE_NAME, TABLE_SCHEMA;
