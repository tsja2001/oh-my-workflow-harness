# 生产环境 · 集采四页面配置交付清单

> 日期：2026-07-31  
> 工具：Codex  
> 当前状态：生产业务表、导出模板、菜单和日计划任务均未配置；已准备仅含 5 张业务表的生产 SQL，以及全部页面配置清单。  
> 下一阶段：UAT 四页最终验收通过后，由生产配置/运维负责人按本文顺序执行；每完成一项在第 10 节勾选并回传结果。

本文可以直接发给生产配置/运维负责人。本文取代“把 UAT SQL 改库名后直接交生产”的做法。

转发时可直接说：

> 你好，这是“集采业务管理台账”四个页面的生产配置清单和建表 SQL。请按清单执行并回填第 10 节。Excel 导出模板不要执行 SQL，请在生产“导出 Excel 模板”页面按本文第 3 节创建，只使用给出的模板编码，主模板和明细 ID 都让生产系统自动生成。菜单、角色和任务也不要复制 test/UAT 的 ID。生产角色与测试环境不一致，请先按第 5.3 节确认最终授权对象；UAT 未完成最终验收前暂不要开始生产变更。

## 0. 本次生产要做什么

上线四个页面：

| 页面 | 后端服务 | 业务表 | 导出模板编码 |
|---|---|---|---|
| 集采日金额统计台账 | source | `sc_collection_daily_amount_ledger` | `collection-daily-ledger-export` |
| 集采日计划统计台账 | order | `to_central_purchase_daily_statistics` | `centralPurchaseStatistics` |
| 煤炭重点坑口日指标 | source | `sc_coal_pit_daily_indicator`、`sc_coal_pit_daily_indicator_item` | `coal-pit-daily-export` |
| 价格趋势维护 | source | `sc_price_trend` | `priceTrend` |

生产配置分五部分：

1. 执行 5 张业务表 DDL。
2. 在生产管理页面创建 4 个 Excel 导出模板。
3. 创建 1 个一级菜单、4 个子菜单，并授权生产实际岗位/角色。
4. 创建并启动 1 个日计划定时任务。
5. 按正式发布流程部署 source、order 和 `procurementScheme` 前端。

2026-07-31 16:42 只读核对生产现状：

| 核对项 | 当前数量 |
|---|---:|
| 本次 5 张业务表 | 0 |
| 本次 4 个导出模板 | 0 |
| 本次 5 个菜单 | 0 |
| “集采日统计服务”任务 | 0 |

所以本次都是新增，不是修改现有生产配置。

## 1. 开始前的硬性条件

以下条件没有全部满足，不要操作生产：

- UAT 四个页面已经完成查询、新增、修改、删除和实际 Excel 下载验收。
- 价格趋势删除 V3 已在 UAT 验证。
- UAT 四个 Excel 列数已确认是 9 / 11 / 14 / 9，且列名、顺序、格式正确。
- source、order、`procurementScheme` 的正式发布版本和回退版本已确定。
- 已明确生产变更窗口、执行人和回退负责人。
- 已确认生产要授权的实际岗位/角色，见第 5.3 节。

当前工作区最后一份 UAT 操作教程仍有多项未勾选；若线下已经验完，请先把结果补回交接记录，不要凭口头“应该没问题”直接上生产。

## 2. 数据库：只执行 5 张业务表 SQL

交付 SQL：

`docs/需求/04和生产环境运维对接需求1-4/sql/02-prod-集采四页面业务表.sql`

该文件只做：

- 在 `scm_source` 创建 4 张表。
- 在 `scm_order` 创建 1 张表。
- 最后只读核对 5 张表。

明确不包含：

- 不操作 `scm_ubm.scm_simple_template`。
- 不插入任何导出模板。
- 不插入菜单、角色或岗位。
- 不插入业务数据、演示数据。
- 不修改 ES、Nacos 或字典。
- 不创建定时任务。
- 没有 `DROP`、`TRUNCATE`、`DELETE`、业务数据 `INSERT`。

执行步骤：

