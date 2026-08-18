# 集采业务管理报表及取值需求 · 生产对接交付清单

> 日期：2026-08-18
> 工具：Codex
> 当前状态：六个应用的生产交付分支已基于最新远端 `prod` 在本地提交；运维只读 SQL、导出模板定义、Nacos、ES、XXL-JOB、菜单、部署、补数、验收和回退清单均已准备；未 push、未提 MR、未修改任何生产环境。
> 下一步：先确认 UAT 最终验收和生产 ES 索引名，再由用户 push 六个本地分支并提 MR；代码合入 `prod` 后由运维按本文第 7 节顺序执行。

本文可直接转发给运维、生产配置负责人和代码审核人。建议附带这段话：

> 你好，这次上线范围是“集采管理业务统计报表 + 集采门户取值 + 老驾驶舱取值 + 集采日计划后续修复”。六个应用分支已从各仓最新 `prod` 基线整理为单提交。请先做只读核查，不要直接复制 test/UAT 的数据库 ID、Nacos 整段配置或 XXL-JOB 数字 ID。生产 ES 索引名目前没有权限核实，请由运维确认一个生产物理索引名，并保证 source、order、report 三处完全一致。定时任务先创建为停用，历史数据补齐并验收后再启用。

## 0. 上线结论

本批需求需要发布 3 个后端和 3 个前端：

1. `scm-source-all`：五路报表写入中的 FP/ZC/MT/JD、集采门户汇总、老驾驶舱四组新取值。
2. `scm-order-all`：YC 报表写入、集采日计划同步幂等与四率取值修正。
3. `scm-report-all`：集采报表查询、筛选和平台模板导出。
4. `scm-vue-all-procurementscheme`：集采报表页面，以及 2026-08-17 合入 UAT 的日计划录入规则优化。
5. `scm-vue-hpc`：集采门户真实取值、板块字典名称和最终展示样式。
6. `scm-vue-all-cockpit`：负滞后率柱形按 0 高度显示，但右侧文字保留真实负数。

本批需求本身不新增 MySQL 业务表。它依赖 04 期已经交付的 5 张台账表，并新增/核对：

- 1 个生产 ES 索引，供 source、order 写入、report 查询；
- 3 处 Nacos 的同名 ES 索引配置，另核对 1 个既有 Feign 配置；
- 6 个 XXL-JOB 任务，其中“集采日统计服务”是 04 期既有任务，只核对、不重复创建；
- 1 个 Excel 导出模板；
- 1 个“集采管理业务统计报表”菜单及生产角色权限；
- 3 个后端发布和 3 个前端静态发布。

## 1. 本地生产交付分支

2026-08-18 已对六个仓库执行远端只读 `fetch`。创建分支时的 `origin/prod` 与 fetch 后的最新 `origin/prod` 完全一致，六个分支均只领先生产基线 1 个本地提交、工作区干净，并已取消 upstream，避免误把分支直接推到远端 `prod`。

统一分支名：`jicai-report-quzhi-prod-yang`

统一本地 worktree 根目录：`/home/t/projects/prod-handoff-20260818/`

