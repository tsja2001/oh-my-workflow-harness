# 集采业务管理报表和取值 · UAT 部署方案

> 日期：2026-08-11
>
> 工具：codex
>
> 当前状态：已完成代码、UAT 数据库、ES、调度、菜单、Jenkins 与 K8s 的只读核验；尚未执行 `fetch`、远程 Git、UAT 配置修改、部署或数据同步。
>
> 下一步：用户授权 AI 刷新远程分支并准备 4 个仓库的本地 UAT 交付分支；复核差异后再单独授权推送和提 MR。

---

## 一、先说结论

这次不能把任何一个仓库的 `test` 整段直接合到 `uat`。`test` 中混有 06_2、日计划修复、环境配置和其他业务，直接合会夹带无关改动。

正确做法是：从各仓库最新 `origin/uat` 新开干净交付分支，只提取 03 和 06 的业务代码，再补 UAT 配置、菜单、调度任务和历史数据。

本次最终动作如下：

| 项目 | 结论 |
|---|---|
| `scm-source-all` | **需要交付**：03 的 FP/ZC/MT/JD 统一 ES 同步 + 06 首页汇总和 `kengk/mt/gc` 接台账 |
| `scm-report-all` | **需要交付**：03 的报表分页、筛选和 Excel 导出 |
| `scm-vue-all-procurementscheme` | **需要交付**：03 的“集采管理业务统计报表”页面和固定路由 |
| `scm-vue-hpc` | **需要交付**：06 集采首页真实取值、错误态、图表和样式收口 |
| `scm-order-all` | **不用再合代码**：`origin/prod-chun0518` 已是 `origin/uat` 祖先；03 的 YC 写 ES 代码在 UAT 与 test 完全一致，UAT 当前也已部署该代码 |
| `source/prod-chun` | **不要再直接合**：该分支的价格趋势 3 个提交已由 UAT 收口提交等价带入；直接合旧分支会把 UAT 后续台账文件显示成删除/回退 |
| MySQL DDL | **本次一条都不执行**：需求里提到的 5 张 UAT 业务表全部已存在且已有数据 |
| 导出模板 SQL | **不执行**：UAT 的日金额模板 9 列、坑口模板 14 列均已存在并启用 |
| ES | **不用新建索引**：`index_centralized_procurement_report_uat` 已存在，19 个字段 mapping 已齐，但当前文档数为 0 |
| Nacos | source、order、report 三个服务必须最终都指向同一个 `_uat` 索引；不能把需求中的整段 `_test` 配置复制到 UAT |
| 定时任务 | “同步云采平台计划数据”已在 UAT 运行且最近 5 次成功；还需新增 1 个 YC 写 ES 任务和 4 个 source 写 ES 任务 |
| 菜单 | test 已有，UAT 尚无，需要在 UAT 菜单管理中补配 |
| 历史数据 | 五路数据从 **2026-01-01 00:00:00** 补到部署日前一天；补数后再开启新任务 |

一句大白话：**代码只带 4 个仓，order 不重复合；SQL 不跑；三个服务指同一个 UAT ES；补 5 个任务和菜单；最后把 2026 年历史数据灌入空索引并对账。**

---

## 二、本次到底包含什么

### 2.1 包含

1. 03 集采管理业务统计报表：
   - FP：非平台录入；
   - ZC：招采平台；
   - YC：云采订单；
   - MT：煤炭 SAP；
   - JD：机电四大类日金额台账；
   - report 查询/导出；
   - procurementScheme 报表页面和菜单。
2. 06 集采首页取值：
   - 首页 `overview` 汇总接口；
   - HPC 首页真实数据、失败态、金额精度和最终样式；
   - `kengk/mt/gc` 三个既有接口改读坑口/价格趋势台账；
   - MT 编码、JD 组织编码、类目前缀和各集团率等截至 `origin/test@620391263` 的 06 收口修复。
3. 支撑上述功能的 UAT ES、Nacos、调度、菜单和历史补数。

### 2.2 明确不包含

