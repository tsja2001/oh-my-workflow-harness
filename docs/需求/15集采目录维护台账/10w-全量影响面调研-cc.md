# 10w 全量影响面调研：这两周的改动，到底会碰到多少东西

> **日期**：2026-09-08 ｜ **工具**：cc
> **当前状态**：用户要求"开发前把影响范围全面深度调研一遍，尽量万无一失"。本文是**穷举式排查结果**，
> 不是复述前面的文档——**扫出 9 项前面所有文档都没提到的影响点，并订正了 5 处旧说法**。
> **下一步**：本文的结论已经进 `13-需求定稿-开发基线-cc.md`（开发方案）和 `13b-测试方案-cc.md`（测试）。
>
> 前置阅读：业务背景 `10s`、两批拆解 `10t`、四个影响点 `10v`、工程防线 `10u`。
> **本文不取代任何文档**，但**订正了 `10t` / `10l` / `10v` 各若干处**，清单见 §8。

---

## 0. 先给结论

**之前的文档把影响面理解成"台账 + 三个采购页面"。实际比这大一圈：**

```
                    ┌──────────────────────────┐
                    │  sc_plan_product_range   │  ← 第一周改这张表
                    │       集采范围台账        │
                    └────────────┬─────────────┘
                                 │ 7 处代码读它（已知）
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
    ┌──────────────────┐                 ┌────────────────────┐
    │  三个采购单据     │                 │   云采采集定时任务  │
    │ 计划/方案/非平台  │                 │  （页面上看不见）   │
    └────────┬─────────┘                 └─────────┬──────────┘
             │ 写 is_collection                    │ 写 sc_source_collection
             ▼                                     ▼
   ┌───────────────────────┐            ┌──────────────────────┐
   │ 待采购池 + 两个清单页  │            │  ES 索引             │  🆕
   │ （机电端 / 企业端）    │            │ index_web_collection │
   └───────────┬───────────┘            └──────────┬───────────┘
               │                                   │
               ▼                                   ▼
   ┌────────────────────────────────────────────────────────────┐
   │  🆕 下游消费者：3 套报表 + 集采门户 + 驾驶舱 + 6 个前端页面   │
   └────────────────────────────────────────────────────────────┘
```

**一句话**：台账不只是一张配置表，它是**"是否集采"这个字段的源头**，
而"是否集采"往下游流进了**报表、ES 索引、门户和驾驶舱**。
第二周把"是否集采"的判定口径整个换掉，**等于把这些下游的数字全换了一遍口径**。

---

## 1. 排查方法（说明我怎么保证"穷举"）

| 维度 | 怎么扫的 | 结果 |
|---|---|---|
| 台账表名 | `grep -r "sc_plan_product_range"` 全三仓 | 只在实体类 `@TableName` 里出现 1 处，**没有裸 SQL、没有 XML** |
| 台账实体 | `grep -r "PlanProductRange"` 全后端 | 12 个文件，全在 `scm-source-plan` + `scm-source-source` |
| 台账 Mapper | `grep -r "planProductRangeMapper"` | **7 个调用点**（`10v` §1.2 已列全） |
| 集采字段 | `grep -r "isCollection\|is_collection"` 全后端 | **14 个文件，跨 4 个模块**（plan / scheme / source / **chase**） |
| 集采字段 | `grep -r "isCollection\|isJc"` 全前端 | **6 个 vue 文件**（不是 3 个） |
| 中文关键字 | `grep -r "集采\|集中采购"` 全后端 | 溢出到 `scm-order-all` / `scm-report-all` / `scm-ubm-all` |
| 数据库对象 | `information_schema` 查 VIEWS / TRIGGERS / ROUTINES | **0 命中**——没有视图、触发器、存储过程引用这些表 ✅ |
| 页面配置 | 读 `procurementCatalogMgt/index.vue` 的 `getPageJson` | **是前端静态 JSON，不是后端接口** 🔴 订正 |
| 模板配置 | `export-template.sh inspect` + `scm_staticfile` 查库 | 导出模板 **test 缺失**、uat 有错字；导入模板两边都有 |
| 数据现状 | `dbq.sh` 在 uat 上做字段体检 | 见 §6 |

---

## 2. 🆕 第一类新发现：下游有三套报表 + 一个 ES 索引在吃"是否集采"

**前面所有文档都只讲到"单据上盖一个章"，没讲这个章盖完之后流去了哪。**

### 2.1 链路

```
采购方案 sc_scheme.is_collection = 1
      │
      ├──► ① scm-source-chase 集中采购报表
      │      CentralizedProcurementReportServiceImpl.java:390 → queryCollectionMap(schemeIds)
      │      :815  map.put(schemeId, scheme.getIsCollection())
      │      :503  model.setIsCentralized(isCollection)
      │      :504  model.setPurchaseType(resolvePurchaseType(isCollection))
      │      → 报表里「是否集中采购」和「采购类型」两列，直接由它决定
      │
      ├──► ② 云采采集（定标口径）
      │      SourceCollectionMapper.java:49 原生 SQL
      │      "WHERE c.state='127' AND s.delete_sign=0 AND s.is_collection = 1"
      │      → 只有 is_collection=1 的方案才会被采集进 sc_source_collection
      │
      └──► ③ 待采购池的两个清单页
             SchemeToPurchaseController:428  机电公司端 setIsCollection(1)
             SchemeToPurchaseController:485  企业端     setIsCollection(1)

sc_source_collection（采集表）
      │
      └──► ES 索引 index_web_collection_meta
             写：CollectionMetaServiceImpl（scm-source-chase）
                 pushCollectionMeta / pushCollectionMetaBulk / batchPush / synPush
             读：SourceQueryBuilderImpl_CollectionProduct(Detail)（scm-report-all）
                 CentralizedProcurementPortalServiceImpl（集采门户，走 ES 聚合）
```

