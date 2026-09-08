# 13b 测试方案

> **日期**：2026-09-08 ｜ **工具**：cc
> **当前状态**：配套 `13-需求定稿-开发基线-cc.md` 的测试规划。**§1 那三件事必须在写第一行代码之前做完**，
> 尤其 §1.1 的基线快照——**过了这个时间窗口就补不回来了。**
> **下一步**：§1 三件事今天做掉；用例矩阵在每个任务做完后逐条打勾。
>
> 测试哲学见 `10u` §1~§3（五类故障、五条防线）。**本文不重复讲道理，只给能直接执行的东西。**

---

## 0. 这次测试为什么不能只靠"多点几下"

`10u` 把这次的故障分成五类，其中**两类是点页面测不出来的**：

| 类别 | 例子 | 为什么点页面测不出来 | 本文对策 |
|---|---|---|---|
| **A 静默故障** | 漏加状态过滤、云采采集丢单、BU 编码对不上 | **不报错**，页面一切正常 | §6 审计 SQL ＋ §1.1 基线 diff |
| **B 潜伏故障** | 二级集团层级没人接单、详情页缺字段 | **触发它的数据现在还不存在** | §2 提前造出"未来的数据" |

**所以本方案的重点不是用例数量，是这两件事：**

> **① 动手前把"现在是什么样"录下来；② 提前把"上线后才会有的数据"造出来。**

---

## 1. 🔴 开工前必做的三件事（今天，9/8）

### 1.1 录基线快照（**唯一有时间窗口的事**）

**做什么**：挑一批真实物料，逐个调判集采接口，把返回原样存成文件。改完再跑一遍，**凡是变了的都要能解释**。

**物料怎么挑**（每类至少 5 个，共 30~50 个）：

```sql
-- 在 uat 上挑，存成 /tmp/jicai-baseline-products.txt
USE scm_source_uat;

-- ① 在台账里、轴承类（最大的一类，4975 行）
SELECT product_code, category_code FROM sc_plan_product_range WHERE category_code='2502' LIMIT 8;
-- ② 在台账里、润滑剂类
SELECT product_code, category_code FROM sc_plan_product_range WHERE category_code='1701' LIMIT 5;
-- ③ 在台账里、煤炭类（SAP 采集写死查这一类）
SELECT product_code, category_code FROM sc_plan_product_range WHERE category_code='1001' LIMIT 5;
-- ④ 只配类目、没配物料的行（全库只有 3 条，全要）
SELECT product_code, category_code FROM sc_plan_product_range WHERE product_code IS NULL OR product_code='';
-- ⑤ 台账里那条脏数据（category_name='1'）
SELECT product_code, category_code FROM sc_plan_product_range WHERE category_code='2001';
-- ⑥ 不在台账里的物料（对照组）—— 从 sc_plan_product 随便取，排除台账里有的
SELECT DISTINCT pp.product_code, pp.category_code FROM sc_plan_product pp
 WHERE pp.product_code NOT IN (SELECT product_code FROM sc_plan_product_range WHERE product_code IS NOT NULL)
 LIMIT 10;
```

**怎么跑**：

```bash
# 每个物料调一次，把 请求+返回 追加到基线文件
bash scripts/api.sh --env uat POST /e/business/source/plan/queryInProductRangeNum \
  '{"productCodes":[{"productCode":"XXX","categoryCode":"YYY"}]}'
```

**存到**：`docs/需求/15集采目录维护台账/sql/00-判集采基线-uat-20260908.txt`

> ⚠️ **必须在改任何代码之前跑完。** 改完再录，录下来的就不是"改之前的样子"了。
> ⚠️ **在 uat 录，不要在 test 录**——test 台账只有 5 行，录出来全是"未命中"，没有对照价值。

### 1.2 数据体检并存档

