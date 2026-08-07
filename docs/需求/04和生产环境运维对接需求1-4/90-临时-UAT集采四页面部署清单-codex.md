# UAT 集采四页面部署清单

> 执行时请改看 `90-临时-UAT集采四页面操作教程-codex.md`。本文保留为代码提交与平台侦察依据。
>
> 日期：2026-07-29  
> 工具：Codex  
> 当前状态：四个页面的代码、数据库、导出模板、菜单、调度和 Jenkins 已完成只读核对；UAT 尚不具备完整运行条件，暂时不能只做一次“test 合 uat”就收工。  
> 下一阶段：先拿回第 7 节的同事答复，再由 AI 按第 5 节准备三个仓库的本地 UAT 集成分支和完整 UAT SQL；用户只负责远程合并/推送、点 Jenkins 和管理页面配置。

## 1. 先说结论

你理解的方向对，但少了几层：

1. 四个页面确实都要发同一个前端 `procurementScheme`。
2. 后端不是一个模块：
   - 日金额、煤炭坑口、价格趋势走 `source`。
   - 日计划走同事负责的 `order`。
3. 还要处理业务表、Excel 导出模板、菜单与岗位权限；日计划另外有一个定时任务。
4. 这四个页面都不读 ES，所以本次不需要配 Nacos 里的 `centralizedProcurementReportIndex`。
5. 本次只需要日计划的任务 240；任务 239 是“集采管理业务统计报表-云采”，属于需求 03 的报表，不在这四个页面内。
6. **不能把整个 test 分支直接合到 uat。** 2026-07-29 `git fetch` 后实查：
   - `scm-source-all`：test 相对 UAT 多 1198 个提交；
   - `scm-vue-all-procurementscheme`：多 566 个；
   - `scm-order-all`：多 1088 个。
   里面夹着其他需求，整分支合并会把无关功能一起带上 UAT。

因此，正确做法是：**只迁这四个页面的功能提交 → 执行 UAT 专用 SQL → 构建 source/order/前端 → 配菜单权限 → 配任务 240 → 做四页验收。**

## 2. 四个页面到底依赖什么

| 页面 | 前端 | 后端 | 业务表 | 导出模板 | 定时任务 | ES/Nacos |
| --- | --- | --- | --- | --- | --- | --- |
| 集采日金额统计台账 | `procurementScheme` | `scm-source-all` | `sc_collection_daily_amount_ledger` | `collection-daily-ledger-export`，9 列 | 无 | 无 |
| 集采日计划统计台账 | `procurementScheme` | `scm-order-all` | `to_central_purchase_daily_statistics` | `centralPurchaseStatistics`，test 为 4 列 | **任务 240** | 无 |
| 煤炭重点坑口日指标 | `procurementScheme` | `scm-source-all` | `sc_coal_pit_daily_indicator` + `_item` | `coal-pit-daily-export`，14 列 | 无 | 无 |
| 价格趋势维护 | `procurementScheme` | `scm-source-all` 的 `scm-source-ssc` | `sc_price_trend` | 前端传 `priceTrend`，但 test/UAT 均未找到模板 | 无 | 无 |

接口证据：

- 日金额前端调用 `/e/business/source/collectionDailyAmountLedger`：`dailyAmountStatisticsLedger/index.vue:165`。
- 日计划前端调用 `/d/business/order/centralPurchaseStatistics`：`dailyPlanStatisticsLedger/index.vue:308,352`。
- 坑口前端调用 `/e/business/source/coalPitDailyIndicator`：`coalPitDailyIndicator/index.vue:161`。
- 价格趋势前端调用 `/e/business/source/priceTrend`：`maintenancePriceTrend/index.vue:170`。
- 四条前端路由都已在 test 的 `src/router/index.js:751-773` 注册。

这几条链路都是页面 → Java 接口 → MySQL 表，没有目标 ES 索引，因此 `00任务.md:6-41` 的 ES 配置不属于本次四页面上线。

## 3. 你问的数据库记录在哪里

### 3.1 已经记录完整的两项