### 2.2 为什么这件事要紧

第二周 6.2 把"是否集采"的判定口径**整个换掉**（物料码 → 末级类目 → 逐级向上 ＋ 影响范围过滤 ＋ 状态过滤）。

**换口径 = 换了这些报表的分母。**

| 变化 | 报表上会看到什么 |
|---|---|
| 加了"状态=生效"过滤 | 已作废规矩对应的物资，**新单子不再算集采** → 集采占比下降 |
| 加了"影响范围"过滤 | 不在管辖内的企业，**新单子不再算集采** → 集采占比下降 |
| 类目放开到末级 | 原来只按二级匹配，现在能匹配更细 → **某些原来不算的现在算了** → 上升 |
| 允许改成"否" | 弱管控的单子会被采购员改掉 → 下降 |

**净效果无法预测，但一定会变。** 而这些报表是给领导看的。

> 🔴 **必须做的一件事**：上线前后各跑一次报表口径对账，**并且提前跟报表的使用方打招呼**——
> 否则第一个发现异常的是领导，而不是你。
>
> ⚠️ **一个技术细节**：ES 索引不会自动重算。历史数据在 ES 里是按旧口径写的，
> **新旧口径的数据会混在同一个索引里**，报表按时间段一查就是"半旧半新"。
> 要不要回刷历史，是个需要产品拍板的问题（我的默认：**不回刷**，只在报表上标注口径变更日期）。

### 2.3 不受影响的（查清楚了，可以放心）

| 东西 | 为什么不受影响 |
|---|---|
| `sc_collection_daily_amount_ledger` 集采日金额台账 | 独立表，人工维护（需求 `01b`），不从台账取数 |
| ~~驾驶舱~~ **【订正：只有 `SourceCollectionDataServiceImpl` 那一个 provider 不受影响；`CockpitCollectionProviderImpl` 查 ES，受影响。见 §7.5 N-1】** | `SourceCollectionDataServiceImpl:79-81` 是单表查询 |
| `scm-order-all` 的集采统计报表 | 读云采订单，口径是订单侧的，不读 `sc_plan_product_range` |

---

## 3. 🆕 第二类新发现：前端是 6 个页面，不是 3 个

`grep -rl "isCollection\|isJc"` 全前端（排除已废弃的 `scm-vue-all/` 旧目录）：

| # | 页面 | 文件:行 | 现状 | 这次要做什么 |
|---|---|---|---|---|
| ① | 采购计划**编制** | `scm-vue-all-plan/.../purchasePlan/saveOrSubmit.vue:264` | radio，写死 disabled | 拆 disabled ＋ 加 2 字段 |
| ② | 采购方案**编制** | `.../procurementPlanPreparation/basicInfo2.vue:450` | 同上 | 同上 |
| ③ | 非平台**录入** | `.../supplier/increasedListAdd.vue:62` | 同上（字段名 `isJc`） | 同上 |
| ④ | 🆕 采购计划**详情** | `scm-vue-all-plan/.../purchasePlan/detail.vue:39` | `<a-descriptions-item label="是否集采">` | **加 2 个只读字段** |
| ⑤ | 🆕 采购方案**详情**（寻源过程） | `.../procurementSourcingProcessMgt/procurementSchemeInfo.vue:96` | 同上 | **加 2 个只读字段** |
| ⑥ | 🆕 非平台录入**详情** | `.../supplier/detail/index.vue:19` | 同上（`isJc`） | **加 2 个只读字段** |

### 🔴 为什么④⑤⑥ 不能省

**审批人打开的是详情页，不是编辑页。**

需求的分支②是「强管控 + 改成了否 → 多审一级」。那一级领导打开单子，
**如果详情页上没有「集采目录层级」和「是否强管控」，他就看不到自己为什么会收到这张单子。**

> 只改编辑页 = 三个新字段只有填单人看得见，审批人看不见。**那一级审批就是走过场**——
> 这和 `10r` P5（改成否要不要填理由）是同一个问题的两半。

### 3.1 顺带查清的两个"同名文件"陷阱

| 文件 | 结论 |
|---|---|
| `scm-vue-all/scm-vue-planMgt/.../purchasePlan/saveOrSubmit.vue` | **旧版，不用改**（grep 不到 disabled，也不到弹框文案） |
| `.../procurementPlanPreparation/basicInfo.vue` | **不是采购方案编制页**。`createPurchase.vue:35` 实际 `import basicInfo from './basicInfo2.vue'`；`basicInfo.vue` 里的"集采"是「集采事业部副总」审批人下拉，无关 |

---

## 4. 🔴 第三类新发现：台账页面的列，是**前端静态 JSON**，不是后端下发

**这条直接推翻 `10t` §1.2 的一个关键判断。**

