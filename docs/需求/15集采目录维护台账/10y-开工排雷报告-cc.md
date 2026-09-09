# 10y 开工排雷报告 · 工作流边界、九个雷、明天干什么

> **日期**：2026-09-08 ｜ **工具**：cc
> **当前状态**：开工前最后一份侦察报告。**全部结论都落到了文件行号或一条查询结果上**，没有推断的地方都标了【推断】。
> **下一步**：明天（9/9 周三）按 §5 的顺序动手。**动手前先做 §5.0 那三件事，10 分钟，不做会白干一天。**
>
> ⚠️ 本文回答你问的那个问题：**「审批分支不是我的活，但我是不是还得在代码层面配合工作流？」**
> **答案在 §1，一句话：分支不是你的活，但"值"是你的活，而"值"在这套系统里是三段——算、存、递，其中"算"是这次开发最大的一块。**

---

# 0. 先看这张表（30 秒版）

| 这件事 | 谁干 | 证据 |
|---|---|---|
| 画流程图、配分支条件（谁审、报到哪一级） | ❌ **不是你**，是产品/小韩在 DPS 平台上配 | 产品原话「影响是我们前台配置的事」（录音 09:00~10:23） |
| 把 3 个变量**递给** DPS | ✅ **是你**，改 `SourceWorkflowAdapterBuilder` 4 个重载 | `SourceWorkflowAdapterBuilder.java:148-158 / 226-236 / 311-321` |
| 在 DPS 平台上**注册**这 2 个新变量 | ❌ 不是你（但你得提醒他们，**不注册流程图里选不到**） | `wf.sh metas test` 实跑：现有 13 个变量，**没有** `collectionLevel` / `isStrongControl` |
| 把 3 个值**存到单据表**上 | ✅ **是你**，5 张表要加列 | 实查 uat：5 张表**都只有 `is_collection` 一个字段** |
| **算**出这 3 个值（命中哪条规矩、层级多少、强不强） | ✅✅ **是你，而且这是这次最大的一块** | `PlanProductRangeServiceImpl.queryInRangeNum():119-160` 现在只返回 `"0"/"1"/名字串` |
| 集采的单子**分派给集采执行单位** | ✅✅✅ **是你，而且这块最容易漏** | **`PlanServiceImpl.getCollectionSupplierCode()` + 7 处 `if(1==isCollection)` 分支——这是代码不是流程配置** |
| 前端三个页面接住新的返回结构 | ✅ **是你** | 3 处 `queryInProductRangeNum` 调用点 |

> **所以那句「你得给我传值」听着像一行 `setValue`，实际上是：**
> **改判定算法 → 改接口返回结构 → 改 3 个前端调用点 → 5 张表加列 → 4 个流程适配器加变量 → 改分派逻辑。**
> **产品不是在推卸，他是真的只管配图那一段；只是他不知道"传值"在你这边有多少工。**

---

# 1. 完整链路跟读：一个「是否集采」是怎么从台账走到审批的

**这条链路我逐行跟完了，四段，每段都有你的活。**

```
① 算   前端提交前调接口 ──► PlanProductRangeServiceImpl.queryInRangeNum()
                              查 sc_plan_product_range，返回 "0" / "1" / "钢材、水泥"
② 存   前端拿返回值 set formState.isCollection = 1/0 ──► 保存 ──► sc_plan.is_collection
③ 递   提交审批 ──► SourceWorkflowAdapterBuilder.wrapperProcessMetasData()
                     把 1/0 翻译成中文 "是"/"否"，作为 metas 递给 DPS
④ 判   DPS 按流程图上配的条件走分支  ←── 这一段才是产品的活
     ⑤ 另有一条：计划审批通过 ──► getCollectionSupplierCode() 查台账拿执行单位
                                 ──► 写进待采购池 sc_scheme_to_purchase，状态=待响应
```

## 1.1 第①段「算」——现在的样子

`PlanProductRangeServiceImpl.java:119-160`（`scm-source-all/scm-source-plan`）：