- `docs/需求/06_2取值需求2-驾驶舱取值需求`，包括 `centerHeader/categoryAmount/situA/doRate` 和日计划四个率的新口径；这是单独需求。
- `scm-order-all` 本地未推送的 `beab9ac09`，以及 procurementScheme 的 `47493992`；它们属于 06_2 日计划改动。
- source 工作区现有未提交的 `SourceCollectionServiceImpl.java`。
- 任一前端的 `public/statics/config.js`、token、环境地址或 `4773532/42a552d` 的依赖锁文件历史。
- `scm-source-ssc/.../PriceTrendController.java` 在 test/UAT 间的删除入参差异；UAT 版本更新，本次 06 cockpit 不依赖修改该 Controller，必须保留 UAT 实现。
- `docs/需求/03采集管理业业务统计报表/sql/99-test-JD板块编码修正.sql`，它是 test 数据修正脚本。
- `docs/需求/01台账/sql/99-cockpit-switch-PENDING.sql`，它会切换其他驾驶舱金额链路，未经产品/领导确认不能执行。
- 生产环境的任何动作。

### 2.3 历史补数为什么从 2026-01-01 开始

03 早期答复曾写“首次同步从 2026-07-01 开始”，见 `docs/需求/03采集管理业业务统计报表/12-问题答复.md:7`；但后续 03 实际测试已经按 2026-01-01 补过 FP/ZC/MT/JD，见同目录 `20-开发交接-cc.md:163、294、434` 和 `30-测试报告-codex.md:17、32`。

更重要的是，06 定稿明确“年度/累计＝从 2026-01-01 到查询日前一天”，见 `docs/需求/06取值需求/13-需求定稿-开发基线-cc.md:66-69`。这次 03 与 06 一起发，所以历史补数必须按后来的组合口径从 2026-01-01 开始，否则 06 年度金额天然少 1～6 月。

---

## 三、2026-08-11 核实到的 UAT 现状

### 3.1 五态总表

| 范围 | 已开发 | 已配置 | 已部署 UAT | 已有数据 | 已验收 |
|---|---:|---:|---:|---:|---:|
| order 云采日计划台账 | 是 | 是 | 是 | 是 | 任务最近 5 次成功 |
| order 的 YC 写统一 ES | 是 | Nacos 待人工复核 | 是 | 否，UAT ES 仍为 0 | 否 |
| source 的 FP/ZC/MT/JD 写统一 ES | 是 | 待配置/复核 | 否 | 否 | 否 |
| report 查询与导出 | 是 | 待配置/复核 | 否 | 无数据可查 | 否 |
| procurementScheme 报表页面 | 是 | UAT 菜单缺失 | 否 | — | 否 |
| 06 overview + cockpit | 是 | 共用 source 配置 | 否 | ES 为空；台账有少量数据 | 否 |
| HPC 首页 | 是 | 无新增后端配置 | 否 | — | 否 |

### 3.2 Git 与运行版本

> 下表 Git 引用来自本机已有远端缓存；本轮因没有用户对远程 Git 的当次授权，没有执行 `fetch`。正式开交付分支前必须先刷新并重核一次。

| 仓库 | 本机远端快照 | UAT 运行证据 | 判断 |
|---|---|---|---|
| source | test=`620391263`；uat=`be490ec24`；prod-chun=`a8045d94b` | Jenkins `scm-source-all-uat #479` 构建 `be490ec24`；K8s 镜像 `20260731231500` Ready | 03/06 未部署，UAT `overview` 实调为 404 |
| order | test=`dc47dbf16`；uat=`655e56e8c`；prod-chun0518=`6f15ee11c` | Jenkins `scm-order-all-uat #212` 构建 `655e56e8c`；K8s 镜像 `20260805172422` Ready | 同事分支已进入 UAT；03 YC 相关文件与 test 无差异 |
| report | test=`af8ad36`；uat=`7d70d04` | Jenkins `scm-report-all-uat #41` 仍构建 `7d70d04`；K8s 镜像 `20260731232615` Ready | 03 查询/导出未部署 |
| procurementScheme | test=`47493992`；uat=`cf64c4f5` | UAT 静态站最近对应构建 `#998`，检出 `cf64c4f5` | 03 页面未部署 |
| HPC | test=`f0ffe03`；uat=`f42423e` | UAT 最近 80 个共享静态构建中未找到 `PROJECT=hpc` | 06 改动不在 UAT 分支，需单独部署 |

