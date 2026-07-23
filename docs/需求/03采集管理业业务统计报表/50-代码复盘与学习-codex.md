# 集采管理业务统计报表（招采平台 ZC）· IDEA 代码跟读教程

> 日期：2026-07-23
> 工具：codex
> 当前状态：ZC 写入代码仍在 `feature/jicai-zc-yang` 的 3 个未提交 Java 文件中；report 的 `dataSource` 筛选已在 test 实测通过，前端五项数据来源下拉已开发、构建并本地提交，尚未推送部署。
> 下一阶段：先把前端需求提交从既有 token 配置提交中安全拆出，再由用户发起远程推送和 Jenkins 部署；部署后补做页面与 Excel 的按来源验收。ZC 写入侧仍是另一条独立任务。
> 深度：标准（Java/Vue 新手教学加强版）｜复盘范围：source ZC 写入工作区 + report 查询导出 + Vue 报表页面｜最终代码基线：source `test@5c917220a` + 当前 3 个未提交文件、report `test@5007e07`、front `features/jicai-report-yang@3f4b85de`
>
> 本文覆盖旧的 `50-代码复盘与学习-codex.md`。旧文档讲的是早期相似交易报表和 FP 开发前模型，部分状态已经过时；本版以当前分支、当前代码和 2026-07-23 的 test 证据为准。

---

## 0. 先说结论：你这次到底开发了什么

一句话：

> 这次没有重做整张报表，而是在已有“非平台录入 FP → ES → report 查询/导出”链路上，再增加一个“招采平台 ZC → 同一个 ES”的数据搬运入口。

可以把 ES 理解成报表专用的“公共货架”：

```text
招采平台 ZC 的 MySQL 业务表
        │
        │  当前分支新增：筛选、关联、展开、字段翻译
        ▼
同一个 ES 报表索引 index_centralized_procurement_report_test
        │
        │  既有 report 服务：分页、权限、Excel
        ▼
集采管理业务统计报表页面
```

当前分支只改了下面 3 个文件：

| 顺序 | 文件 | 本次新增的职责 |
|---|---|---|
| 1 | `CentralizedProcurementReportController.java` | 增加人工触发 ZC 同步的 HTTP 门口 |
| 2 | `CentralizedProcurementReportService.java` | 声明 ZC 的手动入口和定时入口 |
| 3 | `CentralizedProcurementReportServiceImpl.java` | 真正完成查 4 类业务表、拼报表字段、批量写 ES |

下面这些重要文件是以前已有、本次只是复用，不能说成“本分支新增”：

| 文件/能力 | 归属 |
|---|---|
| `CentralizedProcurementReportModel.java` | 既有 ES 字段合同 |
| `CentralizedProcurementReportRepository.java` | 既有 ES 写入工具 |
| `SourceChaseConfig.java` | 既有 ES 索引名配置 |
| FP 非平台录入同步 | 前一期已有 |
| report 分页、Excel 导出 | 另一后端仓库已有 |
| Vue 报表页面 | 另一前端仓库的本地功能分支已有 |
| MyBatis-Plus、Spring Data Elasticsearch、Feign | 项目/第三方公共能力 |

### 当前五态，不要混淆

| 能力 | 预期 | 已实现 | 已配置 | 已部署 | 已验证 | 证据 |
|---|---|---|---|---|---|---|
| 当前分支 ZC 抽数写 ES | 是 | 是，工作区 3 文件 | 复用现有索引配置 | **否** | 隔离编译、数据库口径通过；接口未验 | 当前分支未提交；`javac` 退出码 0 |
| FP 抽数写 ES | 是 | 是 | 是 | 是 | 是 | 当前 ES 有 FP 5 条 |
| report 分页查询 | 是 | 是 | 是 | 是 | 是 | test 接口已返回 7 条总数 |
| report Excel 导出 | 是 | 是 | 是 | 代码已进 test | 本轮未下载复测 | `scm-report-all test@5007e07` |
| Vue 报表页面 | 是 | 本地分支有代码 | 菜单未知 | 未发现已进 `origin/test` 的证据 | 旧交接记载构建通过，运行未知 | 前端 `features/jicai-report-yang` |
| 五类来源全部接齐 | 是 | 否 | 否 | 否 | 否 | 当前需求只确认 FP、ZC；YC/MT/JD 不在本分支 |

最重要的一句：

> “ES 里已经有 2 条 `dataSource=ZC`”不等于“当前分支已经部署”。当前分支仍是未提交代码，而且那 2 条记录的 ID 形式与本分支的 ID 规则不同，只能证明另有写入者，不能拿来冒充本分支验收结果。

---

## 1. 先懂业务：报表的一行到底代表什么

### 1.1 不是“一张采购单一行”

这张报表的粒度是：

> 一家中标供应商中标的一条物料 = 报表一行。

假设一个采购方案有两家中标供应商：

```text
方案 A
├─ 供应商甲
│  ├─ 物料 001，含税金额 300
│  └─ 物料 002，含税金额 500
└─ 供应商乙
   └─ 物料 001，含税金额 100
```

报表应出现 3 行，而不是 1 行，也不是 2 行：

| 方案 | 供应商 | 物料 | 金额 |
|---|---|---|---:|
| A | 甲 | 001 | 300 |
| A | 甲 | 002 | 500 |
| A | 乙 | 001 | 100 |

这直接决定了后面 Java 代码为什么有两层循环：

```java
for (DealDetail detail : dealDetails) {     // 每家中标供应商
    for (DealProduct product : products) { // 该供应商的每条中标物料
        // 生成一条 ES 报表记录
    }
}
```

### 1.2 产品说的 5 个页面，数据库里其实是一张主表

产品列了：

- 招标管理；
- 询价管理；
- 竞争性谈判；
- 竞争性磋商；
- 单一来源。

它们不是 5 套完全独立的数据。后端统一存在 `sc_source`，用 `purchase_method` 区分：

| 页面 | 枚举 | 库值 |
|---|---|---:|
| 招标 | `BID` | `101` |
| 单一来源 | `SINGLE` | `102` |
| 询价采购 | `COMPARE` | `103` |
| 竞争性谈判 | `COMPETE_NEGOTIATE` | `104` |
| 竞争性磋商 | `COMPETE_CONSULT` | `105` |
| 竞价（本期不要） | `BID_PRICE` | `106` |
| 资格预审（本期不要） | `PQ` | `107` |

证据：`scm-source-source-api/.../PurchaseMethodEnum.java:10-18`。

所以代码没有分别请求 5 个页面接口，而是一次 SQL：

```sql
WHERE purchase_method IN ('101','102','103','104','105')
```

这也是后端和前端思维的一个差异：

- 前端看起来是 5 个菜单；
- 后端看起来是同一张表的一种分类值。

### 1.3 “已公示”为什么不是前端传的 104

产品页面查询时可能传聚合状态 `104`，但业务表 `sc_source.state` 里真正的“已公示”是 `127`：

```java
SourceStateEnum.IS_COMPLETED("127", "已公示")
```

证据：`scm-source-source-api/.../SourceStateEnum.java:27-31`。

当前代码用枚举而不是直接写 `"127"`：

```java
sourceQuery.eq(Source::getState, SourceStateEnum.IS_COMPLETED.getCode());
```

好处是看到 `IS_COMPLETED` 就知道业务含义，不用背魔法数字。

### 1.4 一笔招采业务分成 4 层

```text
sc_source
一条 = 一个已经进入寻源阶段的采购方案
   │ scheme_id
   ▼
sc_deal_result
一条 = 一版定标方案；被拒后可以重做，所以可能有多版
   │ deal_result_id
   ▼
sc_deal_detail
一条 = 一家参与定标的供应商；is_win_bid=1 才是中标供应商
   │ detail_id
   ▼
sc_deal_product
一条 = 这家供应商中标的一条物料
```

对应页面语言：

| 数据表 | 页面/业务语言 | 本报表用它拿什么 |
|---|---|---|
| `sc_source` | 寻源单、采购方案主信息 | 编号、名称、采购企业、板块、公示时间 |
| `sc_scheme` | 采购方案主表 | 是否集采 |
| `sc_deal_result` | 定标方案 | 找最终审批通过的那一版 |
| `sc_deal_detail` | 中标供应商 | 供应商、标段号 |
| `sc_deal_product` | 中标物料 | 物料、类目、该物料含税金额 |

注意这里实际查了 5 张表，因为 `sc_scheme` 是从侧面补“是否集采”；主业务层次仍然是“寻源 → 定标方案 → 中标供应商 → 中标物料”4 层。

### 1.5 进入报表的筛选口径

当前 ZC 代码只取：

```text
寻源状态 = 已公示（sc_source.state = 127）
采购方式 ∈ 101/102/103/104/105
公示时间 final_time 在本次同步区间内
定标方案状态 = 审批通过（sc_deal_result.state = 104）
供应商记录 = 中标（sc_deal_detail.is_win_bid = 1）
```