```sql
-- 存成 docs/需求/15集采目录维护台账/sql/00-台账体检-uat-20260908.txt
USE scm_source_uat;
SELECT COUNT(*) 总行数,
       SUM(product_code IS NULL OR product_code='') 只配类目,
       COUNT(DISTINCT category_code) 类目数,
       COUNT(DISTINCT bu_code) 影响范围取值数,
       COUNT(DISTINCT supplier_code) 执行单位数 FROM sc_plan_product_range;
SELECT LENGTH(category_code) 码长, COUNT(*) FROM sc_plan_product_range GROUP BY 1 ORDER BY 1;
SELECT category_code, category_name, COUNT(*) FROM sc_plan_product_range GROUP BY 1,2 ORDER BY 3 DESC;
SELECT bu_code, COUNT(*) FROM sc_plan_product_range GROUP BY 1;
SELECT supplier_code, supplier_name, COUNT(*) FROM sc_plan_product_range GROUP BY 1,2 ORDER BY 3 DESC;
```

**2026-09-08 的基线值（已实测，改完要对得上）**：

| 指标 | uat 值 |
|---|---|
| 总行数 | 7343 |
| 只配类目的行 | 3 |
| 类目数 | 7（2502/2302/1701/1001/2113/2102/2001） |
| 类目码长度 | **全部 4 位** |
| `bu_code` 取值 | 2 种：那个 12 个 BU 的串（7342 行）、`'1'`（1 行） |
| `bu_name` | **全部 NULL** |
| 执行单位 | CN13000363(7326) / CN11005095(14) / 4 家拼接(2) / `'1'`(1) |

### 1.3 变量名表发华姐

`13` §3.2 那张表。**10 分钟的事，但它解锁她整整两周的工作。**

---

## 2. ⚠️ 测试数据必须自己造（test 只有 5 行）

### 2.1 两个环境的现状，决定了什么在哪测

| | test | uat |
|---|---|---|
| 台账行数 | **5** | 7343 |
| 唯一索引 `range_product_idx` | **没有** | **有** |
| 导出模板 | **没配** | 有（且有错字） |
| 单据历史数据 | 少 | 计划 27151 / 方案 17075 / 非平台 163，**但盖过集采章的只有 130/244/26（0.5%）** |

**三条结论**：

1. 🔴 **「同一物料存多行」必须在 uat 验**——test 没索引，怎么测都通过（`10w` §6.3）
2. 🔴 **导出功能必须先在 test 建模板**，否则点导出必然失败，会被误判成代码 bug
3. 🔴 **不要指望用历史数据验证**——99.5% 的单子集采字段是空的，**得自己造单子跑**

### 2.2 必须造出来的 8 组数据（`10u` 防线三的具体化）

**全部在 uat 上造**（除非标注）。每组都要**造完 → 走完链路 → 清理**。

| # | 造什么 | 走到哪一步算过 | 防的是 |
|---|---|---|---|
| **S1** | 一条**二级集团集采**台账，**不填集采执行单位** | 提计划 → 审批过 → **看池子里 `collection_supplier_code` 那一格** → 试着做方案 | 🔴 D4 死局 |
| **S2** | 同一物料**配给两个不同 BU** 两行 | ① 第二行**能存进去**（验 D5 删索引 + D1 判重）<br>② 提单子**能正常提交**（验 B2 不抛异常）<br>③ 取到的执行单位是**优先级高的那条**（验 D2） | 🔴 影响点① + 3.3 |
| **S3** | 一条**末级类目**（6 位或 8 位）台账 | ① 导入**能通过校验**（验 D8 去掉二级限制）<br>② **手动触发云采采集**，看订单有没有落库 | 🔴 影响点③ |
| **S4** | 一条规矩**标成失效** | ① 提单子确认不再算集采<br>② **再触发一次采集**，确认失效的没被采进去 | 🔴 影响点② |
| **S5** | S4 失效后**重新录一条一模一样的** | 能录进去（验"失效行不占判重位置"） | 🔴 D1 |
| **S6** | 一张单子里**既有集采又有非集采** | 弹框能正常关掉，**不卡死**，提交流程能继续或明确终止 | 🔴 D13 死锁 |
| **S7** | 🆕 一条影响范围**只填 BU013** 的规矩 | 用 BU013 下的企业提单子，**确认判为集采** | 🔴 D25 编码错 |
| **S8** | 🆕 一条**强管控 + 集团集采**的规矩 | 提单子 → 「是否集采」框**是灰的、改不动**<br>再造一条**弱管控**的 → 框**能改成否** | 分支①②③ |