| 仓库 | 最新生产基线 | 本地提交 | 改动规模 | 本地验证 |
|---|---|---|---:|---|
| `01zhaocai-end/scm-source-all` | `08e324685509` | `4b8b7d1d35e8 feat: 增加集采报表及驾驶舱取值接口` | 18 文件，`+2725/-36` | 目标 Java 文件隔离编译 0 错误；diff check 通过 |
| `01zhaocai-end/scm-order-all` | `317c4eab87ee` | `52b079abc2a1 fix: 完善集采统计同步取值` | 3 文件，`+93/-29` | 目标 Java 文件隔离编译 0 错误；diff check 通过 |
| `01zhaocai-end/scm-report-all` | `14d10a566eac` | `87759d270881 feat: 增加集采业务统计报表查询` | 5 文件，`+261` | 目标 Java 文件隔离编译 0 错误；diff check 通过 |
| `02zhaocai-front/scm-vue-all-procurementscheme` | `46ab215fcc1a` | `b52a01b8d33b feat: 增加集采报表并优化日计划台账` | 3 文件，`+442/-15` | `npm run build:app` 成功，仅有既有体积/CSS 警告 |
| `02zhaocai-front/scm-vue-hpc` | `b0de1335e7ea` | `79b6873b0de5 feat: 完善集采门户统计展示` | 9 文件，`+275/-203` | `npm run build:app` 成功，仅有体积警告 |
| `02zhaocai-front/scm-vue-all-cockpit` | `6d87838f37f4` | `7b7cd7d41fce fix: 修正集采驾驶舱延期率展示` | 2 文件，`+5/-3` | 按锁文件装公开依赖并离线复用现有 `scm-request` 私包后，`npm run build:app` 成功，仅有体积警告 |

逐文件与最新 UAT 对照时，另外五仓的本次目标文件全部一致；`procurementScheme/src/router/index.js` 只差 UAT 还带有 04 期“煤炭重点坑口日指标”路由。该路由属于上一批生产交接，本分支没有重复夹带；本次新增报表路由、报表页面和日计划页面内容均与 UAT 一致。

补充核对：`scm-vue-all-procurementscheme` 的 2026-08-17 两个日计划提交已经进入最新 `origin/uat@f09c4e661991`，不是只存在于个人分支。不过仍需在提生产 MR 前确认 UAT 页面已做最终业务验收。

### 1.1 后续 push/MR 规则

当前没有执行任何 push。用户确认可以远程操作后，才从上述六个 worktree 分别 push 同名分支，并向各仓 `prod` 提 MR。不能直接向 `prod` 提交，也不能把同事的 `prod-chun0518` 等分支当作可写分支。

审核时以“每仓相对 `origin/prod` 只有上表 1 个提交”为准。若 push 前 `origin/prod` 又变化，先重新 fetch、重放并复验，不能直接拿 2026-08-18 的基线硬推。

## 2. 数据库 SQL

本次交付 SQL：

`docs/需求/14和生产环境对接报表取值/sql/01-prod-上线前只读核查.sql`

这个文件只有 `SELECT`，用途是：

1. 记录实际 MySQL 连接信息；
2. 核对 04 期的 5 张业务表是否都存在；
3. 核对 `centralized-procurement-export` 主模板和 15 条明细是否已经存在、是否重复。

为什么没有新的建表/写入 SQL：

- 03 报表数据落 ES，不落新的 MySQL 表；
- 06/06_2 从报表 ES、04 期台账和 order 既有接口聚合，不新增业务表；
- Excel 模板必须通过生产管理页面/API创建，让生产后端生成主键和审计字段，不能复制 UAT ID；
- 菜单、角色和 XXL-JOB 同样不能复制测试环境数字 ID。

只读 SQL 的 5 张前置表应全部返回 `table_exists=1`：

| 库 | 表 |
|---|---|
| `scm_source` | `sc_collection_daily_amount_ledger` |
| `scm_source` | `sc_coal_pit_daily_indicator` |
| `scm_source` | `sc_coal_pit_daily_indicator_item` |
| `scm_source` | `sc_price_trend` |
| `scm_order` | `to_central_purchase_daily_statistics` |

如果有表缺失，先停止本次发布，确认 04 期是否从未在生产执行；核对后再单独使用已经评审过的 `docs/需求/04和生产环境运维对接需求1-4/sql/02-prod-集采四页面业务表.sql`。不要在本次只读 SQL 中临时补 DDL，也不要删除重建已有表。

## 3. ES 与 Nacos

### 3.1 生产 ES 索引

必须由运维确认一个真实的生产物理索引名。AI 无生产权限，当前无法核实索引是否已存在，也不猜默认值。

硬性要求：

