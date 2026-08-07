# UAT 集采四页面操作教程

> 日期：2026-07-30  
> 工具：Codex  
> 当前状态：UAT SQL 已于 2026-07-30 10:40:58 在 `node3:3306` 执行并验收通过；前端已准备成干净的本地 `taizhang-uat-yang` 单提交分支并正式构建通过，尚未推送；source、order、Jenkins、菜单和任务 240 尚未操作。  
> 下一阶段：用户推送前端 `taizhang-uat-yang` 并在 GitLab 合入 `uat`；同时准备并验证 source、order 的 UAT 代码和价格趋势删除 V3，随后从第 4 节部署，不需要重复执行 SQL。

本文是实际执行入口，取代 `90-临时-UAT集采四页面部署清单-codex.md` 作为操作手册；旧文档继续保留提交范围和调查证据。

## 1. 你最终只需要完成这条流水线

```text
先在 test 补测价格趋势删除 V3
  → AI 准备并验证三仓 UAT 代码
  → 你推送并在远程完成 UAT 合并
  → 执行 UAT SQL
  → 点 source/order/前端 Jenkins
  → 找张雨配菜单和岗位权限
  → 在 UAT 新建并启动任务 240
  → 手动执行任务一次
  → 验收四个页面
```

这次只上四个页面：

| 页面 | 后端 | 数据表 | 导出模板 |
| --- | --- | --- | --- |
| 集采日金额统计台账 | source | `sc_collection_daily_amount_ledger` | `collection-daily-ledger-export`，9 列 |
| 集采日计划统计台账 | order | `to_central_purchase_daily_statistics` | `centralPurchaseStatistics`，11 列 |
| 煤炭重点坑口日指标 | source | `sc_coal_pit_daily_indicator`、`sc_coal_pit_daily_indicator_item` | `coal-pit-daily-export`，14 列 |
| 价格趋势维护 | source | `sc_price_trend` | `priceTrend`，9 列 |

本次明确不做：

- 不配 ES，不改 Nacos。
- 不建任务 239；它属于需求 03 的“集采管理业务统计报表-云采”。
- 不带 test 演示数据。
- 不切换日金额驾驶舱字典，不改坑口驾驶舱。
- 不把整个 test 分支合进 UAT。

## 2. 第一步先补一个 test 漏测，再准备 UAT 代码

当前 test 前端删除时发送 JSON 请求体，但 test 后端仍按 URL 参数接收。修复提交 `a8045d94b` 没进 test，所以“test 页面看起来正常”并不能证明删除已经验过。

先对 AI 说：

> 先把价格趋势删除 V3 `a8045d94b` 迁到基于 `origin/test` 的干净本地分支，只做这个修复。完成隔离编译并给我 diff、提交号和推送命令，不要替我推送或操作远程分支。

你自行推送并合入 test 后：

1. 点 `scm-source-all-test`，参数为 `GIT_BRANCH=test`、`VERSION=1.0.0-JDSN-TEST-SNAPSHOT`。
2. 继续等自动触发的 `scm-source-web-test` 成功。
3. 在 test 的价格趋势页新增一条明显的测试数据。
4. 删除它，确认接口成功、列表不再显示。

这一步通过后，再准备 UAT 三仓代码。

不要自己手敲十几次 `cherry-pick`，也不要做 `test → uat` 整分支合并。三个仓的 test 都比 UAT 多几百到上千个无关提交，整合会把其他需求一起带进去。

你只要对 AI 说：

> 按《UAT 集采四页面操作教程》开始准备三个仓库的本地 UAT 集成分支。只迁日金额、日计划、坑口、价格趋势，包含价格趋势删除 V3；不要带需求 03、任务 239、ES、驾驶舱和前端 config.js。完成隔离编译/前端构建并把 diff 和我需要执行的推送命令给我，不要替我推送或操作远程分支。

AI 完成后必须给你这四样东西：

1. source、order、前端三个本地分支名。
2. 三个仓各自的最终提交号。
3. 编译/构建结果和最终 diff 范围。
4. 你可以复制执行的三条 `git push` 命令。

看到下面任意情况先停：

- AI 让你直接合并整个 test。
- source 里没有价格趋势删除 V3 `a8045d94b`。
- 前端 diff 出现 `public/statics/config.js`。
- order diff 出现需求 03 的云采报表提交 `1f6fd0093`。
- AI 没做隔离编译或前端正式构建。

