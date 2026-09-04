-- ============================================================
-- 01b 机电日金额初始化 · TEST 灌库（幂等，可重复执行）
-- 日期：2026-09-04 ｜ 生成：oc ｜ 数据源：机电公司导入模板2026.9.4全.xlsx
-- 行数：81 行 ｜ 金额合计：128740939.09 元（含税）
-- 规则：
--   ledger_no = JCRJE-<统计日>-<序号>（与页面「录入日」中段天然错开）
--   ledger_id = INITJD<统计日><序号>（INITJD 前缀，回滚/识别用）
--   类目已映射字典标准名：润滑油→润滑剂/电缆→电线电缆/轴承→轴承及备件
--   板块短名取 Owningplate 字典（与页面录入一致）
--   采购企业名称按 test 库组织名落（10010000 在 test 为旧名「冀东水泥股份有限公司」）
--   重跑只更新金额/发布信息，创建审计字段保持首跑
-- 前置：01-test-预检.sql 四节全部符合期望
-- ============================================================

USE `scm_source_test`;

START TRANSACTION;

INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201001','JCRJE-20260201-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-02-01','10010000','10010000',
   '冀东水泥股份有限公司',808369.91,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201002','JCRJE-20260201-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-02-01','10000000','10000000',
   '冀东发展集团有限责任公司',7670479.73,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301001','JCRJE-20260301-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-03-01','10010000','10010000',
   '冀东水泥股份有限公司',1298896.97,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301002','JCRJE-20260301-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-03-01','10000000','10000000',
   '冀东发展集团有限责任公司',1302774.68,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301003','JCRJE-20260301-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-03-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',13048.82,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401001','JCRJE-20260401-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-04-01','10010000','10010000',
   '冀东水泥股份有限公司',924268.49,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401002','JCRJE-20260401-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-04-01','10000000','10000000',
   '冀东发展集团有限责任公司',9725761.14,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501001','JCRJE-20260501-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-05-01','10010000','10010000',
   '冀东水泥股份有限公司',1167828.67,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501002','JCRJE-20260501-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-05-01','10000000','10000000',
   '冀东发展集团有限责任公司',3693784.65,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501003','JCRJE-20260501-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-05-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',7399295.00,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601001','JCRJE-20260601-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-06-01','10010000','10010000',
   '冀东水泥股份有限公司',3269373.13,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601002','JCRJE-20260601-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-06-01','10000000','10000000',
   '冀东发展集团有限责任公司',9363398.48,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601003','JCRJE-20260601-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-06-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',4202066.60,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701001','JCRJE-20260701-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-07-01','10010000','10010000',
   '冀东水泥股份有限公司',4705660.76,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701002','JCRJE-20260701-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-07-01','10000000','10000000',
   '冀东发展集团有限责任公司',8702855.58,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701003','JCRJE-20260701-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-07-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',763925.00,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801001','JCRJE-20260801-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-08-01','10010000','10010000',
   '冀东水泥股份有限公司',2239752.66,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801002','JCRJE-20260801-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-08-01','10000000','10000000',
   '冀东发展集团有限责任公司',6645111.31,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801003','JCRJE-20260801-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-08-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',555380.00,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901001','JCRJE-20260901-001','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-09-01','10010000','10010000',
   '冀东水泥股份有限公司',2958649.36,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901002','JCRJE-20260901-002','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-09-01','10000000','10000000',
   '冀东发展集团有限责任公司',4566722.63,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901003','JCRJE-20260901-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1501','钢材','2026-09-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',834225.00,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201003','JCRJE-20260201-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-02-01','10010000','10010000',
   '冀东水泥股份有限公司',1101883.85,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201004','JCRJE-20260201-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-02-01','10000000','10000000',
   '冀东发展集团有限责任公司',23627.08,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301004','JCRJE-20260301-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-03-01','10010000','10010000',
   '冀东水泥股份有限公司',1435543.17,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301005','JCRJE-20260301-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-03-01','10000000','10000000',
   '冀东发展集团有限责任公司',38261.26,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401003','JCRJE-20260401-003','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-04-01','10010000','10010000',
   '冀东水泥股份有限公司',2554516.09,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401004','JCRJE-20260401-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-04-01','10000000','10000000',
   '冀东发展集团有限责任公司',48657.40,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401005','JCRJE-20260401-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-04-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',499694.16,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501004','JCRJE-20260501-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-05-01','10010000','10010000',
   '冀东水泥股份有限公司',2199416.41,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501005','JCRJE-20260501-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-05-01','10000000','10000000',
   '冀东发展集团有限责任公司',133737.50,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501006','JCRJE-20260501-006','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-05-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',288.45,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601004','JCRJE-20260601-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-06-01','10010000','10010000',
   '冀东水泥股份有限公司',1290706.45,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601005','JCRJE-20260601-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-06-01','10000000','10000000',
   '冀东发展集团有限责任公司',58450.86,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601006','JCRJE-20260601-006','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-06-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',1239.60,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701004','JCRJE-20260701-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-07-01','10010000','10010000',
   '冀东水泥股份有限公司',1907551.24,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701005','JCRJE-20260701-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-07-01','10000000','10000000',
   '冀东发展集团有限责任公司',71335.18,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701006','JCRJE-20260701-006','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-07-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',11373.00,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801004','JCRJE-20260801-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-08-01','10010000','10010000',
   '冀东水泥股份有限公司',1932905.17,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801005','JCRJE-20260801-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-08-01','10000000','10000000',
   '冀东发展集团有限责任公司',53249.75,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901004','JCRJE-20260901-004','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-09-01','10010000','10010000',
   '冀东水泥股份有限公司',1429744.08,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901005','JCRJE-20260901-005','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-09-01','10000000','10000000',
   '冀东发展集团有限责任公司',63611.25,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901006','JCRJE-20260901-006','12300000','12300000','唐山冀东机电设备有限公司',
   '1701','润滑剂','2026-09-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',4225.50,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201005','JCRJE-20260201-005','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-02-01','10010000','10010000',
   '冀东水泥股份有限公司',1595194.73,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201006','JCRJE-20260201-006','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-02-01','10000000','10000000',
   '冀东发展集团有限责任公司',39172.00,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301006','JCRJE-20260301-006','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-03-01','10010000','10010000',
   '冀东水泥股份有限公司',712474.10,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301007','JCRJE-20260301-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-03-01','10000000','10000000',
   '冀东发展集团有限责任公司',449423.43,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301008','JCRJE-20260301-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-03-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',19569.50,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401006','JCRJE-20260401-006','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-04-01','10010000','10010000',
   '冀东水泥股份有限公司',1479867.51,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401007','JCRJE-20260401-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-04-01','10000000','10000000',
   '冀东发展集团有限责任公司',1141503.25,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501007','JCRJE-20260501-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-05-01','10010000','10010000',
   '冀东水泥股份有限公司',3390992.14,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501008','JCRJE-20260501-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-05-01','10000000','10000000',
   '冀东发展集团有限责任公司',1004587.82,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601007','JCRJE-20260601-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-06-01','10010000','10010000',
   '冀东水泥股份有限公司',1996347.05,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601008','JCRJE-20260601-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-06-01','18004000','18004000',
   '天津市建筑材料集团（控股）有限公司',13932.00,'BU008','天津建材集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601009','JCRJE-20260601-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-06-01','18005059','18005059',
   '北京建筑材料科学研究总院有限公司',334232.94,'BU010','北京建研总院',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701007','JCRJE-20260701-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-07-01','10010000','10010000',
   '冀东水泥股份有限公司',1801927.69,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701008','JCRJE-20260701-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-07-01','10000000','10000000',
   '冀东发展集团有限责任公司',608000.00,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701009','JCRJE-20260701-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-07-01','18004000','18004000',
   '天津市建筑材料集团（控股）有限公司',15749.28,'BU008','天津建材集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701010','JCRJE-20260701-010','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-07-01','18005059','18005059',
   '北京建筑材料科学研究总院有限公司',68427.15,'BU010','北京建研总院',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701011','JCRJE-20260701-011','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-07-01','18002000','18002000',
   '北京金隅地产开发集团有限公司',10713.00,'BU006','地产集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801006','JCRJE-20260801-006','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-08-01','10010000','10010000',
   '冀东水泥股份有限公司',487400.32,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801007','JCRJE-20260801-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-08-01','10000000','10000000',
   '冀东发展集团有限责任公司',1497000.00,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801008','JCRJE-20260801-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-08-01','18005059','18005059',
   '北京建筑材料科学研究总院有限公司',904116.32,'BU010','北京建研总院',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901007','JCRJE-20260901-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2302','电线电缆','2026-09-01','10010000','10010000',
   '冀东水泥股份有限公司',2541597.49,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201007','JCRJE-20260201-007','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-02-01','10010000','10010000',
   '冀东水泥股份有限公司',849849.41,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260201008','JCRJE-20260201-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-02-01','10000000','10000000',
   '冀东发展集团有限责任公司',285830.00,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301009','JCRJE-20260301-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-03-01','10010000','10010000',
   '冀东水泥股份有限公司',5880.80,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260301010','JCRJE-20260301-010','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-03-01','10000000','10000000',
   '冀东发展集团有限责任公司',601953.55,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401008','JCRJE-20260401-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-04-01','10010000','10010000',
   '冀东水泥股份有限公司',1997741.90,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260401009','JCRJE-20260401-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-04-01','10000000','10000000',
   '冀东发展集团有限责任公司',849238.51,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501009','JCRJE-20260501-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-05-01','10010000','10010000',
   '冀东水泥股份有限公司',504842.71,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260501010','JCRJE-20260501-010','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-05-01','10000000','10000000',
   '冀东发展集团有限责任公司',445028.83,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601010','JCRJE-20260601-010','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-06-01','10010000','10010000',
   '冀东水泥股份有限公司',1267475.08,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260601011','JCRJE-20260601-011','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-06-01','10000000','10000000',
   '冀东发展集团有限责任公司',605137.38,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701012','JCRJE-20260701-012','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-07-01','10010000','10010000',
   '冀东水泥股份有限公司',1447382.99,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701013','JCRJE-20260701-013','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-07-01','10000000','10000000',
   '冀东发展集团有限责任公司',395549.69,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260701014','JCRJE-20260701-014','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-07-01','18001000','18001000',
   '北京金隅新型建材产业化集团有限公司',3057.51,'BU005','新材产业化集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801009','JCRJE-20260801-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-08-01','10010000','10010000',
   '冀东水泥股份有限公司',873159.58,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260801010','JCRJE-20260801-010','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-08-01','10000000','10000000',
   '冀东发展集团有限责任公司',386199.72,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901008','JCRJE-20260901-008','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-09-01','10010000','10010000',
   '冀东水泥股份有限公司',396025.11,'BU002','水泥集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();