`procurementCatalogMgt/index.vue:110-111`：

```js
getPageJson() {
  request("/statics/json/mdm/procurementCatalogMgt.json").then((res) => {
    this.rule = res.data.rule;          // 搜索条件
    const _columns = res.data.columns;  // 表格列
```

这是**一个静态文件**，不是接口。仓库里有**两份，内容完全相同**：

```
02zhaocai-front/scm-vue-all-mdm/public/statics/json/mdm/procurementCatalogMgt.json
02zhaocai-front/scm-vue-all-statics/statics/json/mdm/procurementCatalogMgt.json
```

### 后果

| `10t` 原来的判断 | 实际 |
|---|---|
| "加 4 列只改后端配置，不动 vue 文件" | ❌ **要改前端 JSON，而且要前端发版** |
| 第一周"前端一行不动" | ❌ 前端至少要发一次版（JSON ＋ 可能的操作列改造） |

### 顺带查出这份 JSON 里已有的 4 个毛病

```json
{ "type":"input", "field":"执行单位名称", "title":"影响范围" }   ← field 用中文、title 还写错（和上一条重复）
"optBtns":[{ "optName":"新增", "actionType":"add" }]            ← 配了新增按钮，但 vue 里根本没渲染 optBtns
"rowKey":"memberId"                                             ← 配的是 memberId，vue 里写死 rowKey="rangeId"
columns 里没有"创建人"，只有"创建时间"                            ← 和 10t §1.3 的描述对不上
```

**这四个都是复制粘贴别的页面留下的**，改 JSON 时顺手修掉，成本为零。

---

## 5. 🆕 第四类新发现：主数据这一侧有三个坑

### 5.1 🔴 类目树接口写死"不展示第三级"，而且 20+ 页面共用

`MaterialClassServiceImpl.java:175-178`：

```java
// 2023-04-23 晚上19点05分根据产品需要不展示第三级物料
if(classDto.getClassCode().length()<=4){
    map.get(classDto.getParentClassCode()).add(classMap.get(classDto.getClassCode()));
}
```

**这条推翻 `10l` 的"树/接口/组件全现成"。**

- 现有树接口 `queryProductClassTreeFull` **只返回 2 位和 4 位类目**，选不到末级；
- **前端有 20+ 个页面在用它**（采购计划、需求计划、方案物料弹窗、供应商准入、协议、评审模板…）；
- **绝对不能直接改这个公共接口** —— 改一行，20 多个页面的物料选择行为一起变。

**我的默认决策**：

> **第一周不做树选择器。** 台账目前只有「导入」一个入口，类目码从 Excel 来，**不需要树**。
> 放开末级只要**去掉后端导入校验里的"必须是二级"**（`ProductRangeImportServiceImpl.java:105-108`）就够了。
>
> 如果后面要做 T1（新增/编辑表单），再**新开一个接口**（或给现有接口加 `maxLevel` 参数，默认值保持 4 位不变），
> **不动老接口的默认行为**。

**好消息**：逐级向上找父类目的能力**已经有了**——
`MaterialClassServiceImpl.queryClassLine():265-296` 从给定类目码一路向上走到根，
填出 `bigClassDto`(一级) / `midClassDto`(二级) / `smallClassDto` / `categoryClassDTO`。
**第二周 6.2 的"逐级向上匹配"可以直接复用它，不用自己写。**

> ⚠️ 但 `queryClassLine():271-273` **没判空**：`selectOne` 查不到（编码不存在或已停用）就 NPE。
> 放开末级之后传进去的编码会更五花八门，**这个空指针一定会被触发**。

### 5.2 🔴 影响范围（BU）的编码，台账里存错了

实测 uat：

| 来源 | 值 |
|---|---|
| 主数据 `ubm_organization_manage.belong_bu_code` | `BU001` … `BU013`（**13 个**） |
| 台账 `sc_plan_product_range.bu_code`（7342 行都是这一个串） | `BU001/BU002/.../BU011/BU0013` |

**两个错**：
1. **缺 `BU012`**（主数据里有 2 个组织）
2. **`BU013` 被写成 `BU0013`**（多一个 0，主数据里有 6 个组织）

**今天为什么没事**：影响范围过滤根本还没启用，这个字段现在纯粹是个摆设。

**第二周一启用影响范围过滤**：
> **BU012 和 BU013 下面的 8 个组织，提交的单子会全部判为"不是集采"** ——
> 不报错、不提示，就是悄悄不管了。**典型的 `10u` A 类静默故障。**

**期初脚本必须把这个串修对**，并且**上线后要专门验证 BU012/BU013 的企业**。

### 5.3 🟡 区域数据仍然大面积为空（比 `10l` 说的更严重）

实测 uat `ubm_organization_manage.belong_plate_code` 填充情况：

| BU | 组织数 | 区域为空 | 不同区域数 |
|---|---:|---:|---:|
| BU002 冀东水泥 | 258 | 121 | 28 |
| BU005 新材产业化 | 109 | 93 | 5 |
| BU007 投资物业 | 120 | 101 | 5 |
| BU004 冀东集团 | 60 | **0** | 1 |
| **BU003 混凝土集团** | 86 | **86** | **0** |
| **BU006 地产集团** | 96 | **96** | **0** |
| **BU009 / BU010 / BU011 / BU012** | 27 | **全空** | **0** |
| BU001 / BU008 / BU013 | 38 | 全空 | 1 |