当前代码**没有**：

- 统计竞价、资格预审；
- 按“采购业务分类”再过滤；
- 限制必须 `is_collection=1`；
- 修改任何 MySQL 原业务数据。

`is_collection=0` 的分散采购也会进入报表，只是展示为“是否集采=否、采购业务类型=分散采购”。这是产品答复后的明确口径。

### 1.6 为什么金额取物料级 `tax_total`

`sc_deal_detail.tax_total` 是供应商级总金额。

`sc_deal_product.tax_total` 是每条物料自己的“含税单价 × 采购数量”，证据在：

```text
scm-source-deal/.../DealProduct.java:244-250
```

报表是一物料一行，所以必须取物料级金额。如果一家供应商中了 3 种物料，却把供应商总金额重复放到 3 行里，Excel 求和会把钱算 3 遍。

当前实现：

```java
model.setTaxTotal(product.getTaxTotal());
```

### 1.7 为什么 ZC 主键比 FP 更长

FP 之前用：

```text
采购业务编号 + 物料编码
```

但招采平台真实存在“同一个方案、同一个物料，被不同供应商分着中标”。2026-07-23 对 test 库只读核实：

```text
9 个符合条件的已公示方案
展开后 11 条中标物料行

方案 12870012-XJ-2026-0001
物料 260101010002
被 3 家供应商分标，共 3 行，金额合计 1070.90
```

如果还用“方案编号 + 物料编码”，这 3 行的 ES ID 相同，后写覆盖先写，最终只剩 1 行。

所以 ZC 使用：

```text
方案编号 + 标段号 + 供应商编码 + 物料编码
```

实现位于 `buildZcId(...)`。

---

## 2. 整套系统模型：先在脑中放一张地图

```text
┌──────────────────── 触发层 ────────────────────┐
│ 人工补数：POST .../syncZc                      │
│ 自动增量：XXL-JOB → AIM → syncZcData(SyncParam)│
└──────────────────────┬─────────────────────────┘
                       ▼
        CentralizedProcurementReportServiceImpl
                       │
        ┌──────────────┼──────────────────────┐
        ▼              ▼                      ▼
   MyBatis Mapper   UBM Feign            ES Repository
   查 5 张 MySQL 表  查板块标准名           saveAll
        │              │                      │
        └──────────────┴────→ 统一 Model ─────┘
                                             ▼
                         index_centralized_procurement_report_*
                                             │
                                             ▼
                             scm-report-all 查询/导出
                                             │
                                             ▼
                             Vue 页面显示 / 下载 Excel
```

### 三条流不要混

| 流 | 从哪到哪 | 本分支的关键点 |
|---|---|---|
| 控制流 | Controller 或 XXL → ServiceImpl | 两种入口最终进入同一个核心方法 |
| 数据流 | MySQL 5 表 → Java 对象 → ES Model → ES | 一家供应商的每条物料生成一条 Model |
| 状态流 | 已公示 + 定标通过 + 中标 | 只读最终有效业务状态，不改状态 |

### 归属边界

| 归属 | 内容 | 本次是否修改 |
|---|---|---|
| 本次新增 | ZC 手动入口、定时能力声明、ZC 抽数实现 | 是 |
| 修改既有代码 | 在 FP 的 Controller/Service/Impl 里追加 ZC | 是，但没有改 FP 核心算法 |
| 项目既有能力 | Model、Repository、配置、Mapper、实体、统一返回体 | 只复用 |
| 公司公共能力 | AIM、XXL 通用入口、Feign 包装、数据字典 | 只复用 |
| 第三方能力 | Spring、MyBatis-Plus、Spring Data Elasticsearch、Lombok | 只复用 |
| 其他仓库 | report 查询导出、Vue 页面 | 当前分支不修改 |

---

## 3. Git 里先看懂“这次改动边界”

不要一上来在 51 个模块里乱搜。先让 IDEA 只告诉你当前分支改了什么。

### 3.1 当前 Git 事实

```text
仓库：01zhaocai-end/scm-source-all
分支：feature/jicai-zc-yang
HEAD：5c917220a
基线：本地 test 和 origin/test 也是 5c917220a
工作区：3 个已修改文件，未提交
规模：新增 345 行、删除 4 行
```

本地还有一个备份分支：

```text
backup/zc-commit-20260723 → 8016ea7a4
```

当前 3 个文件与这个备份提交内容完全一致。备份只是防丢，不代表当前功能已进入 test。

### 3.2 变更时间线

| 版本/时间 | 发生了什么 | 当前是否生效 |
|---|---|---|
| source `5c917220a` | FP 定时入口与分批写入合入 test，也是当前 ZC 分支基线 | 是，当前 test 基线 |
| source `8016ea7a4` | 曾把同一份 ZC 改动做成本地提交，现只由 `backup/zc-commit-20260723` 保存 | 否，不在当前分支和远程 test |
| 当前 `feature/jicai-zc-yang` 工作区 | 从 `5c917220a` 上保留 3 个未提交 ZC 文件 | 只在本机 |
| report `92d5b37` → merge `5007e07` | 集采报表分页和导出进入 report test | 是，分页接口已实调 |
| front `330d28e4` 及后续本地提交 | 集采报表页面存在于本地功能分支 | 未发现进入 `origin/test` 的证据 |

### 3.3 在 IDEA 里怎么确认

1. 打开项目目录：

   ```text
   /home/t/projects/work-wsl/01zhaocai-end/scm-source-all
   ```

2. 如果 IDEA 问“作为项目打开还是附加”，选作为独立项目打开。
3. Project SDK 选 Java 8；这个老项目的 Maven SNAPSHOT 可能让 IDEA 出现与本次无关的红线，不要为了跟读去修全库依赖，也不要跑全量 Maven。本文重新执行过隔离 `javac`，当前需求代码是零错误。
4. 右下角确认 Git 分支显示 `feature/jicai-zc-yang`。
5. 打开底部 `Commit` 窗口；如果没看到，用菜单 `View → Tool Windows → Commit`。
6. 应只看到 3 个文件：

   ```text
   CentralizedProcurementReportController.java
   CentralizedProcurementReportService.java
   CentralizedProcurementReportServiceImpl.java
   ```

7. 双击任一文件，IDEA 会打开左右差异：
   - 左边是 `test@5c917220a` 原代码；
   - 右边是当前工作区；
   - 绿色是本次新增；
   - 灰白部分是以前就有。

第一轮学习尽量从这个 Diff 视图进入。它能防止你把 600 行旧 FP 代码也误认为本次开发。

> 本文没有执行提交、推送、切分支或远程分支操作。

---

## 4. IDEA 第一轮：按请求进入系统的顺序读 3 个改动文件

快捷键按 Windows/Linux IDEA 默认键位写：

| 动作 | 快捷键 |
|---|---|
| 搜类 | `Ctrl+N` |
| 搜文件 | `Ctrl+Shift+N` |
| 当前类方法目录 | `Ctrl+F12` |
| 跳到声明 | `Ctrl+B` |
| 跳到实现 | `Ctrl+Alt+B` |
| 查哪里调用了它 | `Alt+F7` |
| 回到刚才位置 | `Ctrl+Alt+←` |
| 查看 Git 历史 | `Alt+9` |

行号会随以后修改漂移。跟读时优先记“类名 + 方法名”，行号只是本次定位证据。

### 第 1 个文件：Controller——人工同步的“门口”

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/controller/
CentralizedProcurementReportController.java
```

第一遍只看 `42-54` 行：

```java
@PostMapping("e/business/source/centralizedProcurementReport/syncZc")
public Result<String> syncZcToEs(@RequestBody(required = false) DateRangeParam param) {
    int count = centralizedProcurementReportService.syncZcData(
            param != null ? param.getStartTime() : null,
            param != null ? param.getEndTime() : null);
    return Result.success("...写入 " + count + " 条");
}
```

翻译成你熟悉的 Node：

```js
router.post('/e/business/source/centralizedProcurementReport/syncZc', async (req, res) => {
  const count = await service.syncZcData(
    req.body?.startTime ?? null,
    req.body?.endTime ?? null
  )
  res.json(success(`写入 ${count} 条`))
})
```

逐个名词：

- `@RestController`：告诉 Spring 这个类里有 HTTP 接口，近似 Express Router。
- `@PostMapping(...)`：注册 POST 路由。
- `@RequestBody`：把 JSON 请求体转成 Java 对象。
- `required=false`：整个 body 可以不传。
- `Result<String>`：统一返回壳，里面的数据类型是字符串。
- `param != null ? A : B`：Java 三元表达式，和 JS 一样。

`DateRangeParam` 在 `59-80` 行：

- `startTime/endTime` 是 Java `Date`；
- `@JsonFormat` 规定 JSON 日期格式和东八区；
- getter/setter 是框架把 JSON 填进对象时会用的方法。

这个文件**不负责**：

- 查 MySQL；
- 判断已公示；
- 计算金额；
- 写 ES。

它只负责“接参数 → 调 Service → 返回数量”。

跟读动作：

1. 光标放到 `syncZcData`；
2. 按 `Ctrl+B`，进入 Service 接口；
3. 以后想回来按 `Ctrl+Alt+←`。

读完检查：

> 为什么 Controller 很短？因为它只是 HTTP 门口，业务决定放在 ServiceImpl。

### 第 2 个文件：Service 接口——能力清单

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/service/
CentralizedProcurementReportService.java
```