### 3.3 同事两个分支的处理结论

#### order `prod-chun0518`

- `git merge-base --is-ancestor origin/prod-chun0518 origin/uat` 返回成功；
- `origin/uat..origin/prod-chun0518` 没有提交；
- 03 YC 的 Controller/Service/Impl/Model/Repository/Config 在 `origin/uat` 与 `origin/test` 的内容差异为 0；
- UAT 运行版本 `655e56e8c` 已包含 `1f6fd0093 集采管理业务统计报表-云采`。

结论：**不要再合这个分支，也不需要 order 代码 MR。**

#### source `prod-chun`

- 分支上只有价格趋势 V1/V2/V3 三个未直接成为 UAT 祖先的提交；
- UAT 已通过 `7b105a8e7 feat(source): 增加台账功能` 收口相同价格趋势代码；价格趋势 7 个业务文件与 `prod-chun` 内容一致；
- `prod-chun` 比 UAT 老，若按整棵树比较，会把 UAT 后续日金额、坑口等文件显示成删除。

结论：**不要再直接合 `prod-chun`；保留 UAT 已有台账收口代码，只带 03/06 新增部分。**

### 3.4 数据库与导出模板

只读查询 UAT 得到：

| 库 | 表 | 当前估算行数 | 本次动作 |
|---|---|---:|---|
| `scm_order_uat` | `to_central_purchase_daily_statistics` | 13 | 已存在，不建表 |
| `scm_source_uat` | `sc_collection_daily_amount_ledger` | 3 | 已存在，不建表 |
| `scm_source_uat` | `sc_coal_pit_daily_indicator` | 2 | 已存在，不建表 |
| `scm_source_uat` | `sc_coal_pit_daily_indicator_item` | 7 | 已存在，不建表 |
| `scm_source_uat` | `sc_price_trend` | 2 | 已存在，不建表 |

导出模板：

| 模板编码 | 状态 | 有效列数 | 本次动作 |
|---|---:|---:|---|
| `collection-daily-ledger-export` | 启用 | 9 | 不执行模板 SQL |
| `coal-pit-daily-export` | 启用 | 14 | 不执行模板 SQL |

### 3.5 ES

- 统一 UAT 索引：`index_centralized_procurement_report_uat`；
- health=`yellow`、status=`open`，mapping 和 count 查询均成功；yellow 的具体副本原因本轮未查，不在本次发版中擅自处理；
- 当前文档数：0；
- mapping 已有 19 个字段，包含 `bookTime/date`、`taxTotal/double`、`isCentralized/integer`、`dataSource/keyword` 等完整合同。

结论：**不要创建、删除或重建索引；只需要让三个服务都指向它并补数据。**

### 3.6 调度任务

UAT 已有：

| UAT Job | 作用 | Cron | 状态 | 运行证据 |
|---:|---|---|---|---|
| 216 | 同步云采平台计划数据到日计划台账 | `0 3 3 * * ?` | RUNNING | 2026-08-07～08-11 最近 5 次 trigger/handle 均为 200 |

UAT 缺少：

- YC 云采订单写统一 ES；
- FP 非平台录入写统一 ES；
- ZC 招采平台写统一 ES；
- MT 煤炭 SAP 写统一 ES；
- JD 机电四大类写统一 ES。

### 3.7 菜单

- test 已有菜单 `M623 集采管理业务统计报表`；
- URL 为 `/procurementScheme/index.html#/reportForms/centralizedProcurement`；
- UAT 按菜单名和 URL 查询均为 0 条。

---

## 四、代码应怎样准备

### 4.1 总原则

1. 用户先授权 AI 执行只读 `fetch`；
2. 每个仓库从最新 `origin/uat` 新开干净交付分支；
3. 现有工作区有其他人的未提交修改，准备分支时使用隔离 worktree，不在当前目录硬切分支；
4. 只带白名单业务文件/提交；
5. 编译、前端生产构建、差异白名单和敏感文件检查通过后，再让用户单独授权 push；
6. MR 目标都是 `uat`，审核人按团队规矩填兰宇。