> 🔴 **S3 和 S4 的"手动触发采集"最容易被跳过**，因为它不在页面上——
> 那是个定时任务，**代码里搜不到调用者**（`grep gatherData` 全仓只命中定义处），入口配在**调度平台的网页**上。
> **页面上怎么点都测不出它。这两条必须单独打勾。**

### 2.3 造数据的 SQL 模板（S2 为例）

```sql
-- ⚠️ 在 uat 上执行前先备份：
-- CREATE TABLE sc_plan_product_range_bak_20260908 AS SELECT * FROM sc_plan_product_range;

USE scm_source_uat;
-- 挑一个已在台账、类目 2502 的物料，再给它配一条二级集团的规矩
INSERT INTO sc_plan_product_range
 (range_id, product_code, product_name, category_code, category_name,
  bu_code, bu_name, supplier_id, supplier_code, supplier_name,
  collection_level, is_strong_control, status, delete_sign, data_version,
  create_by, create_by_name, create_time)
SELECT CONCAT('TEST', LPAD(FLOOR(RAND()*99999),5,'0')),
       product_code, product_name, category_code, category_name,
       'BU002', '冀东水泥', NULL, NULL, NULL,      -- 二级集团层级，不填执行单位（S1 也用这条）
       '2', 0, '1', 0, 1,
       'TESTDATA', '测试数据', NOW()
  FROM sc_plan_product_range
 WHERE category_code='2502' AND product_code IS NOT NULL
 LIMIT 1;

-- 用完清理（造的数据一律带 create_by='TESTDATA'，方便一把删干净）
-- DELETE FROM sc_plan_product_range WHERE create_by='TESTDATA';
```

> 📌 **约定：所有人工造的测试数据，`create_by` 一律填 `TESTDATA`。**
> 提测结束时一条 `DELETE ... WHERE create_by='TESTDATA'` 清干净，不会误删业务数据。

---

## 3. 第一周用例矩阵（对应 `13` §4）

### 3.1 台账页面（功能可见）

| # | 用例 | 步骤 | 期望 | 对应任务 |
|---|---|---|---|---|
| T1-01 | 列表显示新列 | 打开台账页 | 多出「集采目录层级」「是否强管控」「状态」「失效时间」四列 | A8 |
| T1-02 | 默认只看生效 | 打开台账页 | 失效的行**不显示**；筛选状态=失效能翻出来 | A4/A8 |
| T1-03 | 按层级筛选 | 筛选「二级集团集采」 | 只出该层级的行 | A4/A8 |
| T1-04 | 删除改作废 | 点某行【作废】 | 行**还在**（筛失效能看到）、状态=失效、失效时间有值 | A3 |
| T1-05 | 作废后重录 | 作废一行 → 导入一模一样的一行 | **能导入成功**（S5） | A5 |
| T1-06 | 同物料多行 | 导入同物料 + 不同 BU 两行 | **两行都在**（S2，**必须在 uat 验**） | A5/A1 |
| T1-07 | 末级类目导入 | 导入一条 6 位类目 | 校验通过，**类目码原样存 6 位**（不被改写成 4 位） | A6/A7 |
| T1-08 | 新增必填校验 | 导入不填层级 | 报「集采目录层级不能为空」 | A6 |
| T1-09 | 导入模板 | 下载导入模板 | **10 列**，列序 = 类目码/类目名/物料码/物料名/影响范围/执行单位/层级/强管控/(预留)/(预留) | A11 |
| T1-10 | 🔴 旧模板防错 | 用**旧 6 列模板**导入 | 应报错或明确提示，**不能静默错位落库** | A7 |
| T1-11 | 导出 | test 上点【导出】 | **能下载**（现在必然失败） | A10 |
| T1-12 | 导出内容 | 检查导出文件 | 含 4 个新列；`categoryName` 表头是「集采类目名称」不是「集采物料编码」；有「影响范围名称」和「创建时间」 | A10 |
| T1-13 | 影响范围名称回填 | 导入一行 | `bu_name` **有值**（现在 100% 是 NULL） | C1 |