只看 3 块。

#### 第一块：整个能力组的名字

`15` 行：

```java
@TypeMapping("centralizedProcurementReportService")
```

这是公司 AIM 公共能力登记的“服务名”。XXL-JOB 不是直接按 Java 文件路径找方法，而是按这个名字定位。

#### 第二块：定时入口

`40-47` 行：

```java
@MethodMapping("syncZcData")
int syncZcData(SyncParam param);
```

它给 XXL-JOB/AIM 用。`SyncParam` 里的日期先是字符串。

#### 第三块：手动入口

`49-58` 行：

```java
int syncZcData(Date startTime, Date endTime);
```

它给 Controller 用。Controller 已经把 JSON 日期转成 `Date`。

两个方法名字一样、参数不同，叫“方法重载”：

```text
syncZcData(SyncParam)
syncZcData(Date, Date)
```

Java 会根据调用时传了几个参数、参数是什么类型，决定走哪一个。

两条路最后汇合：

```text
XXL-JOB
  → syncZcData(SyncParam)
  → 解析字符串
  ┐
  ├→ syncZcData(Date, Date) → 唯一核心算法
  │
Controller ──────────────────┘
```

为什么不把算法复制两份？因为两份以后容易一份改了、一份忘改。

接口本身只有“能做什么”，没有“怎么做”。在 `syncZcData(Date, Date)` 上按 `Ctrl+Alt+B`，选择：

```text
CentralizedProcurementReportServiceImpl
```

这相当于 TypeScript 的：

```ts
interface Service {
  syncZcData(...): number
}
```

但类比边界是：Java 这里还结合了 Spring 和 AIM 的运行时装配，不只是类型检查。

### 第 3 个文件：ServiceImpl——真正干活的核心

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/service/impl/
CentralizedProcurementReportServiceImpl.java
```

这是 631 行的大文件，但本次不要从第 1 行顺读到第 631 行。按下面 7 站读。

#### 第 1 站：手上有哪些“查库工具”

看 `49-82` 行。

```java
@Service
public class ...ServiceImpl implements ...Service
```

- `@Service`：让 Spring 创建并管理这个业务对象。
- `implements`：这个类负责实现上一文件的能力清单。

本次新增注入了 5 个 Mapper：

| Java 字段 | 查哪张表 | 业务作用 |
|---|---|---|
| `sourceMapper` | `sc_source` | 找已公示采购方案 |
| `schemeMapper` | `sc_scheme` | 补是否集采 |
| `dealResultMapper` | `sc_deal_result` | 找审批通过的最终定标方案 |
| `dealDetailMapper` | `sc_deal_detail` | 找中标供应商、标段 |
| `dealProductMapper` | `sc_deal_product` | 找中标物料和物料金额 |

`@Autowired` 叫依赖注入：

```text
你只声明“我需要 SourceMapper”
→ Spring 启动时找到对应对象
→ 自动放进 sourceMapper 字段
→ 业务方法可直接调用
```

它有点像 Node 的 `import db from './db'`，但区别是实例创建、生命周期和关联关系由 Spring 容器管理。

#### 第 2 站：常量把产品范围固定下来

看 `89-122` 行。

```java
private static final String DATA_SOURCE_ZC = "ZC";
```

写进 ES 的来源编码固定为 `ZC`。

```java
private static final List<String> ZC_PURCHASE_METHODS = Arrays.asList(...);
```

这里把产品确认的 5 种采购方式固定下来，没有竞价和资格预审。

```java
QUERY_BATCH_SIZE = 500;
SAVE_BATCH_SIZE = 1000;
```

- 查 MySQL 时每批最多 500 个 ID，避免 SQL 的 `IN (...)` 太长；
- 写 ES 时每批最多 1000 条，避免一次请求太大。

现在对 `PurchaseMethodEnum.BID` 按 `Ctrl+B`，你会看到 `BID("101","招标",3)`。这就是从业务名称追到真实库值的方式。

#### 第 3 站：定时入口只做参数转换

用 `Ctrl+F12` 搜：

```text
syncZcData(SyncParam)
```

看 `274-284` 行：

```java
startTime = parseDate(param.getStartTime());
endTime = parseDate(param.getEndTime());
return syncZcData(startTime, endTime);
```

这里没有查库。它只把字符串日期转成 `Date`，然后转给真正的核心方法。

#### 第 4 站：决定同步哪段时间

进入：

```text
syncZcData(Date startTime, Date endTime)
```

看 `286-308` 行：

| 入参 | 实际范围 |
|---|---|
| 两个都不传 | 昨天 00:00:00.000 ～ 23:59:59.999 |
| 只传开始 | 开始日期那一整天 |
| 只传结束 | 结束日期那一整天 |
| 两个都传 | 原样使用 |

注意：

> 产品要求“从 2026-01-01 起”没有硬编码进方法。历史补数时必须由调用者传 `2026-01-01`；这段代码只负责尊重传入范围，日常空参数则扫昨天。

#### 第 5 站：找有资格进入报表的寻源单

看 `310-332` 行：

```java
LambdaQueryWrapper<Source> sourceQuery = Wrappers.lambdaQuery();
sourceQuery.eq(Source::getState, SourceStateEnum.IS_COMPLETED.getCode());
sourceQuery.in(Source::getPurchaseMethod, ZC_PURCHASE_METHODS);
sourceQuery.ge(Source::getFinalTime, actualStartTime);
sourceQuery.le(Source::getFinalTime, actualEndTime);
List<Source> sources = sourceMapper.selectList(sourceQuery);
```

近似 SQL：

```sql
SELECT *
FROM sc_source
WHERE state = '127'
  AND purchase_method IN ('101','102','103','104','105')
  AND final_time >= :startTime
  AND final_time <= :endTime
  AND delete_sign = 0;
```

`delete_sign=0` 没在业务代码里手写，因为启动模块的 MyBatis-Plus 全局配置指定：

```text
logic-delete-field: deleteSign
logic-delete-value: 1
```

证据：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/src/main/resources/bootstrap.yml:29-30`。

几个 Java 语法点：

- `Source::getState` 是方法引用，告诉查询构造器对应哪个实体字段；
- `eq` 是等于；
- `in` 是 SQL `IN`；
- `ge/le` 是大于等于/小于等于；
- `selectList` 才真正执行查询；
- `sources` 是查回来的寻源单列表。

如果 `sources` 为空，方法直接 `return 0`，不会继续查后面的表，更不会写 ES。

#### 第 6 站：把 4 层关系批量拼起来

这部分是业务核心，按小段读。

1. `324-332`：从寻源单提取不重复的 `schemeId`。
2. `334-335`：批量查 `sc_scheme.is_collection`，做成：

   ```text
   schemeId → 是否集采
   ```

3. `337-343`：找每个方案“审批通过且创建时间最新”的定标方案。
4. `345-365`：按定标方案 ID 批量查中标供应商，只要 `is_win_bid=1`。
5. `367-387`：按供应商明细 ID 批量查中标物料。
6. `389-395`：把列表转换成两个内存索引：

   ```text
   detailId → 该供应商的物料列表
   schemeId → 寻源主单
   ```

为什么要 `Map`？

假设有 1000 条中标供应商记录。如果每处理一家供应商都再查一次寻源单和物料，数据库会被调用上千次，这叫 N+1。

现在的做法是：

```text
先批量查完
→ 在内存里建 Map
→ 用 key 直接找到对应数据
```

接近 Node 写法：

```js
const sourceMap = new Map(sources.map(item => [item.schemeId, item]))
const productMap = groupBy(products, item => item.dealDetailId)
```

`stream()` 先理解成“对数组做链式处理”即可：

| Java Stream | JS 数组近似写法 |
|---|---|
| `.map(Source::getSchemeId)` | `.map(x => x.schemeId)` |
| `.filter(...)` | `.filter(...)` |
| `.distinct()` | `new Set(...)` |
| `.collect(toList())` | 收集回数组 |
| `.collect(groupingBy(...))` | `groupBy(...)` |

类比边界：Java Stream 有泛型、惰性中间操作和终止操作，不等同于 JS Array，但本方法里可以先这样读。

#### 第 7 站：一条物料变成一条 ES 文档