你自行推送并完成远程 UAT 合并后，再继续下面操作。

### 2.1 前端本地 UAT 已完成

2026-07-30 已在 `scm-vue-all-procurementscheme` 完成以下处理：

- 合入 `origin/prod-feature-jcmh-yangzhuoran`，冲突文件 `src/views/supplier/increasedListAdd.vue` 保留 UAT 原版本。
- 明确剔除源分支里的 `public/statics/config.js` TOKEN 改动，最终文件与远程 UAT 完全一致。
- 补合 `origin/prod-feature-jcmh` 中日计划 0714 的组织下拉调整；否则日计划页会比 test 少一版。
- 原始本地合并提交为 `028674ed`、`f5a2e7df`；`npm run build` 成功，仅有项目原有的体积、CSS 顺序和 Browserslist 警告。
- 最终相对 `origin/uat` 只改路由并新增四个页面，共 5 个文件；四个页面文件与 `origin/test` 完全一致。
- 因用户没有直接推送 UAT 的权限，已从 `origin/uat` 重新生成干净分支 `taizhang-uat-yang`，只有一个提交 `e9432aaf feat: 增加集采台账`；其文件树与构建通过的本地 UAT 完全一致。
- 已建本地安全分支 `backup/uat-before-jicai-20260730`，没有推送任何远程分支。

前端不需要再次解决冲突。用户执行：

```bash
cd /home/t/projects/work-wsl/02zhaocai-front/scm-vue-all-procurementscheme
git push -u origin taizhang-uat-yang
```

然后在 GitLab 新建合并请求：源分支选 `taizhang-uat-yang`，目标分支选 `uat`。推送前若远程 `uat` 被别人更新，先让 AI 重新核对，不要强推。

## 3. 执行数据库 SQL

SQL 文件：

`sql/01-uat-集采四页面部署.sql`

### 3.1 本次执行结果

2026-07-30 10:40:58 已由 Codex 在 UAT MySQL `node3:3306` 完整执行成功，随后做了独立反查：

- 5 张业务表全部存在，均为 InnoDB。
- 5 张业务表行数全部为 0，没有插入台账或演示数据。
- 4 个模板各只有 1 条主记录，没有重复模板 ID。
- 模板明细为 9 / 11 / 14 / 9，共 43 条，全部启用、排序连续。
- 字段名和顺序已逐项核对，无意外记录。

因此正常部署流程不需要再次执行本 SQL。只有后续确认模板字段需要调整时，才按新的修订脚本补跑。

它已经包含：

- `scm_source_uat` 的 4 张寻源业务表。
- `scm_order_uat` 的 1 张日计划表；当前 UAT 已有该表，脚本会自动跳过，不删表、不清数据。
- `scm_ubm_uat` 的 4 个导出模板。
- 最后的自动核验查询。

2026-07-30 已在一次性 MySQL 8.0.46 环境连续完整执行两遍：首次部署成功，第二次重复执行仍成功，最终表数和模板列数都符合预期。这个验证证明 SQL 语法与重复执行逻辑正常，不代表已经在公司 UAT 执行。

本脚本顺手处理了两个现有配置缺口：

- 价格趋势模板原先 test/UAT 都没有，现按页面真实的 9 个展示字段补齐。
- 日计划 test 模板只有 4 列且标题错位，现按页面表格和 Java 返回对象修正为 11 列。

两项都必须在 UAT 实际下载一次 Excel 核对，确认后再作为生产模板来源。

### 3.2 需要重放时在 DBeaver/Navicat 里这样做

1. 连接公司的 **UAT MySQL**。
2. 确认左侧能看到：
   - `scm_source_uat`
   - `scm_order_uat`
   - `scm_ubm_uat`
3. 打开 `sql/01-uat-集采四页面部署.sql`。
4. 再看一眼文件中的 `USE`，只能出现上面三个带 `_uat` 的库名。
5. 全选脚本并执行。
6. 第一条结果会显示 MySQL 主机和端口。若连接名称或主机看起来像生产，立刻停止。
7. 滚到最后看核验结果。

正确结果：

| 核验项 | 期望 |
| --- | --- |
| 业务表 | 共 5 行：source 4 张、order 1 张 |
| `collection-daily-ledger-export` | 9 列 |
| `centralPurchaseStatistics` | 11 列 |
| `coal-pit-daily-export` | 14 列 |
| `priceTrend` | 9 列 |
| 四个模板状态 | `status=1`、`delete_sign=0` |