```java
public String queryInRangeNum(PlanProductRangeCheckDTO dto) {
    // 1. 当前用户所在公司在字典 collection_company 里 → 直接返回 "0"（机电公司自己提单不算集采）
    // 2. 逐行查：
    for (PlanProductRangeCheckLineDTO lineDTO : dtos) {
        query.eq(PlanProductRange::getProductCode, lineDTO.getProductCode())
             .or(w -> w.eq(PlanProductRange::getCategoryCode, lineDTO.getCategoryCode())
                       .isNull(PlanProductRange::getProductCode));
        PlanProductRange productRange = planProductRangeMapper.selectOne(query);   // ← 雷 1
        if (productRange != null) { inRangeNum++; map.put(...); }
    }
    // 3. 全不中→"0"；全中→"1"；部分中→返回命中的物料名拼接串（前端据此弹"不允许混采"）
}
```

**这个方法要改成什么样，见 §3「判定引擎」。它是这次开发的心脏。**

## 1.2 第③段「递」——现在的样子

`SourceWorkflowAdapterBuilder.java` 里有 **4 个 `wrapperProcessMetasData` 重载**，各递不同的变量：

| # | 签名 | 递了几个变量 | 有没有 isCollection | 谁调它 |
|---|---|---:|---|---|
| 1 | `(ProcessStartAO, Scheme)` | 7 | ✅ `:151-158` | `_Clarify:114`、`_ShortList:129`、`ProfessorWorkflowAdapter_Extract:124` |
| 2 | `(ProcessStartAO, Scheme, DealResult)` | 5 | ❌ **没有** | `_DealResult:115`（定标方案） |
| 3 | `(ProcessStartAO, Plan)` | **1（只有 isCollection）** | ✅ `:226-236` | `_Plan:144`（**采购计划**） |
| 4 | `(ProcessStartAO, Scheme, List<SchemeProduct>)` | 8（多一个 `isAllPlan`） | ✅ `:314-321` | `_Scheme:122`（**采购方案**） |

另外**非平台录入完全没有集采变量**：
`SourceWorkflowAdapterServiceImpl_GreenChannel.java:128-172` 只递了 `isCompany`、`memberCode`、`totalAmount` **三个**。

> 📌 **要改的是 #3、#4、GreenChannel 这三处**（三个单据各一处）。
> #1、#2 是澄清/入围/定标的流程，这次需求没点名，**先不动**（但要在文档里写明"为什么不动"）。

## 1.3 ⚠️ 第⑤段「分派」——**这是你之前没算进工作量的那块**

`PlanServiceImpl.java:2029-2036`（`PlanTaskServiceImpl.java:687-694` 有一份**一模一样的复制粘贴**）：

```java
private String getCollectionSupplierCode(PlanProduct planProduct) {
    LambdaQueryWrapper<PlanProductRange> query = new LambdaQueryWrapper<>();
    query.eq(PlanProductRange::getProductCode, planProduct.getProductCode())
         .or(w -> w.in(PlanProductRange::getCategoryCode, planProduct.getMidClassCode())
                   .isNull(PlanProductRange::getProductCode));
    query.last("limit 1");
    PlanProductRange range = planProductRangeMapper.selectOne(query);
    return range.getSupplierCode();      // ← 雷 2：range 可能是 null，没判空
}
```

调用它的地方一共 **7 处**（`PlanServiceImpl` 352/1466/1664/2009，`PlanTaskServiceImpl` 347/623），模式全一样：

```java
schemeToPurchaseDTO.setIsCollection(...);
if (1 == schemeToPurchaseDTO.getIsCollection()) {
    schemeToPurchaseDTO.setCollectionSupplierCode(getCollectionSupplierCode(planProduct));
    schemeToPurchaseDTO.setExecuteState(PendingResponse);   // 状态=待响应
}
```

**翻成大白话**：计划审批通过 → 每一行物料如果是集采 → **去台账里查这条规矩配的"集采执行单位"，把这行扔进待采购池、状态设成"等机电公司响应"**。

