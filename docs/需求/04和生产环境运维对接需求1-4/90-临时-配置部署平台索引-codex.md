# 配置与部署平台索引（只读侦察版）

> 日期：2026-07-27  
> 工具：Codex  
> 当前状态：调度 test/UAT 和 Jenkins 已实际登录并完成只读取证；Nacos 登录页可达，但缺控制台账号，尚未查看配置正文。  
> 下一阶段：用户把 Nacos 控制台账号填入 `ai-docs/creds.env` 后，AI 继续只读核对 test/UAT/prod 的配置差异，再整理正式操作清单；本阶段不执行部署、任务新增或配置发布。

## 1. 先说结论

现在已经有一条能长期复用的浏览器通道，不需要用户反复截图或 Copy as cURL：

- 调度平台和 Nacos：WSL 里的独立 Chromium。
- Jenkins：WSL 访问会返回 502，但 Windows 访问正常，所以用专用 Windows Chrome，再由 WSL Playwright 接管。
- 每个平台、每个环境使用独立浏览器资料目录，避免同一个 IP 不同端口之间 Cookie 串环境。
- 登录、翻页、搜索、查看详情和读取 Network 可以做。
- 构建、执行一次、保存、发布、启动、停止、新增、修改、删除会被网络层护栏拦截，不只依赖 AI 临场记忆。

统一入口：

```bash
bash scripts/browser-ro.sh start scheduling-test
bash scripts/browser-ro.sh start scheduling-uat
bash scripts/browser-ro.sh start nacos-test
bash scripts/browser-ro.sh start jenkins

bash scripts/browser-ro.sh cmd scheduling-test snapshot
bash scripts/browser-ro.sh cmd jenkins goto http://jenkins.jdsn.com/job/scm-source-all-uat/

bash scripts/browser-ro.sh stop scheduling-test
bash scripts/browser-ro.sh stop scheduling-uat
bash scripts/browser-ro.sh stop nacos-test
bash scripts/browser-ro.sh stop jenkins
```

相关文件：

| 文件 | 作用 |
| --- | --- |
| `scripts/browser-ro.sh` | 唯一推荐入口；启动、登录、选择隔离会话 |
| `scripts/browser/readonly-guard.js` | 网络只读护栏 |
| `scripts/browser/launch-windows-chrome-readonly.ps1` | 启动 Jenkins 专用 Windows Chrome |
| `.playwright/cli.config.json` | 浏览器配置和取证文件目录 |
| `.agents/skills/playwright-cli/SKILL.md` | 给后续 AI 的官方 Playwright 操作手册 |
| `ai-docs/creds.env` | 只保存账号密码，不在本文档写明文 |

凭据变量：

```text
SCHEDULING_USER / SCHEDULING_PASS
JENKINS_USER / JENKINS_PASS
NACOS_USER / NACOS_PASS（当前为空）
```

## 2. 平台总索引

| 平台 | 环境 | 入口 | 负责什么 | 当前只读结论 |
| --- | --- | --- | --- | --- |
| 调度中心 | test | `http://10.0.54.16:32740/scm-scheduling-web/jobinfo` | XXL Job 定时任务 | 已登录并取得订单任务 239/240 全部字段 |
| 调度中心 | UAT | `http://10.0.54.16:31799/scm-scheduling-web/jobinfo` | UAT 定时任务 | 已登录；订单中心没有 239/240 对应任务 |
| Nacos | test 控制台 | `http://10.0.54.16:30996/nacos/` | 服务运行配置，例如 ES 索引名 | 登录页可达；缺控制台账号 |
| Jenkins | 全环境 | `http://jenkins.jdsn.com/` | 发 jar、构建镜像、部署服务/前端 | 已登录；已核清 all/web 两段流水线 |

### 2.1 调度中心

菜单：

- 运行报表：看任务数、调度次数、执行器数。
- 任务管理：查任务、开编辑弹窗看完整参数。
- 调度日志：查某次任务是否调度成功、执行成功。
- 执行器管理：看服务是否已注册进调度中心。

页面列表调用：

```text
POST /scm-scheduling-web/jobinfo/pageList
```

已看到的查询参数：

```text
jobGroup / triggerStatus / jobDesc / executorHandler / author / start / length
```

这是查询 POST，已加入只读放行清单。任务新增、更新、删除、执行一次、启停等写接口不放行。

test 的“订单中心”执行器值为 `jobGroup=6`，目标任务如下：

