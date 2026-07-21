-- =====================================================================
-- 集采日金额统计台账 · 生产部署 SQL（给运维同事执行）
-- ---------------------------------------------------------------------
-- 对应需求：docs/需求/台账/
-- 对应代码：scm-source-all/test 分支提交 aa4747310/350e3f2cd/49331ea2a/
--          a4a245926/ca52c5b8f/dd910b1c4 等（已合入远程 test）
-- 产出时间：2026-07-16
-- 执行库：见每节开头。生产环境库名按惯例把 _test 后缀去掉：
--          业务库 scm_source ；字典/导出模板库 scm_ubm
-- 可重复执行：建表用 IF NOT EXISTS；模板用固定主键 + ON DUPLICATE KEY UPDATE
--
-- 不包含的内容（运维不要执行）：
--   1) test 库里业务测试时录入的台账脏数据（JCRJE-20260709-xxx 共 11 条）
--      —— 由业务人员在生产环境重新录入正式数据
--   2) 驾驶舱 collectionShow 字典开关切换（categoryAmount/situA 置 1）
--      —— 见同目录 99-cockpit-switch-PENDING.sql，需产品/领导确认后再单独执行
-- =====================================================================


-- ###################################################################
-- # Section 1：建业务表
-- # 库：scm_source
-- ###################################################################

USE `scm_source`;

