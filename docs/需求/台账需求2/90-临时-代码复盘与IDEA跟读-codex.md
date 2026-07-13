# 台账2（煤炭重点坑口日指标）· 代码复盘与 IDEA 跟读手册

> 日期：2026-07-13  
> 工具：codex  
> 当前状态：已根据 Git 提交、`origin/test` 最终代码、建表/导出 SQL 和 test 库真实主子数据完成复盘。台账管理功能保留，坑口台账到驾驶舱的实时接线已撤回。  
> 下一阶段：你按本文在 IDEA 中跟读；当下版本重做驾驶舱联动时，以本文第 9 节的“现状边界”为起点。

> 命名说明：本文沿用当前文件夹名称叫“台账2”；你之前贴的全组任务表中，这项可能被产品排为“台账3”。和人沟通时建议直接说“煤炭重点坑口日指标台账”，避免编号混淆。

---

## 1. 先纵览：你这个需求做了什么

一句话：你给 source 服务加了一本“每次发布一组坑口煤价”的台账，一次发布有一个执行单位和最多 5 组“坑口名称+含税价”，支持查询、新增发布、修改重发布、逻辑删除、详情和 14 列 Excel 导出。

| 交付面 | 最终内容 | 证据 |
|---|---|---|
| 表结构 | `sc_coal_pit_daily_indicator` 主表 + `_item` 明细表 | test `SHOW CREATE TABLE` 与 `sql/01` 一致 |
| Java 代码 | DTO、Controller、两个 Model、两个 Mapper、Seq、Service、ServiceImpl，共 9 文件 | `1f11538d2`，815 行纯新增 |
| 号码 | `JCKK-yyyyMMdd-NNN`，按录入日期每天重置 | `CoalPitDailyIndicatorCodeSequence` |
| 业务安全 | 服务端填发布人/时间，防前端改流水号、创建人、删除状态 | `clearCreateControlledFields` 和 `modify` |
| 一致性 | 主表与明细新增/修改/删除都在同一个事务中 | `@Transactional(rollbackFor=Exception.class)` |
| 数据校验 | 单位必填；至少 1 组坑口；名价成对；价格非负且最多 2 位小数 | `validateBusiness()` |
| Excel | 分页接口复用通用导出，模板 `coal-pit-daily-export` | UBM test 库已配 14 列 |
| 演示数据 | 1 个测试发布 + 5 条坑口明细 | `sql/03-test-demo-kengk-data.sql`，明确禁止进生产 |
| 驾驶舱 | 曾接到新台账，后因交付延期精确撤回 | `3992bf54e` 被 `d4eb7d21b` 撤回 |

最终交付边界：**管理台账已写好；大屏还是读 `sc_collection_data` 的 5 条旧缓存。**

---

## 2. 两个台账的核心区别

| 对比 | 台账1：日金额 | 台账2：坑口日指标 |
|---|---|---|
| 一次提交 | 就是一笔金额 | 是一次发布，里面有 1～5 个坑口 |
| 表 | 一张表 | 主表+明细表 |
| DTO | 业务字段与表基本平行 | 对前端平铺 `pit1...pit5`，对数据库拆成多行 |
| 修改 | 更新一行 | 更新主表，旧明细逻辑删除，再整批插入新明细 |
| 事务 | 单表操作简单 | 必须有，避免主表成功但明细只写一半 |

台账2的主子表不是“Java 项目都要拆表”，而是对应了它的数据形状：

```text
主表：JCKK-20251208-001，水泥北分，2025-12-08 发布，操作人=测试数据
    ├─ 明细 1：转龙湾蒙化5500大卡，575.00
    ├─ 明细 2：中煤长协5500大卡到站价，677.00
    ├─ 明细 3：石拉乌素6200大卡，650.00
    ├─ 明细 4：金鸡滩陕块6400大卡，660.00
    └─ 明细 5：环渤海5500大卡，730.00
```

如果把 5 个坑口直接做成主表 10 个数据库列，以后产品要 6 个就必须加列、改代码、重发版。拆明细表后，数据层天然能存任意条数；当前代码只是因产品页面定了 5 个位置，在 DTO 和校验层限制为最多 5 个。