若 SQL 中途报错：

1. 不要凭感觉改 SQL。
2. 复制“报错文字 + 报错行号 + 当时选中的连接名称”发给 AI。
3. 脚本没有 DROP/TRUNCATE，前面已成功的建表不会清数据；AI 会先查实际状态再给补跑方案。

## 4. 点 Jenkins 部署

入口：`http://jenkins.jdsn.com/`

后端是“两段流水线”：

```text
*-all-uat 发业务 jar 到 Nexus
  → 成功后自动触发 *-web-uat
  → web 构建镜像并部署到 UAT
```

所以 `all` 绿色不代表部署结束，必须继续等对应 `web` 也成功。

### 4.1 部署 source

1. 打开任务 `scm-source-all-uat`。
2. 点“Build with Parameters/参数化构建”。
3. 核对：
   - `GIT_BRANCH = uat`
   - `VERSION = 1.0.0-JDSN-UAT-SNAPSHOT`
4. 点一次构建，不要在运行中重复点。
5. 等 `scm-source-all-uat` 成功。
6. 再打开 `scm-source-web-uat`，确认自动触发的下游构建也成功。

### 4.2 部署 order

1. 打开任务 `scm-order-all-uat`。
2. 点参数化构建。
3. 核对：
   - `GIT_BRANCH = uat`
   - `VERSION = 1.0.0-JDSN-UAT-SNAPSHOT`
4. 点一次构建。
5. 等 `scm-order-all-uat` 成功。
6. 再打开 `scm-order-web-uat`，确认自动触发的下游构建也成功。

### 4.3 部署采购方案前端

1. 打开任务 `scm-vue-statics-uat`。
2. 点参数化构建。
3. 核对：
   - `PROJECT = procurementScheme`
   - `GIT_BRANCH = uat`
4. 点一次构建并等它成功。

### 4.4 Jenkins 怎么判断失败

| 现象 | 结论 |
| --- | --- |
| all 成功、web 成功 | 后端部署完成 |
| all 成功、web 失败 | 部署失败，服务仍可能是旧版本 |
| all 失败 | jar 没发布，先看 all 控制台日志 |
| 页面出现 502 | Jenkins 入口网络问题，不等于构建失败；用 Windows 公司网络重试 |
| 前端成功但页面还是旧的 | 先强制刷新/无痕窗口，再核对前端构建参数和 UAT 分支 |

任何任务失败时，把“任务名、构建号、控制台日志最后约 100 行”发给 AI，不要连续重跑掩盖首个错误。

## 5. 找张雨配菜单和岗位权限

直接把下面这段发给张雨：

> 麻烦在 UAT 配置一级菜单“集采业务管理台账”和下面四个子菜单，并授权给“集采管理-执行单位集采管理岗”：  
> 1. 集采日金额统计台账：`/procurementScheme/index.html#/businessManagementLedgerJC/dailyAmountStatisticsLedger`  
> 2. 集采日计划统计台账：`/procurementScheme/index.html#/businessManagementLedgerJC/dailyPlanStatisticsLedger`  
> 3. 煤炭重点坑口日指标：`/procurementScheme/index.html#/businessManagementLedgerJC/coalPitDailyIndicator`  
> 4. 价格趋势维护：`/procurementScheme/index.html#/businessManagementLedgerJC/maintenancePriceTrend`  
> 请按 UAT 自己生成菜单记录，不要照搬 test 的菜单主键。配好并授权后告诉我，我要做四页验收。

菜单没配好之前，可以用四条 URL 直接验证页面是否能打开，但“目标岗位能否在菜单中看到”必须等张雨授权后再验。

## 6. 新建 UAT 定时任务 240

必须等 `scm-order-web-uat` 部署成功后再做。

入口：

`http://10.0.54.16:31799/scm-scheduling-web/jobinfo`

### 6.1 先确认没有重复任务

1. 登录 UAT 调度中心。
2. 左侧点“任务管理”。
3. 顶部执行器选择“订单中心”。
4. 任务描述输入“集采日统计服务”并搜索。
5. 2026-07-30 实查结果为 0 条。若你操作时已经有同名任务，不要再新增，先打开“编辑”核对参数。

### 6.2 新增时逐项填写