1. 打开生产数据库连接。
2. 打开上述 SQL 文件。
3. 人工确认文件中只出现生产库 `scm_source`、`scm_order`，不能出现 `_test`、`_uat`。
4. 先执行开头的连接信息查询，记录主机、端口和执行时间。
5. 全选执行。
6. 最后结果必须恰好返回 5 张表：

| 库 | 表 |
|---|---|
| `scm_source` | `sc_collection_daily_amount_ledger` |
| `scm_source` | `sc_coal_pit_daily_indicator` |
| `scm_source` | `sc_coal_pit_daily_indicator_item` |
| `scm_source` | `sc_price_trend` |
| `scm_order` | `to_central_purchase_daily_statistics` |

若执行时报“表已存在”，不要删除重建；先停止，把实际 `SHOW CREATE TABLE` 结果交给开发核对差异。

## 3. Excel 导出模板：必须去生产页面创建

入口：生产平台的“导出 Excel 模板”管理页面。

禁止事项：

- 不允许直接向 `scm_simple_template`、`scm_simple_template_sub` 执行 INSERT。
- 不复制 test/UAT 的 `template_id` 或 `tmp_id`。
- 主模板和每一列的内部 ID 都让生产后端自动生成。
- 不用本文之前候选的 UAT ID 修复映射。

页面基本信息需要填写：

| 页面字段 | 日金额 | 日计划 | 坑口 | 价格趋势 |
|---|---|---|---|---|
| 模板编码 | `collection-daily-ledger-export` | `centralPurchaseStatistics` | `coal-pit-daily-export` | `priceTrend` |
| 模板描述 | 集采日金额统计台账导出 | 集采日统计视图对象 | 煤炭重点坑口日指标台账导出 | 价格趋势维护导出 |
| 分组编码 | `source` | `1` | `source` | `source` |
| 分组名称 | 寻源模块 | `1` | 寻源模块 | 寻源模块 |
| 模板状态 | 启用 | 启用 | 启用 | 启用 |
| 校验码列号 | 留空 | `1` | 留空 | 留空 |
| 是否启用校验码 | 否 | 是 | 否 | 否 |
| 期望明细数 | 9 | 11 | 14 | 9 |

说明：

- “字段名”必须和接口返回字段一致，区分大小写。
- “字段值”是 Excel 表头。
- “字段状态”全部选择“启用”。
- 页面若额外出现“导出文件名称”或“单次导出数量”，先留空；四个业务页面会自己传下载文件名，当前验收配置也未依赖导出上限。

### 3.1 日金额模板：9 列

模板编码：`collection-daily-ledger-export`

| 排序列表 | 字段名 | 字段值 | 字段类型 | 状态 |
|---:|---|---|---|---|
| 1 | `ledgerNo` | 集采日金额统计流水号 | `String` | 启用 |
| 2 | `executeUnitName` | 集采执行单位 | `String` | 启用 |
| 3 | `categoryName` | 集采类目 | `String` | 启用 |
| 4 | `statisticDate` | 统计日期 | `Date` | 启用 |
| 5 | `purchaseCompanyName` | 采购企业 | `String` | 启用 |
| 6 | `taxAmount` | 采购金额（含税） | `BigDecimal` | 启用 |
| 7 | `buName` | 所属板块 | `String` | 启用 |
| 8 | `publishTime` | 发布时间 | `Date` | 启用 |
| 9 | `createByName` | 创建人 | `String` | 启用 |

### 3.2 日计划模板：11 列

模板编码：`centralPurchaseStatistics`

| 排序列表 | 字段名 | 字段值 | 字段类型 | 状态 |
|---:|---|---|---|---|
| 1 | `serialNumber` | 流水号 | `String` | 启用 |
| 2 | `executeUnitName` | 集采执行单位 | `String` | 启用 |
| 3 | `categoryName` | 集采类目 | `String` | 启用 |
| 4 | `statisticsDate` | 统计日期 | `Date` | 启用 |
| 5 | `planQuantity` | 当月计划总数量 | `BigDecimal` | 启用 |
| 6 | `responseQuantity` | 当月响应数量 | `BigDecimal` | 启用 |
| 7 | `executingQuantity` | 当月执行中数量 | `BigDecimal` | 启用 |
| 8 | `completedQuantity` | 当月已完成数量 | `BigDecimal` | 启用 |
| 9 | `delayedQuantity` | 当月已滞后数量 | `BigDecimal` | 启用 |
| 10 | `createTime` | 发布时间 | `Date` | 启用 |
| 11 | `createByName` | 操作人 | `String` | 启用 |