### 3.2 四个保命改造（大部分页面上看不出来）

| # | 用例 | 步骤 | 期望 | 对应 |
|---|---|---|---|---|
| T1-20 | 影响点①·不抛异常 | 台账同物料两行 → 三个页面各提交一张单 | **都能提交**，不报系统错误 | B2 |
| T1-21 | 影响点①·优先级 | 同物料：一条二级集团(BU002)、一条区域 → 用同时属于两者的企业提计划 → 审批通过 | 池子里的 `collection_supplier_code` = **区域那条**的执行单位（D2：范围窄的赢） | B1/B2 |
| T1-22 | 影响点①·判空 | 台账一条不命中的物料，走到审批通过 | **不抛空指针** | B2 |
| T1-23 | 影响点② | 作废一条 → 提单子 | 该物料**不再算集采** | B3 |
| T1-24 | 🔴 影响点②·采集链路 | 作废一条 → **手动触发云采采集** → 查 `sc_source_collection` | 失效的规矩**没被采进去** | B3 |
| T1-25 | 🔴 影响点③·末级不丢单 | 台账配一条 6 位类目 → **手动触发采集** → 查 `sc_source_collection` | 该类目下的订单**有落库**（改之前必然丢） | B4 |
| T1-26 | 影响点③·短码不崩 | 台账配一条 2 位类目 → 触发采集 | **不抛 StringIndexOutOfBounds** | B4 |
| T1-27 | 影响点④·索引 | 在 **uat** 上导入同物料第二行 | **能存进去**（test 上测不出这条） | A1 |

### 3.3 基线回归（每改完一块就跑）

```bash
# 用 §1.1 那批物料重跑一遍，跟基线 diff
diff sql/00-判集采基线-uat-20260908.txt /tmp/jicai-verify-$(date +%m%d).txt
```

**diff 出来的每一条变化都要能回答"这是我想要的变化吗"。**
第一周结束时，**预期变化只有一类**：命中末级类目的物料，从"未命中"变成"命中"。
**其余任何变化都是 bug。**

---

## 4. 第二周用例矩阵（对应 `13` §5）

### 4.1 接口层

| # | 用例 | 期望 |
|---|---|---|
| T2-01 | 新返回结构 | `header` 有 5 个字段，`lines` 每行有 `hitRangeId`/`collectionLevel`/`isStrongControl` |
| T2-02 | 全不命中 | `header.isCollection=0`、`mixed=false`、`lines` 全 `hit=false` |
| T2-03 | 全命中 | `header.isCollection=1`、`mixed=false` |
| T2-04 | 部分命中 | `header.mixed=true`、`mixedProductNames` 是中文物料名（兼容旧文案） |
| T2-05 | 🔴 取最小层级（D3） | 一单两行：一行集团集采、一行二级集团 → `header.collectionLevel` = **集团集采** |
| T2-06 | 🔴 有强取强（6.4） | 一单两行：一行强管控、一行弱 → `header.isStrongControl` = **是** |
| T2-07 | 状态过滤 | 命中的规矩被作废后重调 → `hit=false` |
| T2-08 | 🔴 影响范围过滤（D25） | 用 **BU013** 下的企业调 → 命中（编码修对了）<br>用 **BU012** 下的企业调 → 命中 |
| T2-09 | 影响范围排除 | 用**不在影响范围**内的企业调 → `hit=false` |
| T2-10 | 逐级向上 | 台账只配 `1701`，用 `17010101` 下的物料调 → **命中 1701 那条** |
| T2-11 | 越具体越优先 | 台账同时配 `1701` 和 `170101`，用 `170101` 下的物料调 → 命中 **`170101`** 那条 |

### 4.2 六个页面

