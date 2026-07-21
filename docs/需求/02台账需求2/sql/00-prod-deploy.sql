-- =====================================================================
-- 煤炭重点坑口日指标台账 · 生产部署 SQL（给运维同事执行）
-- ---------------------------------------------------------------------
-- 对应需求：docs/需求/台账需求2/
-- 对应代码：scm-source-all feature/taizhang-yang 提交 1f11538d2（已 merge test：
--          fcfbfd9ff）；驾驶舱实时查台账的 3992bf54e 已由 d4eb7d21b 撤回，
--          故当前大屏坑口表仍读旧缓存 sc_collection_data，本次发版不涉及驾驶舱
-- 产出时间：2026-07-16
-- 执行库：见每节开头。生产环境库名按惯例把 _test 后缀去掉：
--          业务库 scm_source ；字典/导出模板库 scm_ubm
-- 可重复执行：建表用 IF NOT EXISTS；模板用固定主键 + ON DUPLICATE KEY UPDATE
--
-- 不包含的内容（运维不要执行）：
--   1) test 库 5 条演示/测试数据（含 sql/03-test-demo-kengk-data.sql 的 1 主 5 明细，
--      以及联调时通过接口录入的 JCKK-20260710-001、JCKK-20260713-001/002/003）
--      —— 生产由业务人员按实际坑口价格录入
--   2) 驾驶舱实时查台账的代码改动已撤回，本次发版无需任何驾驶舱相关 SQL
-- =====================================================================


-- ###################################################################
-- # Section 1：建业务表（主表 + 明细表）
-- # 库：scm_source
-- ###################################################################

USE `scm_source`;

-- 煤炭重点坑口日指标台账主表
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='煤炭重点坑口日指标台账';

-- 煤炭重点坑口日指标台账明细表（每次发布挂 1~5 个坑口）
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC COMMENT='煤炭重点坑口日指标台账明细';


-- ###################################################################
-- # Section 2：配 Excel 导出模板（主表 + 14 列明细，把 5 组坑口平铺成列）
-- # 库：scm_ubm
-- # 说明：
-- #   - 模板编码 coal-pit-daily-export 已写死在后端注解里，不可改
-- #   - 用固定语义化主键（jckk_*）便于重跑
-- ###################################################################

USE `scm_ubm`;

-- 主表
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

-- 明细 14 列：流水号 + 执行单位 + 5 组坑口（每组名称+价格）+ 发布时间 + 操作人
-- 字段对应 CoalPitDailyIndicatorDTO：indicatorNo / executeUnitName /
--   pit1Name~pit5Name / pit1TaxPrice~pit5TaxPrice / publishTime / publishByName
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


-- ###################################################################
-- # 部署后自检（运维可选执行）
-- # 期望：主表+明细表各 1 张、模板主表 1 条、明细 14 条
-- ###################################################################
-- USE scm_source;
-- SHOW TABLES LIKE 'sc_coal_pit_daily_indicator%';
-- USE scm_ubm;
-- SELECT template_code, status, delete_sign FROM scm_simple_template      WHERE template_code='coal-pit-daily-export';
-- SELECT COUNT(*) AS column_count                         FROM scm_simple_template_sub WHERE template_code='coal-pit-daily-export' AND delete_sign=0;