看 `397-471` 行。

先查一次板块字典：

```java
Map<String, String> buNameMap = queryOwningplateDictMap();
```

然后两层循环：

```java
for (DealDetail detail : dealDetails) {
    Source source = sourceMap.get(detail.getSchemeId());
    List<DealProduct> products = productMap.get(detail.getDetailId());

    for (DealProduct product : products) {
        CentralizedProcurementReportModel model =
                new CentralizedProcurementReportModel();
        // set 字段
        models.add(model);
    }
}
```

最后分批写入：

```java
centralizedProcurementReportRepository.saveAll(saveBatch);
```

这行才是真正发生 ES 写入的地方。

核心方法用 Node 风格重写后是：

```js
async function syncZcData(startTime, endTime) {
  const range = normalizeDateRange(startTime, endTime)

  const sources = await sourceMapper.find({
    state: '127',
    purchaseMethodIn: ['101', '102', '103', '104', '105'],
    finalTimeBetween: range
  })
  if (!sources.length) return 0

  const schemeIds = unique(sources.map(x => x.schemeId).filter(Boolean))
  const collectionMap = await queryCollectionMap(schemeIds)
  const latestPassedDealResultMap = await queryLatestPassedDealResult(schemeIds)

  const winningSuppliers = await queryDealDetails({
    dealResultIds: [...latestPassedDealResultMap.values()].map(x => x.id),
    isWinBid: 1
  })

  const products = await queryProducts(
    winningSuppliers.map(x => x.detailId)
  )

  const sourceMap = keyBy(sources, 'schemeId')
  const productMap = groupBy(products, 'dealDetailId')
  const buNameMap = await queryOwningplateDictMap()

  const documents = []
  for (const supplier of winningSuppliers) {
    const source = sourceMap[supplier.schemeId]
    for (const product of productMap[supplier.detailId] || []) {
      documents.push({
        id: buildZcId(
          source.schemeCode,
          supplier.tenderNum,
          supplier.supplierCode,
          product.productCode
        ),
        buCode: source.buCode,
        buName: standardBuName(buNameMap, source),
        purchaseCompanyName: source.purchaseCompanyName,
        purchaseCompanyCode: source.purchaseCompanyCode,
        supplierName: supplier.supplierName,
        supplierCode: supplier.supplierCode,
        planCode: source.schemeCode,
        planName: source.schemeName,
        materialCode: product.productCode,
        materialName: product.productDesc,
        categoryCode: product.categoryCode,
        categoryName: product.categoryName,
        taxTotal: product.taxTotal,
        bookTime: source.finalTime,
        isCentralized: collectionMap[supplier.schemeId],
        purchaseType:
          collectionMap[supplier.schemeId] === 1 ? '集团集采' : '分散采购',
        dataSource: 'ZC'
      })
    }
  }

  await esRepository.saveAllInBatches(documents, 1000)
  return documents.length
}
```

读完这个文件，你应该能说：

> “先按已公示、5 种采购方式和公示时间查寻源单；再批量找到采购方案、最新审批通过的定标方案、中标供应商和中标物料；把一家供应商的一条物料翻译成一条统一 ES Model；最后分批 saveAll。”

---

## 5. IDEA 第二轮：顺着 `Ctrl+B` 看支撑文件

第一轮主线说顺后，再打开这些文件。它们不是本分支新建的，但解释了“字段从哪来、为什么不用手写 SQL、ES 为什么会写进去”。

### 第 4 个文件：Source——寻源主表实体

从 `Source::getFinalTime` 按 `Ctrl+B`，打开：

```text
scm-source-source/src/main/java/com/pcitc/scm/source/source/model/Source.java
```

重点定位：

| 代码位置 | 含义 |
|---|---|
| `28` | `@TableName("sc_source")`，说明这个类映射主表 |
| `62-72` | `schemeId/schemeCode/schemeName` |
| `98-104` | 采购方式 |
| `178-184` | 状态 |
| `206-216` | 采购企业编码/名称 |
| `412-418` | 板块编码/原始名称 |
| `428-430` | 公示最终时间 `final_time` |

`@Data` 来自 Lombok。你在源码里找不到 `getFinalTime()` 的手写正文，因为编译时自动生成。

### 第 5 个文件：Scheme——补“是否集采”

打开：

```text
scm-source-scheme/src/main/java/com/pcitc/scm/source/scheme/model/Scheme.java
```

只看：

```text
29：@TableName("sc_scheme")
35-40：schemeId、schemeCode
524-530：is_collection、purchase_business_type
```

本期只用 `is_collection`，不拿 `purchase_business_type` 做过滤。

### 第 6 个文件：DealResult——为什么要选最新通过版本

打开：

```text
scm-source-deal/src/main/java/com/pcitc/scm/source/deal/model/DealResult.java
```

只看：

```text
24：表 sc_deal_result
30-44：dealResultId、schemeId
170-180：状态、审批完成时间
190-192：创建时间
```

状态枚举在：

```text
scm-source-deal-api/.../DealStateEnum.java:9-14
```

`PASSED("104","审批通过")`。

同一采购方案可能有被拒版本和重做版本。`queryLatestPassedDealResult` 的规则是：

```text
先只留审批通过
→ 同一 schemeId 再按 createTime 取最新
```

### 第 7 个文件：DealDetail——一家中标供应商

打开：

```text
scm-source-deal/src/main/java/com/pcitc/scm/source/deal/model/DealDetail.java
```

重点：

```text
30：表 sc_deal_detail
36-50：detailId、dealResultId、schemeId
56-62：supplierCode、supplierName
84-86：isWinBid
152-154：tenderNum 标段号
```

不要把 `DealDetail` 翻译成“物料明细”。在这个项目里它实际是一家供应商层；真正物料在下一张表。

### 第 8 个文件：DealProduct——一条中标物料

打开：

```text
scm-source-deal/src/main/java/com/pcitc/scm/source/deal/model/DealProduct.java
```

重点：

```text
29：表 sc_deal_product
35-53：主键、所属供应商明细、物料编码、物料描述
244-250：含税单价、含税总价 taxTotal
276-282：类目编码、类目名称
```

这里能直接拿类目编码，不需要再按类目名称调 MDM 接口。

### 第 9 个文件：Model——ES 的统一字段合同

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/model/
CentralizedProcurementReportModel.java
```

它不负责查数据，只规定“一条 ES 文档长什么样”。

关键注解：

```java
@Document(indexName = "#{@sourceChaseConfig.getCentralizedProcurementReportIndex()}")
```

含义：

```text
索引名不写死
→ 运行时从 sourceChaseConfig 取
→ sourceChaseConfig 再从 Nacos/Spring 配置取
```

```java
@Id
private String id;
```

`id` 是 ES 文档主键。相同 ID 再次 `saveAll` 会覆盖原文档，而不是多插一条，这就是同步能重复跑的基础。

```java
@Field(type = FieldType.Keyword/Text/Date/Double/Integer)
```

定义 ES 类型：

- `Keyword`：整体精确匹配，例如编码；
- `Text`：分词搜索，例如企业名称；
- `Date`：时间范围；
- `Double`：金额；
- `Integer`：是否集采。

注意一个旧注释：

```text
Model.java:19 写“id = 采购业务编号 + 物料编码”
```

它只准确描述 FP，已经不能完整描述 ZC。ZC 的真实主键以 `ServiceImpl.buildZcId(...)` 为准。读代码时要区分“注释”和“实际执行语句”。

### 第 10 个文件：Repository——为什么空接口也能写 ES

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/repositories/
CentralizedProcurementReportRepository.java
```

它只有：

```java
extends ElasticsearchRepository<CentralizedProcurementReportModel, String>
```

两个泛型参数：

```text
CentralizedProcurementReportModel：存什么对象
String：主键是什么类型
```

Spring Data Elasticsearch 自动提供 `saveAll`，所以项目里看不到这段方法的手写实现。

它近似 Mongoose Model 自带的 `save`，但边界是这里由 Spring Data Repository 代理生成，不是 Mongoose。

### 第 11 个文件：Config——索引名从哪里来

打开：

```text
scm-source-chase/src/main/java/com/pcitc/scm/source/chase/config/
SourceChaseConfig.java
```

重点：

```java
@ConfigurationProperties(prefix = "source.chase.es")
private String centralizedProcurementReportIndex;
```

配置链：

```text
Nacos:
source.chase.es.centralizedProcurementReportIndex
        ↓
SourceChaseConfig.centralizedProcurementReportIndex
        ↓ Lombok @Data 生成 getter
getCentralizedProcurementReportIndex()
        ↓
Model 的 @Document
        ↓
真正 ES 索引
```

`SourceWebConfig` 还会注册这个配置 Bean，并扫描 Controller/Service/Mapper：

```text
scm-source-web-jar/src/main/java/com/pcitc/scm/source/webconfig/SourceWebConfig.java
```

