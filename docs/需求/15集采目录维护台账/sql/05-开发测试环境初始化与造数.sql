-- =============================================================
-- 15集采目录维护台账 · ⑤ 开发/测试环境初始化 + 造数
-- 适用库：scm_source_test / scm_source_uat   ❌ 绝不能上生产
-- 用法：  bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/05-开发测试环境初始化与造数.sql scm_source_test
--         bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/05-开发测试环境初始化与造数.sql scm_source_uat
-- 前置：  必须先跑 01-台账加字段.sql（本脚本用到的 9 个新列都是它加的）
--
-- 为什么有这个脚本（2026-09-09 产品第三轮口径）：
--   3.2 维护时只做精准判重（层级+类目+物料+影响范围），不做上下级判重
--   3.3 取值时按 物料编码 ＋ 提单企业所属板块/区域 匹配，优先集团 → 二级集团 → 区域
--   ⇒ 生产的期初值等产品的导入模板，test/uat 不等它，先铺成"能开发能测"的样子。
--
-- 幂等：可反复跑。造的行一律 create_by='TESTDATA'，开头先整批删掉再重建。
-- 回滚：bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/05r-回滚到备份.sql <库名>
--       （备份表 sc_plan_product_range_bak_20260909 + ai-docs/db-backup/*.sql 双份）
-- =============================================================

SELECT '########## ⓪ 执行前 ##########' AS step;
SELECT DATABASE() 库, COUNT(*) 台账行数, SUM(create_by='TESTDATA') 造的测试行 FROM sc_plan_product_range;


-- =============================================================
-- ① 存量刷成基线：集团集采 ＋ 弱管控 ＋ 生效
-- =============================================================
-- 为什么强管控刷 0（弱）而不是产品说的"全是"：
--   全刷强管控，三条审批分支里就只剩强管控那一条能测，另外两条永远走不到。
--   强管控的用例改由下面 TD02/TD06/TD11 三条专门覆盖。
--   生产的期初值以产品的导入模板为准，与本脚本无关。
SELECT '########## ① 存量刷基线 ##########' AS step;

UPDATE sc_plan_product_range
   SET collection_level  = '1',
       is_strong_control = 0,
       status            = '1',
       invalid_time      = NULL,
       delete_sign       = 0,
       data_version      = 1,
       update_time       = NOW(),
       update_by_name    = 'INIT-20260909'
 WHERE IFNULL(create_by,'') <> 'TESTDATA';

-- 顺手修一个存量错字：影响范围里的 BU0013 → BU013（13 §1 D25）
-- 组织表实测：uat 板块码是 BU001~BU013，没有 BU0013 这个东西。
-- 集团集采取值时不看影响范围，所以这个错字今天没炸；但二级集团档一上就会匹配不到人。
UPDATE sc_plan_product_range
   SET bu_code = REPLACE(bu_code, 'BU0013', 'BU013')
 WHERE bu_code LIKE '%BU0013%';

SELECT '刷完：层级/强管控/状态 分布' AS t;
SELECT collection_level 层级, is_strong_control 强管控, status 状态, COUNT(*) 行数
  FROM sc_plan_product_range GROUP BY 1,2,3 ORDER BY 1,2,3;


-- =============================================================
-- ② 造测试数据（全部 create_by='TESTDATA'，一条 DELETE 可清空）
-- =============================================================
SELECT '########## ② 造数 ##########' AS step;

DELETE FROM sc_plan_product_range WHERE create_by = 'TESTDATA';

-- 用的类目/物料，两个环境实测都存在（2026-09-09 核对 scm_ubm_test / scm_ubm_uat）：
--   2502 轴承及备件 > 250201 滚动轴承 > 25020101 球轴承
--                   > 250202 滑动轴承 > 25020201 推力瓦 / 25020202 轴瓦
--   物料 250201011030 / 11484 / 11564 / 11726 / 11734 / 11740 / 11744 / 11745 / 11746 / 11750
--   这 10 个物料在 uat 的 7343 行存量里【都没有】，所以不会被存量的集团行盖住，
--   "二级集团/区域到底生不生效"才测得出来。
--   区域码 JHQY（吉黑区域，隶属 BU002）—— test 和 uat 都有，唯一一个两边都在的区域。
SET @ALLBU := 'BU001/BU002/BU003/BU004/BU005/BU006/BU007/BU008/BU009/BU010/BU011/BU012/BU013';
SET @SUP   := 'CN13000363';
SET @SUPN  := '唐山冀东机电设备有限公司';

INSERT INTO sc_plan_product_range
 (range_id, product_code, product_name, category_code, category_name,
  bu_code, bu_name, supplier_code, supplier_name,
  collection_level, is_strong_control, status, invalid_time,
  delete_sign, data_version, create_by, create_by_name, create_time)
VALUES
-- ---------- A. 集团集采基准（S8：强/弱管控两条）----------
('TD01','250201011030','深沟球轴承','25020101','球轴承',
 @ALLBU,'全部板块',@SUP,@SUPN, '1',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD02','250201011484','带座外球面轴承','25020101','球轴承',
 @ALLBU,'全部板块',@SUP,@SUPN, '1',1,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- B. 二级集团档（S1：不填集采执行单位；S2：同物料跨板块两行）----------
('TD03','250201011564','深沟球轴承','25020101','球轴承',
 'BU002','水泥集团',NULL,NULL,          '2',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD04','250201011564','深沟球轴承','25020101','球轴承',
 'BU006','地产集团',@SUP,@SUPN,         '2',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- C. 区域档（JHQY 吉黑区域，隶属 BU002）----------
('TD05','250201011726','深沟球轴承','25020101','球轴承',
 'JHQY','吉黑区域',NULL,NULL,           '3',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD06','250201011734','推力球轴承','25020101','球轴承',
 'BU002','水泥集团',@SUP,@SUPN,         '2',1,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- D. 失效行（S4）＋ 失效后重录一条一模一样的（S5）----------
('TD07','250201011740','深沟球轴承','25020101','球轴承',
 'JHQY','吉黑区域',NULL,NULL,           '3',0,'0','2026-09-01 00:00:00', 0,1,'TESTDATA','测试数据',NOW()),
('TD08','250201011740','深沟球轴承','25020101','球轴承',
 'JHQY','吉黑区域',NULL,NULL,           '3',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- E. 同一物料三个层级同时存在（3.2 允许存、3.3 规定取集团）----------
--     取值必须命中 TD09。TD10、TD11 是"存得进去但永远不生效"的行 —— 这正是产品认下的体验代价。
('TD09','250201011744','调心球轴承','25020101','球轴承',
 @ALLBU,'全部板块',@SUP,@SUPN,          '1',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD10','250201011744','调心球轴承','25020101','球轴承',
 'BU002','水泥集团',@SUP,@SUPN,         '2',1,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD11','250201011744','调心球轴承','25020101','球轴承',
 'JHQY','吉黑区域',NULL,NULL,           '3',1,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- F. 只管类目 + 末级类目（S3：3.1 支持选到末级，6 位 / 8 位）----------
('TD12',NULL,NULL,'250202','滑动轴承',
 'BU002','水泥集团',@SUP,@SUPN,         '2',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD13',NULL,NULL,'25020201','推力瓦',
 'JHQY','吉黑区域',NULL,NULL,           '3',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
-- BU013：存量里写成 BU0013 的那个板块（S7 / D25）。test 库组织表只到 BU012，这条在 test 上匹配不到人，正常。
('TD14',NULL,NULL,'25020202','轴瓦',
 'BU013','板块BU013',@SUP,@SUPN,        '2',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- G. ⚠️ 同层级两条都命中（11d 边界 4 / 本轮遗留问题）----------
--     TD15 影响范围 BU002/BU003，TD16 影响范围 BU002。
--     按 3.2 精准判重：影响范围字符串不同 ⇒ 两条都能存进去。
--     按 3.3 取值：BU002 的企业提这个物料，TD15 和 TD16【同为二级集团层级、都命中】。
--     👉 3.3 没说同层级多条听谁的。这两条就是用来暴露它的：
--        代码里如果还是 selectOne，这里必然抛 TooManyResultsException（10y 雷 1）。
('TD15','250201011745','带座外球面轴承','25020101','球轴承',
 'BU002/BU003','水泥集团/混凝土集团',@SUP,@SUPN, '2',0,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),
('TD16','250201011745','带座外球面轴承','25020101','球轴承',
 'BU002','水泥集团',NULL,NULL,          '2',1,'1',NULL, 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- H. 失效的粗类目行：验"失效行不参与匹配" ----------
--     250201 是 TD01~TD11 那批物料的上级类目。这条若被当成生效，整个子树都会被集团占住。
('TD17',NULL,NULL,'250201','滚动轴承',
 @ALLBU,'全部板块',@SUP,@SUPN,          '1',0,'0','2026-09-01 00:00:00', 0,1,'TESTDATA','测试数据',NOW()),

-- ---------- I. 逻辑删除的行：验 @TableLogic 过滤（列表看不见、匹配也不能命中）----------
('TD18','250201011746','角接触球轴承','25020101','球轴承',
 @ALLBU,'全部板块',@SUP,@SUPN,          '1',0,'1',NULL, 1,1,'TESTDATA','测试数据',NOW()),

-- ---------- J. ⚠️ 状态=生效 但失效时间已过（本轮遗留问题）----------
--     "状态"和"失效时间"两个字段可能打架。到底以哪个为准、有没有定时任务把它刷成失效 —— 产品没说。
('TD19','250201011750','深沟球轴承','25020101','球轴承',
 'BU002','水泥集团',@SUP,@SUPN,         '2',0,'1','2026-09-01 00:00:00', 0,1,'TESTDATA','测试数据',NOW());


-- =============================================================
-- ③ 自检
-- =============================================================
SELECT '########## ③ 自检 ##########' AS step;

SELECT '--- 造出来的 19 行 ---' AS t;
SELECT range_id, IFNULL(product_code,'(只管类目)') 物料, category_code 类目,
       collection_level 层级, bu_code 影响范围, is_strong_control 强管控,
       status 状态, IFNULL(invalid_time,'') 失效时间, delete_sign 逻辑删,
       IFNULL(supplier_code,'(未填执行单位)') 执行单位
  FROM sc_plan_product_range WHERE create_by='TESTDATA' ORDER BY range_id;

SELECT '--- 全表层级分布（存量应全是 1，造的行三档都有）---' AS t;
SELECT collection_level 层级, COUNT(*) 行数, SUM(create_by='TESTDATA') 其中造的
  FROM sc_plan_product_range GROUP BY 1 ORDER BY 1;

SELECT '--- ⚠️ 同一物料命中多条：selectOne 会炸的位置 ---' AS t;
SELECT IFNULL(product_code,category_code) 节点, COUNT(*) 行数,
       GROUP_CONCAT(CONCAT(range_id,':L',collection_level,'/',bu_code) ORDER BY range_id SEPARATOR ' | ') 明细
  FROM sc_plan_product_range
 WHERE status='1' AND delete_sign=0
 GROUP BY IFNULL(product_code,category_code)
HAVING COUNT(*)>1 ORDER BY 2 DESC;

SELECT '--- 影响范围里还有没有 BU0013 错字（应为 0）---' AS t;
SELECT COUNT(*) 还剩 FROM sc_plan_product_range WHERE bu_code LIKE '%BU0013%';