### 3.3 坑口模板：14 列

模板编码：`coal-pit-daily-export`

| 排序列表 | 字段名 | 字段值 | 字段类型 | 状态 |
|---:|---|---|---|---|
| 1 | `indicatorNo` | 煤炭重点坑口日指标流水号 | `String` | 启用 |
| 2 | `executeUnitName` | 集采执行单位 | `String` | 启用 |
| 3 | `pit1Name` | 坑口1名称 | `String` | 启用 |
| 4 | `pit1TaxPrice` | 坑口1日价格（元/吨） | `BigDecimal` | 启用 |
| 5 | `pit2Name` | 坑口2名称 | `String` | 启用 |
| 6 | `pit2TaxPrice` | 坑口2日价格（元/吨） | `BigDecimal` | 启用 |
| 7 | `pit3Name` | 坑口3名称 | `String` | 启用 |
| 8 | `pit3TaxPrice` | 坑口3日价格（元/吨） | `BigDecimal` | 启用 |
| 9 | `pit4Name` | 坑口4名称 | `String` | 启用 |
| 10 | `pit4TaxPrice` | 坑口4日价格（元/吨） | `BigDecimal` | 启用 |
| 11 | `pit5Name` | 坑口5名称 | `String` | 启用 |
| 12 | `pit5TaxPrice` | 坑口5日价格（元/吨） | `BigDecimal` | 启用 |
| 13 | `publishTime` | 发布时间 | `Date` | 启用 |
| 14 | `publishByName` | 操作人 | `String` | 启用 |

### 3.4 价格趋势模板：9 列

模板编码：`priceTrend`

| 排序列表 | 字段名 | 字段值 | 字段类型 | 状态 |
|---:|---|---|---|---|
| 1 | `serialNumber` | 近12个月价格趋势流水号 | `String` | 启用 |
| 2 | `executeUnitName` | 集采执行单位 | `String` | 启用 |
| 3 | `year` | 年度 | `String` | 启用 |
| 4 | `month` | 月份 | `String` | 启用 |
| 5 | `categoryName` | 类目 | `String` | 启用 |
| 6 | `indicatorName` | 指标 | `String` | 启用 |
| 7 | `price` | 价格（元） | `BigDecimal` | 启用 |
| 8 | `publishTimeStr` | 发布时间 | `String` | 启用 |
| 9 | `createByName` | 创建人 | `String` | 启用 |

### 3.5 模板创建后的验收

每个模板提交后：

1. 回到列表按模板编码搜索，必须只出现 1 条启用记录。
2. 打开详情，逐列核对数量、排序、字段名、字段值、字段类型。
3. 不人工修改系统生成的主 ID 和明细 ID。
4. 等对应应用发布后，到四个业务页面各下载一次 Excel。
5. 实际文件必须分别为 9 / 11 / 14 / 9 列。

## 4. 菜单：创建 1 个父菜单和 4 个子菜单

入口：生产平台菜单管理页面。请使用生产页面生成菜单 ID 和菜单编码，不复制 test 的 `M615`～`M620` 或任何菜单主键。

父菜单：

| 字段 | 值 |
|---|---|
| 菜单名称 | 集采业务管理台账 |
| 菜单链接 | `/` |
| 图标样式 | 对勾（系统值 `check-circle-o`） |
| 菜单排序 | 11 |
| 菜单描述 | 留空 |
| 所属分组编码 | `workbench` |
| 所属分组名称 | 我的工作台（企业端） |
| 状态 | 启用 |

子菜单：

| 排序 | 菜单名称 | 菜单链接 |
|---:|---|---|
| 1 | 集采日金额统计台账 | `/procurementScheme/index.html#/businessManagementLedgerJC/dailyAmountStatisticsLedger` |
| 2 | 集采日计划统计台账 | `/procurementScheme/index.html#/businessManagementLedgerJC/dailyPlanStatisticsLedger` |
| 3 | 煤炭重点坑口日指标 | `/procurementScheme/index.html#/businessManagementLedgerJC/coalPitDailyIndicator` |
| 4 | 价格趋势维护 | `/procurementScheme/index.html#/businessManagementLedgerJC/maintenancePriceTrend` |