| 功能 | 现成 SQL | 内容 | 注意 |
| --- | --- | --- | --- |
| 日金额 | `docs/需求/01台账/sql/00-prod-deploy.sql` | 1 张业务表 + 9 列导出模板 | 文件写的是生产库 `scm_source/scm_ubm` |
| 煤炭坑口 | `docs/需求/02台账需求2/sql/00-prod-deploy.sql` | 2 张业务表 + 14 列导出模板 | 文件写的是生产库 `scm_source/scm_ubm`；不含演示数据和驾驶舱联动 |

两个文件都可以作为 UAT SQL 的来源，但**不能原样在 UAT 执行**：

- 日金额脚本的 `USE scm_source` 在 `00-prod-deploy.sql:25`，模板库 `USE scm_ubm` 在第 72 行。
- 坑口脚本的 `USE scm_source` 在第 26 行，模板库 `USE scm_ubm` 在第 80 行。
- UAT 必须改成 `scm_source_uat` 和 `scm_ubm_uat`，并生成单独 UAT 文件，避免误写生产库。

### 3.2 `00任务.md` 记录了什么

同目录的 `00任务.md` 是整批需求 01～03 的通用部署备忘：

- 第 5 行只写“同事把 SQL 发给我了”，**没有把 SQL 正文存进工作区**。
- 第 17 行的 ES 键和第 52 行的任务 239 属于需求 03 报表。
- 第 51 行的任务 240 才属于本次日计划台账。

所以答案是：**你的日金额和坑口 SQL 有记录；同事的日计划 SQL、价格趋势 SQL没有保存在这个 00 文件里。**

## 4. 2026-07-29 UAT 真实现状

以下均为只读查询，没有改库、改任务或触发构建。

### 4.1 代码

| 仓库 | test | UAT | 结论 |
| --- | --- | --- | --- |
| `scm-source-all` | 有日金额、坑口、价格趋势三个 Controller | 三个 Controller 都不存在 | source 代码待迁 |
| `scm-order-all` | 有 `CentralPurchaseDailyStatisticsController` | 不存在 | order 日计划代码待迁 |
| `scm-vue-all-procurementscheme` | 四个 Vue 页面和路由都存在 | 四个页面都不存在 | 前端待迁 |

### 4.2 数据库与配置

| 项目 | test | UAT | 判断 |
| --- | --- | --- | --- |
| 日金额业务表 | 有 | **无** | 必须建 |
| 坑口主表/明细表 | 有 | **均无** | 必须建 |
| 价格趋势表 | 有 | **无** | 必须建，但工作区缺正式 SQL |
| 日计划表 | 有 11 条 | **已有，0 条** | 不要删表重建；先确认同事 SQL |
| 日金额导出模板 | 9 列 | **无** | 必须配 |
| 坑口导出模板 | 14 列 | **无** | 必须配 |
| 日计划导出模板 | test 有 4 列 | **无** | 必须配 |
| 价格趋势导出模板 | **test 也无** | **无** | 阻塞项，先补 test 并验收导出 |
| 一级菜单 + 四个子菜单 | test 有 | **UAT 全无** | 找张雨配置并授权岗位 |
| UAT 订单任务 240 | test 有 | **无** | order 部署后新增 |

UAT 的日计划表虽然存在，但和 test 不是完全同一份 DDL：

- UAT 主键 `id` 是 `varchar(64)`，test 是 `varchar(50)`；UAT 更宽，不影响 Java 的 String。
- UAT 多两个允许为空的字段 `publish_date/publish_time`，当前代码不使用，不影响运行。
- UAT 少 `execute_unit_id/category_code/statistics_date` 三个普通索引，功能能跑，但数据多后查询会慢。

结论：**不要直接 DROP/重建 UAT 日计划表。** 先让同事确认他给的 SQL 是否应补这三个索引，以及是否包含导出模板。

### 4.3 调度

2026-07-29 只读登录 UAT 调度中心，订单中心仍只有 5 个旧任务，没有 239/240。

本次只新增任务 240：