| # | 页面 | 用例 | 期望 |
|---|---|---|---|
| T2-20 | 计划**编制** | 提交一张集采单 | 表头显示层级和强管控两个新字段，**只读** |
| T2-21 | 计划编制 | 默认「否」 | 「是否集采」框**灰的，改不动** |
| T2-22 | 计划编制 | 默认「是」+ 集团集采 + 强管控 | 框**灰的，改不动**（分支①） |
| T2-23 | 计划编制 | 默认「是」+ 弱管控 | 框**能改成否**；改了要填原因（D18） |
| T2-24 | 计划编制 | 「否」想改成「是」 | **不允许**（6.5 写死） |
| T2-25 | 🔴 三个编制页 | 混采：一单既有集采又有非集采 | 弹框出现，**点确定/取消都有反应**，不卡死（S6） |
| T2-26 | 方案编制 | 🔴 二级集团层级 + 每行都有计划 | **不拦截**，能做方案（D4，S1） |
| T2-27 | 方案编制 | 集团集采 + 每行都有计划 | **拦截**，提示"请联系集采执行单位" |
| T2-28 | 非平台录入 | 同 T2-20~24 | 注意字段名是 `isJc` |
| T2-29 | 🆕 计划**详情** | 打开已提交的单 | **能看到层级和强管控**（审批人视角） |
| T2-30 | 🆕 方案**详情** | 同上 | 同上 |
| T2-31 | 🆕 非平台**详情** | 同上 | 同上 |

### 4.3 回写与流转

| # | 用例 | 期望 |
|---|---|---|
| T2-40 | 计划回写 | `sc_plan` 和 `sc_plan_product` 的两个新列**有值** |
| T2-41 | 池子回写 | 计划审批通过后 `sc_scheme_to_purchase` 两个新列**有值**（D19） |
| T2-42 | 方案取值 | 从池子挑行做方案 → `sc_scheme` 的值**从池子带过来**，不是重算 |
| T2-43 | 非平台回写 | `sc_supplier_green_channel` 两个新列**有值** |
| T2-44 | 🔴 机电公司清单页 | 集团集采的行 → 机电公司端**能筛到**；二级集团的行（无执行单位）→ **企业端能筛到**（D4） |

### 4.4 工作流变量

| # | 用例 | 怎么验 |
|---|---|---|
| T2-50 | 计划递变量 | 起一张计划流程，用 `bash scripts/wf.sh` 查该单据的流程变量，**三个都在且是中文值** |
| T2-51 | 方案递变量 | 同上 |
| T2-52 | 🔴 非平台递变量 | 同上（**这个是从零加的，最容易漏**） |
| T2-53 | 分支①走通 | 集团+强管控的单 → 按华姐画的图，走到集采执行单位那一级 |
| T2-54 | 分支②走通 | 强管控改成否 → **多审一级**，且那一级**能看到原因**（D18） |
| T2-55 | 分支③走通 | 弱管控改成否 → **走原流程**（D14） |

> ⚠️ T2-53~55 **依赖华姐的流程图**，她没切图之前只能验"变量递到了"，验不了"分支走对了"。
> **排期上要留出联调时间**，别等到 9/18 当天才第一次一起跑。

---

## 5. 🆕 报表口径对账（W2-12，别让领导先发现）

第二周换判定口径 = 换了下游报表的分母（`10w` §2）。**必须上线前后各跑一次，出一份对账报告。**

### 5.1 对哪几个数

```sql
-- 上线前存档一份，上线后再跑一份，逐项 diff
USE scm_source_uat;

-- ① 采购方案的集采占比（集中采购报表的分母）
SELECT DATE_FORMAT(create_time,'%Y-%m') 月份,
       COUNT(*) 方案总数,
       SUM(is_collection=1) 集采数,
       ROUND(SUM(is_collection=1)/COUNT(*)*100,2) 占比
  FROM sc_scheme WHERE delete_sign=0 AND create_time >= '2026-01-01' GROUP BY 1 ORDER BY 1;

-- ② 采购计划的集采占比
SELECT DATE_FORMAT(create_time,'%Y-%m'), COUNT(*), SUM(is_collection=1)
  FROM sc_plan WHERE delete_sign=0 AND create_time >= '2026-01-01' GROUP BY 1 ORDER BY 1;

-- ③ 待采购池里"归机电公司"的行数
SELECT collection_supplier_code, COUNT(*) FROM sc_scheme_to_purchase
 WHERE is_collection=1 GROUP BY 1;

-- ④ 云采采集表的行数（影响点③直接影响它）
SELECT data_source, COUNT(*) FROM sc_source_collection GROUP BY 1;
```