🔴 **新需求要求「二级集团 / 区域层级不需要集采执行单位」，而这段代码不知道有层级这回事。**
不改的话：二级集团层级的行 → `isCollection` 仍然是 1 → 照样去查执行单位 → 照样设成"待响应" →
**在企业端列表里显示"待响应"，但机电公司那边根本筛不到（因为筛的是 `collection_supplier_code = 自己`）→ 这张单永远没人响应。**

> 这就是 `11c` 必问④「二级集团的单子谁做方案」的**后端那一半**。
> 之前只找到前端 `basicInfo2.vue:4333` 那一道拦截，**以为改一个 if 就行——不是，后端这 7 处才是真正决定单子去哪的地方。**

---

# 2. 九个雷（按"上线当天会不会炸 + 发现得早不早"排序）

| # | 雷 | 触发条件 | 后果 | 证据 |
|---|---|---|---|---|
| 🔴1 | **`selectOne` 遇多行抛 `TooManyResultsException`** | 台账一旦有同类目多行（= 需求 3.3 的目标） | **三个单据页全部提交不了** | `PlanProductRangeServiceImpl:139`（判集采）、`:110`（getPlanProductRange）；uat 实测现在**每个(类目,物料)组合都恰好只有 1 行**，所以今天跑得好好的 |
| 🔴2 | **`getCollectionSupplierCode` 不判空直接 NPE** | 台账查不到规矩，但单子上 `isCollection=1` | **计划审批通过时报 500，审批卡住** | `PlanServiceImpl:2035` `return range.getSupplierCode();`。<br>而且它和判集采**用的不是同一套查询条件**（这里用 `planProduct.midClassCode`，那边用前端传的 `categoryCode`），两者不一致就会出现"判定说是集采、这里查不到" |
| 🔴3 | **二级集团/区域的单子被扔进"待响应"没人接** | 上线后业务配了第一条二级集团规矩 | 单子卡死。**上线当天不暴露，等业务配了才炸** | §1.3 那 7 处 |
| 🔴4 | **本地分支落后 origin/test 1212 个提交** | 直接在当前分支上开发 | **白干**（经验教训里已经栽过一次） | 实测 fetch 后：`scm-source-all` HEAD 落后 origin/test **1212**、领先 7（价格趋势的旧活）；`scm-vue-all-procurementscheme` 落后 **580**；`scm-vue-all-plan` 落后 25 |
| 🟠5 | **混采弹框是死锁不是拦截** | 一张单既有集采又有非集采物料 | **页面卡死，只能刷新**（点确定点取消都没反应） | 三个页面全是 `await new Promise(...)` 里 `onOk(){}`/`onCancel(){}` 空实现：`saveOrSubmit.vue:1593-1602`、`basicInfo2.vue:4315-4325`、`increasedListAdd.vue:499-508`。<br>6.3「取最小层级」+6.4「有强取强」= 官方承认一单多情况合法 → **混采会从异常变常态，这个死锁必须这次修** |
| 🟠6 | **`gatherOrder` 用 categoryCode 当 map key，后面覆盖前面** | 台账同类目多行 | 云采采集**随机取一条规矩**；加了状态之后**失效行可能覆盖生效行** | `SourceCollectionServiceImpl:207-209` `ranges.forEach(s -> skuMap.put(s.getCategoryCode(), s))` |
| 🟠7 | **`gatherSap` 写死 `category_code='1001'`（煤炭）** | 类目放开到末级后台账开始存 6/8 位码 | SAP 那条采集链路**一条都拉不到** | `SourceCollectionServiceImpl:122-124` |
| 🟡8 | **台账 `supplier_code` 有脏数据，其中 2 行是斜杠拼串** | 命中那 2 行 | 塞进 `collection_supplier_code` 后，集采单位端**精确匹配永远匹配不上**，单子谁也看不见 | uat 实查：`CN11000767/CN31000949/CN31000695/CN11004418`（43 字符）2 行、`CN11005095` name 存成字符串 "null" 14 行、`1`/`1` 垃圾数据 1 行 |
| 🟡9 | **台账列表页 `createTimeStr` 是死代码** | 一直 | 页面创建时间列可能不对（DTO 建了没进 list 就被丢了） | `PlanProductRangeServiceImpl:73-79`：循环里 `new PlanProductRangeDTO()` 设了 `createTimeStr`，**从来没 `voList.add()`**，之后 `ListCoverUtil.listCover` 重新转一遍 |