| 字段 | 值 |
| --- | --- |
| 任务描述 | 集采日统计服务 |
| 执行器 | 订单中心 |
| Cron | `0 3 3 * * ?` |
| 运行模式 / Handler | `BEAN` / `simpleJobHandler` |
| 任务参数 | `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}` |
| 负责人 | `zyl` |
| 路由策略 | `FIRST` |
| 过期策略 | `DO_NOTHING` |
| 阻塞策略 | `SERIAL_EXECUTION` |
| 超时 / 重试 | `0 / 0` |

代码证据：order test 的 `CentralPurchaseDailyStatisticsService` 使用
`@TypeMapping("centralPurchaseDailyStatisticsService")` 和
`@MethodMapping("syncCloudPurchaseData")`。

### 4.4 Jenkins

UAT 的任务入口已经核实：

| 作用 | Jenkins 任务 | 参数 |
| --- | --- | --- |
| 发 source 业务 jar | `scm-source-all-uat` | `GIT_BRANCH=uat`，UAT SNAPSHOT |
| 部署 source 运行服务 | `scm-source-web-uat` | 由 source-all 成功后自动触发 |
| 发 order 业务 jar | `scm-order-all-uat` | `GIT_BRANCH=uat`，UAT SNAPSHOT |
| 部署 order 运行服务 | `scm-order-web-uat` | 由 order-all 成功后自动触发 |
| 发采购方案前端 | `scm-vue-statics-uat` | `PROJECT=procurementScheme`、`GIT_BRANCH=uat` |

2026-07-29 在线核实，source UAT 最近一次是 all #478 自动触发 web #444；order 是 all #208 自动触发 web #199。
所以后端通常各点一次 `*-all-uat`，但必须继续等对应 `*-web-uat` 成功，不能看到 all 变绿就认为服务已更新。

注意：这些历史构建成功不代表四页面已部署，因为当前 UAT 分支根本还没有四页面代码。

## 5. Git 应该怎么迁，不能怎么迁

### 5.1 禁止项

1. 不要执行 `uat merge test`：会带入上千个无关提交。
2. 不要直接合整个 source `feature/taizhang-yang`：该长期分支已经混入 test 历史。
3. 不要直接合整个 order `prod-chun0518`：里面还有需求 03 的云采报表提交 `1f6fd0093`。
4. 不要把前端提交 `62069336` 原样带入 UAT：它同时改了 `public/statics/config.js`；该文件是环境敏感配置。它对路由的改动只是重排坑口路由，没有功能增量，可以不迁。
5. 价格趋势 `a8045d94b`（V3 删除接口修复）目前不在 test，不能未经 test 验收直接送 UAT。

### 5.2 已核实可从当前 UAT 基线干净迁入的候选提交

我已使用临时 Git index 对当前 `origin/uat` 做过三仓补丁预演，下面三组均能顺序干净应用，没有改分支、没有产生真实提交。

`scm-source-all`：

```text
aa4747310  日金额 CRUD
350e3f2cd  日金额逻辑删除
6639e449f  日金额导出
ca52c5b8f  日金额默认导出模板编码
dd910b1c4  日金额导出日期格式
a4a245926  组织和字典查询
8af713b45  组织短名与名称模糊查询
5a54c009b  组织下拉名称修正
1f11538d2  煤炭重点坑口台账
7c8772759  价格趋势 V1
030b1212f  价格趋势 V2
```

补充：`435d0f6b5` 删除组织接口、`73ffeea3e` 又原样恢复，净结果为零；干净迁移时不必把这对来回提交带到 UAT。

`scm-vue-all-procurementscheme`：

```text
0fa177ef  日计划页面和路由
1adfd215  日计划创建时间
4b41671c  日金额页面及日计划调整
30ab068c  价格趋势页面和路由
a9907e1e  价格趋势调整
66544d68  日计划 0714 调整
6af48d12  坑口页面和路由
da9e0f98  坑口名称长度修复
48549264  坑口发布日期锁定
```

`scm-order-all`：