INSERT INTO `sc_collection_daily_amount_ledger`
  (`ledger_id`,`ledger_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,
   `category_code`,`category_name`,`statistic_date`,`purchase_company_id`,`purchase_company_code`,
   `purchase_company_name`,`tax_amount`,`bu_code`,`bu_name`,
   `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
  ('INITJD20260901009','JCRJE-20260901-009','12300000','12300000','唐山冀东机电设备有限公司',
   '2502','轴承及备件','2026-09-01','10000000','10000000',
   '冀东发展集团有限责任公司',42712.58,'BU004','冀东发展集团',
   NOW(),NULL,'董杰',NULL,'董杰',NOW(),0)
ON DUPLICATE KEY UPDATE
  `tax_amount`=VALUES(`tax_amount`), `category_name`=VALUES(`category_name`),
  `purchase_company_name`=VALUES(`purchase_company_name`), `bu_code`=VALUES(`bu_code`), `bu_name`=VALUES(`bu_name`),
  `publish_time`=NOW(), `publish_by_name`=VALUES(`publish_by_name`), `update_time`=NOW();

COMMIT;

-- 自检（期望：81 | 128740939.09）
SELECT COUNT(*) AS init_rows, SUM(`tax_amount`) AS init_amt
FROM `sc_collection_daily_amount_ledger`
WHERE `delete_sign`=0 AND `execute_unit_code`='12300000' AND `create_by_name`='董杰';