---

# 3. 一条最重要的现状事实：**这套集采功能其实几乎没被用起来**

uat 实测填充率：

| 表.字段 | 总行 | 空值 | =1 | =0 |
|---|---:|---:|---:|---:|
| `sc_plan_product.is_collection`（**行级**） | 78,521 | **78,430（99.9%）** | 31 | 60 |
| `sc_plan.is_collection`（单级） | 27,155 | **27,021（99.5%）** | 54 | 80 |
| `sc_scheme.is_collection`（单级） | 17,076 | **16,831（98.6%）** | 53 | 192 |
| `sc_scheme_to_purchase`（待采购池） | 74,498 | — | **9 行**（3 待响应/2 已完成/4 已拒绝） | 74,489 |

**三个判读：**

1. **行级「是否集采」实际上是空的。** 全后端**没有任何一处** `planProduct.setIsCollection(...)`，前端也只设了表头 `formState.isCollection`。
   → 需求 6.3/6.4 要「逐行判层级、再跨行聚合」，**行级这套是从零做，不是改**。
2. 🟢 **好消息：改动风险比想象的小。** 这功能 2025-11 才上，真正走过集采链路的单子只有几十张。改坏了影响面有限。
3. 🔴 **坏消息：没有真实数据可参照，测试数据必须自己造。** `13b-测试方案` 里那 8 种场景，**一条现成的都没有**。

---

# 4. 探针结果汇总（全部实测，不是推断）

| 探针 | 结果 | 判读 |
|---|---|---|
| **DPS 现有流程变量** | 13 个，`isCollection` 在，**`collectionLevel` / `isStrongControl` 不在** | 新变量**必须先在 DPS 平台注册**才能在流程图里被选到。这是产品/小韩的活，**今天就要告诉他们** |
| **台账表 DDL** | 13 列。**uat 有唯一索引 `range_product_idx(product_code, category_code)`，test 没有** | 索引必须删（3.3 要的就是同一物料多行）。**test 上测不出来，只有 uat 会挡** |
| **台账数据** | 7343 行；`category_code` **全部 4 位**；只管类目的只有 3 行；每个 (类目,物料) 组合**恰好 1 行** | 今天没有重复 → `selectOne` 没炸过。**改造后必然重复** |
| **五张单据表** | `sc_plan` / `sc_plan_product` / `sc_scheme` / `sc_scheme_to_purchase` / `sc_supplier_green_channel` **都只有 `is_collection`（或 `is_jc`）一个字段** | 各加 2 列，共 10 列。`sc_scheme_to_purchase_log` 也有 `is_collection`，**别漏了它** |
| **组织机构区域→板块** | `ubm_organization_manage`：36 个区域**全部 1:1 挂唯一板块**，0 跨板块 | 判重要的换算路是通的（详见 `12f` §8） |
| **Git 基线（已 fetch）** | `scm-source-all` 落后 origin/test **1212**、领先 7；`scm-vue-all-procurementscheme` 落后 **580**；`scm-vue-all-plan` 落后 25；`scm-vue-hpc` 落后 88 **且 9 个脏文件** | 🔴 **绝不能在当前分支上开发**。必须从 `origin/test` 新开 |

---

# 5. 明天（9/9 周三）干什么

## 5.0 动手之前，先做这三件（10 分钟，不做会白干一天）

```bash
# ① 从 origin/test 新开分支（三个仓库都要），别在价格趋势那个旧分支上写
git -C 01zhaocai-end/scm-source-all checkout -b feature/jicai-catalog-yang origin/test
git -C 02zhaocai-front/scm-vue-all-plan checkout -b feature/jicai-catalog-yang origin/test
git -C 02zhaocai-front/scm-vue-all-procurementscheme checkout -b feature/jicai-catalog-yang origin/test
```