| 字段 | 任务 240 | 任务 239 |
| --- | --- | --- |
| 任务描述 | 集采日统计服务 | 集采管理业务统计报表-云采 |
| 状态 | RUNNING | RUNNING |
| 调度类型 | CRON | CRON |
| Cron | `0 3 3 * * ?` | `1 1 5 * * ?` |
| 运行模式 | BEAN | BEAN |
| JobHandler | `simpleJobHandler` | `simpleJobHandler` |
| 任务参数 | `order-centralPurchaseDailyStatisticsService-syncCloudPurchaseData-{}` | `order-centralizedProcurementReportService-syncCentralizedOrderToEs-{}` |
| 负责人 | `zyl` | `zyl` |
| 路由策略 | FIRST | FIRST |
| 调度过期策略 | DO_NOTHING | DO_NOTHING |
| 阻塞处理策略 | SERIAL_EXECUTION | SERIAL_EXECUTION |
| 超时时间 / 重试 | 0 / 0 | 0 / 0 |
| 子任务 / 报警邮件 | 空 / 空 | 空 / 空 |

UAT 的“订单中心”同样是 `jobGroup=6`，2026-07-27 只读查询时共有 5 个旧任务，没有上表两项。这证明“需要在 UAT 新建”是真实缺口，不是仅凭同事口述。

### 2.2 Jenkins

可见视图：

| 视图 | 用途 |
| --- | --- |
| `scm-be-deploy-test/uat/prod` | `*-all-*` 业务仓构建 |
| `scm-be-start-test/uat` | `*-web-*` 运行服务镜像和 K8s 部署 |
| `scm-fe-deploy-test/uat` | 前端静态资源部署 |

寻源和订单任务：

| 模块 | 发业务 jar | 部署运行服务 |
| --- | --- | --- |
| source test | `scm-source-all-test` | `scm-source-web-test` |
| source UAT | `scm-source-all-uat` | `scm-source-web-uat` |
| source prod | `scm-source-all-prod` | 当前账号可见任务中没有 `scm-source-web-prod` |
| order test | `scm-order-all-test` | `scm-order-web-test` |
| order UAT | `scm-order-all-uat` | `scm-order-web-uat` |
| order prod | `scm-order-all-prod` | 当前账号可见任务中没有 `scm-order-web-prod` |

最重要的区别：

1. `*-all-*` 的 Jenkins 在线流水线只有“拉取、编译”，实际命令包含 `mvn clean deploy`。它把业务 jar 发进 Nexus，**不会把正在运行的 Pod 换成新代码**。
2. `*-web-*` 从 `scm-cloud-starters-web` 取启动工程，执行“编译 → 镜像构建 → 镜像推送 → 部署到集群”，在线配置明确包含 `docker push` 和 `kubectl apply`。
3. 所以 test/UAT 后端的真实顺序是：**先 all，再 web**。只看到 all 成功，不能说环境已经部署。
4. production 没看到对应 `web-prod`，符合“生产交运维”的边界；不要猜入口，更不能拿 UAT 的任务改参数代替。

2026-07-29 补充核实：UAT 的 source/order 也已经配置上游自动触发。最近一次
`scm-source-all-uat #478` 自动触发 `scm-source-web-uat #444`，
`scm-order-all-uat #208` 自动触发 `scm-order-web-uat #199`。因此通常只需人工点 all，
但仍必须等并检查 web 成功；all 成功、web 失败仍算部署失败。

最近成功构建参数已核对：

| 任务族 | test | UAT | prod |
| --- | --- | --- | --- |
| `source/order-all` 分支 | `test` | `uat` | `prod` |
| `source/order-all` 版本 | `1.0.0-JDSN-TEST-SNAPSHOT` | `1.0.0-JDSN-UAT-SNAPSHOT` | `1.0.0-JDSN-PROD-SNAPSHOT` |
| `source/order-web` 分支 | `test` | `uat` | 未见对应 job |
| `source/order-web` 版本 | `1.0.0-JDSN-TEST-SNAPSHOT` | `1.0.0-JDSN-UAT-SNAPSHOT` | 未核实 |

采购方案前端的已验证任务：

| 环境 | Jenkins job | PROJECT | GIT_BRANCH |
| --- | --- | --- | --- |
| test | `scm-vue-statics-test` | `procurementScheme` | `test` |
| UAT | `scm-vue-statics-uat` | `procurementScheme` | `uat` |

安全提醒：`/job/<任务>/build?delay=0sec` 是危险入口，不能为了“看看参数”直接打开。只读取证使用：

```text
GET /job/<任务>/api/json
GET /job/<任务>/lastBuild/api/json
GET /job/<任务>/config.xml
```

### 2.3 Nacos