这是项目既有启动装配，不是本次新写。

---

## 6. 页面 15 列背后的 18 个 ES 字段怎样落地

页面的序号由前端自动生成，不存 ES。其余字段映射如下：

| 报表字段 | ES 字段 | MySQL 来源/规则 | 代码位置 |
|---|---|---|---|
| 板块名称 | `buName` | `bu_code` 查 `Owningplate` 字典；失败回退原 `bu_name` | Impl `419-421`、`556-577` |
| 板块编码 | `buCode` | `sc_source.bu_code` | Impl `420` |
| 采购企业 | `purchaseCompanyName` | `sc_source.purchase_company_name` | Impl `423-425` |
| 采购企业编码 | `purchaseCompanyCode` | `sc_source.purchase_company_code` | Impl `425` |
| 供应商 | `supplierName` | `sc_deal_detail.supplier_name` | Impl `427-429` |
| 供应商编码 | `supplierCode` | `sc_deal_detail.supplier_code` | Impl `429` |
| 采购方案/订单编号 | `planCode` | `sc_source.scheme_code` | Impl `431-433` |
| 业务名称 | `planName` | `sc_source.scheme_name` | Impl `433` |
| 物料编码 | `materialCode` | `sc_deal_product.product_code` | Impl `435-437` |
| 物料描述 | `materialName` | `sc_deal_product.product_desc` | Impl `437` |
| 类目编码 | `categoryCode` | `sc_deal_product.category_code` | Impl `438` |
| 类目描述 | `categoryName` | `sc_deal_product.category_name` | Impl `439` |
| 交易金额（含税） | `taxTotal` | 该物料 `sc_deal_product.tax_total` | Impl `441-442` |
| 公示/下单时间 | `bookTime` | `sc_source.final_time` | Impl `444-445` |
| 是否集采 | `isCentralized` | `sc_scheme.is_collection` | Impl `447-449` |
| 采购业务类型 | `purchaseType` | 1 → 集团集采；其他 → 分散采购 | Impl `449`、`549-551` |
| 数据来源 | `dataSource` | 固定 `ZC` | Impl `451-452` |
| ES 主键（页面不展示） | `id` | 方案 + 标段 + 供应商 + 物料 | Impl `415-417`、`526-535` |

板块名为什么多绕一步？

```text
主表 bu_name 可能是“冀东水泥”“冀东集团”甚至空
bu_code 比较稳定
→ 用 bu_code 查字典
→ ES 存统一标准名，如“水泥集团”
```

这让页面下拉筛选和列表展示不会各说各话。

---

## 7. 手动和定时两条触发链

### 7.1 手动补数

```text
POST e/business/source/centralizedProcurementReport/syncZc
Body:
{
  "startTime": "2026-01-01 00:00:00",
  "endTime": "2026-07-23 23:59:59"
}
```

调用链：

```text
Controller.syncZcToEs
→ Service.syncZcData(Date, Date)
→ ServiceImpl.syncZcData(Date, Date)
```

用途：

- 首次历史补数；
- 指定某一天补跑；
- 部署后小时间窗口验收。

### 7.2 每天自动增量

预期链：

```text
XXL-JOB simpleJobHandler
→ AIM 根据 @TypeMapping 找到 centralizedProcurementReportService
→ 根据 @MethodMapping 找到 syncZcData
→ ServiceImpl.syncZcData(SyncParam)
→ ServiceImpl.syncZcData(Date, Date)
```

空参数 `{}` 最终同步昨天。

公司公共 XXL 入口用 `-` 分割任务参数，而日期 `2026-07-23` 自身含 `-`，所以：

- 日常任务只传 `{}`；
- 指定日期走手动 HTTP；
- 不要把带日期的 JSON 直接塞进任务参数。

当前分支只是准备好了 Java 定时入口。XXL-JOB 管理台是否已新增 ZC 任务，本轮没有运行证据，不能写成已完成。

---

## 8. 失败、幂等、回滚：这段代码出问题时会怎样

### 8.1 哪些情况会正常返回 0

代码在这些节点主动停止：

- 时间范围没有已公示寻源单；
- 寻源单没有 `schemeId`；
- 没有审批通过的定标方案；
- 没有中标供应商；
- 没有中标物料；
- 最终没拼出任何 Model。

这类返回 0 不一定是程序坏了，可能只是当天没有符合口径的数据。

### 8.2 重跑为什么通常不重复

同一业务行会得到相同 `buildZcId(...)`：

```text
方案编号 + 标段号 + 供应商编码 + 物料编码
```

`saveAll` 遇到同 ID 会覆盖，所以同一时间范围重跑，正常情况下 ES 总数不增加。

### 8.3 当前主键的边界

当前实现是直接拼接，没有分隔符；任何一段为 null 时按空字符串处理。

这符合本期确认方案，但要知道边界：

- 代码不拦截空供应商编码、空物料编码；
- 不同长度字段理论上可能形成相同拼接字符串；
- 当前没有数据库/ES 侧的额外碰撞校验。

这不是本轮擅自改动项。未来若真实出现覆盖，应先和产品/公共 Model 负责人确认，再统一调整 ID 合同。

### 8.4 板块字典服务失败

`queryOwningplateDictMap()` 调 UBM Feign。

如果返回失败或空：

- 不会因为字典空就停止整个同步；
- `resolveBuName` 会回退到 `sc_source.bu_name`；
- 数据可能写入，但板块名可能是旧脏名称。

所以“接口成功写入 N 条”还不够，验收时必须抽查板块名。

### 8.5 日期写错的边界

`parseDate` 解析失败时记录错误日志并返回 null。

如果两个日期最后都变成 null，核心方法会改为同步昨天。这意味着错误日期不一定让接口失败，可能意外扫昨天。人工补数时要核对日志里的：

```text
实际查询时间范围(公示时间 final_time)
```

### 8.6 ES 批量写入中途失败

代码每 1000 条调用一次 `saveAll`，MySQL 全程只读，没有跨 MySQL + ES 的分布式事务。

如果第 2 批写失败：

- 第 1 批可能已经在 ES；
- 后续批次没写；
- 接口会抛异常，而不是自动整体回滚。

恢复方式是修复外部问题后重跑同一时间范围。稳定 ID 会覆盖已成功批次，并补上失败批次。

### 8.7 回退这个分支会发生什么

因为当前 3 个文件未提交、未部署：

- 放弃当前工作区只会放弃 ZC 新代码；
- 不会删除 MySQL 数据；
- 不会自动删除 ES 已有 FP 或其他写入者的数据；
- FP、report 查询和已有页面能力不属于这 3 个未提交文件。

未经用户明确要求，不要执行清理工作区、删除 ES 文档等动作。

---

## 9. 读侧只需看懂边界，不要和当前 3 文件混在一起

### 9.1 report 后端

仓库：

```text
01zhaocai-end/scm-report-all
```

当前本地 `test@5007e07` 已包含：

```text
POST e/business/report/source/centralizedProcurementPageList
POST e/business/report/source/centralizedProcurementDownload
```

可选跟读：

1. `SourceMetaQueryController.java:280-323`：分页和下载 HTTP 门口。
2. `SourceMetaQueryServiceImpl.java:1618-1680`：企业、供应商、板块、时间和数据权限查询 ES。
3. `SourceMetaQueryServiceImpl.java:1682` 以后：复用查询结果生成 Excel。
4. `CentralizedProcurementReportMetaModel.java`：report 侧自己的只读 Model。

source 和 report 没有共用同一个 Java Model 文件。它们能协作靠的是：

```text
同一个物理索引
+ 相同字段名
+ 相同字段类型
```

这叫数据合同。

### 9.2 Vue 页面

仓库：

```text
02zhaocai-front/scm-vue-all-procurementscheme
```

本地功能分支页面：

```text
src/views/reportForms/centralizedProcurementReport/index.vue
```

可选跟读：

| 位置 | 看什么 |
|---|---|
| `1-65` | 查询表单、表格、导出按钮 |
| `72-78` | `ZC/FP/YC/MT/JD` 转中文 |
| `101-145` | 表格列 |
| `153-169` | 板块字典 |
| `171-207` | 组参数、调分页接口 |
| `230-235` | 调下载接口 |
| `router/index.js:463-465` | 固定页面路由 |

前端不懂 5 张 MySQL 表，也不做定标逻辑。它只把筛选条件交给 report，再展示统一 ES 字段。

---

## 10. 本次核实到的运行证据

### 10.1 数据库证据

2026-07-23 对 `scm_source_test` 只读查询：

| 检查 | 结果 |
|---|---:|
| `2026-01-01` 起、已公示、指定 5 种采购方式的寻源单 | 9 |
| 取最新通过定标方案、中标供应商并展开物料 | 11 行 |
| 同方案同物料分给多供应商 | 1 组，展开 3 行 |
| 该 3 行含税金额合计 | 1070.90 |