### 4.2 source：03 + 06 后端

推荐做法不是逐个硬 cherry-pick 03 的平行开发提交。03 的 ZC 与 MT/JD 曾在平行分支改同三个大文件，直接逐个摘会冲突。

已预演可行的干净方法：

1. 从最新 UAT 建交付分支；
2. 先把 `7f37aca32` 时点 03 的 6 个最终业务文件做成一个快照提交：Config、Controller、Model、Repository、Service、ServiceImpl；
3. 再按顺序提取 06 的 8 个提交：

```text
ade85c7f6  feat: 完成取值基础查询
1f419cc84  feat: 驾驶舱接入台账
759884d47  fix: 拼写错误
89be56b57  fix: 完善集采首页取值
2fc0a927c  fix: 轴承2502精确匹配
77f00a27c  fix: JD同步按机电公司组织编码筛选
830771811  fix: 云采改为前缀匹配
620391263  fix: 修改取值-各集团率的分母
```

这一方案此前在 UAT 基线 `be490ec24` 上预演无冲突，13 个目标业务文件与 test 最终版本一致，隔离编译 0 错误。正式操作仍要在 fetch 后对最新 UAT 重跑验证。

必须排除：

- 当前工作区未提交的 `SourceCollectionServiceImpl.java`；
- 06_2 提交；
- `PriceTrendController.java` 的 test 旧入参形式；
- 任意配置文件中的环境值。

### 4.3 report：03 查询/导出

从最新 UAT 依次提取：

```text
92d5b37  feat: 集采业务统计报表
e85640d  feat: 报表增加查询条件
```

目标只有 5 个 Java 文件：SourceChaseConfig、SourceMetaQueryController、MetaModel、Service、ServiceImpl。

### 4.4 procurementScheme：03 报表页面

不要直接提取整段 test 历史，因为其中含 `public/statics/config.js`、依赖锁、06_2 日计划和其他页面。

从 `origin/test` 只取最终版本的两个文件，形成一个干净提交：

```text
src/router/index.js
src/views/reportForms/centralizedProcurementReport/index.vue
```

最终路由必须位于通用 `/reportForms/:purchaseRepot` 之前。

### 4.5 HPC：06 首页

从最新 UAT 依次提取下面 4 个业务提交：

```text
292fbcd  feat: 完善集采首页展示
4957b71  feat: 首页增加平台总交易额
7e151ce  fix: 修改取值二级集团集采率排名统计图样式
f0ffe03  fix: 修改取值样式
```

不要带：

- `4773532 fix: 修复前端依赖安装`；
- merge 提交 `42a552d`；
- `public/statics/config.js`。

上述 4 提交此前已在 UAT 基线预演无冲突，生产构建通过；fetch 后仍需重跑。

### 4.6 order：不做代码分支

order 只做 Nacos 核对、缺失的 ES 同步任务、历史补数和验收。只有在 Nacos 实际发生修改且配置刷新不可靠时，才重启现有 UAT order 服务，不创建代码 MR。

---

## 五、SQL 逐条判断

| 来源 | SQL/对象 | 决定 | 原因 |
|---|---|---|---|
| 本部署需求 | `CREATE TABLE to_central_purchase_daily_statistics` | **不执行** | UAT 表已存在且有 13 行；原 SQL 没有 `IF NOT EXISTS`，执行会直接报错 |
| 本部署需求 | `CREATE TABLE sc_price_trend` | **不执行** | UAT 表已存在且有 2 行 |
| 01 台账 | 日金额表 DDL | **不执行** | UAT 表已存在且有数据 |
| 01 台账 | 日金额导出模板 | **不执行** | UAT 已启用，9 列完整 |
| 02 台账 | 坑口主/明细表 DDL | **不执行** | UAT 两张表均已存在且有数据 |
| 02 台账 | 坑口导出模板 | **不执行** | UAT 已启用，14 列完整 |
| 03 | `99-test-JD板块编码修正.sql` | **禁止执行** | 文件名和内容均是 test 数据修正，不是 UAT 发布 SQL |
| 01 | `99-cockpit-switch-PENDING.sql` | **禁止执行** | 它切换 06 本期不包含的其他驾驶舱链路，且文档要求产品/领导确认 |
| 02 | test 演示数据 | **禁止执行** | UAT 已有自己的坑口/价格数据，本期不造共享演示数据 |

