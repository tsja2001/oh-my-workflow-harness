# Fastjson SafeMode：Dockerfile 更新与重新部署清单

> 日期：2026-07-29  
> 工具：codex  
> 当前状态：22 份目标 Dockerfile 已全部规范化；用户反馈两个 03 仓的改动均已提交完成，已准备 `Jenkinsfile-safeMode-test` 顺序调用 22 个 `*-web-test`。  
> 下一阶段：用户把脚本粘贴到 Pipeline 任务并手动点击一次“立即构建”；完成后核对构建结果、最新 Pod 和 SafeMode 环境变量。之后才进入 UAT。生产发布入口和几份历史 DPS Deployment 仍需运维确认。  
> 文档关系：本文是“到底改哪些 Dockerfile、部署哪些服务”的当前执行清单；关于漏洞原理、官方修复状态和安全验证，仍以 `02漏洞问题/90-临时-Fastjson2漏洞调研与处置总结-codex.md` 为准。本文用 2026-07-29 的 Jenkins/K8s 运行事实补全并更新该文第 5、9 节的待盘点项。

---

## 0. 先看结论

本地一共找到 **39 份 Dockerfile 类文件**，但不能全部修改：

| 分类 | 数量 | 结论 |
|---|---:|---|
| 实际 Jenkins 可构建的公司 Java 运行镜像 | **22** | 本次 SafeMode 范围 |
| 其中 Source | 1 | test 已部署并确认参数生效；本地 feature 已清理重复配置 |
| 其余 21 份 | **21** | 本地 feature 已增加 SafeMode；待合入 test、构建新镜像并滚动新 Pod |
| 前端 Nginx、Elasticsearch、历史副本、样例、未使用入口 | **17** | 本次不改，理由见第 4 节 |
| 02 前端业务仓 Dockerfile | 0 | 前端镜像配方集中在 03 的启动仓，不在 02 |

一句话：

> 不是“看到 Dockerfile 就改”，而是“这个 Dockerfile 是否真的制作了一个在线 Java 服务的镜像，而且这个 Java 服务包含 Fastjson”。当前答案是 22 份；本地代码修改已完成，运行环境仍只有 Source test 已确认生效。

### 当前最重要的运行事实

1. `scm-source-web` 的 test 新 Pod 使用 2026-07-29 10:58 构建的镜像。
2. Source Pod 启动日志明确出现：

   ```text
   Picked up JAVA_TOOL_OPTIONS: -Dfastjson.parser.safeMode=true
   ```

3. 所以 Source 已从“本地试点”变成“test 已部署、启动参数已确认生效”。
4. Source UAT Pod 日志没有该回执，仍需后续推广。
5. 当前 K8s Deployment YAML 没有单独声明 `JAVA_TOOL_OPTIONS`；Source 的值来自镜像内 Dockerfile。  
   因此“Deployment 的 env 列表为空”不等于镜像里没有这个环境变量，最终要看新 Pod 启动日志。

---

## 1. 为什么这些 Java 服务都要分别更新

公司后端链路是：

```text
01 业务仓源码
  → mvn deploy 发业务 jar 到 Nexus
  → 03 启动仓把业务 jar 打进各自的可运行包
  → 每个服务各做一个 Docker 镜像
  → K8s 各跑一个独立 JVM
```

`scm-source-web`、`scm-order-web`、`scm-auth-web` 不是同一个 Java 进程。给 Source 镜像加 SafeMode，只能保护 Source，不能自动保护 Order/Auth。

本次统一配置建议是：

```dockerfile
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"
```

为什么放这里：

- `JAVA_TOOL_OPTIONS` 是 JVM 启动时自动读取的环境变量。
- Fastjson SafeMode 必须在 Fastjson 类加载前生效，不能等 Spring/Nacos 启动后再配。
- 一行配置同时适用于 Spring Boot `java -jar` 和 DPS 的 Tomcat JVM。
- 每个服务必须重新制作镜像并拉起新 Pod；只重启使用旧镜像的 Pod不会获得新 Dockerfile 配置。

为什么用不带 `2` 的属性名：

- 当前 2.0.62 兼容包同时识别 `fastjson.parser.safeMode` 和 `fastjson2.parser.safeMode`。
- 不带 `2` 的名字兼容现有 `com.alibaba.fastjson.*` 使用方式，也便于覆盖 DPS 这类实际版本尚未从运行容器中取证的老应用。
- 配一处即可；同一个属性写进 `JAVA_TOOL_OPTIONS` 后，不要再在 `java` 命令行重复一次。