```bash
# ② 确认新分支上的代码和本报告读的一致（分支换了，行号可能变）
grep -n "getCollectionSupplierCode\|TooManyResults\|selectOne" 01zhaocai-end/scm-source-all/scm-source-plan/src/main/java/com/pcitc/scm/source/plan/service/impl/PlanProductRangeServiceImpl.java 01zhaocai-end/scm-source-all/scm-source-plan/src/main/java/com/pcitc/scm/source/plan/service/impl/PlanServiceImpl.java
```

③ 把 3 个变量名发给产品，问一句发给小韩还是华姐（**并提醒：这两个新变量得先在 DPS 平台注册，不然流程图里选不到**）。

## 5.05 🟢 SQL 已经替你写好了，明天直接跑

都在 [`sql/`](sql/) 下，**幂等、可重跑、自带自检**：

| 文件 | 干什么 | 怎么跑 |
|---|---|---|
| `01-台账加字段.sql` | 台账加 4 个业务列 + 5 个审计列，`bu_code` 放长，**条件删唯一索引**（uat 有 test 没有，先查再删），补一个查询索引 | `bash scripts/dbq.sh docs/需求/15集采目录维护台账/sql/01-台账加字段.sql scm_source_test` 然后换 `scm_source_uat` |
| `02-单据表加字段.sql` | **六张**单据表各加 2 列（比需求文档多一张 `sc_scheme_to_purchase_log`，别漏），三张再加"改成否的原因" | 同上 |
| `03-回滚.sql` | 回滚 01/02 的结构。**跑之前会先告诉你新列里有没有数据** | 同上 |
| `04-开工前体检.sql` | **只读**。基线快照 + 存量冲突体检 + 脏数据清单 | 同上 |

> ✅ **`04` 已经在 uat 实跑过了**（见下），能正常出结果，明天直接用。

### 04 在 uat 的实跑结论（重要）

| 检查 | 结果 | 意味着 |
|---|---|---|
| 同一 (类目,物料) 多行 | **0 组** | 🟢 存量数据没有重复 → **新判重规则不会把老数据判成非法** |
| 类目祖先/后代关系 | **0 对** | 🟢 同上 |
| 物料行落在只管类目的行下面 | **0 对** | 🟢 同上 |
| `sc_supplier_green_channel` 填充 | 164 行，137 空，11 为 1，16 为 0 | 非平台录入也几乎没用起来 |

> 🟢 **这是这轮排雷最好的消息**：判重规则不管最后怎么定，**都不会炸到现有那 7343 行**。
> 风险只在"上线之后新录进来的数据"，而那是可控的。

---

## 5.1 明天能做完的（不依赖任何人的答案）

| 顺序 | 干什么 | 为什么明天做 | 大概 |
|---|---|---|---|
| **1** | **台账表 DDL** —— ✅ **脚本已写好，直接跑 `sql/01-台账加字段.sql`**（test 和 uat 各一遍） | 口径已定、产品不会再改；DDL 上环境要走流程，越早越好 | **10min** |
| **2** | **把判定引擎单独抽成一个类**（`CollectionRangeMatcher`），先写空壳 + 单元测试骨架 | 这是这次的心脏。**先把接口形状定下来，后面所有改动都往里填**，避免逻辑散在 7 个地方。<br>🟢 **好消息：祖先判定用字符串前缀就行**（类目码实测是 2/4/6/8 位严格前缀树，1418/1418 成立），**不用递归查类目树** | 2h |
| **3** | **修雷 1**：`selectOne` → `selectList` + 显式挑一条（判重口径没定也能先做，挑法先按"范围最窄+最新"） | 不改这个，第 1 步的 DDL 一上，台账一有重复数据，**三个单据页立刻全挂** | 1h |
| **4** | **修雷 2**：`getCollectionSupplierCode` 判空 + 两处复制粘贴合并到 Matcher 里 | 顺手，成本几乎为零 | 0.5h |
| **5** | **修雷 5**：三个页面的混采死锁弹框（`$message.warning` + `return`，去掉那个永不 resolve 的 Promise） | 独立、无依赖、纯收益，**而且这是产品能立刻看见的改善** | 1h |
| **6** | **单据表 DDL** —— ✅ **脚本已写好，`sql/02-单据表加字段.sql`**（六张表，含容易漏的 `sc_scheme_to_purchase_log`） | 和第 1 步一起提，省一次上环境 | **10min** |