**6 个 BU 完全没有区域数据**（`10l` 当时说"有四个二级集团是 0%"，实际是 6 个）。

**我的默认决策**：**区域这一档做成字典开关，第一版关闭**（照 `10u` 防线四）。
字段和逻辑都写，但不放开录入。理由：**做出来也没法验证，上线也没人能用。**

### 5.4 三级层级 vs 系统里已有的组织层级

系统里**已经有**一套组织层级枚举，值得对齐而不是另起炉灶：

`OrganizationLevelEnum { JT, GS, BS, QY }`，且带一个数值排序：

```java
map.put(JT, 1);   // 集团
map.put(GS, 2);
map.put(BS, 3);
// ⚠️ QY 没有进 map
public static int compare(String l1, String l2) { ... return map.get(l1) - map.get(l2); }
```

**两条结论**：

1. **`10r` P10「最小层级是哪个方向」，系统里已有先例**：现有约定就是**数字越小层级越高，集团=1**。
   → **"最小层级 = 集团集采"** 与既有代码一致。**这条可以按默认拍板，不用等产品。**
2. ⚠️ **`QY` 不在 map 里**，`compare()` 遇到 QY 返回 `-1`，**和"l1 更高"的返回值撞车**。
   新的「区域·企业集采」如果复用这个枚举，**这个坑会被踩到**。要么补进 map，要么新层级不复用它。

实测 uat 的 `auth_level` 分布：`BS 662 / NULL 171 / GS 17 / QY 3 / JT 1`。

---

## 6. 数据现状体检（uat，2026-09-08 实测）

### 6.1 台账本体

| 项 | 值 | 说明 |
|---|---|---|
| 总行数 | **7343** | |
| 配了物料的行 / 只配类目的行 | 7340 / **3** | 几乎全是按物料配的 |
| 不同类目数 | **7** | 2502 轴承(4975) / 2302 电线电缆(1741) / 1701 润滑剂(610) / 1001 煤炭(14) / 2113(1) / 2102(1) / 2001(1，脏数据) |
| **类目码长度分布** | **全部 4 位** | 一条末级类目都没有——**末级功能上线后是零基线，没有历史数据可参照** |
| 影响范围为空 | 0 | 但 7342 行是同一个串（见 §5.2） |
| `bu_name` | **全部 NULL** | 「导入不回填影响范围名称」这个缺陷是 100%，不是偶发 |
| 执行单位 | CN13000363 唐山冀东机电(7326) / CN11005095(14，`supplier_name` 是字符串 `"null"`) / 4 家拼接(2) / 脏数据(1) |
| 按现有唯一索引口径的重复 | 0 | |

### 6.2 表结构（uat）

```
range_id varchar(32) PK
product_code / product_name / category_code / category_name
bu_code varchar(256)        ← 存 "/" 拼接的多个 BU
bu_name varchar(1024)       ← 全 NULL
supplier_id / supplier_code / supplier_name  varchar(2048)
create_by / create_by_name / create_time
```

**没有 `delete_sign`、没有 `update_by`/`update_time`、没有 `data_version`** ——
这在本仓库里是异类（`@TableLogic` 全仓 70 处，`scm-source-all` 内 11 处）。

### 6.3 索引：test 和 uat 不一样（`10v` §1.6 已述，这里补数据）

| 环境 | 行数 | 索引 |
|---|---:|---|
| uat | 7343 | `PRIMARY(range_id)` ＋ **`UNIQUE range_product_idx(product_code, category_code)`** |
| test | **5** | 只有 `PRIMARY(range_id)` |

> ⚠️ **test 只有 5 行数据**。意味着 test 上**任何跟数据量、判重、多行相关的行为都测不出来**。
> 见 `13b-测试方案` §2「测试数据必须自己造」。

---

## 7. 🆕 第五类新发现：三处配置和一处判重逻辑

### 7.1 导入是**按列位置**取值（这条决定新列只能加在最后）

`ProductRangeImportServiceImpl.java:66-70` 和 `:163-167`（check 和 save 各一份）：

```java
categoryCode = lines.get(0).getFieldVal();
productCode  = lines.get(2).getFieldVal();
buCode       = lines.get(4).getFieldVal();
supplierId   = lines.get(5).getFieldVal();
```

**列序固定为**：0 类目编码 / 1 类目名称 / 2 物料编码 / 3 物料名称 / 4 影响范围编码 / 5 执行单位编码。

> ✅ **新的 4 列只能追加在第 6~9 位**。插在中间 = 全部错位落库，而且**不报错**。
> ⚠️ 上线时**旧模板必须同时换掉**，否则业务拿旧模板导进来就是错位数据。

### 7.2 🔴 导入的判重逻辑，会直接挡住需求 3.3

`ProductRangeImportServiceImpl.java:112-119`：

```java
planProductRangeDTO.setCategoryCode(categoryCode);
planProductRangeDTO.setProductCode(productCode);
PlanProductRangeDTO exist = planProductRangeService.getPlanProductRange(planProductRangeDTO);
if(exist != null) { ... msg.append("数据已存在;"); }
```

而 `getPlanProductRange`（`PlanProductRangeServiceImpl.java:103-108`）：