结论：**这次没有 SQL 包交给 UAT 运维执行。**

---

## 六、Nacos 与 ES 配置

### 6.1 只改/核对三个业务键

namespace=`scm-jdsn-uat`，group=`common`。在 Nacos 页面分别找到现有相邻键，不按 dataId 名字猜位置：source/order 找各自已有 ES 配置，report 找 `tradeDataMateIndex`。

| 服务 | Java 实际读取路径 | UAT 目标值 |
|---|---|---|
| source | `source.chase.es.centralizedProcurementReportIndex` | `index_centralized_procurement_report_uat` |
| order | `order.elastic.config.centralizedProcurementReportIndex` | `index_centralized_procurement_report_uat` |
| report | `report.config.commonConfigs.source.settings.centralizedProcurementReportIndex` | `index_centralized_procurement_report_uat` |

处理规则：

1. 已经是目标值：不改，只截图/记录核验；
2. 缺失或不是目标值：只增改这一项；
3. 修改前使用 Nacos 自带历史版本能力保留回退点；
4. 发布后重启对应服务，再用新接口和 ES 实际读写验证；
5. report 代码有 `_test` 默认值，UAT 若漏配可能误读 test，因此 report 配置是阻断项。

### 6.2 需求中那段 order 配置不能整段复制

原需求里的 `orderIndex`、`orderDelay...`、`tradeDataReportIndex` 等全部是 `_test`。UAT 只需核对/增加 `centralizedProcurementReportIndex`，其余已有 UAT 值保持原样。

### 6.3 当前无法完全自动确认 Nacos 的说明

本轮只读工具可以打开三个 UAT 应用配置，但提取到的只是公共数据库/Redis键，没有解析出业务 ES 段；因此本文不把“该键已存在/不存在”当事实。必须由用户在 Nacos 页面按完整属性名搜索并确认，确认结果再由 AI复核。

---

## 七、定时任务配置

### 7.1 保留现有任务

UAT Job 216 不重建、不改 Cron：

```text
描述：集采日统计服务
执行器：订单中心（group 6）
Cron：0 3 3 * * ?
Handler：simpleJobHandler
参数：order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}
状态：RUNNING
```

它就是需求中“同步云采平台计划数据”。最近 5 次执行均成功。

### 7.2 新增 5 个任务

先按 STOP 新建，完成历史补数和对账后再启用。任务 ID 让 UAT 自动生成，不复制 test 的 239～244。

统一设置：

```text
schedule_type：CRON
executor_handler：simpleJobHandler
executor_route_strategy：FIRST
misfire_strategy：DO_NOTHING
executor_block_strategy：SERIAL_EXECUTION
executor_timeout：0
executor_fail_retry_count：0
```

| 执行器 | 描述 | Cron | 参数 |
|---|---|---|---|
| 订单中心，group 6 | 集采管理业务统计报表-云采 | `1 1 5 * * ?` | `order-centralizedProcurementReportService-syncCentralizedOrderToEs-{}` |
| 寻源模块，group 2 | 集采业务统计报表-非平台采购 | `0 10 3 * * ?` | `source-centralizedProcurementReportService-syncCentralizedProcurementData-{}` |
| 寻源模块，group 2 | 集采业务统计报表-招采平台 | `0 20 3 * * ?` | `source-centralizedProcurementReportService-syncZcData-{}` |
| 寻源模块，group 2 | 集采业务统计报表-煤炭SAP | `0 30 3 * * ?` | `source-centralizedProcurementReportService-syncMtData-{}` |
| 寻源模块，group 2 | 集采业务统计报表-机电四大类 | `0 40 3 * * ?` | `source-centralizedProcurementReportService-syncJdData-{}` |

任务参数只能传 `{}`，表示每天同步前一天。不要把带短横线的日期塞进 AIM 参数；指定日期补跑走 HTTP 手动接口。

---

## 八、完整执行顺序

### 阶段 A：代码准备与评审