- 不能使用带 `_test` 或 `_uat` 的索引名；
- source、order、report 三份配置必须指向完全相同的物理索引；
- source 和 order 的 Model 默认允许创建索引，report 的 Model 明确 `createIndex=false`，因此先发布/启动写入侧，再发布 report；
- source 与 order 的 ES 字段 mapping 已核对一致；首次启动后仍要由运维导出实际 mapping 留档，再开始补数；
- 未确认三处配置一致前，不执行任何手工同步，也不启用定时任务。

### 3.2 Nacos 精确配置位置

namespace：`jdsn-prod`
group：`common`

| 应用 | Data ID | YAML 位置 | 要做的事 |
|---|---|---|---|
| source | `scm-source-web-prod.yaml` | `source.chase.es.centralizedProcurementReportIndex` | 设置为已确认的生产 ES 物理索引名 |
| order | `scm-order-web-prod.yaml` | `order.elastic.config.centralizedProcurementReportIndex` | 设置为同一个生产 ES 物理索引名 |
| report | `scm-report-web-prod.yaml` | `report.config.commonConfigs.source.settings.centralizedProcurementReportIndex` | 设置为同一个生产 ES 物理索引名 |
| source | `scm-source-web-prod.yaml` | `scm.feign.order.web` | 只确认既有配置存在且可访问生产 order，不新增、不复制 UAT 值 |

配置示意只表达键位，不代表实际索引名：

```yaml
# scm-source-web-prod.yaml
source:
  chase:
    es:
      centralizedProcurementReportIndex: <生产统一物理索引名>

# scm-order-web-prod.yaml
order:
  elastic:
    config:
      centralizedProcurementReportIndex: <同一个生产统一物理索引名>

# scm-report-web-prod.yaml
report:
  config:
    commonConfigs:
      source:
        settings:
          centralizedProcurementReportIndex: <同一个生产统一物理索引名>
```

变更要求：

1. 修改前保存三份 Nacos 历史版本/导出快照；
2. 只改上表指定键，不把 test/UAT 整段 YAML 复制到生产；
3. 发布后若应用不支持热刷新，按运维流程滚动重启对应服务；
4. 回传三处最终值和版本号/截图，必须能证明三值一致。

特别风险：report 代码在键缺失时会回退到 `index_centralized_procurement_report_test` 这个名字，所以 report 的生产键缺失是阻断项，不能依赖默认值启动上线。

## 4. Excel 导出模板

模板定义文件：

`docs/需求/14和生产环境对接报表取值/sql/00-导出模板定义.json`

该定义已通过 `scripts/export-template.sh validate`，共 15 列。2026-08-18 对 UAT 数据库只读反查得到的最终主配置为：

| 字段 | 生产要配置的值 |
|---|---|
| 模板编码 | `centralized-procurement-export` |
| 模板描述 | `集采管理业务统计报表导出` |
| 分组编码 | `报表查询` |
| 分组名称 | `报表查询` |
| 状态 | 启用（`1`） |
| 校验码列号 | 留空 |
| 是否启用校验码 | 否（`false`） |
| 文件名/单次数据上限 | 沿用页面默认值，不人工猜填 |

注意：早期 SQL 里曾用过 `source / 寻源模块`，但 UAT 当前有效模板已经是 `报表查询 / 报表查询`。本次以 UAT 只读反查的最终值为准。

执行方法：

1. 先运行只读 SQL；如果有效主模板是 0 条，在生产“导出 Excel 模板”页面按 JSON 新建；
2. 如果是 1 条，不新建，打开详情逐项对照 JSON；
3. 如果大于 1 条，停止并交开发处理重复，不自行删除；
4. 主模板和 15 条明细的内部 ID 全由生产系统生成；
5. 发布后从报表页实际下载，必须能打开、数据行数与当前查询一致、列数为 15、列顺序为 0～14。

禁止直接复制 UAT 的 `template_id/tmp_id`、创建人、创建时间或执行 INSERT SQL。

