# SCM 项目平台索引

更新日期：2026-07-30。这里记录可长期复用的名称规律和入口，不记录任何密码、token、cookie。

## 两层入口与依赖

优先从项目场景入口开始；只有需要补某个平台的细节时，才使用底层入口：

```bash
bash skills/diagnose-scm-project/scripts/project.sh <场景> ...
bash skills/diagnose-scm-project/scripts/platform.sh <平台> <动作> ...
```

依赖：

- 项目模块目录：`references/modules.json`，负责代码仓、Application、Deployment、Jenkins、Nacos、调度执行器和路由前缀之间的映射。
- 凭据文件：`ai-docs/creds.env`，脚本内部加载，禁止输出内容。
- 只读浏览器：`scripts/browser-ro.sh`。
- 浏览器网络护栏：`scripts/browser/readonly-guard.js`。
- Playwright 配置：`.playwright/cli.config.json`。
- 会话缓存：用户缓存目录下的 `work-wsl-platforms` 和既有 `work-wsl-browser`，目录权限 700、cookie 文件权限 600，不进入 Git。
- K8s 走 KubeSphere Web Session + Kubernetes GET API；Jenkins、项目文档走 Windows Chrome 网络桥接；调度和 Nacos 使用持久化只读浏览器会话。
- K8s 日志两层获取：`k8s logs` 用 Pod log API 看**存活容器**实时日志；`k8s eslogs` 用 KubeSphere 日志查询 API（`/kapis/tenant.kubesphere.io/v1alpha2/logs`，集群 fluent-bit 全量采集进 Elasticsearch）查**历史/跨副本/全文检索**日志。Pod 滚动更新后旧日志只能用 `k8s eslogs` 找回。
- 同一个浏览器 profile 由文件锁串行访问，避免两个查询互相改写页面状态。

## 凭据变量名

只允许在 `ai-docs/creds.env` 中配置值。

| 平台 | 必需变量 | 可选变量 |
| --- | --- | --- |
| K8s 非生产 | `K8S_URL`、`K8S_USER`、`K8S_PASS` | `K8S_NAMESPACE_DEV/TEST/UAT` |
| K8s 生产 | 可复用上面账号，或 `K8S_PROD_USER/PASS` | `K8S_PROD_URL`、必须人工确认的 `K8S_NAMESPACE_PROD` |
| Jenkins | `JENKINS_USER`、`JENKINS_PASS` | 无 |
| Nacos | `NACOS_USER`、`NACOS_PASS` | `NACOS_BASE_URL`、各环境 `NACOS_NAMESPACE_*` |
| 调度平台 | `SCHEDULING_USER`、`SCHEDULING_PASS` | 无 |

不要从项目文档页面、代码默认值、Jenkins 日志或聊天记录补猜凭据。

## 环境索引

### K8s

已在线验证：

| 环境 | Namespace | 备注 |
| --- | --- | --- |
| test | `si-scm-product-test` | 当前 KubeSphere 集群 |
| uat | `si-scm-product-uat` | 当前 KubeSphere 集群 |
| dev | 不固定 | 先 `k8s namespaces dev`，再显式配置 |
| prod | 未确认 | 生产真实集群/namespace 必须问运维，不从目录名猜 |

`si-scm-product` 不能直接认定为生产：历史核查中主后端多为 0 副本，且 Jenkins 没有常规 `*-web-prod` 任务。

### Nacos

Data ID 规律：

```text
<spring.application.name>-<profile>.yaml
```

常用配置：

| 环境 | namespace | group |
| --- | --- | --- |
| dev | `scm-jdsn`（使用前按 bootstrap 核实） | `common` |
| test | `scm-jdsn-test` | `common` |
| uat | `scm-jdsn-uat` | `common` |
| prod | `jdsn-prod` | `common` |

例：`scm-order-web-uat.yaml`、`scm-source-web-test.yaml`。

### 调度平台

| 环境 | 入口 | 结构化命令 |
| --- | --- | --- |
| test | `10.0.54.16:32740/scm-scheduling-web` | 已验证 |
| uat | `10.0.54.16:31799/scm-scheduling-web` | 已验证 |
| dev | `10.0.54.16:31369/scm-scheduling-web` | 地址已知，当前包装器未开放 |
| prod | `10.79.10.201:30605/scm-scheduling-web` | 只记录地址，正式操作先找运维 |

常用执行器：

| ID | 名称 |
| --- | --- |
| 2 | 寻源模块 |
| 3 | 供应商模块 |
| 4 | 基础管理模块 |
| 5 | 接口模块 |
| 6 | 订单中心 |
| 7 | 工作流代理服务 |
| 8 | 商品中心 |
| 9 | 合同模块 |
| 10 | 专家模块 |

列表状态 `RUNNING/STOP` 是任务配置状态；日志的成功/失败是某次执行结果，二者不要混为一谈。

### Jenkins