四个子菜单共同设置：

- 父菜单：刚创建的“集采业务管理台账”。
- 图标样式：对勾（系统值 `check-circle-o`）。
- 菜单描述：留空。
- 所属分组：`workbench / 我的工作台（企业端）`。
- 状态：启用。
- 当前管理页不要求填写菜单编码、菜单 ID 或菜单类型；保存时由后台生成菜单编码和 ID，菜单类型按现有普通左侧菜单落为 `Left`。
- 页面如出现“打开方式”，沿用同分组现有普通菜单默认值，不使用新窗口或 iframe。

## 5. 权限：授权生产实际岗位/角色

### 5.1 必须授权的菜单

目标岗位/角色必须同时拥有：

- 父菜单“集采业务管理台账”。
- 集采日金额统计台账。
- 集采日计划统计台账。
- 煤炭重点坑口日指标。
- 价格趋势维护。

只授权四个子菜单、不授权父菜单，导航树可能仍不显示。

### 5.2 已核实的环境差异

| 环境 | 现状 |
|---|---|
| test | 活跃授权使用 `ROLE_SCM_JC0001 / 集采业务管理台账` |
| UAT | 没有上述角色；另有 `MALL_JTJCGL / 集采管理门户专属` |
| 生产 | 两个角色都不存在 |
| 原需求口径 | 目标为“集采管理-执行单位集采管理岗” |

因此禁止复制 test/UAT 的角色 ID、角色编码或角色菜单关系。

### 5.3 生产必须确认的一项

请菜单/权限负责人确认：

> 生产这四个页面最终授权给哪个现有岗位/角色？原需求写的是“集采管理-执行单位集采管理岗”，但生产角色表中没有 test 的 `ROLE_SCM_JC0001 / 集采业务管理台账`，也没有 UAT 的 `MALL_JTJCGL / 集采管理门户专属`。请按生产组织权限规则选择或创建正确角色，并把角色名称、角色编码回填到本文。

回填：

| 项目 | 生产实际值 |
|---|---|
| 岗位/角色名称 | 待负责人填写 |
| 岗位/角色编码 | 待负责人填写 |
| 配置人 | 待负责人填写 |
| 配置时间 | 待负责人填写 |

## 6. 定时任务：只创建“集采日统计服务”

生产调度库当前已有执行器：

| 字段 | 当前值 |
|---|---|
| 执行器名称 | 订单中心 |
| 应用名 | `scm-order-web` |

当前没有本次任务。必须等生产 `scm-order-web` 新版本部署成功、执行器在线后再创建。

任务配置：

| 页面字段 | 填写值 |
|---|---|
| 执行器 | 订单中心 |
| 任务描述 | 集采日统计服务 |
| 负责人 | `zyl` |
| 报警邮件 | 留空 |
| 调度类型 | CRON |
| Cron | `0 3 3 * * ?` |
| 运行模式 | BEAN |
| JobHandler | `simpleJobHandler` |
| 任务参数 | `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}` |
| 路由策略 | 第一个（FIRST） |
| 子任务 ID | 留空 |
| 调度过期策略 | 忽略（DO_NOTHING） |
| 阻塞处理策略 | 单机串行（SERIAL_EXECUTION） |
| 任务超时时间 | `0` |
| 失败重试次数 | `0` |

配置要求：

- Cron 表示每天凌晨 03:03 执行。
- 本次不创建任务 239，不创建“集采管理业务统计报表-云采”任务。
- 保存后先确认任务参数逐字符一致。
- 启动任务。
- 在变更窗口手动执行一次。
- 调度结果和执行结果都必须成功。
- 执行后核对 `scm_order.to_central_purchase_daily_statistics` 有符合生产上游数据口径的记录。
- 如果日志成功但表仍为空，先查上游数据和任务日志，不要连续重复执行。

## 7. 应用发布

本次配置依赖三个发布物：