用户给出的 ES 配置页是 Nacos 配置中心，不是 K8s YAML 编辑页。两者关系是：

```text
Nacos 保存应用配置
  → scm-order-web / scm-source-web 启动时读取
  → Jenkins 部署的新 Pod 按对应 profile 使用这份配置
```

从 starter 代码核实出的配置定位规则：

| 环境 | namespace | group | order Data ID | source Data ID |
| --- | --- | --- | --- | --- |
| test | `scm-jdsn-test` | `common` | `scm-order-web-test.yaml` | `scm-source-web-test.yaml` |
| UAT | `scm-jdsn-uat` | `common` | `scm-order-web-uat.yaml` | `scm-source-web-uat.yaml` |
| prod | `jdsn-prod` | `common` | `scm-order-web-prod.yaml` | `scm-source-web-prod.yaml` |

证据：

- 应用名：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-order/src/main/resources/bootstrap.yml:15` 和 `scm-cloud-source/.../bootstrap.yml:15`。
- namespace/group：同目录 `bootstrap-test.yml:6-7`、`bootstrap-uat.yml:6-7`、`bootstrap-prod.yml:6-7`。
- test 页面链接里的 Data ID、group、namespace 与代码规则完全一致。

当前没有 Nacos 控制台账号，因此还不能确认：

- UAT 配置正文里是否已经有 `elastic.config`。
- 应插入在哪个 YAML 层级，是否存在同名键。
- prod 由哪个 Nacos 控制台入口维护。
- 修改后是否需要仅发布配置、重启服务，或两者都要。

这些都不猜，等登录后按页面和 Network 实际核对。

## 3. 平台与本地代码怎么对应

| 线上名字 | 本地代码 | 说明 |
| --- | --- | --- |
| `scm-source-all-*` | `01zhaocai-end/scm-source-all` | 寻源业务源码；all 流水线发 jar |
| `scm-source-web-*` | `03zhaocai-start/scm-cloud-starters-web/scm-cloud-source` | 寻源启动工程；web 流水线打镜像并部署 |
| `scm-order-all-*` | `01zhaocai-end/scm-order-all` | 订单业务仓；本地当前只有 README，最终以远端/Jenkins 为准 |
| `scm-order-web-*` | `03zhaocai-start/scm-cloud-starters-web/scm-cloud-order` | 订单启动工程 |
| `scm-vue-statics-*` + `PROJECT=procurementScheme` | `02zhaocai-front/scm-vue-all-procurementscheme` | 采购方案前端 |
| 调度“寻源模块” | `scm-source-web` 注册的 XXL Job 执行器 | 参数前缀通常是 `source-` |
| 调度“订单中心” | `scm-order-web` 注册的 XXL Job 执行器 | 参数前缀通常是 `order-` |

## 4. 后续 UAT 的建议顺序（当前仅记录，不执行）

1. 核对并执行 UAT SQL。
2. 在 UAT Nacos 补齐对应 ES 索引配置。
3. 构建 `*-all-uat`，确认业务 jar 成功发布。
4. 构建 `*-web-uat`，确认新镜像和 Pod 部署成功。
5. 如有前端改动，构建 `scm-vue-statics-uat`，参数 `PROJECT=procurementScheme`。
6. 在 UAT 调度中心新增任务；在服务已部署、执行器在线后再启动，避免任务先跑而服务还没准备好。
7. 查调度日志、ES 和页面做对账。
8. production 的 SQL、Nacos、任务参数、分支和版本整理成一份话术交运维；不由 AI 或用户照搬 UAT 页面直接改生产。

## 5. 当前只需要用户补一件事

把下面两项填到 `ai-docs/creds.env`，不要发到聊天或普通文档：

```text
NACOS_USER='...'
NACOS_PASS='...'
```

如果需要向同事询问，可直接复制：

> 我在整理需求 1～4 从 test 上 UAT/生产的配置清单，需要只读核对 Nacos 里 `scm-order-web-test/uat/prod.yaml` 和 `scm-source-web-test/uat/prod.yaml` 的差异。麻烦给我 Nacos 控制台的登录账号，或者告诉我该找谁开只读权限。我不会发布或修改配置。

拿到后，AI 会继续登录查看，不会点击“发布”或“保存”。

## 6. 本轮明确没有做的动作

- 没有触发任何 Jenkins 构建。
- 没有新增、执行、启动、停止或修改任何定时任务。
- 没有保存或发布任何 Nacos 配置。
- 没有修改数据库、ES、K8s 或远程 Git 分支。
- 调度任务的“编辑”只打开弹窗读取字段，未改字段、未保存。