---

## 3. Git 时间线：开发、接大屏、再撤回

| 时间 | 提交 | 发生的事 | 最终状态 |
|---|---|---|---|
| 07-10 15:44:49 | `1f11538d2` | 新增坑口台账 9 个 Java 文件 | 保留 |
| 07-10 15:44:58 | `3992bf54e` | 修改共享驾驶舱 Service，`kengk` 改实时读新台账 | 后来撤回 |
| 07-10 15:46 | `fcfbfd9ff` | 当时把上述两个提交合入 test | 历史保留 |
| 07-10 16:30 | `d4eb7d21b` | 精确反向撤回 `3992bf54e` 的 1 个文件 | 最终状态 |
| 07-10 17:09 | `03a3117fe` | 将撤回合入 test | 已进 test |

这次撤回值得学两个 Git 观念：

1. **revert 不是删历史**：`3992bf54e` 仍能在 Log 里看到，`d4eb7d21b` 是新增一个“反向补丁”。这对已共享的 test 分支安全，同事 pull 不会被强制改历史。
2. **只撤共享接线，不撤台账主体**：当前 9 个台账文件、两张表、导出模板和 test 演示数据都还在。

在 IDEA 里打开 `Alt+9 > Log`，搜索 `3992bf54e`，右边看 diff；再搜 `d4eb7d21b`，你会看到相反的加减行。

---

## 4. IDEA 跟读路线和快捷键

打开仓库：`/home/t/projects/work-wsl/01zhaocai-end/scm-source-all`。为了同时看到台账1和台账2，建议在 IDEA 右下 Git 分支菜单切到本地 `test`。

| 操作 | 快捷键 | 这次怎么用 |
|---|---|---|
| 找文件 | `Ctrl+Shift+N` | 输入 `CoalPitDailyIndicatorServiceImpl` |
| 找 Java 类 | `Ctrl+N` | 输入 `CoalPitDailyIndicatorDTO` |
| 看方法目录 | `Ctrl+F12` | 输入 `add` / `modify` / `validateBusiness` |
| 跳定义 | `Ctrl+B` | 从 Controller 跳 Service，从 Service 跳 Model/Mapper |
| 查谁在用 | `Alt+F7` | 对 `queryCockpitData()` 执行，证明当前没有运行时调用方 |
| 调用层级 | `Ctrl+Alt+H` | 从 `insertItems` 向上看 add/modify |
| 全局搜索 | `Ctrl+Shift+F` | 搜 `/coalPitDailyIndicator` 或表名 |
| 回到上一处 | `Ctrl+Alt+←` | 在多层跳转后原路返回 |
| 项目树 | `Alt+1` | 展开 API 模块与业务模块 |
| Git 日志 | `Alt+9` | 按 hash 看每次提交 diff |

最有效的跟读顺序是：

```text
Controller.add
  → Service 接口 add
    → ServiceImpl.add
      → validateBusiness
      → clearCreateControlledFields
      → GIDService + Seq
      → 主表 Mapper.insert
      → insertItems
        → 明细 Mapper.insert
```

---

## 5. 第一轮：读懂“新增并发布”

### Controller：只定义 HTTP 入口

`CoalPitDailyIndicatorController#add()` 只有三层意思：

```text
POST /e/business/source/coalPitDailyIndicator/add
JSON 转 CoalPitDailyIndicatorDTO
调 service.add(dto)，返回 JCKK 号
```

它对应 Koa Router，不应该把“价格能不能为负”这种业务规则塞进 Controller。

### DTO：对前端的平铺合同

前端页面展示 5 组固定列，所以 DTO 设计为：

```json
{
  "executeUnitCode": "DEMO001",
  "executeUnitName": "水泥北分",
  "publishDate": "2026-07-10",
  "pit1Name": "金鸡滩5000大卡",
  "pit1TaxPrice": 540.00,
  "pit2Name": "金鸡滩5600大卡",
  "pit2TaxPrice": 530.00
}
```

这是“对外简单，对内正规化”：前端不需要了解主子表，ServiceImpl 在内部把 5 组字段转成 0～5 条明细。