这证明：

- 一方案不等于一行；
- 一物料也不一定只有一家供应商；
- ZC 主键必须包含供应商/标段维度。

### 10.2 编译证据

按项目规定使用隔离 `javac`，显式编译：

- 3 个当前改动文件；
- 既有 Model/Repository；
- Lombok 实体 `Source/Scheme/DealResult/DealDetail/DealProduct` 等。

结果：

```text
javac 退出码：0
error 条数：0
```

这证明当前源码在已有依赖下语法、类型和方法引用成立；不等于已经部署运行。

### 10.3 ES 和 API 证据

当前 test 索引：

```text
index_centralized_procurement_report_test
总数 7
FP 5
ZC 2
```

mapping 的 18 个字段类型与 Model 一致，`bookTime` 是：

```text
date_optional_time||epoch_millis
```

当前 report 分页接口已真实返回：

```text
status=true
totalCount=7
```

但当前 2 条 ZC 的 ID 形如：

```text
PO..._P...
```

本分支的 ID 应是：

```text
方案编号 + 标段号 + 供应商编码 + 物料编码
```

且本分支仍未提交，所以这 2 条 ZC 一定不能作为当前分支运行成功的证据。部署前需要确认它们由哪个服务写入、来源编码是否按公共合同使用。

---

## 11. 设计取舍、已知边界和待确认项

| 主题 | 当前事实 | 为什么这样做 | 边界/下一步 |
|---|---|---|---|
| 报表粒度 | 一中标供应商的一物料一行 | 页面需要供应商、物料、明细金额同时可统计 | 不能改成一方案一行 |
| 查询 5 个页面 | 查同一 `sc_source` 的 5 个枚举值 | 页面只是同表不同采购方式 | 不含竞价、资格预审 |
| 定标版本 | 审批通过中取 `create_time` 最新 | 被拒后可重做 | 若业务以后以 `approve_time` 判最终版，要重新确认 |
| 金额 | `DealProduct.taxTotal` | 防止供应商总额在每条物料上重复 | 与产品 Excel 框选字段一致 |
| 板块名称 | 编码查字典，失败回退原名 | 主表名称不统一 | 字典异常时仍可能写脏名 |
| 主键 | 方案 + 标段 + 供应商 + 物料 | 防同物料多供应商覆盖 | 无分隔符、null 兜底为空 |
| 同步日期 | `final_time` | 产品展示和筛选都是公示时间 | 公示后改定标明细不会因修改时间再次被扫 |
| 起算日 | 调用时传 2026-01-01 | 方便补任意时间 | 代码没有硬性下限 |
| 事务 | MySQL 只读、ES 分批写 | 跨系统不做大事务 | 中途失败可能部分成功，靠幂等重跑 |
| Model 注释 | 仍只写 FP 主键说明 | 历史遗留 | 学习时以 `buildZcId` 为准；以后可做小修正 |
| 当前 ES 的 2 条 ZC | 已存在，但不是本分支写入证据 | 写入者尚未定位 | 部署前查清所有权和来源编码 |
| MT/JD/YC | 当前分支未实现 | 需求资料/分工不在本次代码 | 不要对外说五路已完成 |

如果要向同事确认现有 2 条 ZC，逐字话术：

> 我这边准备部署招采平台 ZC 的同步代码，但 test 的 `index_centralized_procurement_report_test` 里已经有 2 条 `dataSource=ZC`，ID 是 `PO..._P...`，和我这边“方案编号+标段号+供应商编码+物料编码”的规则不同。麻烦确认一下这两条是哪个服务、哪个来源写的，以及 `ZC` 是否仍固定代表招采平台，避免两边把不同来源写成同一个编码。

---

## 12. Java 新手概念卡

### `class`

- 大白话：一类对象的结构和行为。
- 类比：JS 的 class/module。
- 边界：Java 的 public class 通常必须放在同名 `.java` 文件。

### `interface` + `implements`

- 大白话：interface 先列能力，implements 的类写真正实现。
- 类比：TypeScript interface + class。
- 本链路：`CentralizedProcurementReportService` + `...ServiceImpl`。

### 注解 `@Xxx`

- 大白话：贴在类、方法、字段上的框架标签。
- 例子：`@PostMapping` 注册路由，`@Service` 注册业务对象，`@TableName` 映射表。
- 边界：注解本身通常不写业务算法，而是被 Spring/MyBatis 等框架读取。

### Mapper

- 大白话：MySQL 数据访问入口。
- 类比：ORM 的 Model/DAO。
- 本链路：`selectList(queryWrapper)` 执行查询。

### Entity/Model

本项目里“Model”一词容易混：

- `Source/DealDetail/DealProduct` 是 MySQL 实体；
- `CentralizedProcurementReportModel` 是 ES 文档模型；
- 它们字段相似，但目的地不同。

### `List` 和 `Map`

- `List<T>`：有顺序的一批 T，近似 JS Array。
- `Map<K,V>`：按 key 快速找 value，近似 JS Map/普通索引对象。
- 本链路：先批量查成 List，再转 Map，避免循环查库。

### 枚举 `enum`

- 大白话：给固定编码起可读名字。
- 本链路：用 `IS_COMPLETED` 表达 `127`，用 `BID` 表达 `101`。
- 好处：代码直接显示业务意义。

### 方法重载

- 大白话：同名方法用不同参数区分。
- 本链路：定时传 `SyncParam`，手动传两个 `Date`。
- 最终都进同一个核心算法。

### Feign

- 大白话：在 Java 里像调用本地方法一样访问另一个微服务。
- 本链路：去 UBM 服务取板块字典。
- 边界：底层仍是远程调用，可能超时或失败。

### ES Repository

- 大白话：Spring 自动生成的 ES 读写代理。
- 本链路：`saveAll` 批量新增/覆盖文档。
- ES 是报表副本，不是采购业务真身。

### Nacos

- 大白话：公司集中管理 `.env` 的远程配置中心。
- 本链路：不同环境用不同 ES 索引名，不把 `_test` 写死进 Java。

### XXL-JOB + AIM

- XXL-JOB：定时闹钟。
- AIM：按“服务名 + 方法名”把闹钟请求送到正确 Java 方法。
- 当前业务只登记方法，不自己重写调度框架。

---

## 13. 30 秒复述与所有权验收

### 30 秒复述

> “这个分支只增加招采平台 ZC 的写入侧，不是整张报表重做。它先按已公示、5 种采购方式和公示时间从 `sc_source` 找方案，再取 `sc_scheme` 的是否集采、最新审批通过的 `sc_deal_result`、中标的 `sc_deal_detail` 和对应 `sc_deal_product`。报表一行是一家中标供应商的一条物料，金额取物料自己的含税总价，ID 用方案+标段+供应商+物料防覆盖。组装成统一 Model 后分批 saveAll 到 ES，report 和 Vue 再从 ES 查询展示。当前代码编译通过但仍未提交部署，所以不能说 ZC 已上线。”

### IDEA 定位练习

不看答案做一遍：

1. 从 Controller 的 `/syncZc` 跳到 Service，再跳到实现类。
2. 找到真正执行 `sc_source` 查询的 `selectList`。
3. 从 `Source::getFinalTime` 跳到 `Source.java`，指出它对应 `final_time`。
4. 找到“只取审批通过定标方案”的枚举值 `104`。
5. 找到“只取中标供应商”的 `isWinBid=1`。
6. 找到金额为什么是 `DealProduct.taxTotal`，不是 `DealDetail.taxTotal`。
7. 找到两层循环，并说明一供应商 3 物料为什么生成 3 条。
8. 找到真正写 ES 的唯一一行 `saveAll`。
9. 找到 ZC 主键拼接方法，说出为什么需要供应商编码。
10. 指出哪个文件是本次新增逻辑，哪个 Model/Repository 是以前已有。

### 自测题

1. 为什么产品 5 个页面在代码里只查一张 `sc_source`？
2. 前端状态 104 和库里的已公示 127 为什么不能混用？
3. `sc_deal_result` 为什么不能随便取一条？
4. `DealDetail` 和 `DealProduct` 各代表什么粒度？
5. 为什么金额不能取供应商总金额？
6. `Map` 在这里解决了什么性能问题？
7. Controller 和 XXL-JOB 有什么不同，又在哪里汇合？
8. 同一范围重跑为什么通常不新增重复行？
9. 接口返回写入 0 条，为什么不一定是错误？
10. 为什么 ES 已有 ZC 数据仍不能证明这个分支部署成功？

前 6 题能顺口回答，说明业务和核心代码已读懂；10 题都能回答，说明你已经具备和 Java 同事讨论这次改动的最低维护能力。

---

## 14. 最短跟读清单

如果只拿 30 分钟，就按这个顺序：

