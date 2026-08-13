# 集采管理业务统计报表 + 取值需求 · UAT 部署执行清单

> 日期：2026-08-11 ｜ 工具：oc ｜ 状态：**方案已由 codex 核清（`10-UAT部署方案-codex.md`），本文是照着做的执行清单；全部现状 2026-08-11 实查**
> 下一步：用户按第 2 节清单操作；AI 负责交付分支准备、部署后冒烟、历史补数、数据对账。
> 本文配合 `10-UAT部署方案-codex.md` 使用：方案讲"为什么这么做"，本文讲"每步点哪里、填什么"。

---

## 0. 先说结论（大白话）

这次把两件事一起上 UAT：

1. **03 集采管理业务统计报表**：五个来源（非平台/招采/云采/煤炭SAP/机电）的数据汇总进 ES，报表页能查能导出。
2. **06 取值需求**：集采门户首页的汇总数字（各集团集采率、煤炭钢材趋势、坑口指标）从旧缓存改成实时查真数据。

**要动 4 个仓库的代码**（source 后端、report 后端、采购方案前端、HPC 前端）；**order 后端不用动代码**（同事的 `prod-chun0518` 分支已经全部在 UAT 上了，YC 云采写 ES 的代码 UAT 与 test 完全一致）。

**不用做的事**（核查过）：
- ✅ 不建表：UAT 的 5 张业务表全部已存在且有数据
- ✅ 不配导出模板：UAT 的日金额 9 列、坑口 14 列模板已启用
- ✅ 不建 ES 索引：`index_centralized_procurement_report_uat` 已存在，19 字段 mapping 齐全，当前 0 条数据
- ✅ 不重建 Job 216「集采日统计服务」：UAT 已有且最近 5 次执行成功
- ✅ 不整段复制同事给的 `_test` 配置：只加 3 个索引键中缺的 2 处

**要做的事**：合 4 个仓代码 → 补 Nacos 2 处 → 点 Jenkins 4 个任务 → 新建 5 个定时任务 → 配菜单 → 历史补数（AI 做）→ 验收。

---

## 1. 现状核查结果（2026-08-11 实查）

### 1.1 代码差异（哪些仓要动）

| 仓库 | 结论 | 证据 |
|---|---|---|
| `scm-source-all` | **要交付**：03 FP/ZC/MT/JD 同步 + 06 overview/kengk/mt/gc | uat=`be490ec24`，test 领先 23 个 07-21 后提交 |
| `scm-report-all` | **要交付**：03 报表分页/筛选/导出 | uat=`7d70d04`，缺 `92d5b37`/`5007e07`/`e85640d`/`af8ad36` |
| `scm-vue-all-procurementscheme` | **要交付**：03 报表页面（2 个文件） | uat=`cf64c4f5` 无 `centralizedProcurementReport` 目录 |
| `scm-vue-hpc` | **要交付**：06 首页取值（4 个业务提交） | uat=`f42423e`，缺 `292fbcd`/`4957b71`/`7e151ce`/`f0ffe03` |
| `scm-order-all` | **不交付代码** | `git log origin/uat..origin/prod-chun0518` 为空；YC 相关文件 uat 与 test diff=0 |

**注意**：需求.md 里写"分支合uat：order 服务 prod-chun0518、source 服务 prod-chun"——实测两个分支都不需要直接合：
- order `prod-chun0518` 已全部在 UAT（`merge-base --is-ancestor` 通过）。
- source `prod-chun` 的价格趋势代码 UAT 已通过 `7b105a8e7` 收口带入（7 个文件与 prod-chun 内容一致）；**直接合这个旧分支反而会把 UAT 后续的日金额/坑口文件显示成删除**。只带 03/06 新增部分。

### 1.2 数据库与导出模板（全部不动）

5 张表已存在：`to_central_purchase_daily_statistics`(13 行)、`sc_collection_daily_amount_ledger`(3)、`sc_coal_pit_daily_indicator`(2)、`_item`(7)、`sc_price_trend`(2)。模板 `collection-daily-ledger-export`(9 列)、`coal-pit-daily-export`(14 列) 已启用。

**⚠️ SQL 一条都不执行**：需求.md 里同事贴的两张表 UAT 已有；03 的 `99-test-JD板块编码修正.sql` 是 test 数据修正脚本，禁止执行；01 的 `99-cockpit-switch-PENDING.sql` 会切别的驾驶舱链路，未确认禁止执行。

### 1.3 ES

`index_centralized_procurement_report_uat`：open/yellow，19 字段 mapping 齐全，**0 条数据**。不建不删，部署后补数据。

### 1.4 Nacos（**要配 2 处**，namespace `scm-jdsn-uat`，group `common`）

oc 已用 API 实查（codex 当时未能确认，本文为准）：