---

## 2. 本地 Dockerfile 全量盘点

扫描范围：

```text
01zhaocai-end
02zhaocai-front
03zhaocai-start
```

排除了 `node_modules` 和 `target` 构建产物。

| 仓库/目录 | Dockerfile 数量 | 本次进入更新范围 | 说明 |
|---|---:|---:|---|
| `01zhaocai-end` | 4 | 0 | 当前在线服务由 03 启动仓制作镜像；01 的 4 份是历史副本/样例/旧入口 |
| `02zhaocai-front` | 0 | 0 | 前端源码仓没有 Dockerfile |
| `03zhaocai-start/scm-cloud-starters-web` | 24 | 19 | 19 个实际 Java 服务；其余为根级备用 Dockerfile、未使用的 Java statics 和 Nginx 变体 |
| `03zhaocai-start/scm-cloud-starters-wfproduct` | 6 | 3 | DPS、DPS Service、DPS Core 三个 Java/Tomcat 镜像；另 3 个是 Nginx |
| `03zhaocai-start/scm-cloud-starter-vue` | 4 | 0 | 全是 Nginx 前端静态镜像 |
| `03zhaocai-start/scm-cloud-starters-elasticsearch` | 1 | 0 | Elasticsearch 自身镜像，不是公司 Spring Boot/Fastjson 应用 |
| **合计** | **39** | **22** | Source 已完成 test，其余 21 份待更新 |

---

## 3. 需要更新/重新部署的 Java 镜像

### 3.1 03 主后端启动仓：19 份

统一路径前缀：

```text
03zhaocai-start/scm-cloud-starters-web/
```

Jenkins 在线配置确认，这些 `*-web-test` / `*-web-uat` 任务都会：

```text
mvn clean install
→ docker build 当前 PROJECT_DIR/Dockerfile
→ docker push
→ kubectl apply
```

#### A. Source：test 已完成，UAT/生产仍未完成

| 项目 | Dockerfile | test | UAT | 下一步 |
|---|---|---|---|---|
| Source | `scm-cloud-source/Dockerfile` | ✅ 新 Pod 日志确认 SafeMode | ❌ UAT Pod 无 SafeMode 回执 | 不再追加配置；先清理重复的命令行 `-D`，再把规范化版本推广到 UAT/生产 |

当前 test 分支 `64dfc8f` 同时存在两处相同配置：

```dockerfile
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"
```

以及长启动命令中的：

```text
-Dfastjson.parser.safeMode=true
```

安全功能已经生效，但第二处属于重复配置。最终规范形态建议只保留顶部 `JAVA_TOOL_OPTIONS`。

对应 Jenkins：

```text
scm-source-web-test
scm-source-web-uat
```

Dockerfile-only 改动不需要先点 `scm-source-all-*`。

#### B. 其余 18 份：本地 feature 已加 SafeMode，尚未合入和部署

| 启动模块 / Dockerfile | test 运行态 | UAT 运行态 | 对应 Jenkins test | 结论 |
|---|---|---|---|---|
| `scm-cloud-auth/Dockerfile` | 运行中 | 运行中 | `scm-auth-web-test` | 改并重部署 |
| `scm-cloud-contract/Dockerfile` | 运行中 | 运行中 | `scm-contract-web-test` | 改并重部署 |
| `scm-cloud-devops/Dockerfile` | 运行中 | 运行中 | `scm-devops-web-test` | 改并重部署 |
| `scm-cloud-fee/Dockerfile` | Deployment 期望 1，当前可用 0 | 未见 Deployment | `scm-fee-web-test` | Dockerfile 要改；服务当前异常，部署时同时排查起不来原因 |
| `scm-cloud-file/Dockerfile` | 运行中 | 运行中 | `scm-file-web-test` | 改并重部署 |
| `scm-cloud-gateway-mall/Dockerfile` | 运行中 | 运行中 | `scm-gateway-mall-web-test` | 改并重部署 |
| `scm-cloud-gateway/Dockerfile` | 运行中 | 运行中 | `scm-gateway-web-test` | 改并重部署 |
| `scm-cloud-ifs-schedule/Dockerfile` | 运行中 | 未见 Deployment | `scm-ifs-schedule-web-test` | 改并重部署 test；UAT 是否需要上线另确认 |
| `scm-cloud-ifs/Dockerfile` | 运行中 | 运行中 | `scm-ifs-web-test` | 改并重部署 |
| `scm-cloud-order/Dockerfile` | 运行中 | 运行中 | `scm-order-web-test` | 改并重部署 |
| `scm-cloud-product/Dockerfile` | 运行中 | 运行中 | `scm-product-web-test` | 改并重部署 |
| `scm-cloud-professor/Dockerfile` | 运行中 | 运行中 | `scm-professor-web-test` | 改并重部署 |
| `scm-cloud-report/Dockerfile` | 运行中 | 运行中 | `scm-report-web-test` | 改并重部署 |
| `scm-cloud-scheduling/Dockerfile` | 运行中 | 运行中 | `scm-scheduling-web-test` | 改并重部署 |
| `scm-cloud-srm/Dockerfile` | 运行中 | 运行中 | `scm-srm-web-test` | 改并重部署 |
| `scm-cloud-ubm-mall/Dockerfile` | 运行中 | 运行中 | `scm-ubm-mall-web-test` | 改并重部署 |
| `scm-cloud-ubm/Dockerfile` | 运行中 | 运行中 | `scm-ubm-web-test` | 改并重部署 |
| `scm-cloud-workflow/Dockerfile` | 运行中 | 运行中 | `scm-workflow-web-test` | 改并重部署 |