## 5. 菜单与权限

在生产“我的工作台（企业端）-报表查询”下新增或核对：

| 字段 | 值 |
|---|---|
| 菜单名称 | `集采管理业务统计报表` |
| URL | `/procurementScheme/index.html#/reportForms/centralizedProcurement` |
| 分组 | `workbench / 我的工作台（企业端）` |
| 父菜单 | `报表查询` |
| 状态 | 启用 |
| 排序、图标、打开方式 | 沿用生产同级普通报表菜单规则 |

先按菜单名和 URL 双重查询：不存在才新建，存在则核对，不重复创建。菜单 ID/编码由生产系统生成，不能复制 test 的 `M623` 或 UAT ID。

权限必须配给生产实际使用岗位/角色。不能照搬 test/UAT 角色 ID。配置负责人需回传“哪些生产岗位可见”。

06 集采门户、06_2 老驾驶舱和 02 日计划页面都使用现有入口，本次不新增它们的菜单。

## 6. XXL-JOB

2026-08-18 对 UAT 调度库只读核对到 6 个任务。生产应先按“任务描述 + 执行参数”查询，存在则核对/更新，不存在才新增；绝不能复制 UAT 的任务 ID、执行器 group 数字 ID 或注册地址。

共同配置：

- 调度类型：`CRON`
- 运行模式：`BEAN`
- JobHandler：`simpleJobHandler`
- 路由策略：`FIRST`
- 阻塞策略：`SERIAL_EXECUTION`
- 过期策略：`DO_NOTHING`
- 超时：`0`
- 失败重试：`0`
- 任务参数：空
- 报警邮箱：按生产规则；UAT 当前为空
- 初始状态：停用，完成第 8 节补数和第 9 节验收后再启用

| 执行器（按名称选，不复制 ID） | 任务描述 | UAT 负责人参考 | CRON | JobHandler 执行参数 |
|---|---|---|---|---|
| `scm-order-web`（订单中心） | 集采日统计服务 | `zyl` | `0 3 3 * * ?` | `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}` |
| `scm-source-web`（寻源模块） | 集采业务统计报表-非平台采购 | `yangzhuoran` | `0 10 3 * * ?` | `source-centralizedProcurementReportService-syncCentralizedProcurementData-{}` |
| `scm-source-web`（寻源模块） | 集采业务统计报表-招采平台 | `yangzhuoran` | `0 20 3 * * ?` | `source-centralizedProcurementReportService-syncZcData-{}` |
| `scm-source-web`（寻源模块） | 集采业务统计报表-煤炭SAP | `yangzhuoran` | `0 30 3 * * ?` | `source-centralizedProcurementReportService-syncMtData-{}` |
| `scm-source-web`（寻源模块） | 集采业务统计报表-机电四大类 | `yangzhuoran` | `0 40 3 * * ?` | `source-centralizedProcurementReportService-syncJdData-{}` |
| `scm-order-web`（订单中心） | 集采管理业务统计报表-云采 | `zyl` | `1 1 5 * * ?` | `order-centralizedProcurementReportService-syncCentralizedOrderToEs-{}` |

“负责人”字段如果生产要求填写当前值班/业务负责人，可按生产制度替换；表中值只是 UAT 实际配置参考。其余任务契约、CRON 和执行参数必须按表核对。

## 7. 代码发布与配置顺序

建议在同一变更窗口按以下顺序执行：