| 发布物 | 作用 |
|---|---|
| source 后端 | 日金额、坑口、价格趋势接口与导出 |
| order 后端 | 日计划接口、导出与同步任务 |
| `procurementScheme` 前端 | 四个页面和路由 |

按公司正式生产发布流程执行，不照搬 test/UAT Jenkins 任务名。当前可见 Jenkins 中没有对应 `*-web-prod` 入口，生产实际发布入口和回退方式由运维确认。

推荐顺序：

1. 执行业务表 SQL。
2. 发布 source、order 后端。
3. 发布 `procurementScheme` 前端。
4. 创建 Excel 模板。
5. 创建菜单并授权。
6. 创建、启动并手动执行日计划任务。
7. 验收四个页面。

## 8. 本次明确不配置

- 不配 ES 索引。
- 不改 Nacos。
- 不新增数据字典。
- 不切换日金额驾驶舱开关。
- 不接煤炭坑口驾驶舱。
- 不创建任务 239。
- 不插入测试数据或演示数据。
- 不把 UAT 的模板 ID、菜单 ID、角色 ID、任务 ID复制到生产。
- 不执行旧 UAT SQL 的 Section 3 模板 INSERT。

## 9. 生产验收

### 9.1 数据库与配置

- 5 张业务表全部存在。
- 4 个模板各只有 1 条启用记录。
- 模板列数为 9 / 11 / 14 / 9。
- 父菜单和 4 个子菜单可见。
- 目标生产岗位/角色已授权全部 5 个菜单。
- 日计划任务已启动，手动执行日志成功。

### 9.2 四个页面

| 页面 | 必测项 |
|---|---|
| 日金额 | 打开、查询、新增、修改、删除、导出 9 列 |
| 日计划 | 任务生成数据、查询、汇总比例、导出 11 列、任务幂等 |
| 坑口 | 新增 1～5 个坑口、修改、删除、导出 14 列 |
| 价格趋势 | 新增、修改、删除、导出 9 列 |

生产验收数据必须按公司的生产数据规范处理；不要为了页面好看擅自插入演示数据。

### 9.3 回退原则

- 应用发布失败：按运维准备的上一版本回退。
- 模板填错：在生产模板页面修改，不用 SQL 改主键。
- 菜单/权限填错：在管理页面停用或撤销授权。
- 定时任务异常：先停止任务，再看日志；不要直接删任务掩盖记录。
- 5 张新表如果已经产生生产数据，不允许直接 `DROP`。是否删除空表也必须走生产变更审批。

## 10. 执行回执

| 序号 | 配置项 | 执行人 | 时间 | 结果/截图或日志编号 |
|---:|---|---|---|---|
| 1 | 5 张业务表 SQL |  |  |  |
| 2 | 日金额导出模板 |  |  |  |
| 3 | 日计划导出模板 |  |  |  |
| 4 | 坑口导出模板 |  |  |  |
| 5 | 价格趋势导出模板 |  |  |  |
| 6 | 父菜单 + 4 个子菜单 |  |  |  |
| 7 | 生产岗位/角色授权 |  |  |  |
| 8 | source 后端发布 |  |  |  |
| 9 | order 后端发布 |  |  |  |
| 10 | `procurementScheme` 前端发布 |  |  |  |
| 11 | 日计划定时任务 |  |  |  |
| 12 | 四页面生产验收 |  |  |  |

## 11. 交付依据

- 业务表结构：`sql/01-uat-集采四页面部署.sql:22-170`，已在 UAT 执行并反查。
- 导出模板字段：`sql/01-uat-集采四页面部署.sql:174-319`，仅作为字段依据，不交生产执行。
- 模板页面字段：`02zhaocai-front/scm-vue-all-platform/src/views/xlsMgt/add.vue:1-56`、`src/components/xlsMgt/ChildModal.vue:12-29`。
- 四页面模板编码：四个业务前端 `handleExport` 实现。
- 菜单值：test `scm_ubm_test.ubm_rbac_menu` 只读反查；生产由页面重新生成 ID/编码。
- 任务参数：order 代码 AIM 映射与 UAT 操作教程。
- 生产现状：2026-07-31 对 `scm_source`、`scm_order`、`scm_ubm`、`scm_xxljob` 的只读查询。