这些文件为什么进入范围：

1. Dockerfile 明确启动 Java 可运行包。
2. Jenkins 当前在线任务明确把对应目录作为 `PROJECT_DIR`。
3. test K8s 存在对应 Deployment；除 Fee 当前不可用外，其余都在运行。
4. 它们通过公司统一依赖和业务 jar 使用 Fastjson；当前 Dockerfile 和 K8s 模板均未配置 SafeMode。

### 3.2 工作流产品仓：3 份

统一路径前缀：

```text
03zhaocai-start/scm-cloud-starters-wfproduct/
```

| 项目 / Dockerfile | 代码证据 | K8s/Jenkins 证据 | 结论 |
|---|---|---|---|
| `scm-cloud-dps-service/Dockerfile` | POM 直接声明 `com.alibaba:fastjson` | test 有 `scm-dps-service-web`；Jenkins 有 test/UAT 任务 | 改并重部署 |
| `scm-cloud-dps/Dockerfile` | POM 直接声明 `com.alibaba:fastjson` | test 的标准任务部署 `scm-workflow-dps`；UAT 任务部署 `workflow-dps-uat` | 改并重部署 |
| `scm-cloud-dpscore/Dockerfile` | POM 直接声明 `com.alibaba:fastjson` | test/UAT 均有对应运行实例和 Jenkins 任务 | 改并重部署 |

DPS 不是 Spring Boot `java -jar`，而是 Dockerfile 启动 Tomcat，但仍然是 JVM。`JAVA_TOOL_OPTIONS` 会被 Tomcat 启动的 Java 进程自动读取，所以配置方式不变。

对应 Jenkins：

```text
scm-dps-service-web-test
scm-dps-web-test
scm-dpscore-web-test

scm-dps-service-web-uat
scm-dps-web-uat
scm-dpscore-web-uat
```

#### DPS 的遗留重复实例必须另外确认

K8s 还存在以下运行中的 DPS/Workflow 实例，但它们没有与当前可见 Jenkins 任务一一对应：

```text
test：scm-workflow-dps-test
si-scm-product 命名空间：scm-workflow-dps、workflow-dps
```

当前 Jenkins 只看到 9 个 DPS dev/test/UAT 任务，没有额外的 prod 或这些旧名字的任务。

因此：

- 修改上面 3 份 Dockerfile，可以覆盖当前标准 Jenkins 任务后续制作的新镜像。
- 不能据此宣布这些历史 Deployment 已被覆盖。
- 需要运维确认这些实例是否仍有流量、镜像从哪条流水线产生；若仍在使用，要用同一 SafeMode 参数重新制作或在正式 Deployment 模板注入。

---

## 4. 明确不用更新的 17 份 Dockerfile

“不用更新”仅指**不因这次 Fastjson SafeMode 修改它**，不是建议删除文件。

### 4.1 01 业务仓里的 4 份：当前不是主线镜像入口