1. 用户授权 AI 对 5 个相关仓库执行 `fetch`；
2. AI 重核最新 test/UAT/同事分支关系；
3. AI 在隔离 worktree 中准备 source、report、procurementScheme、HPC 四个本地 UAT 交付分支；order 只复核，不建分支；
4. AI 完成后端隔离编译、两个前端生产构建、业务文件白名单、敏感配置和 merge-tree 检查；
5. 用户查看交付清单后，再当次授权 AI push；
6. 用户在 GitLab 提 4 个 MR，目标 `uat`，审核人兰宇。

### 阶段 B：部署前配置

1. 核对三处 Nacos 索引键，全部指向 `index_centralized_procurement_report_uat`；
2. 确认 ES 索引仍存在且 mapping 未被改坏；
3. 在调度中心先以 STOP 状态创建缺失的 5 个任务；
4. 不执行任何 SQL；
5. 暂不创建/启用菜单也可以，接口可先验，但最终验收前必须补菜单和岗位权限。

### 阶段 C：Jenkins 部署

后端按下面顺序：

1. `scm-source-all-uat`，确认成功后继续确认下游 `scm-source-web-uat`；
2. `scm-report-all-uat`，确认成功后继续确认下游 `scm-report-web-uat`；
3. order 没有代码 MR：若 order 的 Nacos 键发生修改，则按团队流程重启 `scm-order-web-uat`；未修改则跳过。

前端分别构建：

1. `scm-vue-statics-uat`：`PROJECT=procurementScheme`、`GIT_BRANCH=uat`；
2. `scm-vue-statics-uat`：`PROJECT=hpc`、`GIT_BRANCH=uat`；
3. 共享 Job 的 `lastBuild` 可能是别的模块，必须按 PROJECT 找到各自构建号再验日志。

每个 Jenkins 任务都要确认：实际 Git 仓、`GIT_BRANCH=uat`、目标提交号、下游镜像和 K8s Pod Ready；只看到上游绿灯不算部署完成。

### 阶段 D：部署后空数据冒烟

在任何历史写入前先验证：

1. source `POST /e/business/source/centralizedProcurementPortal/overview` 不再是 404；
2. report `POST /e/business/report/source/centralizedProcurementPageList` 不再是 404；
3. `kengk/mt/gc` 三接口成功，且读取的是 UAT 台账；
4. 页面资源版本已更新；
5. ES 文档数此时仍可为 0，不能为了“看起来有数”临时造数据。

### 阶段 E：历史补数

补数由 AI 在用户确认部署完成后执行，用户不用手工拼接口。统一时间范围：

```text
startTime = 2026-01-01 00:00:00
endTime   = 部署日前一天 23:59:59
```

为便于失败重试和逐月对账，按自然月切窗，依次执行：

| 顺序 | 来源 | 接口 |
|---:|---|---|
| 1 | YC 云采订单 | `POST /d/business/order/centralizedProcurementReport/syncToEs` |
| 2 | FP 非平台录入 | `POST /e/business/source/centralizedProcurementReport/sync` |
| 3 | ZC 招采平台 | `POST /e/business/source/centralizedProcurementReport/syncZc` |
| 4 | MT 煤炭 SAP | `POST /e/business/source/centralizedProcurementReport/syncMt` |
| 5 | JD 机电四大类 | `POST /e/business/source/centralizedProcurementReport/syncJd` |

每跑完一个来源就对账，不要五路一起盲跑。代码使用稳定 ES 文档 ID，已在 test 验证同区间重跑不会增加重复文档；UAT 仍要用一次小窗口重跑确认。

现有 Job 216 不承担统一 ES 补数，它只维护 `to_central_purchase_daily_statistics`，保持原计划自动运行即可。

### 阶段 F：菜单与最终启用

1. 在 UAT “我的工作台（企业端）-报表查询”下新增菜单；
2. 菜单名：`集采管理业务统计报表`；
3. URL：`/procurementScheme/index.html#/reportForms/centralizedProcurement`；
4. 岗位/角色权限照 test 的 `M623` 和同级报表配置；
5. 历史数据和页面验收通过后，将新增 5 个任务从 STOP 改为 RUNNING；
6. 次日查看真实执行日志，5 个任务都要同时满足 trigger=200、handle=200，不能只看 RUNNING 标签。

