# Fastjson SafeMode test 手动部署与 K8s 验证

> 日期：2026-07-29  
> 工具：codex  
> 当前状态：22 个 Java 服务的 Dockerfile 改动已完成；当前优先使用同目录的 `Jenkinsfile-safeMode-test` 顺序调用 22 个 Jenkins 任务，本文保留手动部署顺序和 K8s 网页终端验证命令。  
> 下一阶段：用户把 Jenkinsfile 粘贴到 Pipeline 任务并手动点击一次“立即构建”；流水线完成后检查最新 Pod。出现构建失败或 SafeMode 验证失败时先停止并把结果交给 AI 排查。

## 0. 推荐方式：Pipeline 自动顺序部署

配置文件：

```text
docs/需求/05fastjson升级/Jenkinsfile-safeMode-test
```

该脚本只在人工点击“立即构建”后执行，不包含定时、GitLab 或 SCM 自动触发。
它会一个接一个调用下面的 22 个 `*-web-test`，等待当前任务成功后才调用下一个；
任意任务失败时会停止，不再继续后面的部署。

## 1. Jenkins 怎么点

在 Jenkins 首页搜索任务名，进入任务后点击左侧的 **“立即构建”**。

执行规则：

1. 同一批任务可以依次点击，让它们同时构建。
2. 等当前批次全部构建成功后，再点击下一批。
3. 任何任务出现红色失败，先停止，不要继续下一批。
4. 每个任务只点击一次；已经进入构建队列后不要重复点击。
5. 只点击下面的 `*-web-test`，不要点击 `*-all-*`、dev 或 UAT。

### 第一批：基础和入口

按下面顺序点击：

```text
scm-auth-web-test
scm-gateway-web-test
scm-gateway-mall-web-test
scm-ifs-web-test
scm-ifs-schedule-web-test
scm-source-web-test
```

### 第二批：核心业务

第一批全部成功后点击：

```text
scm-order-web-test
scm-product-web-test
scm-srm-web-test
scm-contract-web-test
scm-report-web-test
scm-ubm-web-test
scm-ubm-mall-web-test
```

### 第三批：其他业务

第二批全部成功后点击：

```text
scm-file-web-test
scm-professor-web-test
scm-scheduling-web-test
scm-devops-web-test
scm-workflow-web-test
scm-fee-web-test
```

### 第四批：DPS

第三批全部成功后点击：

```text
scm-dps-service-web-test
scm-dps-web-test
scm-dpscore-web-test
```

## 2. K8s 网页里怎么验证

每批 Jenkins 成功后，在 K8s 网页中：

1. 进入 test 环境对应的命名空间。
2. 找到刚部署服务的 Deployment。
3. 进入它最新创建、状态为 Running 的 Pod。
4. 点击“终端/执行命令/Terminal”。
5. 如果网页让选择容器，选择服务自身的 Java 容器，不要选择 sidecar。

### 最简单的验证命令

复制执行：

```bash
printenv JAVA_TOOL_OPTIONS
```

成功时应看到：

```text
-Dfastjson.parser.safeMode=true
```

环境变量里即使还有其他 JVM 参数，只要包含
`-Dfastjson.parser.safeMode=true` 也算通过。

### 一条命令直接显示通过或失败

```bash
printenv JAVA_TOOL_OPTIONS | grep -q -- '-Dfastjson.parser.safeMode=true' && echo 'PASS：SafeMode 已配置' || echo 'FAIL：未找到 SafeMode'
```

看到下面这行算通过：

```text
PASS：SafeMode 已配置
```

### 再确认 JVM 能读取这个参数

需要更稳妥地确认时，再执行：

```bash
java -XshowSettings:properties -version 2>&1 | grep -E 'Picked up JAVA_TOOL_OPTIONS|fastjson.parser.safeMode'
```

正常应看到类似：

```text
Picked up JAVA_TOOL_OPTIONS: -Dfastjson.parser.safeMode=true
    fastjson.parser.safeMode = true
```

这表示容器内的 JVM 已经把 SafeMode 读取成 Java 系统属性。

## 3. 什么情况先停止

遇到下面任意情况，先不要继续下一批：

- Jenkins 构建变红或一直卡住。
- Deployment 没有产生新的 Pod。
- 新 Pod 不是 Running，或者反复重启。
- `printenv JAVA_TOOL_OPTIONS` 没有输出。
- 验证命令显示 `FAIL：未找到 SafeMode`。
- JVM 检查中看不到 `fastjson.parser.safeMode = true`。

注意一定要进入**本次部署后新创建的 Pod**。旧 Pod 没有这个环境变量，不代表新镜像配置失败。