1. 看本文第 1 章，先懂“一供应商的一物料一行”。
2. IDEA Commit/Diff 确认只有 3 个文件。
3. Controller 只看 `syncZcToEs`。
4. Service 只看两个 `syncZcData`。
5. ServiceImpl 只看：

   ```text
   89-102   来源和 5 种采购方式
   274-308  两种入口和日期
   310-398  查表并建 Map
   400-471  拼 Model 并写 ES
   477-535  三个关键辅助方法
   ```

6. 用 `Ctrl+B` 依次跳 `Source → Scheme → DealResult → DealDetail → DealProduct`。
7. 最后看 Model 的 `@Id/@Document` 和 Repository 的 `saveAll` 来源。
8. 合上文档，讲一遍第 13 章的 30 秒复述。

第一轮不要钻 import、Swagger 注解、所有 getter/setter，也不要试图通读 51 个 Maven 模块。先抓住：

```text
定时间
→ 查有资格的方案
→ 找最终中标结果
→ 展开到供应商的物料行
→ 翻译公共字段
→ 写 ES
```

这就是本次开发真正的主干。

---

## 15. 新增“数据来源”查询条件：你亲手开发的逐步教程

> 本章新增于 2026-07-23。目标不是让我代写，而是让你亲手完成一次范围清楚、可以独立验证的前端小改。
>
> 执行更新：用户随后改为由 AI 直接实施。前端已完成 19 行新增、1 行调整，本地提交为 `3f4b85de feat: 增加数据来源查询`；`npm run build` 退出码 0，test 六组来源请求结果与本章预期一致。当前未推送、未部署；分支历史中的 `3cc5230c 配置token` 必须先清理，不能直接推远程。

### 15.1 先给结论：这次不用改后端，只改一个前端文件

你问“是不是前后端都得改”，以当前代码和 test 实测为准，答案是：

> **不用再改后端。后端分页查询和 Excel 导出已经完整支持 `dataSource`，本次只需要给前端补上下拉框、查询状态和重置逻辑。**

改动范围只有：

```text
仓库：
02zhaocai-front/scm-vue-all-procurementscheme

文件：
src/views/reportForms/centralizedProcurementReport/index.vue
```

下面这些文件本次只读、不改：

| 仓库/文件 | 已有能力 | 证据 |
|---|---|---|
| report `CentralizedProcurementReportMetaModel.java` | 已有 `dataSource` 请求字段，类型为 `keyword` | `97-99` 行 |
| report `SourceMetaQueryServiceImpl.java` | 参数有值时对 ES 增加精确筛选 | `1648-1651` 行 |
| report `SourceMetaQueryServiceImpl.java` | 导出复用同一个分页查询方法，所以筛选自动影响 Excel | `1682-1688` 行 |
| report `SourceMetaQueryServiceImpl.java` | 导出时把 5 个编码转换成中文 | `1758-1775` 行 |
| front 当前页面 | 表格已经把 5 个编码转换成中文展示 | `72-78`、`138-144` 行 |

2026-07-23 用当前 test 分页接口只读实测：

| 请求里的 `model.dataSource` | `totalCount` | 结论 |
|---|---:|---|
| 不传 | 7 | 不选就是全部 |
| `ZC` | 2 | 后端已能筛招采平台 |
| `FP` | 5 | 后端已能筛非平台录入 |
| `YC` | 0 | 筛选生效，只是该来源目前还没有数据 |
| `MT` | 0 | 筛选生效，只是该来源目前还没有数据 |
| `JD` | 0 | 筛选生效，只是该来源目前还没有数据 |

所以本次不是“设计一套新查询”，而是把后端已有能力接到页面上。

### 15.2 先看懂完整参数链

你这次要接通的是这一条很短的链：

```text
用户在下拉框选“招采平台”
        ↓
queryList.dataSource = "ZC"
        ↓
buildQueryParams() 把整个 queryList 放进请求的 model
        ↓
POST centralizedProcurementPageList
        ↓
Java 的 param.getDataSource() 得到 "ZC"
        ↓
termQuery("dataSource", "ZC")
        ↓
ES 只返回 dataSource=ZC 的文档
```

用你熟悉的 Node 写法类比，后端已有逻辑近似：

```js
if (model.dataSource) {
  esQuery.must({ term: { dataSource: model.dataSource } })
}
```

这里必须传编码，不传中文：

| 页面显示 | 请求值 |
|---|---|
| 招采平台 | `ZC` |
| 非平台录入 | `FP` |
| 云采平台 | `YC` |
| 煤炭-SAP | `MT` |
| 机电四大类 | `JD` |

为什么“不选就是全部”不用额外增加一个“全部”编码？

```text
下拉框未选/被清空
→ dataSource 是 undefined
→ JSON 请求不带这个字段
→ 后端不添加 dataSource 过滤条件
→ ES 返回当前账号权限内的全部来源
```

不要向后端传 `"ALL"`、`"全部"` 或空格；当前合同里没有这些编码。

### 15.3 开工前先确认位置，别进错前端项目

在 WSL 终端执行：

```bash
cd /home/t/projects/work-wsl/02zhaocai-front/scm-vue-all-procurementscheme
git status --short --branch
```

当前应看到分支：

```text
features/jicai-report-yang
```

本地 `public/statics/config.js` 已经有一处与本需求无关的敏感配置修改。你本次不要打开、修改或提交它，后面也不要使用 `git add .`。

在 IDEA 中打开正确项目：

```text
/home/t/projects/work-wsl/02zhaocai-front/scm-vue-all-procurementscheme
```

然后用 `Ctrl+Shift+N` 搜索：

```text
centralizedProcurementReport/index.vue
```

如果打开的文件路径里出现 `scm-vue-all-productmgt`，说明进错项目了，立刻停下。

### 15.4 第一步：在查询表单增加下拉框

当前文件 `1-45` 行是查询表单。找到“供应商名称”这一块和下面的查询/重置按钮。

把这一段整理成下面的结构：

```vue
<a-col class="gutter-row" :span="6">
  <a-form-model-item label="供应商名称" prop="supplierName">
    <a-input v-model.trim="queryList.supplierName" placeholder="请输入" />
  </a-form-model-item>
</a-col>

<a-col class="gutter-row" :span="6">
  <a-form-model-item label="数据来源" prop="dataSource">
    <a-select v-model="queryList.dataSource" placeholder="请选择" allow-clear>
      <a-select-option
        v-for="item in dataSourceOptions"
        :key="item.value"
        :value="item.value"
      >
        {{ item.label }}
      </a-select-option>
    </a-select>
  </a-form-model-item>
</a-col>

<a-col class="gutter-row" :span="18" style="text-align:right;line-height:50px;">
  <a-button type="primary" icon="search" @click="getSearchQuery">查询</a-button>
  <a-button type="primary" style="margin-left:20px;" ghost icon="undo" @click="getReload">
    重置
  </a-button>
</a-col>
```

这里有两处真正的变化：

1. 新增一个 `span=6` 的“数据来源”下拉框。
2. 原按钮区的 `span` 从 `24` 改成 `18`。

Ant Design Vue 的一行栅格总宽度是 24：

```text
第一行：4 个查询项 × 6 = 24
第二行：数据来源 6 + 按钮区 18 = 24
```

如果不把按钮区从 24 改成 18，数据来源和按钮会被挤成两行，页面会多出一块不必要的空白。

这一段各部分的职责：

| 代码 | 大白话 |
|---|---|
| `v-model="queryList.dataSource"` | 选中值存到查询对象 |
| `v-for="item in dataSourceOptions"` | 循环生成 5 个选项 |
| `:value="item.value"` | 请求真正传 `ZC/FP/...` |
| `{{ item.label }}` | 用户看到中文 |
| `allow-clear` | 允许点叉清空，回到“全部” |
| `prop="dataSource"` | 让表单重置知道这个控件对应哪个字段 |

完成后先停 10 秒，自查：

- 页面显示的是中文；
- `value` 传的是编码；
- 没有手写第六个“全部”选项；
- `v-model` 和 `prop` 都叫 `dataSource`，大小写完全一致。

### 15.5 第二步：给查询对象增加 `dataSource`

找到 `data()` 返回值里的 `queryList`，当前大约在 `87-94` 行。

在 `supplierName` 后增加：

```js
queryList: {
  purchaseCompanyName: '',
  buCode: undefined,
  supplierName: '',
  dataSource: undefined,
  queryTimeArr: [],
  beginTime: null,
  endTime: null
},
```

为什么初始值用 `undefined`，不用 `''` 或 `'ALL'`？

- `undefined` 表示“没有选择”；
- `JSON.stringify` 会自动省略值为 `undefined` 的字段；
- 后端因此不会增加来源过滤，正好对应“不选就是全部”；
- 点击下拉框清除按钮后，也回到同样的状态。

### 15.6 第三步：准备 5 个下拉选项

仍在 `data()` 返回值里，找到：