| 服务 | 读取路径 | UAT 现状 | 动作 |
|---|---|---|---|
| source | `source.chase.es.centralizedProcurementReportIndex` | **缺**（test 有） | 加 `index_centralized_procurement_report_uat` |
| order | `order.elastic.config.centralizedProcurementReportIndex` | **已有** `index_centralized_procurement_report_uat` | 不动 |
| report | `report.config.commonConfigs.source.settings.centralizedProcurementReportIndex` | **缺** | 加 `index_centralized_procurement_report_uat` |

> ⚠️ report 是**阻断项**：代码默认值是 `index_centralized_procurement_report_test`（`SourceChaseConfig.java:99`），UAT 漏配会误读 test 索引。
> 只加这一项，**不要整段复制**需求.md 里同事给的 `_test` 配置（那是 test 的，orderIndex/tradeDataReportIndex 等全部是 `_test` 值）。

### 1.5 定时任务（UAT 调度中心）

**保留**：Job 216 集采日统计服务 `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}`（RUNNING，近 5 次成功）＝需求里"同步云采平台计划数据"。

**新建 5 个**（先建 STOP，补数验收后再启用；ID 让 UAT 自动生成，不抄 test 的 239~244）：

统一设置：CRON、`simpleJobHandler`、FIRST、DO_NOTHING、SERIAL_EXECUTION、超时 0/重试 0。

| 执行器 | 描述 | Cron | 参数 |
|---|---|---|---|
| 订单中心(group 6) | 集采管理业务统计报表-云采 | `1 1 5 * * ?` | `order-centralizedProcurementReportService-syncCentralizedOrderToEs-{}` |
| 寻源模块(group 2) | 集采业务统计报表-非平台采购 | `0 10 3 * * ?` | `source-centralizedProcurementReportService-syncCentralizedProcurementData-{}` |
| 寻源模块(group 2) | 集采业务统计报表-招采平台 | `0 20 3 * * ?` | `source-centralizedProcurementReportService-syncZcData-{}` |
| 寻源模块(group 2) | 集采业务统计报表-煤炭SAP | `0 30 3 * * ?` | `source-centralizedProcurementReportService-syncMtData-{}` |
| 寻源模块(group 2) | 集采业务统计报表-机电四大类 | `0 40 3 * * ?` | `source-centralizedProcurementReportService-syncJdData-{}` |

任务参数只能传 `{}`（每天同步前一天）；指定日期补跑走 HTTP 手动接口。

### 1.6 菜单

test 已有「集采管理业务统计报表」→ `/procurementScheme/index.html#/reportForms/centralizedProcurement`；**UAT 按菜单名和 URL 查询均为 0 条**，需补配。

---

## 2. 你要做的操作清单（按顺序）

> 红线：远程 git 一律你操作；Jenkins 构建按钮只有你能点；AI 不碰远程、不点构建。

### 第 1 步：授权 AI 准备 4 个交付分支

跟我说一声"可以 fetch 了"，我来：fetch 5 个仓 → 重核最新 test/uat/同事分支 → 在隔离 worktree 从各仓最新 `origin/uat` 建 4 个干净交付分支（source/report/procurementscheme/hpc；order 不建）→ 编译/构建/白名单/敏感文件检查 → 给你看交付清单。**先不要整分支 `uat merge test`**（会带进 06_2、环境配置等无关改动）。

### 第 2 步：推 4 个分支 + 提 MR（你操作）

我确认分支干净后，你推送并到 GitLab 提 4 个 MR，目标 `uat`，**审核人：兰宇**。

给兰宇的逐字话术：

> 这次发 UAT 是"集采管理业务统计报表 + 集采首页取值"。共 4 个 MR：source 后端、report 后端、采购方案前端、HPC 前端，都是从最新 UAT 拉的干净交付分支，只带 03/06 业务文件；order 的同事分支已经在 UAT，不再重复合。麻烦审核合入 UAT。

### 第 3 步：配 Nacos（你操作，2 处）

按 1.4 表：`scm-source-web-uat.yaml` 的 `source.chase.es:` 段、`scm-report-web-uat.yaml` 的 `report.config.commonConfigs.source.settings:` 段各加一行索引键。改前在 Nacos 留历史版本点，只加这一项，发布后如配置不热刷新则重启服务。

### 第 4 步：点 Jenkins（你操作，4 个任务）

| 顺序 | 任务 | 核对 |
|---|---|---|
| 1 | `scm-source-all-uat` | `GIT_BRANCH=uat`、VERSION 带 UAT；等下游 `scm-source-web-uat` 也成功 |
| 2 | `scm-report-all-uat` | 同上，等 `scm-report-web-uat` |
| 3 | `scm-vue-statics-uat` | `PROJECT=procurementScheme`、`GIT_BRANCH=uat`，按 PROJECT 找自己的构建号 |
| 4 | `scm-vue-statics-uat` | `PROJECT=hpc`、`GIT_BRANCH=uat`（共享 Job，lastBuild 可能是别人的） |