1. 变更前：运行只读 SQL，保存结果；确认 5 张表、导出模板现状和 UAT 最终验收。
2. ES：确认/创建生产物理索引方案，确定唯一索引名。
3. Nacos：保存快照，补齐三处索引键，核对 source 的 `scm.feign.order.web`。
4. Git：六个 MR 审核后合入各自 `prod`；记录 merge commit 和回退版本。
5. 后端：先发 `scm-source-all`、`scm-order-all`，确认应用健康和 ES mapping；再发 `scm-report-all`。
6. XXL-JOB：按第 6 节核对/创建 6 个任务，全部保持停用。
7. 配置：创建/核对 Excel 模板、菜单和生产岗位权限。
8. 前端：发布 `procurementScheme`、`hpc`、`cockpit` 三个工程。
9. 补数：按第 8 节覆盖 2026-01-01 至上线前一天。
10. 验收：按第 9 节完成接口、页面、导出、数字和幂等检查。
11. 启用任务：最后启用 6 个任务，首个自然调度日再复查执行日志和数据。

已核实的 Jenkins 事实：

- 后端发包 Job 有 `scm-source-all-prod`、`scm-order-all-prod`；生产 Web 服务部署由运维负责，现有资料没有可由当前账号使用的 `scm-source-web-prod/scm-order-web-prod`。
- 前端生产共享 Job 是 `scm-vue-statics-pro`。
- 已有资料确认参数 `PROJECT=procurementScheme` 和 `PROJECT=hpc`。
- `scm-vue-all-cockpit` 源码的模块名和部署上下文都是 `cockpit`，但现有文档没有保存生产 Jenkins 的可选参数截图。运维必须在 Job 参数页核对该工程对应值后再点，不把 `PROJECT=cockpit` 当作未经界面确认的既定事实。
- `scm-report-all` 的生产发包/部署 Job 名同样由运维在生产 Jenkins 核对，本文不猜任务名。

所有生产构建必须使用已合入的 `prod` 分支，不允许 Jenkins 直接构建个人交付分支。

## 8. 首次历史补数

五个日任务默认只处理前一天，不能代替首次历史补数。代码和配置发布完成、任务仍停用时，由有生产调用权限的人通过网关受控调用以下接口，时间范围统一为：

```json
{
  "startTime": "2026-01-01 00:00:00",
  "endTime": "<上线前一天> 23:59:59"
}
```

| 顺序 | 来源 | 接口 |
|---:|---|---|
| 1 | YC 云采 | `POST /d/business/order/centralizedProcurementReport/syncToEs` |
| 2 | FP 非平台 | `POST /e/business/source/centralizedProcurementReport/sync` |
| 3 | ZC 招采平台 | `POST /e/business/source/centralizedProcurementReport/syncZc` |
| 4 | MT 煤炭 SAP | `POST /e/business/source/centralizedProcurementReport/syncMt` |
| 5 | JD 机电四大类 | `POST /e/business/source/centralizedProcurementReport/syncJd` |

每一路单独执行、记录返回数量和耗时；失败时只重跑失败来源。不要把带日期的 JSON 塞进 AIM 的连字符执行参数，避免参数解析错误。

补完后按 `dataSource=YC/FP/ZC/MT/JD` 分组核对 ES 文档数、金额和最早/最晚时间。源数据不变化的情况下，再跑同一时间窗后总文档数不能增长；主键相同的数据应覆盖，以此验证幂等。

## 9. 生产验收

### 9.1 技术冒烟

- source、order、report 应用健康，日志无索引名为空、指向 test/UAT、mapping 冲突、Feign 连接失败。
- 三个 Nacos 键的最终值完全一致。
- ES 有且只有本次确认的生产索引，五个 `dataSource` 分组均可核对。
- 五个同步接口和 report 分页接口不再是 404/5xx。

### 9.2 页面与业务

- “集采管理业务统计报表”菜单对目标岗位可见；分页、板块/企业/供应商/编号/时间/来源等筛选有效。
- 报表导出文件能打开，行数与同条件查询一致，共 15 列，时间和中文描述正确。
- 集采门户首页不再显示假数；总额、集采额、集采率、板块排名、七品类、煤钢趋势能从生产数据还原。
- 老驾驶舱 `centerHeader/categoryAmount/situA/doRate` 四组新值可用，头部金额与七品类/右侧分项在同一口径下自洽。
- 滞后率为负时：柱形高度显示 0，右侧文字仍显示真实负百分比。
- 集采日计划录入：计划/响应/执行中/完成允许 0 且按整数处理；响应不能大于计划；执行中+完成不能大于响应；滞后数量只读并自动计算；错误提示不重复。