### ServiceImpl#add：一个完整业务事务

将 88～104 行翻译成 Node 逻辑：

```text
transaction(async () => {
  validate(dto)
  const main = copy(dto)
  clearClientControlledFields(main)
  main.no = generateJCKK()
  main.publishDate ??= today
  main.deleteSign = 0
  main.publisher = currentUser
  insertMain(main)
  insertItems(main.id, dto)
  return main.no
})
```

`@Transactional(rollbackFor=Exception.class)` 是这段的关键。例如主表 INSERT 成功，第 3 个坑口明细 INSERT 失败，整个事务回滚，主表和前两个明细也不留。如果没有事务，就会出现“页面上一次发布只剩半条数据”。

### validateBusiness：后端的最后防线

它检查：

1. 请求不为空。
2. 执行单位 code/name 都有。
3. 字段长度不超数据库列容量。
4. 每个坑口名称和价格要么都有，要么都没有。
5. 价格不小于 0，最多 2 位小数，整数位不超数据库 `decimal(20,2)` 的 18 位。
6. 最少有 1 组有效坑口。

这里比台账1的实现更完整，也是你以后学新增/修改业务校验更好的样本。

### insertItems：把平铺 DTO 转成明细行

方法先将 5 个 name 和 5 个 price 变成两个数组，按位置 1～5 循环；空位置跳过，有值的插入明细表，`sort_no` 保留页面顺序。

---

## 6. 第二轮：读懂分页“两次查询，内存组装”

`queryListByPage()` 不是对每条主表再查一次明细，而是：

1. 先分页查当页主表。
2. 拿到当页所有 `indicatorId`。
3. 用一条 `IN (...)` SQL 把当页所有明细一次查回来。
4. 在 Java 里按 `indicatorId` 分组成 `Map`。
5. `fillPitFields()` 按 `sortNo` 填回 DTO 的 `pit1...pit5`。

这是在避免常见的 N+1 问题：如果一页 20 条，“每个主表查一次明细”会变成 1+20 条 SQL；现在固定是 2 条主查询（分页总数的 SQL 由分页框架另行处理）。

查询条件是：

- 流水号 LIKE。
- 执行单位编码精确或名称 LIKE。
- 发布时间起止区间。
- 排序先按发布日期，再按真实发布时间，新的在前。

---

## 7. 第三轮：读懂修改和删除

### 修改为什么是“整批替换明细”

`modify()` 的顺序：

```text
检查主键 → 查现有主表 → 校验新业务数据
→ 更新主表可改字段和发布人/时间
→ 逻辑删除该主表的全部旧明细
→ 按新 DTO 重新插入明细
```

因为最多只有 5 条，整批替换比对比“哪个坑口新增、哪个改名、哪个换位置”更简单，容错率更低。test 库中某条已删测试台账对应两条 `sort_no=1` 的已删明细，就是修改时旧明细保留的痕迹。

整个过程有事务，不会在“旧明细已删，新明细尚未全部插入”时留下半成品。

### 修改时什么不允许变

- `indicatorNo`：业务身份不变。
- `publishDate`：当前口径是发布所属日不变，修改只刷新 `publishTime`。
- `create*`：原创建人不变。
- `deleteSign`：不能借修改接口改删除状态。
- `update*`：前端传的不信，交给框架自动填。

### 删除

主表和属于它的明细都调 Mapper 删除，两个 Model 都有 `@TableLogic`，所以实际是把 `delete_sign` 改 1。这保证分页、详情、导出都不再看到，但数据库还能追溯。

---

## 8. Excel 导出和数据库索引为什么这样设计

### 导出

Controller 的分页方法有：

```java
@ExportRequestTransfer(exportTemplateCode = "coal-pit-daily-export")
```

UBM test 库对应 14 列：流水号、执行单位、5 组名称+价格、发布时间、操作人。

导出看起来是平铺 14 列，因为 Service 已经将主子数据转成平铺 DTO，通用导出组件不需要知道数据库有两张表。

### 主表索引