order 无代码 MR：若 Nacos 配置改了且不热刷新才需重启 `scm-order-web-uat`。
⚠️ `*-all` 绿 ≠ 部署完成，必须等 `*-web` 也绿、Pod Ready。

### 第 5 步：建 5 个定时任务（你操作）

按 1.5 表在 UAT 调度中心新建（先 STOP）。建完告诉我。

### 第 6 步：配菜单（发给张雨）

> 麻烦在 UAT"我的工作台（企业端）-报表查询"下新增"集采管理业务统计报表"，URL 配 `/procurementScheme/index.html#/reportForms/centralizedProcurement`，岗位/角色权限照 test 的 M623 和同级报表配置。配好后告诉我可见岗位，我做页面验收。

### 第 7 步：告诉我"部署和配置完成"，AI 接手（我来做）

1. **空数据冒烟**：`overview`、`centralizedProcurementPageList`、`kengk/mt/gc` 不再是 404，页面资源更新。
2. **历史补数**（2026-01-01 00:00:00 → 部署日前一天 23:59:59，按自然月切窗、逐来源跑、逐个对账）：

| 顺序 | 来源 | 接口 |
|---|---:|---|
| 1 | YC 云采 | `POST /d/business/order/centralizedProcurementReport/syncToEs` |
| 2 | FP 非平台 | `POST /e/business/source/centralizedProcurementReport/sync` |
| 3 | ZC 招采 | `POST /e/business/source/centralizedProcurementReport/syncZc` |
| 4 | MT 煤炭SAP | `POST /e/business/source/centralizedProcurementReport/syncMt` |
| 5 | JD 机电 | `POST /e/business/source/centralizedProcurementReport/syncJd` |

3. **对账**：源库行数 vs ES `dataSource` 文档数 vs taxTotal 合计，小窗口重跑不增文档。
4. **验收**：报表分页/筛选/15 列导出、overview 金额与 ES 独立聚合逐项一致、mt/gc 固定 12 个月空点显示 `--`。
5. 验收通过后通知你**把 5 个任务从 STOP 改 RUNNING**，次日查 trigger/handle 双 200。

---

## 3. 待确认事项（先问同事）

1. **06_2（驾驶舱取值需求2）是否本次一起上？** 需求.md 只列了 03 和 06，但 test 上还混着 06_2 的提交（order `6830f6a90`/`dc47dbf16`、procurementscheme `47493992`、source `1a88ac1bd`，都已在 test）。本文按 codex 方案**只带 03+06、排除 06_2**；如果你要一起上，跟我说一声，我把 06_2 的文件加进交付分支。

> 逐字话术（问产品/同事）："这次 UAT 部署的范围我按 03 报表 + 06 取值来准备的；test 上还有 06_2 驾驶舱那批改动（日计划四个率、类目前缀匹配），这次要不要一起上 UAT？"

2. **source 的 `prod-chun` 分支不要直接合**（理由见 1.1），如果有同事坚持要合，先让他看 codex 方案 §3.3。

---

## 4. 回退方案（万一要回）

| 模块 | 发布前 UAT 基线 |
|---|---|
| source | `be490ec24` |
| report | `7d70d04` |
| procurementScheme | `cf64c4f5` |
| HPC | `f42423e` |
| order | `655e56e8c`（本次不改代码） |

- Nacos 恢复历史版本；停用 5 个新任务；**不要停 Job 216**；临时隐藏菜单。
- 数据回退最安全是不删 ES（停任务+回代码即可）；确要清理先记总数和 `dataSource/bookTime` 分布，按来源/时间窗精确删，禁止删整个索引（删除需另行授权）。
- 本次没执行 SQL，无表结构回退。

---

## 5. 证据索引

- 方案全文（含逐仓提交清单、预演结果）：`10-UAT部署方案-codex.md`
- 03 交接：`docs/需求/03采集管理业业务统计报表/20-开发交接-cc.md`、`20-开发交接-codex.md`
- 06 口径：`docs/需求/06取值需求/13-需求定稿-开发基线-cc.md`
- 三处配置读取代码：source `SourceChaseConfig.java:97`、order `OrderESConfig.java:40`、report `SourceChaseConfig.java:99`
- 补数接口：order `CentralizedProcurementReportController.java:24`（`/d/business/order/centralizedProcurementReport`）、source `CentralizedProcurementReportController.java`
- 现状数据：oc 2026-08-11 Nacos API 实查三份 uat yaml；XXL-JOB uat/test 实查（216 已存在、缺 5 个）；ES `_count`=0、mapping 19 字段
