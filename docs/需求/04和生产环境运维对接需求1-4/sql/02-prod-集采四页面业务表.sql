-- =====================================================================
-- 生产环境：集采四页面业务表部署 SQL
-- 日期：2026-07-31
-- 适用范围：
--   1. 集采日金额统计台账
--   2. 集采日计划统计台账
--   3. 煤炭重点坑口日指标
--   4. 价格趋势维护
--
-- 重要：
--   1. 本文件只创建 5 张业务表。
--   2. 不包含 Excel 导出模板、菜单、角色、定时任务、字典、ES/Nacos。
--   3. 不插入业务数据或演示数据。
--   4. Excel 导出模板必须在生产管理页面创建，由系统生成内部 ID。
--   5. 只能由生产配置/运维负责人在正式变更窗口执行。
-- =====================================================================

SET NAMES utf8mb4;

-- 执行前记录连接信息，并人工确认本次目标确实是生产。
SELECT @@hostname AS mysql_host, @@port AS mysql_port, NOW() AS execute_time;


-- #####################################################################
-- # Section 1：寻源业务表，共 4 张
-- #####################################################################

USE `scm_source`;

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
-- #####################################################################

USE `scm_order`;

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
-- # Section 3：执行后核验
-- #####################################################################

SELECT `TABLE_SCHEMA`, `TABLE_NAME`, `ENGINE`, `TABLE_ROWS`
FROM `information_schema`.`TABLES`
WHERE `TABLE_SCHEMA` IN ('scm_source','scm_order')
  AND `TABLE_NAME` IN (
    'sc_collection_daily_amount_ledger',
    'sc_coal_pit_daily_indicator',
    'sc_coal_pit_daily_indicator_item',
    'sc_price_trend',
    'to_central_purchase_daily_statistics'
  )
ORDER BY `TABLE_SCHEMA`, `TABLE_NAME`;

-- 正确结果：共 5 行，scm_source 4 张、scm_order 1 张。
-- 本脚本不会创建或修改 scm_ubm.scm_simple_template 及其明细表。