开发 Jenkins：`http://jenkins.jdsn.com/`。WSL 直连可能 502，统一命令会复用 Windows Chrome。

后端常见两段式：

```text
scm-<module>-all-<env>
  └─ 成功后触发 scm-<module>-web-<env>
       └─ 构建镜像 + 推送 + kubectl apply
```

test 与 UAT 已确认多个模块存在这条自动链路。仍要分别验证 `all` 和 `web` 的实际构建号，不能只看上游绿灯。

前端常见任务：

```text
scm-vue-statics-<env>
```

通常带 `PROJECT` 和 `GIT_BRANCH` 参数。前端运行态常落在 `Deployment/scm-statics-web`，不是业务后端 Deployment。

这是共享 Job，`lastBuild` 可能属于另一个前端。项目级前端发布诊断会用 `PROJECT` 参数在最近构建中找到对应记录，再取该构建号的控制台证据。

## 后端模块映射

| 业务 | application / Deployment | 默认端口 | Jenkins 任务规律 | 调度执行器 |
| --- | --- | ---: | --- | --- |
| 网关 | `scm-gateway-web` | 9900 | `scm-gateway-all/web-<env>` | — |
| 认证 | `scm-auth-web` | 8000 | `scm-auth-all/web-<env>` | — |
| 基础管理 | `scm-ubm-web` | 8100 | `scm-ubm-all/web-<env>` | 基础管理模块 |
| 寻源 | `scm-source-web` | 8110 | `scm-source-all/web-<env>` | 寻源模块 |
| 供应商 | `scm-srm-web` | 8130 | `scm-srm-all/web-<env>` | 供应商模块 |
| 合同 | `scm-contract-web` | 8150 | `scm-contract-all/web-<env>` | 合同模块 |
| 订单 | `scm-order-web` | 8200 | `scm-order-all/web-<env>` | 订单中心 |
| 商品 | `scm-product-web` | 8300 | `scm-product-all/web-<env>` | 商品中心 |
| 接口 | `scm-ifs-web` | 8083 | `scm-ifs-all/web-<env>` | 接口模块 |
| 专家 | `scm-professor-web` | 8002 | `scm-professor-all/web-<env>` | 专家模块 |
| 文件 | `scm-file-web` | 8003 | `scm-file-all/web-<env>` | — |
| 报表 | `scm-report-web` | 80 | `scm-report-all/web-<env>` | — |
| 工作流代理 | `scm-workflow-web` | 9800 | `scm-workflow-all/web-<env>` | 工作流代理服务 |
| 调度中心 | `scm-scheduling-web` | 8902 | 平台自身，勿通过本技能启停 | — |

以上 test/UAT Jenkins 名称已于 2026-07-30 批量核实。运行态精确名称仍以 `jenkins jobs <keyword>` 和 `k8s deployments <env> <filter>` 的实时结果为准。

## 项目文档站

入口：`http://yingle.jdsn.com/yingle1991/`

已确认的招采页面：

| 主题 | 路径 |
| --- | --- |
| 中间件清单/访问地址 | `pages/4fbb04/` |
| 部署步骤 | `pages/c82752/` |
| 运维总结 | `pages/26f751/` |

只读标题与目录，不抓取整页表格。历史页面可能包含明文账号信息，但凭据的唯一受控来源仍是 `ai-docs/creds.env`。

## 与现有脚本的分工

| 证据 | 首选工具 |
| --- | --- |
| 从接口/页面/发布/任务出发的模块定位与证据链 | 本技能 `project.sh` |
| Jenkins/Nacos/K8s/调度/内部文档的单项细查 | 本技能 `platform.sh` |
| MySQL 查询 | `scripts/dbq.sh` |
| ES 索引、mapping、count、样本 | `scripts/esq.sh` |
| test API | `scripts/api.sh` |
| 需求字段填充率 | `scripts/fieldcheck.sh` |
| Java 隔离编译 | `scripts/jc.sh` |

不要在本技能复制数据库、ES、API 凭据或重造这些脚本。

## 已知限制

- Nacos 的结构化读取依赖页面编辑器 DOM；Nacos 升级后如果提取为空，先核实页面和权限，再只调整提取选择器。
- 调度平台按任务 ID 查日志时，受页面接口和只读护栏限制：先按执行器加载当天最多 100 条，再本地筛选 ID。
- `project.sh diagnose task` 会只读查询 test/UAT 的 `xxl_job_info` 和 `xxl_job_log`，适合获取精确任务配置与最深层失败原因；其他环境未固化数据库名。
- Jenkins `evidence` 只抽取版本、镜像、kubectl 和最终结果等关键行；需要完整上下文时用小范围 `log --tail`。
- 自动脱敏是最后一道防线，不代表可以无边界抓取页面。先缩小查询范围。
- 生产入口、namespace、发布流程可能与 test/UAT 不同，任何缺口都必须交给运维确认。