-- 集采日金额统计台账主表
-- 与 test 库 scm_source_test.sc_collection_daily_amount_ledger 结构一致
CREATE TABLE IF NOT EXISTS `sc_collection_daily_amount_ledger` (
  `ledger_id` varchar(32) NOT NULL COMMENT '主键id',
  `ledger_no` varchar(32) DEFAULT NULL COMMENT '集采日金额统计流水号 JCRJE-yyyyMMdd-NNN',
  `execute_unit_id` varchar(32) DEFAULT NULL COMMENT '集采执行单位id',
  `execute_unit_code` varchar(64) DEFAULT NULL COMMENT '集采执行单位编码',
  `execute_unit_name` varchar(200) DEFAULT NULL COMMENT '集采执行单位名称',
  `category_code` varchar(32) DEFAULT NULL COMMENT '集采类目编码',
  `category_name` varchar(128) DEFAULT NULL COMMENT '集采类目名称',
  `statistic_date` date DEFAULT NULL COMMENT '统计日期',
  `purchase_company_id` varchar(32) DEFAULT NULL COMMENT '采购企业id',
  `purchase_company_code` varchar(64) DEFAULT NULL COMMENT '采购企业编码',
  `purchase_company_name` varchar(200) DEFAULT NULL COMMENT '采购企业名称',
  `tax_amount` decimal(20,2) DEFAULT NULL COMMENT '交易金额(含税/元)',
  `bu_code` varchar(32) DEFAULT NULL COMMENT '所属板块编码',
  `bu_name` varchar(64) DEFAULT NULL COMMENT '所属板块名称',
  `publish_time` datetime DEFAULT NULL COMMENT '最新发布/修改时间',
  `publish_by` varchar(32) DEFAULT NULL COMMENT '最新发布/修改人id',
  `publish_by_name` varchar(64) DEFAULT NULL COMMENT '最新发布/修改人',
  `create_by` varchar(32) DEFAULT NULL COMMENT '创建人ID',
  `create_by_name` varchar(32) DEFAULT NULL COMMENT '创建者',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(32) DEFAULT NULL COMMENT '更新人ID',
  `update_by_name` varchar(32) DEFAULT NULL COMMENT '更新者',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `delete_sign` int(11) DEFAULT '0' COMMENT '删除标记 0正常 1删除',
  PRIMARY KEY (`ledger_id`) USING BTREE,
  UNIQUE KEY `uk_ledger_no` (`ledger_no`) USING BTREE,
  KEY `idx_statistic_date` (`statistic_date`) USING BTREE,
  KEY `idx_execute_unit` (`execute_unit_code`) USING BTREE,
  KEY `idx_purchase_company` (`purchase_company_code`) USING BTREE,
  KEY `idx_category` (`category_code`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='集采日金额统计台账';


-- ###################################################################
-- # Section 2：配 Excel 导出模板（主表 + 9 列明细）
-- # 库：scm_ubm
-- # 说明：
-- #   - 模板编码 collection-daily-ledger-export 已写死在后端注解里，不可改
-- #   - 用固定语义化主键（jcrje_*）便于重跑；test 库里用的是雪花 id，
-- #     生产另起一份不影响功能（后端按 template_code 查询）
-- ###################################################################

USE `scm_ubm`;

-- 主表
INSERT INTO `scm_simple_template`
(`template_id`,`template_code`,`template_desc`,`group_code`,`group_name`,`status`,`check_code`,
 `enable_check_code`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,
 `delete_sign`,`data_version`,`file_name`,`data_scan_limit`)
VALUES
('jcrje_daily_export_template','collection-daily-ledger-export','集采日金额统计台账导出','source','寻源模块','1','',
 'false','system','系统',NOW(),'system','系统',NOW(),0,1,NULL,NULL)
ON DUPLICATE KEY UPDATE
`template_code`=VALUES(`template_code`),`template_desc`=VALUES(`template_desc`),
`group_code`=VALUES(`group_code`),`group_name`=VALUES(`group_name`),`status`='1',
`update_by`='system',`update_by_name`='系统',`update_time`=NOW(),`delete_sign`=0;

-- 明细 9 列（sort_name 即列顺序）
-- 字段对应 CollectionDailyAmountLedgerDTO：ledgerNo / executeUnitName / categoryName /
--   statisticDate / purchaseCompanyName / taxAmount / buName / publishTime / createByName
INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
VALUES
('jcrje_daily_export_field_01','jcrje_daily_export_template','collection-daily-ledger-export','source','1','ledgerNo','集采日金额统计流水号','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_02','jcrje_daily_export_template','collection-daily-ledger-export','source','2','executeUnitName','集采执行单位','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_03','jcrje_daily_export_template','collection-daily-ledger-export','source','3','categoryName','集采类目','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_04','jcrje_daily_export_template','collection-daily-ledger-export','source','4','statisticDate','统计日期','Date','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_05','jcrje_daily_export_template','collection-daily-ledger-export','source','5','purchaseCompanyName','采购企业','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_06','jcrje_daily_export_template','collection-daily-ledger-export','source','6','taxAmount','采购金额（含税）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_07','jcrje_daily_export_template','collection-daily-ledger-export','source','7','buName','所属板块','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_08','jcrje_daily_export_template','collection-daily-ledger-export','source','8','publishTime','发布时间','Date','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcrje_daily_export_field_09','jcrje_daily_export_template','collection-daily-ledger-export','source','9','createByName','创建人','String','1','system','系统',NOW(),'system','系统',NOW(),0,1)
ON DUPLICATE KEY UPDATE
`template_id`=VALUES(`template_id`),`template_code`=VALUES(`template_code`),`group_code`=VALUES(`group_code`),
`sort_name`=VALUES(`sort_name`),`field_name`=VALUES(`field_name`),`field_val`=VALUES(`field_val`),
`field_type`=VALUES(`field_type`),`status`='1',`update_by`='system',`update_by_name`='系统',
`update_time`=NOW(),`delete_sign`=0;


-- ###################################################################
-- # 部署后自检（运维可选执行）
-- # 期望：表 1 张、模板主表 1 条、明细 9 条
-- ###################################################################
-- USE scm_source;
-- SELECT COUNT(*) AS ledger_table_rows FROM sc_collection_daily_amount_ledger;
-- USE scm_ubm;
-- SELECT template_code, status, delete_sign FROM scm_simple_template      WHERE template_code='collection-daily-ledger-export';
-- SELECT COUNT(*) AS column_count                                        FROM scm_simple_template_sub WHERE template_code='collection-daily-ledger-export' AND delete_sign=0;
