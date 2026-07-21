-- 【仅限 test，禁止在生产执行】煤炭重点坑口日指标演示数据
-- 执行库：scm_source_test
-- 说明：价格和坑口名称来自原 sc_collection_data 的 5 条 kengk 数据；原数据缺失的单位、日期、操作人使用明确的测试值。

INSERT INTO `sc_coal_pit_daily_indicator`
(`indicator_id`,`indicator_no`,`execute_unit_id`,`execute_unit_code`,`execute_unit_name`,`publish_date`,
 `publish_time`,`publish_by`,`publish_by_name`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
('demo_jckk_20251208_001','JCKK-20251208-001','demo-org-001','DEMO001','水泥北分（测试）','2025-12-08',
 '2025-12-08 12:00:00','demo-user','测试数据','demo-user','测试数据','2025-12-08 12:00:00',0)
ON DUPLICATE KEY UPDATE
`execute_unit_name`=VALUES(`execute_unit_name`),`publish_date`=VALUES(`publish_date`),
`publish_time`=VALUES(`publish_time`),`publish_by_name`=VALUES(`publish_by_name`),`delete_sign`=0;

INSERT INTO `sc_coal_pit_daily_indicator_item`
(`item_id`,`indicator_id`,`pit_name`,`tax_price`,`sort_no`,`create_by`,`create_by_name`,`create_time`,`delete_sign`)
VALUES
('demo_jckk_item_001','demo_jckk_20251208_001','转龙湾蒙化5500大卡(内蒙)',575.00,1,'demo-user','测试数据','2025-12-08 12:00:00',0),
('demo_jckk_item_002','demo_jckk_20251208_001','中煤长协5500大卡到站价(山西)',677.00,2,'demo-user','测试数据','2025-12-08 12:00:00',0),
('demo_jckk_item_003','demo_jckk_20251208_001','石拉乌素6200大卡(内蒙)',650.00,3,'demo-user','测试数据','2025-12-08 12:00:00',0),
('demo_jckk_item_004','demo_jckk_20251208_001','金鸡滩陕块6400大卡(陕西)',660.00,4,'demo-user','测试数据','2025-12-08 12:00:00',0),
('demo_jckk_item_005','demo_jckk_20251208_001','环渤海5500大卡',730.00,5,'demo-user','测试数据','2025-12-08 12:00:00',0)
ON DUPLICATE KEY UPDATE
`pit_name`=VALUES(`pit_name`),`tax_price`=VALUES(`tax_price`),`sort_no`=VALUES(`sort_no`),`delete_sign`=0;