```text
856501a8b  日计划 V1
6366eb512  日计划 V2-1
4aefb22ac  日计划 V2-2
1304f1e75  日计划 V3
0fe2d3ea0  日计划 V4
938936ea0  日计划 V5
d31b6b273  日计划 V6 导出
437ded44e  日计划 V6 请求转换修正
6f15ee11c  日计划定时任务 AIM 映射
```

这份清单是“集成依据”，不是让用户手敲十几次 cherry-pick。更稳的协作方式是：

> 用户明确授权 AI 按本文准备三个**本地** UAT 集成分支；AI 负责挑提交、处理冲突、编译/构建和核对 diff；用户最后自己推送和发起远程合并。

## 6. 两个上线前必须补的质量缺口

### 6.1 价格趋势删除接口没有进 test

当前 test 前端把删除参数作为 JSON 请求体发送：

```text
maintenancePriceTrend/index.vue:478-483
POST /e/business/source/priceTrend/delete
body = {"trendId":"..."}
```

请求封装也能互证：`src/utils/request.js:274-286` 会剥离 `method`，再把其余参数交给
`postJson`，所以 `trendId` 不是 URL 查询参数。

当前 test 后端 V2 却用 `@RequestParam String trendId` 接收 URL 参数：

```text
PriceTrendController.java:57-60
```

未进 test 的 `a8045d94b` 才把它改为读取 JSON body。说明“test 没问题”至少没有覆盖价格趋势删除，不能把它当成完整验收。

处理方式：

1. 先把 V3 合入 test。
2. 在 test 实测新增一条 → 删除 → 列表不可见。
3. 通过后再把 V3 加进 source 的 UAT 迁移清单。

### 6.2 价格趋势导出模板连 test 都没有

前端导出固定传 `exportTemplateCode: priceTrend`，但 2026-07-29 查询
`scm_ubm_test.scm_simple_template` 没找到该编码，UAT 也没有。

处理方式：

1. 找同事确认价格趋势导出列定义，不能由 AI猜列名和顺序。
2. 先在 test 补模板并实际导出 Excel。
3. 把同一模板整理成可重复执行的 UAT/生产 SQL。

## 7. 现在先问同事这一段

逐字发：

> 我刚把这次“只上 UAT 集采四个台账页面”的依赖重新核了一遍。日金额和坑口的建表+导出模板 SQL 我这里有；UAT 的日计划业务表已经存在，但日计划导出模板和任务 240 还没有；价格趋势的业务表 UAT 没有，而且 `priceTrend` 导出模板连 test 也没查到。  
>   
> 我再确认四件事：  
> 1）这次范围只包含日金额、日计划、坑口、价格趋势四个页面，对吧？那需求 03 的 ES 配置 `centralizedProcurementReportIndex` 和任务 239 这次都不做，只做日计划任务 240。  
> 2）你之前发我的日计划 SQL 是否包含 `centralPurchaseStatistics` 导出模板？麻烦把最终 SQL 再发我一份，我存进需求文件夹。  
> 3）价格趋势 `sc_price_trend` 建表 SQL和 `priceTrend` 导出模板由谁提供？现在工作区没有，test 库也没有导出模板。  
> 4）价格趋势删除修复 V3（提交 `a8045d94b`）目前没进 test，我准备先补到 test 测完删除再上 UAT，这样处理对吧？

对面答复的判断：

| 对方回答 | 下一步 |
| --- | --- |
| 四页面，239/ES 不做 | 按本文缩小范围 |
| 239/ES 也要做 | 说明范围又包含需求 03，必须另开一组部署清单，不能混进四页面 |
| 给了日计划 SQL | AI 对照 UAT 现表，只补缺项，不删表 |
| 没有价格趋势模板 | 请产品/前端确认导出列；先补 test |
| V3 可以先上 test | 补 test 并回归删除后再迁 UAT |

## 8. 答复回来后的实际执行顺序

### 第一步：AI 准备，不让用户手工拼

