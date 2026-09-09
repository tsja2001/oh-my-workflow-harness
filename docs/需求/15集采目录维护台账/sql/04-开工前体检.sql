-- =============================================================
-- 15集采目录维护台账 · ④ 开工前体检（只读，随时可跑，不改任何数据）
-- 用法：bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/04-开工前体检.sql scm_source_uat
--       bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/04-开工前体检.sql scm_source_test
--
-- 干三件事：
--   ① 基线快照 —— 改之前的数字，改完拿它对账（13b §1.1 要的那份，过了这个窗口补不回来）
--   ② 存量冲突体检 —— 新判重规则一上，现有数据里哪些行本来就冲突（11d 边界 7）
--   ③ 脏数据清单 —— 期初要处理的
--
-- 依据（2026-09-08 实测）：类目编码是 2/4/6/8 位的严格前缀式四级树
--   （mdm_material_class：27 个一级 / 230 二级 / 626 三级 / 562 四级；
--    除 27 个顶级节点 parent='0' 外，1418/1418 条父码都是子码的前缀）
--   ⇒ 祖先/后代判定可以直接用字符串前缀，不必递归查树。
-- =============================================================

SELECT '########## ① 基线快照 ##########' AS section;

SELECT DATABASE() AS 库, NOW() AS 快照时间;

SELECT '--- 台账 ---' AS t;
SELECT COUNT(*) 总行数,
       SUM(product_code IS NULL OR product_code='')       只管类目行,
       COUNT(DISTINCT category_code)                       类目数,
       COUNT(DISTINCT bu_code)                             影响范围取值种类,
       COUNT(DISTINCT supplier_code)                       执行单位种类,
       MIN(create_time) 最早, MAX(create_time) 最新
  FROM sc_plan_product_range;

SELECT '--- 台账：类目编码长度分布（末级类目改造的影响面）---' AS t;
SELECT LENGTH(category_code) 编码长度, COUNT(*) 行数 FROM sc_plan_product_range GROUP BY 1 ORDER BY 1;

SELECT '--- 单据：是否集采的填充率（改之前的分母）---' AS t;
SELECT 'sc_plan' 表, COUNT(*) 总行, SUM(is_collection IS NULL) 空, SUM(is_collection=1) 为1, SUM(is_collection=0) 为0 FROM sc_plan
UNION ALL SELECT 'sc_plan_product', COUNT(*), SUM(is_collection IS NULL), SUM(is_collection=1), SUM(is_collection=0) FROM sc_plan_product
UNION ALL SELECT 'sc_scheme',       COUNT(*), SUM(is_collection IS NULL), SUM(is_collection=1), SUM(is_collection=0) FROM sc_scheme
UNION ALL SELECT 'sc_scheme_to_purchase', COUNT(*), SUM(is_collection IS NULL), SUM(is_collection=1), SUM(is_collection=0) FROM sc_scheme_to_purchase
UNION ALL SELECT 'sc_supplier_green_channel', COUNT(*), SUM(is_jc IS NULL), SUM(is_jc=1), SUM(is_jc=0) FROM sc_supplier_green_channel;

SELECT '--- 待采购池：执行状态分布（分派链路的基线）---' AS t;
SELECT is_collection, execute_state, execute_state_desc, COUNT(*) c
  FROM sc_scheme_to_purchase GROUP BY 1,2,3 ORDER BY 1,2;


SELECT '########## ② 存量冲突体检 ##########' AS section;

-- 冲突 A：同一 (类目, 物料) 有多行 —— selectOne 会抛 TooManyResultsException，三个单据页全提交不了
SELECT '--- A. 同一(类目,物料)多行 → selectOne 会炸 ---' AS t;
SELECT category_code, IFNULL(product_code,'(只管类目)') 物料, COUNT(*) 行数,
       GROUP_CONCAT(range_id ORDER BY create_time SEPARATOR ',') range_ids
  FROM sc_plan_product_range
 GROUP BY category_code, IFNULL(product_code,'')
HAVING COUNT(*) > 1
 ORDER BY 行数 DESC LIMIT 50;

SELECT '--- A. 汇总 ---' AS t;
SELECT COUNT(*) 冲突组数, IFNULL(SUM(c),0) 涉及行数 FROM (
  SELECT COUNT(*) c FROM sc_plan_product_range
   GROUP BY category_code, IFNULL(product_code,'') HAVING COUNT(*)>1) x;

-- 冲突 B：类目祖先/后代关系（只管类目的行之间）——「集团配了 1701，又有人配 170101」
--          用前缀判定；只比"只管类目"的行（有物料码的行归物料管，不参与类目包含）
SELECT '--- B. 类目包含关系（一条的类目码是另一条的前缀）---' AS t;
SELECT a.range_id 祖先行, a.category_code 祖先类目, a.bu_code 祖先影响范围,
       b.range_id 后代行, b.category_code 后代类目, b.bu_code 后代影响范围
  FROM sc_plan_product_range a
  JOIN sc_plan_product_range b
    ON b.category_code <> a.category_code
   AND b.category_code LIKE CONCAT(a.category_code,'%')
   AND LENGTH(b.category_code) > LENGTH(a.category_code)
 WHERE (a.product_code IS NULL OR a.product_code='')
   AND (b.product_code IS NULL OR b.product_code='')
 LIMIT 50;

-- 冲突 C：物料落在别人的类目管辖之下（物料行 vs 只管类目的行）
SELECT '--- C. 物料行落在某条只管类目的行下面（匹配时谁赢，要靠优先级规则）---' AS t;
SELECT c.range_id 类目行, c.category_code 类目, p.range_id 物料行, p.product_code 物料, p.category_code 物料的类目
  FROM sc_plan_product_range c
  JOIN sc_plan_product_range p
    ON p.category_code LIKE CONCAT(c.category_code,'%')
   AND p.product_code IS NOT NULL AND p.product_code <> ''
 WHERE (c.product_code IS NULL OR c.product_code='')
 LIMIT 50;


SELECT '########## ③ 脏数据清单（期初要处理）##########' AS section;

SELECT '--- D. supplier_code（集采执行单位）取值分布 ---' AS t;
SELECT supplier_code, supplier_name, COUNT(*) 行数, LENGTH(supplier_code) 码长
  FROM sc_plan_product_range GROUP BY 1,2 ORDER BY 行数 DESC;

SELECT '--- E. 明显异常的 supplier_code（含斜杠=多个码拼串 / 过短 / name 存成字符串null）---' AS t;
SELECT range_id, category_code, product_code, supplier_code, supplier_name
  FROM sc_plan_product_range
 WHERE supplier_code LIKE '%/%' OR LENGTH(IFNULL(supplier_code,''))<4
    OR supplier_name='null' OR supplier_name IS NULL
 LIMIT 50;

SELECT '--- F. bu_code（影响范围）取值分布 ---' AS t;
SELECT bu_code, COUNT(*) 行数 FROM sc_plan_product_range GROUP BY 1 ORDER BY 行数 DESC LIMIT 20;

SELECT '--- G. bu_code 里出现了主数据没有的板块码（BU0013 这类）---' AS t;
SELECT '⚠️ 下面这条要连 scm_ubm_* 库比对，本脚本只列出原始串，人工核对：' AS note;
SELECT DISTINCT bu_code FROM sc_plan_product_range WHERE bu_code LIKE '%BU0013%' OR bu_code NOT LIKE '%BU012%';

SELECT '########## 体检结束 ##########' AS section;