| Dockerfile | 为什么不改 |
|---|---|
| `01zhaocai-end/scm-source-all/scm-cloud-source/Dockerfile` | Source 当前 Jenkins 的 `PROJECT_DIR=scm-cloud-source` 来自 03 的 `scm-cloud-starters-web`；K8s 新镜像也由该任务产生。01 这份是历史/并行副本 |
| `01zhaocai-end/scm-datacenter-all/scm-cloud-ifs/Dockerfile` | 当前 `scm-ifs-web-*` Jenkins 构建 03 的 `scm-cloud-ifs`，不是这份历史副本 |
| `01zhaocai-end/scm-workflow-all/Dockerfile` | 当前 `scm-workflow-web-*` Jenkins 构建 03 的 `scm-cloud-workflow`；本文件使用 `mvn spring-boot:run`，不是当前在线入口 |
| `01zhaocai-end/scm-assemblies-all/scm-scheduling-all/xxl-job-executor-sample-springboot/Dockerfile` | 这是 XXL Job 示例执行器；当前在线调度中心由 03 的 `scm-cloud-scheduling` 构建 |

只有后续 Jenkins/运维证明确有 Pod 由这 4 份文件构建，才重新纳入，不能因为文件存在就两边都改。

### 4.2 前端 Nginx：不运行 Java，不加载 Fastjson

以下共 10 份不改：

```text
03zhaocai-start/scm-cloud-starter-vue/scm-cloud-statics/Dockerfile
03zhaocai-start/scm-cloud-starter-vue/scm-cloud-statics/Dockerfile-Nginx
03zhaocai-start/scm-cloud-starter-vue/scm-cloud-statics/Dockerfile-Nginx-Uat
03zhaocai-start/scm-cloud-starter-vue/scm-cloud-statics/Dockerfile-Nginx-Prod

03zhaocai-start/scm-cloud-starters-web/scm-cloud-statics/Dockerfile-Nginx
03zhaocai-start/scm-cloud-starters-web/scm-cloud-statics/Dockerfile-Nginx-Uat
03zhaocai-start/scm-cloud-starters-web/scm-cloud-statics/Dockerfile-Nginx-Prod

03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dpscore/Dockerfile-Nginx
03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dpscore/Dockerfile-Nginx-Uat
03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dpscore/Dockerfile-Nginx-Prod
```

K8s 中的这些 Deployment 也确认是静态/Nginx 服务，不改：

```text
scm-statics-web
scm-statics-mall-web
scm-statics-h5-web
scm-statics-mall-h5-web
docs-yingle-web
nginx-proxy
```

其中 `docs-yingle-web` 虽然本地没找到同名 Dockerfile，但运行日志是 Nginx 启动脚本，不是 Java。

### 4.3 其余 3 份

| Dockerfile | 为什么不改 |
|---|---|
| `03zhaocai-start/scm-cloud-starters-elasticsearch/scm-cloud-elasticsearch/Dockerfile` | Elasticsearch 自身虽用 JVM，但不是公司打包的 Fastjson 业务应用；本镜像只安装 ES 插件/库 |
| `03zhaocai-start/scm-cloud-starters-web/Dockerfile` | 根级通用/备用配方；当前 22 个 web test/UAT 任务都进入各自 `PROJECT_DIR` 并使用子目录 Dockerfile |
| `03zhaocai-start/scm-cloud-starters-web/scm-cloud-statics/Dockerfile` | 这是 Java 版静态服务配方，但当前 K8s 的 statics 实例实际是 03 Vue 启动仓制作的 Nginx 镜像，Jenkins 也没有对应 Java statics web 任务 |

### 4.4 第三方 MockServer

test 还有 `mockserver-netty:latest`。它不是当前公司源码/Dockerfile 制作的业务镜像，也没有证据表明包含公司的 Fastjson 2.0.62，因此不进入本轮修改清单。

---

## 5. K8s 当前环境事实

核对时间：2026-07-29 11:06（Asia/Shanghai）。

### 5.1 test：`si-scm-product-test`

| 项目 | 当前事实 |
|---|---|
| Deployment 总数 | 28 |
| 主后端 Java Deployment | 19 个；18 个可用，Fee 期望 1 但可用 0 |
| DPS/Workflow Java Deployment | 4 个运行中，其中 1 个是未映射的历史名字 `scm-workflow-dps-test` |
| 已确认 SafeMode | 只有 `scm-source-web` |
| 前端/静态 | 4 个 statics Nginx，不处理 |
| 第三方 | MockServer，不处理 |

### 5.2 UAT：`si-scm-product-uat`