- [ ] 把同事 SQL 存入本需求文件夹。
- [ ] 生成一份 UAT 专用、可重复执行的 SQL：库名只能是 `scm_source_uat/scm_order_uat/scm_ubm_uat`。
- [ ] SQL 不带 test 演示数据，不带驾驶舱切换，不动生产库。
- [ ] 基于三个仓库各自 `origin/uat` 准备本地集成分支。
- [ ] 加入价格趋势 V3（前提是已进 test 并通过）。
- [ ] source 做隔离 javac，前端跑 `npm run build`；order 由同事代码仓做隔离 javac。
- [ ] 最终 diff 只包含四页面，不含报表、ES、任务 239、`public/statics/config.js`。

### 第二步：用户做远程动作

- [ ] 用户自己把三个本地集成分支推到远程。
- [ ] 用户自己发起/完成到 UAT 的合并。
- [ ] 禁止整分支 `test → uat`。

### 第三步：UAT 数据库

- [ ] 执行 AI 整理的 UAT SQL。
- [ ] 反查 4 张 source 业务表（其中坑口两张）和 order 日计划表。
- [ ] 反查 4 个导出模板及列数：日金额 9、坑口 14、日计划 4、价格趋势按确认结果。
- [ ] 不删除 UAT 已有的日计划表。

### 第四步：Jenkins

- [ ] 点 `scm-source-all-uat`，继续等自动触发的 `scm-source-web-uat` 成功。
- [ ] 点 `scm-order-all-uat`，继续等自动触发的 `scm-order-web-uat` 成功。
- [ ] 点 `scm-vue-statics-uat`，参数 `PROJECT=procurementScheme`、`GIT_BRANCH=uat`。
- [ ] 任何一个 all 绿、web 红，都算部署失败。

### 第五步：菜单和岗位权限

发给张雨：

> 麻烦在 UAT 配置一级菜单“集采业务管理台账”和下面四个子菜单，并授权给“集采管理-执行单位集采管理岗”：  
> 1. 集采日金额统计台账：`/procurementScheme/index.html#/businessManagementLedgerJC/dailyAmountStatisticsLedger`  
> 2. 集采日计划统计台账：`/procurementScheme/index.html#/businessManagementLedgerJC/dailyPlanStatisticsLedger`  
> 3. 煤炭重点坑口日指标：`/procurementScheme/index.html#/businessManagementLedgerJC/coalPitDailyIndicator`  
> 4. 价格趋势维护：`/procurementScheme/index.html#/businessManagementLedgerJC/maintenancePriceTrend`  
> 配好后麻烦告诉我，我要做 UAT 页面和岗位可见性验收。

不要把 test 的菜单主键原样复制到 UAT；让管理平台生成本环境记录。

### 第六步：任务 240

- [ ] order 的 web 服务部署成功、订单执行器在线后，再新增任务 240。
- [ ] 先核对参数，再保存；不要先建任务再部署代码。
- [ ] 是否立即手动执行一次由同事确认；若执行，检查调度日志和日计划表写入结果。
- [ ] 本次不建任务 239。

### 第七步：四页验收

每个页面都要勾：

- [ ] 菜单可见，直接 URL 也能打开，不是空白页/404。
- [ ] 列表查询正常。
- [ ] 新增后列表能看到，数据库有记录。
- [ ] 修改后页面和数据库同步变化。
- [ ] 删除后列表不可见。
- [ ] Excel 能下载，列名、顺序、日期和金额格式正确。
- [ ] 换“集采管理-执行单位集采管理岗”账号仍能看到菜单并操作。

日计划额外验：

- [ ] 汇总比例接口有返回。
- [ ] 任务 240 日志 trigger/handle 均成功。
- [ ] 同一天重跑不会无限新增重复记录。

## 9. 本轮明确没有做

- 没有合并、提交或推送任何公司远程分支。
- 没有执行 UAT/生产 SQL。
- 没有新增或启动调度任务。
- 没有触发 Jenkins 构建。
- 没有修改 Nacos、ES、菜单或岗位权限。
- 浏览器只读护栏持续生效；本轮只读取 UAT 调度列表和 Jenkins 构建信息。
