-- 煤炭重点坑口日指标台账 DDL
-- 执行库：目标环境 scm_source 库（test 对应 scm_source_test）
-- 生产必须执行；可重复执行。

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