### 5.2 对账报告要回答三个问题

1. **数字变了没有？** 变了多少？
2. **变化能不能解释？** 每一条变化对应哪个口径变更（状态过滤 / 影响范围过滤 / 末级类目 / 允许改否）
3. **ES 索引怎么办？** 历史数据是旧口径写的，**新旧会混在同一个索引里**。
   默认不回刷（`13` N6），但**报表上要标注口径变更日期**，否则跨这个日期的时间段查询没有可比性。

> 🔴 **这份报告要在上线前发给报表使用方**，不是上线后被问的时候才拿出来。

---

## 6. 审计 SQL（专治静默故障，上线后定期跑）

### 6.1 上线当天必跑

```sql
USE scm_source_<env>;

-- ① 期初有没有漏（必须全是 0）
SELECT SUM(collection_level IS NULL) 层级空,
       SUM(is_strong_control IS NULL) 强管控空,
       SUM(status IS NULL) 状态空
  FROM sc_plan_product_range WHERE delete_sign=0;

-- ② 🆕 BU 编码有没有修对（必须是 0）
SELECT COUNT(*) FROM sc_plan_product_range WHERE bu_code LIKE '%BU0013%';

-- ③ 🆕 影响范围里出现主数据没有的 BU 编码（应该是空结果）
--    把 bu_code 拆开逐个跟 ubm_organization_manage.belong_bu_code 比
SELECT range_id, bu_code FROM sc_plan_product_range
 WHERE delete_sign=0
   AND bu_code NOT REGEXP '^(BU0(0[1-9]|1[0-3]))(/(BU0(0[1-9]|1[0-3])))*$'
 LIMIT 20;

-- ④ 按新判重口径有没有冲突（必须是 0，否则导入会失败）
SELECT COUNT(*) FROM (
  SELECT category_code, product_code, collection_level, bu_code
    FROM sc_plan_product_range WHERE delete_sign=0 AND status='1'
   GROUP BY 1,2,3,4 HAVING COUNT(*)>1) x;

-- ⑤ 类目码长度分布（验"降级改写"真的去掉了）
SELECT LENGTH(category_code), COUNT(*) FROM sc_plan_product_range GROUP BY 1 ORDER BY 1;
```

### 6.2 上线后一周内每天跑（验算值真的生效了）

```sql
-- 🔴 新提交的单子，三个新字段的填充率。如果还是 0，说明算值那段根本没生效
SELECT DATE(create_time) 日期, COUNT(*) 新单数,
       SUM(collection_level IS NOT NULL) 有层级,
       SUM(is_strong_control IS NOT NULL) 有强管控
  FROM sc_plan WHERE create_time >= '<上线日>' GROUP BY 1 ORDER BY 1;

-- 云采采集有没有断流（影响点③改坏了会直接掉到 0）
SELECT pull_date, data_source, COUNT(*) FROM sc_source_collection
 WHERE pull_date >= '<上线日>' GROUP BY 1,2 ORDER BY 1;
```

> 🔴 **"新单子三个字段填充率 = 0"是最重要的一个信号**。
> 它意味着代码上线了但算值没跑起来——**页面上完全看不出来**，只有这条 SQL 能发现。

---

## 7. 回归范围：不改但必须验的

**改动虽然集中在 `scm-source-all`，但下面这些东西共享了被改的代码或数据，必须回归。**