> **明天不要做的**：判重的最终规则（等 `11d` 问完产品）、接口返回结构改造（等判定引擎定型）、工作流变量递值（等 DPS 注册）。

## 5.2 顺序为什么是这个

```
DDL 先行 ─► 因为上环境要走流程，晚一天就晚一天
   │
   ├─► 但 DDL 一上，台账就能存重复行 ─► selectOne 会炸 ─► 所以雷 1 必须紧跟着修
   │
   └─► 判定引擎抽壳 ─► 后面所有活（判重、层级、强管控、分派）都往这一个类里填
                        ─► 避免重蹈覆辙：现在同一段查询逻辑在代码里有 3 份（判集采 / 分派 / 云采采集），
                           口径一变要改 3 处，漏一处就是静默 bug
```

---

# 6. 这次开发的真实工作量（重新估）

之前 `13c` 估的两周里，**漏了「分派逻辑」和「行级字段从零做」这两块**。重估：

| 块 | 原估 | 现估 | 差在哪 |
|---|---:|---:|---|
| 台账本体（DDL+导入判重+列表+状态） | 4d | 4d | — |
| 判定引擎（算） | 2d | **4d** | 行级判定是从零做；判重规则复杂度上升（板块换算+祖先占位） |
| 接口契约改造 + 3 个前端调用点 | 1.5d | 1.5d | — |
| **分派逻辑（7 处 + 待采购池状态）** | **0（漏了）** | **1.5d** | §1.3 |
| 单据表 + 6 个页面 + 3 个详情页 | 3d | 3d | — |
| 工作流递值（3 个适配器） | 0.5d | 0.5d | — |
| 顺手修的雷（5/6/7/8/9） | 0.5d | 1d | 雷 6/7 是新发现的 |
| **合计** | **11.5d** | **15.5d** | |

**可用工期**：9/9（周三）~ 9/18（周五）= **8 个工作日**。

> 🔴 **缺口 7.5 天，比会前算的还大。** 但**上线推到国庆后了**，所以真实死线不是 9/18 而是 9/24 测试结束。
> 建议明天就跟产品把这句话说了：**「9/18 我给你一个能测的版本，但不会是全功能；剩下的边测边补，10/1 前收口。」**
> 砍的顺序仍按 `13` §7.3，但**第一个该砍的现在变成「区域·企业这一档」**——数据只有水泥集团一家有（`12f` §8），砍掉最不疼。

---

## 附 · 本文每条结论的出处

| 结论 | 出处 |
|---|---|
| 4 个 metas 重载、各递几个变量 | `SourceWorkflowAdapterBuilder.java` 全文 343 行读完 |
| 非平台录入没有集采变量 | `SourceWorkflowAdapterServiceImpl_GreenChannel.java:128-172` |
| 谁调哪个重载 | `grep -rn wrapperProcessMetasData` 全 `01zhaocai-end` |
| 分派逻辑 7 处 | `grep -rn "isCollection" scm-source-plan` + 逐处读上下文 |
| 前端 3 个调用点及其处理 | `saveOrSubmit.vue:1582-1614`、`basicInfo2.vue:4302-4340`、`increasedListAdd.vue:487-521` |
| DPS 现有 13 个变量 | `bash scripts/wf.sh metas test` 实跑 |
| 全部表结构与填充率 | `bash scripts/dbq.sh` 实查 `scm_source_uat` / `scm_ubm_uat` |
| Git 基线 | `git fetch origin test uat prod` 后 `rev-list --count` |