- `uk_indicator_no`：流水号唯一。
- `idx_execute_unit_code`：支持按执行单位编码查。
- `idx_publish_time`：支持发布时间区间。
- `idx_cockpit_latest(delete_sign,publish_date,publish_time)`：为“找最新有效发布”预留的组合索引。当前驾驶舱接线撤回，该索引暂时不在大屏路径中使用，但不影响管理台账。

### 明细表索引

`idx_indicator_items(indicator_id,delete_sign,sort_no)` 对应代码最常做的事：按主表 id 查未删明细，并按顺序号排序。索引列顺序与查询条件顺序一致，不是随便拼的。

表没有数据库外键，关联一致性由 Service 事务和 `indicator_id` 条件维护。这符合该项目常见的微服务表风格，也避免发布/清理数据时被数据库级联锁阻塞；代价是代码必须负责不产生孤儿明细。

---

## 9. 驾驶舱接线：曾经怎么写，现在为什么不生效

### 原来的大屏路径

```text
前端 GET /e/business/source/source/cockpit_collection_data_kengk
  → SourceQueryController
  → SourceCollectionDataServiceImpl.queryCollectionData("kengk")
  → else 分支查 sc_collection_data WHERE data_type='kengk'
  → 返回 5 条旧坑口价格
```

test 库现有 5 条缓存价格：575 / 677 / 650 / 660 / 730。

### `3992bf54e` 当时做了什么

它只改了 `SourceCollectionDataServiceImpl.java` 一个共享文件：

1. 注入 `CoalPitDailyIndicatorService`。
2. 如果 `typeCode=kengk`，在查字典前直接走 `queryKengk()`。
3. `queryKengk()` 调 `coalPitDailyIndicatorService.queryCockpitData()`。

`queryCockpitData()` 会找 `publish_date` 最新、同日 `publish_time` 最新的一个主表，再把明细转成老大屏认识的 `SourceCollectionData` 格式。这是一层“适配器”：新表格式变了，大屏前端的 JSON 合同不变。

### 现在的最终状态

`d4eb7d21b` 将上述三处精确撤回，所以：

- `SourceCollectionDataServiceImpl#queryKengk()` 又返回 `null`，且没有人调它。
- `queryCollectionData("kengk")` 继续落入 else，查旧缓存表。
- `CoalPitDailyIndicatorService#queryCockpitData()` 和实现仍在，但当前是“已经写好、没有入口调用”的预留代码。

在 IDEA 对 `queryCockpitData()` 按 `Alt+F7`，你会看到 ServiceImpl 的实现关系，但不会看到当前运行路径从 `SourceCollectionDataServiceImpl` 调它。

为什么不顺手删掉预留方法？它不会自动运行，不影响现有功能，下版本可以在新口径确认后复用或改造。这是“延后交付”而不是“已经上线的联动”。

---

## 10. test 数据现场教学

2026-07-13 只读查询结果：

### 主表

| 流水号 | 单位 | 发布日 | 发布人 | 状态 |
|---|---|---|---|---|
| `JCKK-20251208-001` | 水泥北分（测试） | 2025-12-08 | 测试数据 | 有效 |
| `JCKK-20260710-001` | 水泥北分（测试） | 2026-07-10 | 张雨 | 已逻辑删除 |

### 明细表

- 演示主表对应 5 条有效坑口。
- 已删测试主表对应的明细也都是 `delete_sign=1`。
- 同一个已删主表下有两个已删 `sort_no=1` 明细，分别是修改前/后的测试坑口名；这证明修改采用“旧明细逻辑删除+新明细插入”。

这些数据说明增、改、删的链路至少曾在 test 环境产生过真实落库结果；但数据库结果不能单独证明“当前 K8s Pod 一定已经部署 `03a3117fe` 后的最新 jar”，部署版本仍要看 Jenkins/K8s。

---

## 11. 从高层看：为什么 AI 这样写

### 这些设计是有意义的