```java
query.eq(StringUtils.isNotBlank(productCode), PlanProductRange::getProductCode, productCode);
query.eq(StringUtils.isBlank(productCode),   PlanProductRange::getCategoryCode, categoryCode);
query.isNull(StringUtils.isBlank(productCode), PlanProductRange::getProductCode);
PlanProductRange productMallRange = planProductRangeMapper.selectOne(query);
```

**物料编码不为空时，它只按物料编码查，完全忽略类目、影响范围、层级。**

→ 同一个物料想配第二行（不同 BU / 不同层级），**导入时就被判成"数据已存在"打回来了**，
根本轮不到数据库唯一索引出手。

> 📌 **所以 `10v` §1.6 说的"索引挡着"只是第二道门。第一道门是这段代码。**
> 两道门都要拆。而 `10u` 已经拍板：**索引删掉，判重统一收敛到应用层一个方法**——那个方法就替换这里。

### 7.3 导出模板：test 完全没有，uat 有个错字

`export-template.sh inspect`：

| 环境 | 结果 |
|---|---|
| **test** | **主模板和明细都是空的** → 点【导出】必然失败 |
| uat | `planProductRangeExport`，8 个字段 |

uat 明细里的问题：

| sort | field_name | field_val（表头中文） | 问题 |
|---:|---|---|---|
| 3 | `categoryName` | **集采物料编码** | 🔴 **写错了**，应该是「集采类目名称」（和 sort 4 的 productCode 重复） |
| — | 缺 `buName` | | 影响范围名称没导出 |
| — | 缺 `createTimeStr` | | 创建时间没导出 |

**这次要加 4 列，正好把这三处一起修掉。**

### 7.4 导入模板文件：两个环境都在，不用补

`scm_staticfile` 表，`staticfile_code = planProductRangeTemplate`：test / uat 各一条，`enable=1`。
**上线时要做的是"换文件"（传新的 10 列 xlsx 到 OBS，更新 `staticfile_path`），不是"新建配置"。**

---

## 7.5 🔁 第二遍复扫（2026-09-08 当天补做）：又找到 4 项

> **为什么会有第二遍**：用户问「你确定找全了吗」。我复盘了第一遍的方法，发现它只扫了 `isCollection` 这一个字段名，
> **没扫同义名**（`isCentralized`、`is_jc`）、**没扫全部前端仓库**（只扫了假定相关的 3 个）。
> 按补上的口径重扫，**又出来 4 项**。这 4 项如实记在这里，也说明第一遍确实不全。

| # | 新发现 | 怎么漏的 | 影响 |
|---|---|---|---|
| **N-1** | 🔴 **驾驶舱是受影响的**（§2.3 原来判它"不受影响"，**判错了**） | 驾驶舱有**两个** provider：`SourceCollectionDataServiceImpl` 读独立表（不受影响），但 `CockpitCollectionProviderImpl:182` **查 ES 且带 `termQuery("isCentralized", 1)`**。第一遍只看到前一个 | 口径变了驾驶舱数字跟着变 |
| **N-2** | 🔴 **B4 的改法会连带影响驾驶舱和集采门户的类目聚合** | 需要两步推理才能看出来，单纯 grep 看不到 | 见下方专项说明 |
| **N-3** | 🆕 第 **7** 个前端页面：`scm-vue-all-vmp/.../queryLedgerOfProcurementPlanGYS/index.vue`（供应商端集采计划查询台账，列里有「集采执行单位编码」） | 第一遍只扫了 plan / procurementscheme / mdm 三个前端仓，**没扫 vmp** | 只展示执行单位，**本次可不改**，但属于池子数据的消费方，要列进回归 |
| **N-4** | 🟢 `SchemeBPMConditionDTO.isCentralized` 是**死字段** | 第一遍没扫 `isCentralized` | 唯一两处使用全被注释（`SourceRevealTaskServiceImpl:229/583`）。**不是第二条工作流通路**，别被它误导 |

### 🔴 N-2 专项：改云采采集（影响点③）会连带改变驾驶舱和集采门户的数字

**现在的代码**（`SourceCollectionServiceImpl:224-226`）：

```java
String midClassCode = s.getCategoryCode().substring(0,4);   // 订单的类目码砍成 4 位
if(skuMap.get(midClassCode) != null) {
    s.setCategoryCode(midClassCode);                        // ← 把类目码【覆盖】成 4 位再存库
    s.setCategoryName(skuMap.get(midClassCode).getCategoryName());
```

所以今天 `sc_source_collection.category_code` **永远是 4 位**，ES 索引也跟着永远是 4 位。

**而下游有两处按类目码做前缀聚合**（全仓就这两处）：

```
CockpitCollectionProviderImpl:190        QueryBuilders.prefixQuery(F_CATEGORY_CODE, categoryCode)   驾驶舱
CentralizedProcurementPortalServiceImpl:383  同一句                                                 集采门户
```

`CockpitCollectionProviderImpl` 的注释还写着：**「按四位大类前缀，含全部下级细类（2113 命中 211303 笔及笔芯）」「与集采首页保持同一套口径」**。

**推论**：B4 改成"逐级向上匹配"时，**存什么进 `category_code` 是一个要显式决定的事**：

