-- 备份：test 库 scm_order_test，to_central_purchase_daily_statistics
-- 内容：2026-08-04 云采平台 4 条记录（清理前原样，含重复的 002/003/004）
-- 生成时间 2026-08-10，工具 cc
--
-- 实际执行的清理：物理删除 002/003/004 三条，保留 001。
-- （曾先做软删除 delete_sign=1，因 uk_serial_number 唯一索引不认 delete_sign、
--   软删的号还占坑会让手工新增撞唯一键，用户拍板改为物理删除。）
--
-- 回退：把下面 002/003/004 三条 INSERT 原样执行即可（001 现在还在，别重复插）。

INSERT INTO to_central_purchase_daily_statistics (id,serial_number,execute_unit_id,execute_unit_code,execute_unit_name,category_code,category_name,statistics_date,plan_quantity,response_quantity,executing_quantity,completed_quantity,delayed_quantity,operator,create_by,create_by_name,create_time,update_by,update_by_name,update_time,delete_sign,data_version) VALUES ('2084918085182259202','JCRJH-20260804-001','YC_PLATFORM','YC_PLATFORM','云采平台','YC_PLATFORM','云采平台','2026-08-04','2.00','2.00','0.00','2.00','0.00','系统自动','1','System','2026-08-05 16:23:02','1','System','2026-08-05 16:23:02','0','1');
INSERT INTO to_central_purchase_daily_statistics (id,serial_number,execute_unit_id,execute_unit_code,execute_unit_name,category_code,category_name,statistics_date,plan_quantity,response_quantity,executing_quantity,completed_quantity,delayed_quantity,operator,create_by,create_by_name,create_time,update_by,update_by_name,update_time,delete_sign,data_version) VALUES ('2084924428661207042','JCRJH-20260804-002','YC_PLATFORM','YC_PLATFORM','云采平台','YC_PLATFORM','云采平台','2026-08-04','2.00','2.00','0.00','2.00','0.00','系统自动','1','System','2026-08-05 16:48:14','1','System','2026-08-05 16:48:14','0','1');
INSERT INTO to_central_purchase_daily_statistics (id,serial_number,execute_unit_id,execute_unit_code,execute_unit_name,category_code,category_name,statistics_date,plan_quantity,response_quantity,executing_quantity,completed_quantity,delayed_quantity,operator,create_by,create_by_name,create_time,update_by,update_by_name,update_time,delete_sign,data_version) VALUES ('2084924449704030209','JCRJH-20260804-003','YC_PLATFORM','YC_PLATFORM','云采平台','YC_PLATFORM','云采平台','2026-08-04','2.00','2.00','0.00','2.00','0.00','系统自动','1','System','2026-08-05 16:48:19','1','System','2026-08-05 16:48:19','0','1');
INSERT INTO to_central_purchase_daily_statistics (id,serial_number,execute_unit_id,execute_unit_code,execute_unit_name,category_code,category_name,statistics_date,plan_quantity,response_quantity,executing_quantity,completed_quantity,delayed_quantity,operator,create_by,create_by_name,create_time,update_by,update_by_name,update_time,delete_sign,data_version) VALUES ('2084924485728907265','JCRJH-20260804-004','YC_PLATFORM','YC_PLATFORM','云采平台','YC_PLATFORM','云采平台','2026-08-04','2.00','2.00','0.00','2.00','0.00','系统自动','1','System','2026-08-05 16:48:28','1','System','2026-08-05 16:48:28','0','1');