---

## 九、验收与对账清单

### 9.1 代码与部署

- [ ] 4 个 MR 相对最新 UAT 只有本需求白名单文件；
- [ ] 没有 `public/statics/config.js`、token、环境地址、package-lock 或 06_2 文件；
- [ ] source/report 两段 Jenkins 均成功，实际提交号正确；
- [ ] procurementScheme/HPC 两个 PROJECT 各有正确构建号；
- [ ] source/report/order（如重启）和静态站 Pod Ready。

### 9.2 配置与基础设施

- [ ] source/order/report 三个实际配置值都是 `_uat`，没有任何一个指向 `_test`；
- [ ] ES 仍是既有 UAT 索引，19 个字段类型不变；
- [ ] 5 张业务表和 2 个导出模板保持原样；
- [ ] Job 216 保留且继续成功；
- [ ] 新增 5 个任务参数/Cron/执行器准确；
- [ ] UAT 菜单及岗位权限完成。

### 9.3 数据

对每个来源分别核：

1. 源库符合条件的业务行数；
2. 预期唯一 ES ID 数；
3. ES `dataSource` 文档数；
4. 源库含税金额合计与 ES `taxTotal` 合计；
5. `bookTime` 北京时间日分布；
6. 企业、板块、供应商、类目、金额等关键字段空值；
7. 同一小窗口重跑后文档数不增加；
8. 某来源源库本来为 0 时，必须留查询证据，不能用假数据把它补成非 0。

### 9.4 接口与页面

- [ ] `overview` 返回成功，且金额与对 ES 的独立聚合逐项一致；
- [ ] 当月/季度/年度/平台额/集采率、二级集团、六类目、煤炭和钢材专项都验；
- [ ] 集团率分母按本集团平台金额，不再用全平台分母；
- [ ] 报表分页、5 个来源、企业/板块/时间/供应商组合筛选正确；
- [ ] Excel 可打开、15 列、中文枚举和日期正确；
- [ ] `kengk` 等于 UAT 最新有效坑口台账；
- [ ] `mt/gc` 固定前 12 个自然月，缺值为 `null/--`，不显示假 0；
- [ ] HPC 接口失败显示错误态和 `--`，不回退假数；
- [ ] 菜单可见岗位能打开页面，未授权岗位不可见。

---

## 十、回退方案

### 10.1 代码/运行版本

若新版本启动或接口异常，优先回退对应 MR并重部署上一个已知 UAT 版本：

| 模块 | 发布前 UAT 基线 |
|---|---|
| source | `be490ec24` |
| report | `7d70d04` |
| procurementScheme | `cf64c4f5` |
| HPC | `f42423e` |
| order | 本次不改代码，维持 `655e56e8c` |

### 10.2 配置/任务/菜单

1. Nacos 恢复修改前历史版本；
2. 停用本次新增的 5 个 ES 同步任务；
3. **不要停 Job 216**，它是发布前已稳定运行的日计划任务；
4. 临时隐藏新增菜单；
5. 旧 source/report/HPC 恢复后再复验老接口。

### 10.3 数据

最安全的回退是不删 ES：停任务、隐藏菜单、回退代码即可，UAT 补入的数据保留供排查。

如果确实要求清理：先记录索引总数和按 `dataSource/bookTime` 分布，再按来源和本次时间窗精确删除；禁止直接删整个索引。删除属于破坏性动作，必须另行得到用户明确授权。

本次没有执行 SQL，因此不存在表结构回退。

---

## 十一、用户最后一次性操作清单

以下事项等 AI 把 4 个本地交付分支准备并验证完后，再由用户一次性处理：

1. 同意 AI push 4 个已核对分支；
2. 在 GitLab 提 4 个 MR 到 `uat`，审核人兰宇；
3. 在 Nacos 核对/修改 source、order、report 三个索引键；
4. 在调度中心把缺失 5 个任务先建成 STOP；
5. MR 合并后点 source、report 后端 Jenkins，以及 procurementScheme、HPC 两次前端共享 Jenkins；order 仅在配置变更需要重启时处理；
6. 配 UAT 菜单和岗位权限；
7. 告诉 AI“部署和配置完成”，由 AI 做空数据冒烟、历史补数和数据对账；
8. AI 验收通过后，把 5 个新任务启用；次日再让 AI核任务日志。