| 存法 | 驾驶舱/门户的影响 | 评价 |
|---|---|---|
| 存**订单原始的完整类目码**（6/8 位） | `prefixQuery("2113")` 仍能命中 `211303` ✅，而且粒度更细 | **推荐** |
| 存**命中的台账类目码**（可能是 4 位，也可能是 6/8 位） | 粒度取决于台账怎么配，**同一批订单可能出现长短不一的类目码**，聚合口径不稳定 | ❌ 不要 |

> 📌 **写进开发基线**：B4 改造时，`s.setCategoryCode(...)` **保留订单自己的完整类目码，不要覆盖成台账里那条的类目码**。
> 台账那条只用来判定"算不算集采"，不用来改写数据。
> **这一条不写明，开发时最自然的写法恰恰是错的那种**（照着现有代码的形状改，就会覆盖）。

### 第二遍还确认为干净的

| 扫了什么 | 结果 |
|---|---|
| `scm-datacenter-all`（数据中心/抽数） | **0 命中**，不碰这些表 ✅ |
| `03zhaocai-start` | 只命中压缩过的第三方 JS 库，**误报** ✅ |
| `is_jc` / `getIsJc` 后端全扫 | 3 个文件，**全部已在清单内**（报表、实体、Mapper） ✅ |
| 全部 7 个前端仓库逐个扫 | 只多出 vmp 那 1 个（N-3），其余为已废弃的 `scm-vue-all/` 旧目录 ✅ |
| 类目码前缀聚合 | 全仓**只有 2 处**，都在上面 N-2 里 ✅ |

---

## 8. 对既有文档的订正清单

| # | 文档 | 原说法 | 订正 | 影响 |
|---|---|---|---|---|
| 1 | `10t` §1.2 | 台账列和搜索条件是后端配置下发，加列不动 vue | **是前端静态 JSON，两份，要前端发版** | 🔴 第一周多一次前端发版 |
| 2 | `10l` §一 | 类目放开到末级：树/接口/组件全现成 | **树接口写死 ≤4 位，20+ 页面共用，不能改** | 🔴 改成"第一周不做树选择器" |
| 3 | `10v` §1.6 / `10t` B4 | 唯一索引挡着第二行 | **第一道门是导入的 `getPlanProductRange` 判重，索引是第二道门** | 🟡 两处都要改 |
| 4 | `10t` §2.2 / `10v` §2.3 | 前端 3 个页面 | **6 个**（多 3 个详情页，审批人看的就是它们） | 🔴 工作量 +0.5 天 |
| 5 | `10l` §三 | 有四个二级集团区域数据 0% | **6 个 BU 完全为空** | 🟡 支持"区域档先关闭" |
| 6 | 全部文档 | 影响面止于三个采购页面 | **下游还有 3 套报表 + ES 索引 + 集采门户** | 🔴 要做口径对账 |

---

## 9. 影响面总表（开发和测试都照这张表走）

图例：🔴 必做且高风险 ｜ 🟡 必做 ｜ 🟢 顺手 ｜ ⚪ 确认不受影响

### 9.1 后端代码

| # | 位置 | 属于 | 动作 | 级别 |
|---|---|---|---|---|
| B-01 | `PlanProductRange.java` 实体 | 一周 | 加 4 列 + `delete_sign` + `@TableLogic` + `update_by/time` | 🔴 |
| B-02 | `PlanProductRangeServiceImpl:70` 列表分页 | 一周 | 绕过 `@TableLogic`，让页面能看到失效行 | 🟡 |
| B-03 | `PlanProductRangeServiceImpl:103-108` 查单条 | 一周 | `selectOne`→`selectList`，判重口径整个换 | 🔴 |
| B-04 | `PlanProductRangeServiceImpl:119-138` **判集采主接口** | 一/二周 | 一周：`selectOne`→`selectList`＋优先级<br>二周：**改返回结构为每行明细** | 🔴 |
| B-05 | `PlanTaskServiceImpl:687` 取执行单位 | 一周 | 加排序＋判空（现在 `limit 1` 无序 ＋ 空指针） | 🔴 |
| B-06 | `PlanServiceImpl:2034` 取执行单位（复制粘贴的第二份） | 一周 | 同上 | 🔴 |
| B-07 | `SourceCollectionServiceImpl:124` SAP 采集 | 一周 | 写死 `category_code='1001'`；`@TableLogic` 后自动带状态过滤 | 🟡 |
| B-08 | `SourceCollectionServiceImpl:205,224` 订单采集 | 一周 | **去掉 `substring(0,4)`，改逐级向上** | 🔴 |
| B-09 | `ProductRangeImportServiceImpl:105-108` 二级校验 | 一周 | 去掉"必须二级"，改成"存在且启用" | 🔴 |
| B-10 | `ProductRangeImportServiceImpl:112-124` 判重 | 一周 | 换成新判重方法 | 🔴 |
| B-11 | `ProductRangeImportServiceImpl:66-70/163-167` 列位置 | 一周 | 追加 4 个新列（只能加在 6~9 位） | 🔴 |
| B-12 | `ProductRangeImportServiceImpl:186-193` 不回填 `buName` | 一周 | 顺手补 | 🟢 |
| B-13 | `MaterialClassServiceImpl:271-273` `queryClassLine` 空指针 | 一/二周 | 判空（放开末级后必被触发） | 🟡 |
| B-14 | `sc_plan` / `sc_plan_product` / `sc_scheme` / `sc_supplier_green_channel` | 二周 | 各加 2 列 ＋ 实体/DTO/Mapper | 🟡 |
| B-15 | `sc_scheme_to_purchase` 待采购池 | 二周 | 建议也加 2 列（`10r` P8） | 🟡 |
| B-16 | `SourceWorkflowAdapterBuilder:225-240` 计划递变量（现在只递 1 个） | 二周 | 追加 2 个 | 🟢 |
| B-17 | `SourceWorkflowAdapterBuilder:79-160` 方案递变量（现在 7 个） | 二周 | 追加 2 个 | 🟢 |
| B-18 | `SourceWorkflowAdapterServiceImpl_GreenChannel:130-172` 非平台（3 个，全无关集采） | 二周 | **从零加一整组** | 🟡 |
| B-19 | 🆕 `CentralizedProcurementReportServiceImpl` 集中采购报表 | 二周 | **不改代码，但要做口径对账** | 🔴 |
| B-20 | 🆕 `SourceCollectionMapper:49` 定标采集 SQL（`s.is_collection=1`） | 二周 | 不改代码，口径变化会影响采集量 | 🟡 |
| B-21 | 🆕 ES `index_web_collection_meta` | 二周 | 不改代码，**新旧口径数据会混存** | 🟡 |