```js
buOptions: [],
```

紧跟着增加：

```js
dataSourceOptions: [
  { label: '招采平台', value: 'ZC' },
  { label: '非平台录入', value: 'FP' },
  { label: '云采平台', value: 'YC' },
  { label: '煤炭-SAP', value: 'MT' },
  { label: '机电四大类', value: 'JD' }
],
```

这里先采用显式数组，是因为：

1. 和项目里的旧交易数据报表样板一致；
2. 对 Java/Vue 新手最好读；
3. 产品目前就是固定 5 项，不需要为了少写几行提前抽象。

文件顶部 `72-78` 行已经有一个同内容的 `dataSourceMap`。它负责“表格拿到编码后怎样显示中文”；新加的 `dataSourceOptions` 负责“下拉框有哪些选项”。两者用途不同：

```text
dataSourceOptions：中文 → 用户选择 → 编码
dataSourceMap：接口返回编码 → 表格显示中文
```

本次先不要顺手重构成一个公共常量。先把最小改动跑通。

### 15.7 第四步：重置时清空数据来源

找到 `getReload()`，当前大约在 `222-229` 行。

在重置板块后增加一行：

```js
getReload() {
  this.$refs.ruleForm.resetFields()
  this.queryList.queryTimeArr = []
  this.queryList.beginTime = null
  this.queryList.endTime = null
  this.queryList.buCode = undefined
  this.queryList.dataSource = undefined
  this.init()
},
```

理论上 `resetFields()` 会根据 `prop="dataSource"` 重置它，但当前页面已经对日期和板块做了显式清理。这里继续沿用页面原有写法，保证重置后请求一定不残留旧来源。

### 15.8 第五步：这三处不要改

#### 不要改 `buildQueryParams`

当前方法：

```js
const model = JSON.parse(JSON.stringify(this.queryList)) || {}
```

它会复制整个 `queryList`。只要你在第二步加了 `dataSource`，选中后它会自动出现在：

```json
{
  "model": {
    "dataSource": "ZC"
  }
}
```

不需要再手写：

```js
model.dataSource = this.queryList.dataSource
```

#### 不要改分页请求

分页已经统一调用：

```js
...this.buildQueryParams(params)
```

所以数据来源会自动随分页一起传。用户翻到第 2 页时，筛选不会丢。

#### 不要改单独的导出参数

导出同样调用：

```js
this.buildQueryParams({ currentPage: 1, limit: 10000 })
```

因此选择 `ZC` 后再点导出，`dataSource: "ZC"` 会自动进入导出请求。后端导出又复用了分页查询方法，所以 Excel 会和页面使用同一筛选条件。

这就是当前代码设计得比较好的地方：

```text
一个 queryList
→ 一个 buildQueryParams
→ 同时服务查询、分页和导出
```

### 15.9 写完先看 Diff，不要急着构建

在前端仓库目录执行：

```bash
git diff --check -- src/views/reportForms/centralizedProcurementReport/index.vue
git diff -- src/views/reportForms/centralizedProcurementReport/index.vue
```

第一条没有输出，表示没有多余空格、冲突标记等基础格式问题。

第二条里应该只有下面 4 类变化：

1. 模板新增“数据来源”下拉框；
2. 按钮区 `span=24` 改成 `span=18`；
3. `queryList` 新增 `dataSource`；
4. 新增 5 个选项，重置时清空来源。

如果 Diff 里出现下面文件，先不要继续：

```text
public/statics/config.js
src/router/index.js
```

`config.js` 是已有敏感本地改动；路由本来就已经存在，本需求不需要再动。

### 15.10 做前端机器验证

在正确前端仓库执行：

```bash
npm run build
```

当前环境是：

```text
Node v14.21.3
npm 6.14.18
```

这个项目 2026-07-22 已经实际构建通过。预期：

- 命令退出码为 0；
- 可能仍有项目原有的 CSS 顺序、包体积告警；
- 告警不等于本次失败；
- 如果报 Vue template 编译错误，优先检查标签有没有漏关、`dataSourceOptions` 后面的逗号有没有写错。

本次不需要跑全量后端 Maven，因为没有修改 Java 文件。

### 15.11 浏览器联调：先看请求，再看页面

打开页面后按 `F12 → Network`，筛选：

```text
centralizedProcurementPageList
```

依次做下面 6 组测试：

| 用例 | 页面操作 | Request Payload 应看到 | 当前 test 预期 |
|---|---|---|---:|
| 全部 | 不选数据来源，点查询 | `model` 中没有 `dataSource` | 7 条 |
| 招采平台 | 选招采平台 | `"dataSource":"ZC"` | 2 条 |
| 非平台录入 | 选非平台录入 | `"dataSource":"FP"` | 5 条 |
| 云采平台 | 选云采平台 | `"dataSource":"YC"` | 0 条 |
| 煤炭-SAP | 选煤炭-SAP | `"dataSource":"MT"` | 0 条 |
| 机电四大类 | 选机电四大类 | `"dataSource":"JD"` | 0 条 |

`YC/MT/JD` 当前返回 0 是正常的，因为对应数据源还在导入完善；关键是请求成功、总数为 0，而不是报错。

再验证清空：

1. 先选 `ZC`，确认 2 条；
2. 点下拉框右侧的叉；
3. 点查询；
4. 请求中应不再有 `dataSource`；
5. 总数回到 7。

再验证重置：

1. 选 `FP`；
2. 点“重置”；
3. 下拉框应恢复“请选择”；
4. 请求中不带 `dataSource`；
5. 总数回到全部。

### 15.12 导出验收

先选“招采平台”，再点“导出”，在 Network 中找到：

```text
centralizedProcurementDownload
```

请求体应包含：

```json
{
  "currentPage": 1,
  "limit": 10000,
  "model": {
    "dataSource": "ZC"
  }
}
```

打开 Excel 后检查：

- 只有当前账号能看到的招采平台数据；
- “数据来源”列显示“招采平台”，不是 `ZC`；
- 当前 test 预计 2 行数据，不算表头；
- 页面和 Excel 的筛选口径一致。

然后清空来源再导出一次，应恢复导出全部 7 条。

### 15.13 最后做 Git 边界检查

先只检查，不提交：

```bash
git status --short
git diff --stat
git diff -- src/views/reportForms/centralizedProcurementReport/index.vue
```

本需求真正要进入提交的只有：

```text
src/views/reportForms/centralizedProcurementReport/index.vue
```

不要使用：

```bash
git add .
```

因为它会把 `public/statics/config.js` 的既有敏感修改一起放进提交。

等代码、构建和浏览器验证都通过，并由 AI 再看一次 Diff 后，如果你要自己做本地提交，只精确添加目标文件：

```bash
git add src/views/reportForms/centralizedProcurementReport/index.vue
git diff --cached
git commit -m "feat: 增加数据来源查询"
```

这只是本地提交。不要执行 `git push`，不要操作远程 `test`；远程动作必须由你另行明确发起。

### 15.14 最容易踩的 7 个坑

| 坑 | 会发生什么 | 正确做法 |
|---|---|---|
| 下拉值写中文 | 后端查 `dataSource=招采平台`，ES 实际存 `ZC`，结果 0 条 | label 中文，value 用编码 |
| 加一个 `ALL` 选项 | 后端会精确查一个不存在的来源 `ALL` | 不选/清空就代表全部 |
| 忘加 `queryList.dataSource` | 下拉框看着能选，请求却可能没有稳定状态 | 显式初始化为 `undefined` |
| 忘记重置 | 点重置后页面或请求仍残留旧来源 | `dataSource = undefined` |
| 另改导出逻辑 | 查询和导出容易形成两套条件 | 继续复用 `buildQueryParams` |
| 顺手改 Java Model | 制造无意义后端 Diff | Model 和 termQuery 已存在 |
| 使用 `git add .` | 把本地 token/config 改动带进提交 | 只 add 目标 Vue 文件 |

### 15.15 你写完后应该能复述

30 秒版本：

> “后端原来就支持 `dataSource` 精确筛选，导出也复用同一个查询方法，所以这次只改前端一个 Vue 文件。我增加一个中文下拉框，但实际 value 传 ZC、FP、YC、MT、JD；选中值进入 `queryList`，现有 `buildQueryParams` 会自动把它放进分页和导出请求。不选或清空时值是 undefined，请求不带这个字段，后端就不加来源条件，所以显示全部。”

自测：

1. 为什么这次不用改 Java？
2. 页面显示“招采平台”时，请求为什么必须传 `ZC`？
3. 为什么不需要新增“全部”选项？
4. `buildQueryParams` 为什么不用改？
5. 为什么导出会自动带上数据来源？
6. 重置时为什么还显式写一次 `dataSource = undefined`？
7. 为什么本次不能执行 `git add .`？

这 7 题都能回答，你不只是“照着敲完”，而是真的拥有了这次小改。