| # | 什么 | 为什么会被波及 | 怎么验 |
|---|---|---|---|
| R1 | 采购计划**审批通过**流程 | `PlanTaskServiceImpl:687` / `PlanServiceImpl:2034` 被改（取执行单位） | 走一遍计划审批，池子里有行且执行单位正确 |
| R2 | **云采采集四个任务** | `SourceCollectionServiceImpl` 被改 | 手动触发 `gatherData`，四个来源（Source/Sap/Order/Fpt）各有数据 |
| R3 | ES 集采索引 | 上游 `sc_source_collection` 变了 | 采集后查 ES 索引条数有增长 |
| R4 | 集采门户 | 读 ES 索引 | 页面能打开、有数据 |
| R5 | 集中采购报表 | 读 `sc_scheme.is_collection` | 报表能出数（数字变化见 §5） |
| R6 | 机电公司「集采采购计划」清单页 | 池子字段变了 | 机电公司账号登录能筛到自己的行 |
| R7 | **物料主数据类目查询** | `MaterialClassServiceImpl.queryClassLine` 加了判空 | 采购计划选物料、方案物料弹窗正常 |
| R8 | 🔴 **20+ 个用类目树的页面** | **只要没动 `getProductClassTreeFull` 就不受影响** | 抽验 2 个（采购计划选物料、方案 MaterialModal），树还是只到二级 |

> R8 是个**反向验收**：确认我们**没有**动那个公共接口。
> 如果哪天树突然能展开到三级了，说明有人改了公共接口——**那是事故，不是功能**。

---

## 8. 验收标准（Definition of Done）

### 第一周（9/11）

- [ ] T1-01 ~ T1-13 全过（台账页面）
- [ ] T1-20 ~ T1-27 全过（四个保命改造）
- [ ] **T1-24 / T1-25 的"手动触发采集"确实跑过了**（不是"应该没问题"）
- [ ] **T1-06 / T1-27 在 uat 上验过**（不是只在 test）
- [ ] 基线 diff 跑过，每条变化都能解释
- [ ] R1 / R2 回归通过
- [ ] §6.1 审计 SQL 全部返回预期值

### 第二周（9/18）

- [ ] T2-01 ~ T2-11 全过（接口）
- [ ] T2-20 ~ T2-31 全过（**六个页面，不是三个**）
- [ ] T2-40 ~ T2-44 全过（回写与流转）
- [ ] T2-50 ~ T2-52 全过（变量递到了）
- [ ] T2-53 ~ T2-55 **与华姐联调过**（分支走对了）
- [ ] §5 报表对账报告出了，**并且发给了使用方**
- [ ] R3 ~ R8 回归通过
- [ ] 测试数据清理干净：`DELETE FROM sc_plan_product_range WHERE create_by='TESTDATA'`

---

## 9. 最容易被跳过的 6 件事（单独列出来盯）

**这 6 条每一条都有"跳过了也不会立刻出事"的特点，所以必须单独盯。**

| # | 事 | 跳过的后果 | 什么时候能发现 |
|---|---|---|---|
| 1 | **动手前录基线快照** | 改完之后再也不知道"哪些行为变了" | 永远补不回来 |
| 2 | **手动触发云采采集**（T1-24/25） | 采集静默丢单 | 几个月后对账时 |
| 3 | **在 uat 验多行**（T1-06/27） | test 通过、uat 失败 | 提 UAT 的时候 |
| 4 | **三个详情页**（T2-29/30/31） | 审批人看不到新字段，分支②形同虚设 | 第一次走分支②时 |
| 5 | **非平台录入递变量**（T2-52） | 非平台的单子分支判不出来 | 第一张非平台单走审批时 |
| 6 | **报表口径对账**（§5） | 领导先发现数字变了 | 领导问的时候 |

> **建议**：把这 6 条抄到提测前的检查清单顶部，**逐条打勾，不打勾不提测**。

---

## 附 · 本方案与其他文档的关系

| 文档 | 关系 |
|---|---|
| `10u` | 测试**哲学**在那里（五类故障、五条防线、为什么不搞严格 TDD）。本文是它的**执行版** |
| `10u` §4 `jicai.sh` 脚本提案 | 本文的 §1.1 / §1.2 / §6 就是那个脚本要封装的内容。**先手工跑一遍，值得再封装成脚本** |
| `13` §1 | 每个用例对应的默认决议编号（D1~D25） |
| `10w` §9 | 回归范围（§7）来自它的影响面总表 |
| `10v` | 第一周四个影响点的原理说明；本文 §3.2 是它的验收版 |