### 9.2 前端

| # | 页面 | 属于 | 动作 | 级别 |
|---|---|---|---|---|
| F-01 | `procurementCatalogMgt.json`（**两份**） | 一周 | 加 4 列 + 2 个筛选 + 修 4 处配置错 | 🔴 |
| F-02 | `procurementCatalogMgt/index.vue` | 一周 | 【删除】文案改「作废」，确认框文案跟着改 | 🟡 |
| F-03 | `purchasePlan/saveOrSubmit.vue:264,1596` | 二周 | 拆 disabled ＋ 加 2 字段 ＋ 修死锁 ＋ 接新返回结构 | 🔴 |
| F-04 | `basicInfo2.vue:450,4316,4333` | 二周 | 同上 ＋ **拦截改成只对集团集采生效** | 🔴 |
| F-05 | `increasedListAdd.vue:62,501` | 二周 | 同上（注意 `isJc`） | 🔴 |
| F-06 | 🆕 `purchasePlan/detail.vue:39` | 二周 | 加 2 个只读字段 | 🟡 |
| F-07 | 🆕 `procurementSchemeInfo.vue:96` | 二周 | 加 2 个只读字段 | 🟡 |
| F-08 | 🆕 `supplier/detail/index.vue:19` | 二周 | 加 2 个只读字段 | 🟡 |

### 9.3 配置与数据

| # | 项 | 属于 | 动作 | 级别 |
|---|---|---|---|---|
| C-01 | 导出模板 `planProductRangeExport` | 一周 | **test 从零建**；uat 加 4 列 + 修 `categoryName` 错字 + 补 `buName`/`createTimeStr` | 🔴 |
| C-02 | 导入模板 xlsx（OBS） | 一周 | 传 10 列新文件，改 `scm_staticfile.staticfile_path` | 🔴 |
| C-03 | 台账 DDL（test + uat） | 一周 | **两个环境都要跑**（test 缺唯一索引，状态不一致） | 🔴 |
| C-04 | 单据表 DDL ×4~5 | 二周 | 建议跟一周的 DDL 一起提 | 🟡 |
| C-05 | 期初脚本 | 上线 | 7343 行补层级/强管控/状态 + **修 `BU0013`→`BU013`、补 `BU012`** | 🔴 |
| C-06 | 区域开关字典 | 一周 | 新增一条字典，默认关闭 | 🟡 |
| C-07 | 生产台账口径清单 | 上线 | ⚠️ **我只能看到 test/uat，生产实际管哪些类目必须要到清单** | 🔴 |

### 9.4 确认不受影响（不用管）

⚪ 数据库视图 / 触发器 / 存储过程（全库 0 命中）
⚪ `sc_collection_daily_amount_ledger` 集采日金额台账（独立表，人工维护）
~~⚪ 驾驶舱 `cockpit_collection_data`（读独立表）~~ **【订正 2026-09-08：判错了。驾驶舱有两个 provider，`CockpitCollectionProviderImpl:182` 查 ES 且带 `isCentralized=1`，是受影响的。详见 §7.5 N-1】**
⚪ `scm-order-all` 云采订单统计报表（读订单侧，不读台账）
⚪ 寻源报名/报价那 9 处 `substring(0,4)`（不读台账，本次不动，但 `13` §风险 里留了记录）
⚪ `scm-vue-all/` 下的旧版同名前端文件

---

## 10. 风险排序（按"发现得有多晚"排，照 `10u` 的分类法）