| 项目 | 当前事实 |
|---|---|
| Deployment 总数 | 22 |
| 主后端 Java Deployment | 17 个，均运行中 |
| 未见的主服务 | Fee、IFS Schedule |
| Source SafeMode | 尚未生效，Pod 日志无 `Picked up JAVA_TOOL_OPTIONS` |
| 前端/静态 | 4 个 statics + `docs-yingle-web`，均为 Nginx，不处理 |

DPS UAT 任务实际把带 `-uat` 的实例放在 `si-scm-product` 命名空间，不在上述 UAT 命名空间里。

### 5.3 `si-scm-product`：不能直接当成完整生产清单

当前看到：

- Auth、Contract、Source、Order、Gateway 等 18 个主后端 Deployment 都是期望副本 0，没有运行 Pod。
- Statics/Nginx 有运行实例。
- 有 5 个 DPS/Workflow 相关 Java 实例运行，其中混有 `-uat` 名字。
- Jenkins 当前有 18 个 `*-all-prod` 任务，但没有任何 `*-web-prod` 任务。

所以现在只能得出：

> 当前账号可见的这个命名空间，不足以证明“正式生产所有后端服务的真实运行入口”。不能拿 test/UAT 的 Jenkins 任务猜生产发布方式。

生产推广前必须先确认：

1. 正式生产后端到底在哪个集群/命名空间运行。
2. 为什么这里的主后端 Deployment 都缩容到 0。
3. 正式镜像由哪条 Jenkins/运维流水线构建。
4. 生产是否使用另一套 Helm/Deployment 模板。

---

## 6. 推荐修改和部署顺序

### 6.1 代码修改

在剩余 21 份 Dockerfile 中，紧跟时区配置附近加入一行：

```dockerfile
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"
```

Source 的最终规范：

```dockerfile
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"
```

并从长 `java` 命令中删除重复的：

```text
-Dfastjson.parser.safeMode=true
```

不要改：

- Nacos。
- `application.yml`。
- 前端 Nginx Dockerfile。
- 01 中的历史 Dockerfile副本。
- Elasticsearch Dockerfile。

### 6.2 test 推荐顺序

第一批：入口和外部输入面较大

```text
scm-auth-web-test
scm-gateway-web-test
scm-gateway-mall-web-test
scm-ifs-web-test
scm-ifs-schedule-web-test
```

Source 已经完成 test，不需要为了安全开关重复部署；如果清理重复配置，则把它作为普通 Dockerfile 整理重新部署一次：

```text
scm-source-web-test
```

第二批：核心业务

```text
scm-order-web-test
scm-product-web-test
scm-srm-web-test
scm-contract-web-test
scm-report-web-test
scm-ubm-web-test
scm-ubm-mall-web-test
```

第三批：平台和辅助服务

```text
scm-file-web-test
scm-professor-web-test
scm-scheduling-web-test
scm-devops-web-test
scm-workflow-web-test
scm-fee-web-test
```

第四批：DPS，建议由该模块负责人一起观察

```text
scm-dps-service-web-test
scm-dps-web-test
scm-dpscore-web-test
```

注意：

- 这次只改 03 Dockerfile，直接点 `*-web-test`。
- 不需要先点 `*-all-test`；点 all 会重新发布 01 业务 jar，属于多余动作。
- 每次不要只看 Jenkins 绿灯，还要确认新镜像、新 Pod、启动日志。

### 6.3 UAT

test 全部验证通过并把代码进入 UAT 分支后，按实际存在的 UAT Deployment 逐项点对应 `*-web-uat`。

Fee、IFS Schedule 当前在 UAT 命名空间没有 Deployment，不要盲目创建；先问是否本来就不部署。

### 6.4 生产

当前不提供“照着点”的生产 Jenkins 清单，因为在线 Jenkins 没有 `*-web-prod`，K8s 中主后端又都是 0 副本。先让运维确认正式入口，再写生产执行单。

---

## 7. 每个服务怎么验收

一个服务只有同时满足下面 5 条，才能标记完成：

1. Jenkins `*-web-*` 的“编译、镜像构建、镜像推送、部署到集群”全部成功。
2. K8s Deployment 使用新的镜像 tag。
3. 新 Pod 创建时间晚于本次 Jenkins 构建。
4. 新 Pod 启动日志出现：

   ```text
   Picked up JAVA_TOOL_OPTIONS: -Dfastjson.parser.safeMode=true
   ```

5. 普通业务回归通过，日志没有新增 AutoType/反序列化兼容错误。

建议维护一张执行表：