### 9.3 定时任务

- 启用前手工核对 6 个任务执行器、CRON、参数和停用状态。
- 首个自然调度日逐个查看日志；不能只看 XXL-JOB “成功”，还要核对实际写入/更新数量。
- “集采日统计服务”同一天重跑不能新增重复台账记录。
- 五路 ES 同步同一日期重跑后文档数不能无故增加。

## 10. 回退

出现严重问题时，按下面顺序处理：

1. 先停用本次 6 个 XXL-JOB，阻止继续写数据。
2. 前端回退到发布前静态版本；后端按各仓记录的发布前版本回退。
3. Nacos 用变更前快照恢复三处键，按运维流程滚动重启。
4. 新菜单可先撤销角色权限或停用，不物理删除。
5. 新导出模板可在管理页面停用，不直接删数据库记录。
6. ES 已写入的数据和索引先保留供排查，不在应急阶段执行删除索引或批量删除；确需清理时另开评审过的数据变更单。
7. 本次没有新建 MySQL 业务表，因此不存在本批 DDL 回滚；04 期前置表也不能随本次回退删除。

## 11. 运维回填清单

- [ ] 只读 SQL 已执行，5 张前置表结果全为 1；模板主/明细数量已回填。
- [ ] 生产 ES 物理索引名：`________________`；mapping 已留档。
- [ ] source/order/report 三处 Nacos 最终值一致，变更前快照和发布版本已留档。
- [ ] `scm.feign.order.web` 已确认存在且 source 可调用 order。
- [ ] 六个仓库 MR 的 prod merge commit 和发布前版本已记录。
- [ ] 三个后端已发布，健康检查通过。
- [ ] 六个 XXL-JOB 已核对/创建，补数前保持停用。
- [ ] Excel 模板为 1 主 + 15 明细，无重复字段/排序。
- [ ] 报表菜单和生产实际岗位权限已配置。
- [ ] `procurementScheme`、`hpc`、`cockpit` 三个前端工程均已发布；cockpit 的生产 `PROJECT` 参数已在 Jenkins 页面核实。
- [ ] 2026-01-01 至上线前一天的五路补数完成，按来源对账及幂等复跑通过。
- [ ] 页面、导出、门户、驾驶舱、日计划表单均验收通过。
- [ ] 六个任务已启用，首个自然调度日复查通过。

## 12. 证据来源

- 分支与提交：六个本地 worktree 的 `git status/log/diff`，并于 2026-08-18 对远端执行只读 fetch 后复核 `origin/prod`。
- UAT 定时任务：`scm_xxljob_uat.xxl_job_info` 与 `xxl_job_group` 的只读查询结果。
- UAT 导出模板：`scm_ubm_uat.scm_simple_template`、`scm_simple_template_sub` 的只读反查；模板实际导出测试见 `docs/需求/03采集管理业业务统计报表/测试反馈/30-导出模板测试报告-codex.md`。
- Nacos 键契约：source/order/report 三仓配置类和 ES Model，以及 `docs/部署/集采业务管理报表和取值/20-UAT部署执行-oc.md`。
- 菜单与补数接口：`docs/部署/集采业务管理报表和取值/20-UAT部署执行-oc.md` 和五个 Controller 实现。
- 04 期表结构：`docs/需求/04和生产环境运维对接需求1-4/sql/02-prod-集采四页面业务表.sql`。

未核实项已明确留空：生产 ES 实际索引名、生产配置当前值、生产 Jenkins 中 cockpit/report 的准确参数或 Job 名、生产实际岗位/角色。未经生产只读证据，不得用 test/UAT 默认值补空。