1. **主子表**：解决一次发布内有多个坑口的可变列表，数据层可扩展。
2. **平铺 DTO**：屏蔽前端对主子表的感知，直接匹配产品的 5 列页面。
3. **事务**：保证一次发布/修改/删除的主表和明细全成功或全失败。
4. **批量查明细**：避免每条主表再打一次数据库。
5. **整批替换明细**：最多 5 条时，简洁和一致性比微优化更重要。
6. **逻辑删除**：保留台账修改/删除痕迹。
7. **适配大屏旧 JSON**：曾经的 `queryCockpitData()` 设计保持前端接口不变，只换后端数据源，影响面小。
8. **撤回使用 revert**：不改写已共享 Git 历史，不误伤台账主体。

### 你还要知道的边界

1. **当前管理页最多 5 个**：数据库可扩展，但 DTO、`MAX_PIT_COUNT`、导出模板和前端都固定 5。以后要 6 个不是“只插第 6 条库数据”，还要改接口合同和页面。
2. **修改会积累已删明细**：这是逻辑删除+整批替换的结果。量小时可接受；如果未来修改非常频繁，需要考虑归档/审计表策略。
3. **没有 DB 外键**：符合现有项目风格，但要靠 Service 事务维护主子一致性。
4. **预留大屏方法不等于已交付大屏联动**：谈进度时必须明确分开。
5. **新增允许前端传 `publishDate`**：不传默认当天，传了则使用前端日期；修改不允许改它。这与“页面日期控件，默认提交日”的口径一致。

---

## 12. 你和负责人/同事怎么聊

### 30 秒版

> “煤炭重点坑口日指标台账后端已经完成。数据库是主子表：主表表示一次发布，明细表表示 1 到 5 个坑口和价格。对前端仍是平铺的 pit1 到 pit5，Service 负责拆分和组装。新增、修改、删除都有事务，避免主子数据只成功一半；价格和必填校验在后端。导出模板是 14 列。驾驶舱实时读新台账的接线因为交付延期已经revert，当前大屏仍读旧缓存。”

### 同事问“为什么不直接建 pit1～pit5 十个列”

> “坑口是重复明细，不是固定属性。主子表让数据层可扩展，页面当前最多 5 个的限制放在 DTO 和业务校验层。对前端仍返回 pit1 到 pit5，不增加它的复杂度。”

### 同事问“修改怎么处理明细”

> “在一个事务里更新主表，逻辑删除原明细，再按前端传回的完整 1 到 5 组数据整批插入。明细很少，这种写法比逐条对比新增修改删除更稳。”

### 同事问“现在大屏到底读哪”

> “当前最终 test 代码已撤回 kengk 到新台账的接线，大屏接口地址不变，还是按 `data_type=kengk` 查 `sc_collection_data` 的 5 条旧数据。新台账里有一个 `queryCockpitData()` 预留方法，但当前没有运行时入口调用它。”

---

## 13. 跟读完的自测题

1. 为什么台账1用单表，台账2用主子表？
2. 前端为什么仍然看到 `pit1Name`，而不是明细数组？
3. `@Transactional` 在 add/modify/delete 里各防了什么半成品？
4. 分页查询为什么不会一页 20 条就查 20 次明细？
5. 修改时为什么要整批替换明细？
6. `validateBusiness()` 防住了哪些脏数据？
7. `3992bf54e` 和 `d4eb7d21b` 是什么关系？
8. 为什么代码里还有 `queryCockpitData()`，却不能说大屏联动已交付？

---

## 14. 证据索引

- 台账主体：`1f11538d2`
- 曾经的驾驶舱接线：`3992bf54e`
- 精确撤回：`d4eb7d21b`；合入 test：`03a3117fe`
- 代码主路径：`scm-source-source-api/.../CoalPitDailyIndicatorDTO.java` 和 `scm-source-source/.../CoalPitDailyIndicator*.java`
- 建表：`docs/需求/台账需求2/sql/01-create-coal-pit-daily-indicator.sql`
- 导出：`docs/需求/台账需求2/sql/02-export-template.sql`
- test 演示数据：`docs/需求/台账需求2/sql/03-test-demo-kengk-data.sql`，禁止生产执行
- 数据库核对日期：2026-07-13；业务库 `scm_source_test`，导出配置库 `scm_ubm_test`。
