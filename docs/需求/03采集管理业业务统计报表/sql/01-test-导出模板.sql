START TRANSACTION;

INSERT INTO `scm_simple_template`
(`template_id`, `template_code`, `template_desc`, `group_code`, `group_name`, `status`,
 `check_code`, `enable_check_code`, `create_by`, `create_by_name`, `create_time`,
 `update_by`, `update_by_name`, `update_time`, `delete_sign`, `data_version`, `file_name`, `data_scan_limit`)
VALUES
('2087449952601423873', 'centralized-procurement-export', '集采管理业务统计报表导出', 'source', '寻源模块', '1',
 '', 'false', '10930002', '张雨', '2026-08-12 16:03:46',
 '10930002', '张雨', '2026-08-12 16:03:46', 0, 1, NULL, NULL);

INSERT INTO `scm_simple_template_sub`
(`tmp_id`, `template_id`, `template_code`, `group_code`, `sort_name`, `field_name`, `field_val`, `field_type`,
 `status`, `create_by`, `create_by_name`, `create_time`, `update_by`, `update_by_name`, `update_time`, `delete_sign`, `data_version`)
VALUES
('2087449952601423874', '2087449952601423873', 'centralized-procurement-export', 'source', '0',  'INDEX',               '序号',                'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423875', '2087449952601423873', 'centralized-procurement-export', 'source', '1',  'buName',              '板块名称',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423876', '2087449952601423873', 'centralized-procurement-export', 'source', '2',  'purchaseCompanyName', '采购企业',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423877', '2087449952601423873', 'centralized-procurement-export', 'source', '3',  'supplierName',        '供应商',              'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423878', '2087449952601423873', 'centralized-procurement-export', 'source', '4',  'planCode',            '采购方案/订单编号',   'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423879', '2087449952601423873', 'centralized-procurement-export', 'source', '5',  'planName',            '业务名称',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423880', '2087449952601423873', 'centralized-procurement-export', 'source', '6',  'materialCode',        '物料编码',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423881', '2087449952601423873', 'centralized-procurement-export', 'source', '7',  'materialName',        '物料描述',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423882', '2087449952601423873', 'centralized-procurement-export', 'source', '8',  'categoryCode',        '类目编码',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423883', '2087449952601423873', 'centralized-procurement-export', 'source', '9',  'categoryName',        '类目描述',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423884', '2087449952601423873', 'centralized-procurement-export', 'source', '10', 'taxTotal',            '交易金额（含税）',    'BigDecimal', '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423885', '2087449952601423873', 'centralized-procurement-export', 'source', '11', 'bookTimeStr',         '公示/下单时间',       'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423886', '2087449952601423873', 'centralized-procurement-export', 'source', '12', 'isCentralizedDesc',   '是否集采',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423887', '2087449952601423873', 'centralized-procurement-export', 'source', '13', 'purchaseType',        '采购业务类型',        'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1),
('2087449952601423888', '2087449952601423873', 'centralized-procurement-export', 'source', '14', 'dataSourceDesc',      '数据来源',            'String',     '1', '10930002', '张雨', '2026-08-12 16:03:46', '10930002', '张雨', '2026-08-12 16:03:46', 0, 1);

COMMIT;

SELECT `template_id`, `template_code`, `template_desc`, `group_code`, `group_name`, `status`, `delete_sign`
FROM `scm_simple_template`
WHERE `template_code` = 'centralized-procurement-export';

SELECT `sort_name`, `field_name`, `field_val`, `field_type`, `status`, `delete_sign`
FROM `scm_simple_template_sub`
WHERE `template_code` = 'centralized-procurement-export'
ORDER BY CAST(`sort_name` AS UNSIGNED);
