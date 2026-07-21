-- 煤炭重点坑口日指标台账导出模板
-- 执行库：目标环境 UBM 库（test 对应 scm_ubm_test）
-- 生产必须执行；脚本使用固定主键并带 ON DUPLICATE KEY UPDATE，可重复执行。

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