点“新增”。注意：即使列表刚筛选了订单中心，新增弹窗里的执行器仍可能默认成“合同模块”，必须手动重新选择“订单中心”。

| 页面字段 | 填写值 |
| --- | --- |
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

Cron 的意思是每天凌晨 03:03 执行一次。

填写完先逐字符核对任务参数，再点“保存”。本次不要创建任务 239。

### 6.3 启动并手动执行一次

1. 搜索刚新增的“集采日统计服务”。
2. 若状态是 `STOP`，在“操作”里选择“启动”。
3. 确认订单执行器已有在线注册节点。
4. 在“操作”里选择“执行一次”。
5. 转到“调度日志”，按新任务 ID 搜索。
6. 确认本次日志的调度结果和执行结果都成功。

任务执行后，让 AI 用只读 SQL 核对：

```sql
SELECT COUNT(*) AS row_count
FROM scm_order_uat.to_central_purchase_daily_statistics
WHERE delete_sign = 0;
```

当前 UAT 表为 0 条。执行成功后通常应出现汇总数据；若仍为 0，先看任务日志和上游数据，不要反复点“执行一次”。

## 7. 四个页面怎么验收

建议用目标岗位账号验收。每页都做“打开、查询、新增、修改、删除、导出”六项。

### 7.1 集采日金额统计台账

URL：

`/procurementScheme/index.html#/businessManagementLedgerJC/dailyAmountStatisticsLedger`

- 录入一条带明显 UAT 标识的数据。
- 检查流水号、执行单位、类目、日期、采购企业、金额、板块。
- 修改金额后重新查询。
- 导出 Excel，核对 9 列。
- 删除后列表不可见。

### 7.2 集采日计划统计台账

URL：

`/procurementScheme/index.html#/businessManagementLedgerJC/dailyPlanStatisticsLedger`

- 先确认任务 240 执行成功并有数据。
- 查询列表和页面顶部比例/汇总。
- 导出 Excel，核对修正后的 11 列与页面表格一致。
- 再手动执行任务一次，确认同一天不会无上限制造重复记录。

日计划测试数据来源于同步任务，优先验任务生成的数据，不建议手工伪造正式统计记录。

### 7.3 煤炭重点坑口日指标

URL：

`/procurementScheme/index.html#/businessManagementLedgerJC/coalPitDailyIndicator`

- 录入一条主记录和 1～5 个坑口价格。
- 检查发布日期默认当天且不能随意修改。
- 修改一个坑口名称/价格。
- 导出 Excel，核对 14 列和 5 组坑口平铺顺序。
- 删除后列表不可见。

### 7.4 价格趋势维护

URL：

`/procurementScheme/index.html#/businessManagementLedgerJC/maintenancePriceTrend`

- 录入一条价格趋势。
- 修改价格并重新查询。
- 删除并确认列表不可见；这一步专门验证 V3 修复已进入 UAT。
- 导出 Excel，核对 9 列。

价格趋势是本批最需要认真验的页面：删除 V3 原先没有进入 test，导出模板原先也不存在。任一失败都不要带到生产。

## 8. 最终通过标准

- [ ] 三个仓库的 UAT 代码只包含四页面范围。
- [x] 前端本地 `taizhang-uat-yang` 和 `npm run build` 已通过，最终只涉及路由和四个页面。
- [ ] 前端 `taizhang-uat-yang` 已由用户推送并在 GitLab 合入 `uat`。
- [x] UAT 5 张业务表齐全，且当前均为 0 行。
- [x] 四个导出模板列数为 9 / 11 / 14 / 9。
- [ ] source-all → source-web 均成功。
- [ ] order-all → order-web 均成功。
- [ ] procurementScheme 前端构建成功。
- [ ] 一级菜单、四个子菜单、目标岗位权限已配置。
- [ ] UAT 只新增任务 240，参数与本文完全一致。
- [ ] 任务 240 启动且手动执行日志成功。
- [ ] 四页查询、增改删、导出全部通过。
- [ ] 价格趋势删除和导出单独通过。
- [ ] 没有修改 Nacos/ES，没有创建任务 239。

全部勾完后再整理生产交付包。**这份 UAT SQL 不能原样交生产执行**；生产库名、正式发布入口和任务平台都要由运维确认，届时让 AI根据 UAT 实测结果另生成生产 SQL 与逐字交接话术。