| 排名 | 风险 | 类别 | 什么时候才会被发现 | 怎么堵 |
|---:|---|---|---|---|
| 1 | 🆕 **BU012/BU013 编码对不上**，8 个组织静默脱管 | A 静默 | 可能永远发现不了 | 期初脚本修；上线后专项验证 |
| 2 | 6 处读台账漏加状态过滤 | A 静默 | 几个月后 | `@TableLogic` 框架兜底 |
| 3 | 云采采集 `substring(0,4)` 丢单 | A 静默 | 对账时 | 手动触发采集验证 |
| 4 | 🆕 **报表口径变了没人知道** | A 静默 | 领导问的时候 | 上线前后口径对账 + 提前打招呼 |
| 5 | P1 二级集团层级单子没人接 | B 潜伏 | 业务配第一条二级集团规矩时 | 提前造数据走完整链 |
| 6 | 🆕 **详情页没加字段，审批人看不到** | B 潜伏 | 第一次走分支②审批时 | 6 个页面一起改 |
| 7 | 判集采接口 `selectOne` 抛异常 | C 显性 | 上线几小时内 | 改 `selectList` |
| 8 | 🆕 **test 缺唯一索引，3.3 在 test 测得通** | C 显性 | 到 uat 才炸 | DDL 两边都跑；关键用例在 uat 验 |
| 9 | 🆕 **旧导入模板错位落库** | E 数据 | 业务用旧模板那天 | 上线同时换模板文件 |
| 10 | 期初 7343 行填错 | E 数据 | 上线当天 | 上线前后 health diff |

---

## 附 · 本文所有结论的出处

| 结论 | 证据 |
|---|---|
| 台账表无裸 SQL/XML/视图/触发器 | `grep -r sc_plan_product_range` 三仓仅 1 处（实体 `@TableName`）；`information_schema.VIEWS/TRIGGERS/ROUTINES` 查询 0 行 |
| 7 处读台账 | `grep -rn planProductRangeMapper`：`PlanProductRangeServiceImpl:70/108/138`、`PlanTaskServiceImpl:687`、`PlanServiceImpl:2034`、`SourceCollectionServiceImpl:124/205` |
| 三个页面共用判集采接口 | `PlanController.java:485` → `/e/business/source/plan/queryInProductRangeNum`；前端 `saveOrSubmit.vue:1584`、`basicInfo2.vue:4304`、`increasedListAdd.vue:489` |
| 集中采购报表读 `is_collection` | `CentralizedProcurementReportServiceImpl.java:390/815/503/504` |
| 定标采集 SQL 过滤 `is_collection=1` | `SourceCollectionMapper.java:49` |
| ES 集采索引写/读 | 写 `CollectionMetaServiceImpl`（scm-source-chase）；读 `SourceQueryBuilderImpl_CollectionProduct(Detail)`（scm-report-all）、`CentralizedProcurementPortalServiceImpl` |
| 前端 6 个页面 | `grep -rl "isCollection\|isJc" 02zhaocai-front`（排除 `scm-vue-all/` 旧目录）：`saveOrSubmit.vue`、`detail.vue`、`basicInfo2.vue`、`procurementSchemeInfo.vue`、`increasedListAdd.vue`、`supplier/detail/index.vue` |
| `basicInfo2` 才是真正在用的方案编制页 | `createPurchase.vue:35` `import basicInfo from './basicInfo2.vue'` |
| 台账页面列来自静态 JSON | `procurementCatalogMgt/index.vue:110-111`；文件在 `scm-vue-all-mdm/public/statics/json/mdm/` 和 `scm-vue-all-statics/statics/json/mdm/`，`diff` 完全相同 |
| 类目树写死 ≤4 位 | `MaterialClassServiceImpl.java:175-178`（带 2023-04-23 的注释） |
| 20+ 前端页面用树接口 | `grep -rl "queryProductClassTree"` 02zhaocai-front |
| 逐级向上的现成实现 | `MaterialClassServiceImpl.queryClassLine():265-296` |
| BU 编码对不上 | 主数据 `SELECT DISTINCT belong_bu_code FROM scm_ubm_uat.ubm_organization_manage` → BU001~BU013；台账 `SELECT DISTINCT bu_code FROM scm_source_uat.sc_plan_product_range` → `...BU011/BU0013`（缺 BU012、BU013 写成 BU0013） |
| 区域数据 6 个 BU 全空 | `GROUP BY belong_bu_code` 统计 `belong_plate_code` 空值 |
| 组织层级枚举与排序 | `OrganizationLevelEnum.java`：`JT=1, GS=2, BS=3`，`QY` 不在 map |
| uat auth_level 分布 | `SELECT auth_level, COUNT(*) FROM ubm_organization_manage GROUP BY 1` → BS 662 / NULL 171 / GS 17 / QY 3 / JT 1 |
| 台账数据体检 | `scm_source_uat.sc_plan_product_range` 聚合查询（§6.1） |
| test/uat 索引差异 | `SHOW INDEX FROM sc_plan_product_range`（两库分别执行） |
| 导入按列位置取值 | `ProductRangeImportServiceImpl.java:66-70` 和 `:163-167` |
| 导入判重只按物料码 | `ProductRangeImportServiceImpl.java:112-119` + `PlanProductRangeServiceImpl.java:103-108` |
| 导出模板 test 缺失、uat 错字 | `bash scripts/export-template.sh inspect test\|uat planProductRangeExport` |
| 导入模板两环境都在 | `scm_staticfile` 查询，`staticfile_code='planProductRangeTemplate'`，`enable=1` |
| 台账表无 delete_sign/update_* | `information_schema.COLUMNS` 查 uat 表结构；`PlanProductRange.java` 实体字段 |
| `@TableLogic` 全仓 70 处 / source 内 11 处 | `grep -rn "@TableLogic" 01zhaocai-end \| grep -v target \| wc -l` |