| 环境 | 服务 | 新镜像 tag | 新 Pod | SafeMode 日志 | 业务回归 | 结果 |
|---|---|---|---|---|---|---|
| test | scm-auth-web | 待填 | 待填 | 待填 | 待填 | 待执行 |

Source test 当前可以先填：

| 环境 | 服务 | 新镜像时间 | 新 Pod | SafeMode 日志 | 结果 |
|---|---|---|---|---|---|
| test | scm-source-web | 2026-07-29 10:58 | 运行中 | 已出现 | JVM 参数生效；业务/无害安全探针仍应按正史文档完成 |

---

## 8. 需要用户去问人的两件事

### 8.1 问运维：正式生产入口

逐字话术：

> “我只读核对 KubeSphere 后发现，`si-scm-product` 里 Auth、Source、Order、Gateway 等主后端 Deployment 都是 0 副本；Jenkins 目前也只有 `*-all-prod`，没有 `*-web-prod`。麻烦确认一下正式生产后端实际运行在哪个集群和命名空间、镜像由哪条流水线发布，以及有没有统一 Helm/Deployment 模板可以加 `JAVA_TOOL_OPTIONS=-Dfastjson.parser.safeMode=true`。我不会直接按 test/UAT 流程猜着发生产。”

### 8.2 问 Workflow/DPS 负责人：历史重复实例

逐字话术：

> “当前标准 Jenkins 只覆盖 DPS Service、DPS、DPS Core 的 dev/test/UAT 任务，但 K8s 里还在跑 `scm-workflow-dps-test`、`scm-workflow-dps`、`workflow-dps` 这些额外实例。麻烦确认它们是否仍有流量、分别由哪条流水线和哪份 Dockerfile构建。Fastjson SafeMode 推广时要把仍在用的实例一起覆盖。”

---

## 9. 证据索引

### 本地代码

- 主启动模块清单：`03zhaocai-start/scm-cloud-starters-web/pom.xml:80-100`
- Source 当前两处重复配置：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Dockerfile:8,19`
- 普通 Java 镜像样板：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-auth/Dockerfile:1-38`
- DPS Service 直接声明 Fastjson：`03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dps-service/pom.xml:41-42`
- DPS 直接声明 Fastjson：`03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dps/pom.xml:41-42`
- DPS Core 直接声明 Fastjson：`03zhaocai-start/scm-cloud-starters-wfproduct/scm-cloud-dpscore/pom.xml:41-42`
- 前端 Nginx 证据：`03zhaocai-start/scm-cloud-starter-vue/scm-cloud-statics/Dockerfile:1`
- Elasticsearch 证据：`03zhaocai-start/scm-cloud-starters-elasticsearch/scm-cloud-elasticsearch/Dockerfile:1,16-20`

### Jenkins 在线只读核对（2026-07-29）

- 22 个 `*-web-test` 和 22 个 `*-web-uat` 当前都包含 Docker build、push、kubectl apply。
- 主后端任务的 `PROJECT_DIR` 与本文 19 个 `scm-cloud-*` 子目录逐项一致。
- DPS 三组 test/UAT 任务分别指向 `scm-cloud-dps-service`、`scm-cloud-dps`、`scm-cloud-dpscore`。
- 当前 Jenkins 没有 `*-web-prod`。

### KubeSphere 在线只读核对（2026-07-29 11:06）

- test 命名空间：28 个 Deployment。
- UAT 命名空间：22 个 Deployment。
- `si-scm-product`：29 个 Deployment，但主后端 18 个均为 0 副本。
- Source test Pod 日志已出现 SafeMode JVM 回执。
- Source UAT Pod 日志未出现该回执。
- 没有执行保存、构建、部署、扩缩容、重启或删除操作。

---

## 10. 30 秒复述

> “本地虽然有 39 份 Dockerfile，但只有 22 份是真正给当前公司 Java 服务做运行镜像的：主后端 19 份、DPS 3 份。Source test 已经开了 SafeMode并在 Pod 日志确认生效，剩下 21 份要加同一行 `JAVA_TOOL_OPTIONS`，再逐个点对应的 `*-web-test` 重建镜像和 Pod。前端 Nginx、Elasticsearch、01 的历史 Dockerfile、样例和未使用入口都不改。UAT 等 test 通过后再推；生产当前看不到 `*-web-prod`，而可见命名空间里的主后端又都是 0 副本，必须先让运维确认正式入口，不能猜。”
