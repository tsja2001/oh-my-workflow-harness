-- =====================================================================
-- UAT 集采四页面数据库部署包
-- 日期：2026-07-30
-- 适用范围：
--   1. 集采日金额统计台账
--   2. 集采日计划统计台账
--   3. 煤炭重点坑口日指标
--   4. 价格趋势维护
--
-- 只能在 UAT 执行。脚本中的库名全部带 _uat，不含生产库操作。
-- 不包含测试/演示数据，不包含菜单，不包含定时任务，不包含 ES/Nacos。
-- 建表使用 IF NOT EXISTS，导出模板使用固定主键 + ON DUPLICATE KEY UPDATE，
-- 在当前 UAT 状态下可重复执行。
-- =====================================================================

SET NAMES utf8mb4;

-- 执行前先看结果，确认当前连接确实是 UAT。
SELECT @@hostname AS mysql_host, @@port AS mysql_port, NOW() AS execute_time;


-- #####################################################################
-- # Section 1：寻源业务表，共 4 张
-- #####################################################################

USE `scm_source_uat`;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC
  COMMENT='集采日金额统计台账';

CREATE TABLE IF NOT EXISTS `sc_coal_pit_daily_indicator` (
  `indicator_id` varchar(32) COLLATE utf8mb4_general_ci NOT NULL COMMENT '主键id',
  `indicator_no` varchar(32) COLLATE utf8mb4_general_ci NOT NULL COMMENT '煤炭重点坑口日指标流水号 JCKK-yyyyMMdd-NNN',
  `execute_unit_id` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '集采执行单位id',
  `execute_unit_code` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '集采执行单位编码',
  `execute_unit_name` varchar(200) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '集采执行单位名称',
  `publish_date` date NOT NULL COMMENT '发布日期',
  `publish_time` datetime NOT NULL COMMENT '最新发布/修改时间',
  `publish_by` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '最新发布/修改人id',
  `publish_by_name` varchar(64) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '最新发布/修改人',
  `create_by` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '创建人ID',
  `create_by_name` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '创建者',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '更新人ID',
  `update_by_name` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '更新者',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `delete_sign` int(11) DEFAULT '0' COMMENT '删除标记 0正常 1删除',
  PRIMARY KEY (`indicator_id`) USING BTREE,
  UNIQUE KEY `uk_indicator_no` (`indicator_no`) USING BTREE,
  KEY `idx_execute_unit_code` (`execute_unit_code`) USING BTREE,
  KEY `idx_publish_time` (`publish_time`) USING BTREE,
  KEY `idx_cockpit_latest` (`delete_sign`,`publish_date`,`publish_time`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC
  COMMENT='煤炭重点坑口日指标台账';

CREATE TABLE IF NOT EXISTS `sc_coal_pit_daily_indicator_item` (
  `item_id` varchar(32) COLLATE utf8mb4_general_ci NOT NULL COMMENT '主键id',
  `indicator_id` varchar(32) COLLATE utf8mb4_general_ci NOT NULL COMMENT '台账主表id',
  `pit_name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL COMMENT '坑口/港口名称',
  `tax_price` decimal(20,2) NOT NULL COMMENT '今日含税价格(元/吨)',
  `sort_no` int(11) NOT NULL COMMENT '显示顺序',
  `create_by` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '创建人ID',
  `create_by_name` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '创建者',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '更新人ID',
  `update_by_name` varchar(32) COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '更新者',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `delete_sign` int(11) DEFAULT '0' COMMENT '删除标记 0正常 1删除',
  PRIMARY KEY (`item_id`) USING BTREE,
  KEY `idx_indicator_items` (`indicator_id`,`delete_sign`,`sort_no`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC
  COMMENT='煤炭重点坑口日指标台账明细';

CREATE TABLE IF NOT EXISTS `sc_price_trend` (
  `trend_id` varchar(64) NOT NULL COMMENT '主键ID',
  `serial_number` varchar(50) DEFAULT NULL COMMENT '流水号',
  `execute_unit_code` varchar(50) DEFAULT NULL COMMENT '集采执行单位编码',
  `execute_unit_name` varchar(100) DEFAULT NULL COMMENT '集采执行单位名称',
  `year` varchar(10) DEFAULT NULL COMMENT '年度',
  `month` varchar(10) DEFAULT NULL COMMENT '月份',
  `category_code` varchar(20) DEFAULT NULL COMMENT '类目编码',
  `category_name` varchar(50) DEFAULT NULL COMMENT '类目名称',
  `indicator_name` varchar(100) DEFAULT NULL COMMENT '指标名称',
  `price` decimal(18,2) DEFAULT NULL COMMENT '价格（元）',
  `publish_time` datetime DEFAULT NULL COMMENT '发布时间',
  `create_by` varchar(64) DEFAULT NULL COMMENT '创建人ID',
  `create_by_name` varchar(100) DEFAULT NULL COMMENT '创建人姓名',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT NULL COMMENT '更新人ID',
  `update_by_name` varchar(100) DEFAULT NULL COMMENT '更新人姓名',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `delete_sign` int(11) DEFAULT '0' COMMENT '删除标记',
  `data_version` int(11) DEFAULT NULL COMMENT '数据版本',
  PRIMARY KEY (`trend_id`),
  KEY `idx_serial_number` (`serial_number`),
  KEY `idx_publish_time` (`publish_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='价格趋势表';


-- #####################################################################
-- # Section 2：订单业务表，共 1 张
-- # UAT 当前已存在，本段执行时会自动跳过，不会删表或清数据。
-- #####################################################################

USE `scm_order_uat`;

CREATE TABLE IF NOT EXISTS `to_central_purchase_daily_statistics` (
  `id` varchar(64) NOT NULL COMMENT '主键ID',
  `serial_number` varchar(50) DEFAULT NULL COMMENT '流水号',
  `execute_unit_id` varchar(64) DEFAULT NULL COMMENT '集采执行单位ID',
  `execute_unit_code` varchar(50) DEFAULT NULL COMMENT '集采执行单位编码',
  `execute_unit_name` varchar(200) DEFAULT NULL COMMENT '集采执行单位名称',
  `category_code` varchar(50) DEFAULT NULL COMMENT '集团集采类目编码',
  `category_name` varchar(200) DEFAULT NULL COMMENT '集团集采类目名称',
  `statistics_date` date DEFAULT NULL COMMENT '统计日期',
  `plan_quantity` decimal(18,2) DEFAULT NULL COMMENT '当月计划总数量',
  `response_quantity` decimal(18,2) DEFAULT NULL COMMENT '当月响应数量',
  `executing_quantity` decimal(18,2) DEFAULT NULL COMMENT '当月执行中数量',
  `completed_quantity` decimal(18,2) DEFAULT NULL COMMENT '当月已完成数量',
  `delayed_quantity` decimal(18,2) DEFAULT NULL COMMENT '当月已滞后数量',
  `publish_date` date DEFAULT NULL COMMENT '发布日期',
  `publish_time` datetime DEFAULT NULL COMMENT '发布时间',
  `operator` varchar(50) DEFAULT NULL COMMENT '操作人',
  `create_by` varchar(64) DEFAULT NULL COMMENT '创建人ID',
  `create_by_name` varchar(100) DEFAULT NULL COMMENT '创建人姓名',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT NULL COMMENT '更新人ID',
  `update_by_name` varchar(100) DEFAULT NULL COMMENT '更新人姓名',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `delete_sign` int(11) DEFAULT '0' COMMENT '删除标记',
  `data_version` int(11) DEFAULT NULL COMMENT '数据版本',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_serial_number` (`serial_number`),
  KEY `idx_execute_unit_id` (`execute_unit_id`),
  KEY `idx_category_code` (`category_code`),
  KEY `idx_statistics_date` (`statistics_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='集采日统计主表';


-- #####################################################################
-- # Section 3：四个 Excel 导出模板
-- # 期望列数：日金额 9、日计划 11、坑口 14、价格趋势 9。
-- #####################################################################

USE `scm_ubm_uat`;
START TRANSACTION;

-- 3.1 集采日金额统计台账
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

-- 3.2 集采日计划统计台账
-- test 当前模板只有 4 列且第 2 列标题明显错位；这里按页面表格和
-- CentralPurchaseDailyStatisticsVO 的真实 11 个展示字段修正。
INSERT INTO `scm_simple_template`
(`template_id`,`template_code`,`template_desc`,`group_code`,`group_name`,`status`,`check_code`,
 `enable_check_code`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,
 `delete_sign`,`data_version`,`file_name`,`data_scan_limit`)
VALUES
('jcplan_daily_export_template','centralPurchaseStatistics','集采日统计视图对象','1','1','1','1',
 'true','system','系统',NOW(),'system','系统',NOW(),0,1,NULL,NULL)
ON DUPLICATE KEY UPDATE
`template_code`=VALUES(`template_code`),`template_desc`=VALUES(`template_desc`),
`group_code`=VALUES(`group_code`),`group_name`=VALUES(`group_name`),`status`='1',
`check_code`=VALUES(`check_code`),`enable_check_code`=VALUES(`enable_check_code`),
`update_by`='system',`update_by_name`='系统',`update_time`=NOW(),`delete_sign`=0;

INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
VALUES
('jcplan_daily_export_field_01','jcplan_daily_export_template','centralPurchaseStatistics','1','1','serialNumber','流水号','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_02','jcplan_daily_export_template','centralPurchaseStatistics','1','2','executeUnitName','集采执行单位','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_03','jcplan_daily_export_template','centralPurchaseStatistics','1','3','categoryName','集采类目','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_04','jcplan_daily_export_template','centralPurchaseStatistics','1','4','statisticsDate','统计日期','Date','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_05','jcplan_daily_export_template','centralPurchaseStatistics','1','5','planQuantity','当月计划总数量','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_06','jcplan_daily_export_template','centralPurchaseStatistics','1','6','responseQuantity','当月响应数量','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_07','jcplan_daily_export_template','centralPurchaseStatistics','1','7','executingQuantity','当月执行中数量','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_08','jcplan_daily_export_template','centralPurchaseStatistics','1','8','completedQuantity','当月已完成数量','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_09','jcplan_daily_export_template','centralPurchaseStatistics','1','9','delayedQuantity','当月已滞后数量','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_10','jcplan_daily_export_template','centralPurchaseStatistics','1','10','createTime','发布时间','Date','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jcplan_daily_export_field_11','jcplan_daily_export_template','centralPurchaseStatistics','1','11','createByName','操作人','String','1','system','系统',NOW(),'system','系统',NOW(),0,1)
ON DUPLICATE KEY UPDATE
`template_id`=VALUES(`template_id`),`template_code`=VALUES(`template_code`),`group_code`=VALUES(`group_code`),
`sort_name`=VALUES(`sort_name`),`field_name`=VALUES(`field_name`),`field_val`=VALUES(`field_val`),
`field_type`=VALUES(`field_type`),`status`='1',`update_by`='system',`update_by_name`='系统',
`update_time`=NOW(),`delete_sign`=0;

-- 3.3 煤炭重点坑口日指标
INSERT INTO `scm_simple_template`
(`template_id`,`template_code`,`template_desc`,`group_code`,`group_name`,`status`,`check_code`,
 `enable_check_code`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,
 `delete_sign`,`data_version`,`file_name`,`data_scan_limit`)
VALUES
('jckk_daily_export_template','coal-pit-daily-export','煤炭重点坑口日指标台账导出','source','寻源模块','1','',
 'false','system','系统',NOW(),'system','系统',NOW(),0,1,'煤炭重点坑口日指标台账',NULL)
ON DUPLICATE KEY UPDATE
`template_code`=VALUES(`template_code`),`template_desc`=VALUES(`template_desc`),
`group_code`=VALUES(`group_code`),`group_name`=VALUES(`group_name`),`status`='1',
`update_by`='system',`update_by_name`='系统',`update_time`=NOW(),`delete_sign`=0,
`file_name`=VALUES(`file_name`);

INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
VALUES
('jckk_daily_export_field_01','jckk_daily_export_template','coal-pit-daily-export','source','1','indicatorNo','煤炭重点坑口日指标流水号','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_02','jckk_daily_export_template','coal-pit-daily-export','source','2','executeUnitName','集采执行单位','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_03','jckk_daily_export_template','coal-pit-daily-export','source','3','pit1Name','坑口1名称','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_04','jckk_daily_export_template','coal-pit-daily-export','source','4','pit1TaxPrice','坑口1日价格（元/吨）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_05','jckk_daily_export_template','coal-pit-daily-export','source','5','pit2Name','坑口2名称','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_06','jckk_daily_export_template','coal-pit-daily-export','source','6','pit2TaxPrice','坑口2日价格（元/吨）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_07','jckk_daily_export_template','coal-pit-daily-export','source','7','pit3Name','坑口3名称','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_08','jckk_daily_export_template','coal-pit-daily-export','source','8','pit3TaxPrice','坑口3日价格（元/吨）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_09','jckk_daily_export_template','coal-pit-daily-export','source','9','pit4Name','坑口4名称','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_10','jckk_daily_export_template','coal-pit-daily-export','source','10','pit4TaxPrice','坑口4日价格（元/吨）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_11','jckk_daily_export_template','coal-pit-daily-export','source','11','pit5Name','坑口5名称','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_12','jckk_daily_export_template','coal-pit-daily-export','source','12','pit5TaxPrice','坑口5日价格（元/吨）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_13','jckk_daily_export_template','coal-pit-daily-export','source','13','publishTime','发布时间','Date','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('jckk_daily_export_field_14','jckk_daily_export_template','coal-pit-daily-export','source','14','publishByName','操作人','String','1','system','系统',NOW(),'system','系统',NOW(),0,1)
ON DUPLICATE KEY UPDATE
`template_id`=VALUES(`template_id`),`template_code`=VALUES(`template_code`),`group_code`=VALUES(`group_code`),
`sort_name`=VALUES(`sort_name`),`field_name`=VALUES(`field_name`),`field_val`=VALUES(`field_val`),
`field_type`=VALUES(`field_type`),`status`='1',`update_by`='system',`update_by_name`='系统',
`update_time`=NOW(),`delete_sign`=0;

-- 3.4 价格趋势：按页面当前 9 个展示字段生成
INSERT INTO `scm_simple_template`
(`template_id`,`template_code`,`template_desc`,`group_code`,`group_name`,`status`,`check_code`,
 `enable_check_code`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,
 `delete_sign`,`data_version`,`file_name`,`data_scan_limit`)
VALUES
('price_trend_export_template','priceTrend','价格趋势维护导出','source','寻源模块','1','',
 'false','system','系统',NOW(),'system','系统',NOW(),0,1,'价格趋势维护',NULL)
ON DUPLICATE KEY UPDATE
`template_code`=VALUES(`template_code`),`template_desc`=VALUES(`template_desc`),
`group_code`=VALUES(`group_code`),`group_name`=VALUES(`group_name`),`status`='1',
`update_by`='system',`update_by_name`='系统',`update_time`=NOW(),`delete_sign`=0,
`file_name`=VALUES(`file_name`);

INSERT INTO `scm_simple_template_sub`
(`tmp_id`,`template_id`,`template_code`,`group_code`,`sort_name`,`field_name`,`field_val`,`field_type`,
 `status`,`create_by`,`create_by_name`,`create_time`,`update_by`,`update_by_name`,`update_time`,`delete_sign`,`data_version`)
VALUES
('price_trend_export_field_01','price_trend_export_template','priceTrend','source','1','serialNumber','近12个月价格趋势流水号','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_02','price_trend_export_template','priceTrend','source','2','executeUnitName','集采执行单位','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_03','price_trend_export_template','priceTrend','source','3','year','年度','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_04','price_trend_export_template','priceTrend','source','4','month','月份','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_05','price_trend_export_template','priceTrend','source','5','categoryName','类目','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_06','price_trend_export_template','priceTrend','source','6','indicatorName','指标','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_07','price_trend_export_template','priceTrend','source','7','price','价格（元）','BigDecimal','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_08','price_trend_export_template','priceTrend','source','8','publishTimeStr','发布时间','String','1','system','系统',NOW(),'system','系统',NOW(),0,1),
('price_trend_export_field_09','price_trend_export_template','priceTrend','source','9','createByName','创建人','String','1','system','系统',NOW(),'system','系统',NOW(),0,1)
ON DUPLICATE KEY UPDATE
`template_id`=VALUES(`template_id`),`template_code`=VALUES(`template_code`),`group_code`=VALUES(`group_code`),
`sort_name`=VALUES(`sort_name`),`field_name`=VALUES(`field_name`),`field_val`=VALUES(`field_val`),
`field_type`=VALUES(`field_type`),`status`='1',`update_by`='system',`update_by_name`='系统',
`update_time`=NOW(),`delete_sign`=0;

COMMIT;


-- #####################################################################
-- # Section 4：执行后核验
-- # 期望：
-- #   source 4 张表全部显示，order 1 张表显示；
-- #   四个模板的 column_count 依次为 9 / 11 / 14 / 9。
-- #####################################################################

SELECT `TABLE_SCHEMA`, `TABLE_NAME`
FROM `information_schema`.`TABLES`
WHERE `TABLE_SCHEMA` IN ('scm_source_uat','scm_order_uat')
  AND `TABLE_NAME` IN (
    'sc_collection_daily_amount_ledger',
    'sc_coal_pit_daily_indicator',
    'sc_coal_pit_daily_indicator_item',
    'sc_price_trend',
    'to_central_purchase_daily_statistics'
  )
ORDER BY `TABLE_SCHEMA`, `TABLE_NAME`;

USE `scm_ubm_uat`;

SELECT
  t.`template_code`,
  t.`status`,
  t.`delete_sign`,
  COUNT(s.`tmp_id`) AS `column_count`
FROM `scm_simple_template` t
LEFT JOIN `scm_simple_template_sub` s
  ON s.`template_id` = t.`template_id`
 AND s.`delete_sign` = 0
WHERE t.`template_code` IN (
  'collection-daily-ledger-export',
  'centralPurchaseStatistics',
  'coal-pit-daily-export',
  'priceTrend'
)
GROUP BY t.`template_id`, t.`template_code`, t.`status`, t.`delete_sign`
ORDER BY t.`template_code`;