给兰宇的逐字话术：

> 这次发 UAT 是“集采管理业务统计报表 + 集采首页取值”。共 4 个 MR：source 后端、report 后端、采购方案前端、HPC 前端，都是从最新 UAT 拉的干净交付分支，只带 03/06 业务文件；order 的同事分支已经在 UAT，不再重复合。麻烦审核合入 UAT。

给 Nacos 配置同事的逐字话术：

> 麻烦在 UAT 的 `scm-jdsn-uat`、group `common` 中核对三个服务的统一集采报表 ES 索引：source 的 `source.chase.es.centralizedProcurementReportIndex`、order 的 `order.elastic.config.centralizedProcurementReportIndex`、report 的 `report.config.commonConfigs.source.settings.centralizedProcurementReportIndex`，三处都应为 `index_centralized_procurement_report_uat`。只改这一项，原来其他索引值不要动，更不要复制 test 的整段配置。改好后请把三处最终值和是否需要重启告诉我。

给调度配置同事的逐字话术：

> UAT 的“同步云采平台计划数据”Job 216 已有且正常，不要重建。麻烦参照 test 239、241～244，在 UAT 新建 5 个统一 ES 同步任务：订单 YC 1 个、寻源 FP/ZC/MT/JD 4 个。执行器、Cron、`simpleJobHandler` 参数、FIRST、DO_NOTHING、SERIAL_EXECUTION 都按我给的部署文档配置，先保持 STOP，历史补数和验收后我再通知启用。

给菜单配置同事的逐字话术：

> 麻烦在 UAT“我的工作台（企业端）-报表查询”下新增“集采管理业务统计报表”，URL 配 `/procurementScheme/index.html#/reportForms/centralizedProcurement`，岗位/角色权限照 test 的 M623 和同级报表配置。配好后告诉我可见岗位，我做页面验收。

---

## 十二、证据索引

### 12.1 需求与代码证据

- 部署输入：`docs/部署/集采业务管理报表和取值/需求.md`；
- 03 最终交接：`docs/需求/03采集管理业业务统计报表/20-开发交接-cc.md`、`20-开发交接-codex.md`、`30-测试报告-codex.md`；
- 06 最终口径：`docs/需求/06取值需求/13-需求定稿-开发基线-cc.md`、`20-开发交接-cc.md`、`21-驾驶舱交接-codex.md`；
- source 同步接口：`scm-source-chase/.../CentralizedProcurementReportController.java`；
- order 同步接口：`scm-order-report/.../CentralizedProcurementReportController.java`；
- 三处配置读取代码：source `SourceChaseConfig.java:97`、order `OrderESConfig.java:40`、report `SourceChaseConfig.getCentralizedProcurementReportIndex()`；
- report 接口：`SourceMetaQueryController.java:286、304`。

### 12.2 只读环境查询

- MySQL：`information_schema.TABLES` 核对 5 张表；`scm_simple_template/_sub` 核对 2 个模板；
- ES：`indices '*centralized_procurement_report*'`、UAT `_count`、mapping 和 `dataSource` 聚合；
- 调度：UAT/test `xxl_job_info` 对比；`diagnose task uat order 216` 核最近 5 次执行；
- 菜单：test/UAT `ubm_rbac_menu` 按名称和 URL 联合查询；
- 发布：`diagnose release uat source/order/report/procurement-scheme`，核 Jenkins 构建号、提交、镜像和 K8s Ready；
- Git：`merge-base --is-ancestor`、目标路径 `diff --exit-code`、`origin/uat..分支` 提交差异。

### 12.3 当前限制

- 本轮未获远程 Git 当次授权，因此未 fetch；所有分支动作前还要刷新一次；
- Nacos 业务键未能由只读工具可靠解析，必须由用户在页面核对；
- 本轮没有写 UAT 数据、修改配置、触发任务、点击 Jenkins、push 或提 MR。
