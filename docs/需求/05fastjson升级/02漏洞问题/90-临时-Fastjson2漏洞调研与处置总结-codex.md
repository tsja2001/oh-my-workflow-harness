# Fastjson2 漏洞调研与处置总结

> 日期：2026-07-28  
> 工具：codex  
> 当前状态：公司源码和 Source 有效依赖均命中 Fastjson2 2.0.62；官方修复已合入主干但尚未发布正式 Maven 版本；Source Dockerfile 已做一行 SafeMode 本地试点，尚未提交、部署。  
> 下一阶段：先确认在线 Java Deployment 清单，在 test 用 Source 灰度验证 SafeMode，再推广到全部受影响服务；官方正式版发布后再统一升级依赖。  
> 文档关系：本文补充 `01漏洞问题.md`；本文关于官方补丁状态、仓库扫描数字、部署落点和验证方法的结论，取代 `../90-临时-2.0.62安全漏洞处置-cc.md` 中对应的旧结论，旧文仍可作为讨论背景。

---

## 0. 先看结论

这次问题可以用一句话概括：

> 公司当前统一使用 Fastjson 2.0.62，实际底层是 Fastjson2 2.0.62，命中官方确认的 AutoType 安全问题；正式修复代码已经进入 Fastjson2 主干，但还没有可升级的正式 Maven 包，所以现在先用 SafeMode 关闭 AutoType，等正式版发布后再升级。

当前最稳妥的推进顺序：

1. 在 test 先给 `scm-source-web` 开启 SafeMode。
2. 验证 JVM 确实读到参数、无害安全探针被阻断、普通业务接口正常。
3. 按“实际在线的后端 Java Deployment”清单推广，不按“目录里有 Dockerfile”盲目全改。
4. 经过 test、UAT 后再进入生产。
5. 等官方发布包含修复提交 `ec47e24c487fdc864bfe0d18e1850398de634cef` 的正式版本，再修改公司统一依赖并全量重建服务。
6. 正式升级后仍保留 SafeMode，除非后续确认某项业务确实依赖 AutoType。

不能把下面几件事混为一谈：

- 代码中有 SafeMode 配置，不等于已经进入镜像。
- 镜像构建成功，不等于 Deployment 已切换到新镜像。
- Pod 重启成功，不等于 JVM 真的读取到了 SafeMode。
- 父 POM 版本改了，不等于所有已运行 Pod 都换成了新 Fastjson。
- 官方修复进入主干，不等于 Maven Central 已经存在正式修复版。

---

## 1. 漏洞事实边界：确认了什么，没确认什么

### 1.1 已确认事实

Fastjson2 维护者在 issue #7702 中明确确认：

- AutoType 类型解析路径存在安全问题。
- 在特定条件下可能被利用。
- 当时所有已发布版本均不包含修复。
- 正式版发布前建议立即设置 `-Dfastjson2.parser.safeMode=true`，完全禁用 AutoType。

维护者原始回复：

- [问题确认与临时缓解建议](https://github.com/alibaba/fastjson2/issues/7702#issuecomment-5088553122)
- [Docker/Kubernetes 配置方式和启动期限制](https://github.com/alibaba/fastjson2/issues/7702#issuecomment-5089668138)

### 1.2 本轮没有越界声称的内容

外部安全材料把问题描述为远程代码执行（RCE），但本轮研究：

- 没有获得或运行公开武器化 PoC。
- 没有在 test、UAT、prod 尝试远程代码执行。
- 没有证明公司任意接口可以直接完成完整利用链。
- 没有发现公开 CVE/GHSA 编号。

因此本文采用更严谨的说法：

> 官方确认 AutoType 路径存在可被利用的安全问题；公司版本和解析入口满足需要立即缓解的条件。完整 RCE 能力来自安全通报，本轮只验证了危险类型名能够到达类加载路径这一关键前置条件，以及 SafeMode 能阻断它。

### 1.3 为什么“没主动打开 AutoType”仍要处理

问题就在 AutoType 类型识别路径本身。不能只凭“业务没有调用 `setAutoTypeSupport(true)`”判断安全。

SafeMode 相当于把 AutoType 的总电闸拉下：

```text
-Dfastjson2.parser.safeMode=true
```

官方文档说明 SafeMode 会完全禁用 AutoType：

- [Fastjson2 AutoType 官方文档](https://github.com/alibaba/fastjson2/blob/main/docs/autotype_cn.md)

---

## 2. 官方修复与发版状态

核对时间：2026-07-28 14:36（Asia/Shanghai）。

| 事项 | 当前状态 | 结论 |
|---|---|---|
| issue #7702 | 仍为公开问题讨论 | 维护者已确认问题并推荐 SafeMode |
| 原始 PR #7695 | 已关闭，未合入 | 不能当作正式修复依据 |
| 替代修复 PR #7703 | 已合入 `main` | 修复代码已进入主干 |
| 主干修复提交 | `ec47e24c487fdc864bfe0d18e1850398de634cef` | 后续判断正式版本是否包含修复的锚点 |
| `com.alibaba:fastjson` 正式版 | 最新仍为 2.0.62 | 还没有正式修复包 |
| `com.alibaba.fastjson2:fastjson2` 正式版 | 最新仍为 2.0.62 | 还没有正式修复包 |
| Fastjson2 主干 POM | `2.0.62-SNAPSHOT` | 不能把主干快照当公司正式依赖 |

官方修复：

- [PR #7703](https://github.com/alibaba/fastjson2/pull/7703)
- [GitHub API 中的合并状态](https://api.github.com/repos/alibaba/fastjson2/pulls/7703)
- [主干修复提交 ec47e24](https://github.com/alibaba/fastjson2/commit/ec47e24c487fdc864bfe0d18e1850398de634cef)
- [官方回归测试 AutoTypeValidationTest](https://github.com/alibaba/fastjson2/blob/main/core/src/test/java/com/alibaba/fastjson2/autoType/AutoTypeValidationTest.java)

修复主要增加三层保护：

1. URL 特殊字符阻断：类型名包含 `:`、`!` 时不允许进入类加载。
2. 白名单文本复核：哈希命中后还要核对真实前缀文本，不能只信哈希。
3. 黑名单一致性：在不同 AutoType 分支中统一阻断 ClassLoader、DataSource、RowSet 等危险类型。

Maven Central 当前版本：

- [`com.alibaba:fastjson` metadata](https://repo.maven.apache.org/maven2/com/alibaba/fastjson/maven-metadata.xml)
- [`com.alibaba.fastjson2:fastjson2` metadata](https://repo.maven.apache.org/maven2/com/alibaba/fastjson2/fastjson2/maven-metadata.xml)

因此现在不能：

- 猜测修复版本一定叫 2.0.63。
- 自行依赖 GitHub 主干 SNAPSHOT。
- 只看到 PR 合并就向领导说“已经有正式修复版”。

正确升级判据是：

1. Maven Central 出现新的正式版本。
2. 对应 tag/提交历史包含 `ec47e24` 或官方等价修复。
3. 公司在 test 完成兼容性回归。

---

## 3. 公司仓库当前是什么状态

### 3.1 代码与运行的整体关系

当前后端主链路不是 01 和 03 各跑一套，而是：

```text
01/scm-cloud-parent
        │ 统一管理第三方依赖版本
        ▼
01 各业务 *-all 仓库
        │ 构建并发布业务 JAR 到 Nexus
        ▼
03/scm-cloud-starters-web
        │ 引入业务 JAR，生成 Spring Boot 可运行包
        ▼
各服务独立 Docker 镜像
        ▼
Kubernetes Deployment / Pod
```

对应持久知识见：

- `note/project-ai-context.md:8`
- `note/project-ai-context.md:227-233`

所以：

- 现在临时开启 SafeMode，主要改运行启动层，即 03 的后端 Java 镜像或 K8s Deployment。
- 将来升级正式修复版，要改 01 的统一父 POM，再重新构建 01 业务 JAR 和 03 启动镜像。

### 3.2 公司统一版本确实是 2.0.62

版本控制点：

```xml
<fastjson.version>2.0.62</fastjson.version>
```

证据：

- `01zhaocai-end/scm-cloud-parent/pom.xml:65`
- `01zhaocai-end/scm-cloud-parent/pom.xml:306-310`
- `scm-cloud-parent` 当前 `prod` 与 `origin/prod` 一致。
- 最新提交 `256a2be`，提交说明为 `fastjson升级到2.0.62`。

### 3.3 虽然 import 是旧包名，底层仍是 Fastjson2

Source 有效依赖树实测：

```text
com.alibaba:fastjson:2.0.62
└── com.alibaba.fastjson2:fastjson2-extension:2.0.62
    └── com.alibaba.fastjson2:fastjson2:2.0.62
```

这意味着：

- Java 代码多数仍写 `com.alibaba.fastjson.*`。
- Maven 坐标看起来仍是 `com.alibaba:fastjson`。
- 但 2.0.62 兼容包的底层核心已经是 Fastjson2 2.0.62。
- 不能因为没有 `import com.alibaba.fastjson2.*` 就判断不受影响。

复核命令：

```bash
cd /home/t/projects/work-wsl/03zhaocai-start/scm-cloud-starters-web

mvn -q -pl scm-cloud-source dependency:tree \
  -Dincludes=com.alibaba:fastjson,com.alibaba.fastjson2:fastjson2,com.alibaba.fastjson2:fastjson2-extension \
  -Dverbose \
  -DoutputFile=/tmp/scm-source-fastjson-tree.txt
```

### 3.4 使用面和外部输入面

对 `01zhaocai-end`、`03zhaocai-start` 的静态粗扫结果：

| 检查项 | 结果 | 怎么理解 |
|---|---:|---|
| 直接声明 `<artifactId>fastjson</artifactId>` 的 POM | 67 个 | 依赖面广 |
| 引用 `com.alibaba.fastjson` 的 Java 文件 | 全部源码 821 个；`src/main` 生产源码 760 个 | 旧 API 兼容层使用广 |
| 包含 parse/parseObject/parseArray 的 Java 文件 | 全部源码 375 个；生产源码 342 个 | 解析点分散 |
| 上述解析调用总数 | 全部源码 755 处；生产源码 708 处 | 不适合紧急全量迁移其他 JSON 库 |
| `setAutoTypeSupport`、`SupportAutoType` 等主动开启配置 | 0 处 | 没发现业务显式依赖 AutoType |
| Java/配置中的字面量 `"@type"` | 0 处 | 没发现业务主动构造 `@type` 数据 |

这些数字是代码文本静态扫描，不代表 755 处都能被匿名外网直接调用，也不能替代运行时安全扫描。

已确认存在“外部请求内容进入 Fastjson 解析”的代表入口：

- `01zhaocai-end/scm-ifs-all/scm-ifs-outservice/src/main/java/com/pcitc/scm/ifs/outservice/sap/controller/SapPlanController.java:37-51`
- `01zhaocai-end/scm-ifs-all/scm-ifs-contract/src/main/java/com/pcitc/scm/ifs/contract/controller/ContractReceiveController.java:34-48`
- `01zhaocai-end/scm-ifs-all/scm-ifs-log/src/main/java/com/pcitc/scm/ifs/log/controller/ApiController.java:40-43,91-94`

这只能证明存在输入面。具体接口是否经过网关、登录、白名单和网络隔离，要逐个结合运行配置判断。

### 3.5 SafeMode 当前五态

| 能力 | 预期 | 已实现 | 已配置 | 已部署 | 已验证 |
|---|---|---|---|---|---|
| Source Dockerfile 开 SafeMode | 是 | 本地已加一行 | 本地工作区是 | 否 | 本地 JVM 探针通过 |
| test 的 `scm-source-web` | 是 | 代码已准备 | 尚未进入 test 镜像 | 否 | 否 |
| 其他后端 Java 服务 | 是 | 否 | 否 | 否 | 否 |
| WAF 拦截 `@type` | 防御补充 | 未核实 | 未核实 | 未核实 | 未核实 |
| 正式修复版本升级 | 后续需要 | 官方主干已修，公司未改 | 不适用 | 否 | 否 |
| 所有在线 Pod 的实际 Fastjson 版本清单 | 需要 | 未盘点 | 不适用 | 未知 | 否 |

Source 当前本地试点改动：

```dockerfile
ENV TZ Asia/Shanghai
ENV JAVA_TOOL_OPTIONS="-Dfastjson2.parser.safeMode=true"
```

证据：

- `03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Dockerfile:7-8`
- 当前仓库分支：`prod`
- 当前状态：本地未提交、未推送、未执行 Jenkins

### 3.6 日期兼容修复与本漏洞是两件事

工作区里还有一组“Fastjson2 把 Date 变成 String”的兼容修复：

- `01zhaocai-end/scm-cloud-dependencies` 当前在本地分支 `dev-fixfastjson`，有本地提交 `1bccd20` 和尚未提交的后续调整。
- `01zhaocai-end/scm-assemblies-all` 当前 `dev` 与 `origin/dev` 一致，已有提交 `80e24fa`，工作区仍有本地调整。

这组改动解决日期/类型兼容，不会封堵本次 AutoType 安全路径；SafeMode 也不会解决 Date/String 问题。两者可以在同一轮回归中一起观察，但发布状态和验收结论必须分开记录。

---

## 4. Dockerfile、deploy-docker.yaml、Jenkins 分别负责什么

| 对象 | 大白话 | 加 SafeMode 后怎么生效 | 是否要重新构建镜像 |
|---|---|---|---|
| Dockerfile | 制作单个服务镜像的配方 | `ENV JAVA_TOOL_OPTIONS=...` 被装进新镜像 | 是 |
| deploy-docker.yaml | K8s 启动这个镜像时的说明书 | 在 `containers[].env` 注入启动环境变量 | 理论上不用，只需应用 YAML 并滚动新 Pod |
| Jenkinsfile | 自动打包、做镜像、推镜像、部署的流水线机器人 | 读取上面两个文件执行 | 不需要为 SafeMode 单独修改 |

Source 的现有 Jenkins 流程已经会：

1. 进入 `scm-cloud-source` 编译：`Jenkinsfile-Test:35-40`。
2. 使用当前目录 Dockerfile 构建镜像：`Jenkinsfile-Test:46-50`。
3. 应用 `deploy-docker.yaml`：`Jenkinsfile-Test:67-75`。

生产 Jenkinsfile 应用的是：

```text
scm-cloud-source/deploy-docker-prod.yaml
```

证据：`scm-cloud-source/Jenkinsfile-Prod:67-75`。

### 4.1 两种落地方式二选一

#### 方式 A：在 K8s Deployment 注入，适合紧急全量缓解

```yaml
containers:
  - name: container-APP_NAME
    image: IMAGE_URL
    env:
      - name: JAVA_TOOL_OPTIONS
        value: "-Dfastjson2.parser.safeMode=true"
```

优点：

- 不需要修改 Java 代码。
- 理论上不用重新制作应用镜像。
- 适合运维用统一 Helm/K8s 模板一次覆盖所有 Java Deployment。

注意：

- 当前代码仓中每个服务有自己的 YAML；如果公司没有统一平台模板，仍要逐个修改。
- 只用 `kubectl set env` 临时打补丁，下一次 Jenkins 部署可能覆盖，必须保存到正式部署模板。

#### 方式 B：写进每个后端 Java Dockerfile，当前 Source 试点采用

```dockerfile
ENV JAVA_TOOL_OPTIONS="-Dfastjson2.parser.safeMode=true"
```

优点：

- 参数跟随镜像，test、UAT、prod 使用该新镜像时都会具备。
- 官方明确给出了这种 Docker/Kubernetes 配置方式。

代价：

- 每个服务都是独立镜像，必须分别修改。
- 必须重新构建、推送和部署每个镜像。
- 只重启旧 Pod、继续使用旧镜像不会生效。
- K8s 如果在运行时设置了同名环境变量，可以覆盖 Dockerfile 中的值。

### 4.2 不推荐放置的位置

不要放在：

- Nacos 配置。
- Spring `application.yml`。
- Spring `application.properties`。
- 服务已经启动后的动态配置。

原因是 SafeMode 在 Fastjson 类加载时读取，是启动期配置。Spring/Nacos 配置加载得太晚，官方明确说明不会自动生效。

---

## 5. 到底哪些项目和服务要处理

### 5.1 正确判据

正确范围不是：

> 全项目搜索 Dockerfile，看到一个就改一个。

正确范围是：

> 所有实际在线运行、最终应用包内包含受影响 Fastjson2 版本的后端 Java Deployment。

只按 Dockerfile 搜索会有两类误差：

- 误改：前端 Nginx、Elasticsearch、代码生成器、历史目录、未部署工程也可能有 Dockerfile。
- 漏改：某些在线服务可能使用外部 Jenkins 模板、Helm 或平台公共镜像，代码目录未必有自己的 Dockerfile。

### 5.2 当前主线范围

当前主要后端启动仓库：

```text
03zhaocai-start/scm-cloud-starters-web
```

它的根 POM 列出 gateway、auth、source、ifs、srm、order、contract、workflow、report 等独立启动模块。每个服务是独立镜像，改 Source 不会自动影响 IFS、SRM、Order。

需要单独核实：

- `03zhaocai-start/scm-cloud-starters-wfproduct`：其中多个 POM 直接声明 fastjson；如果仍有在线 Java 服务，需要纳入。
- 01 中少量历史/独立 Dockerfile：当前主线的 `*-all` 主要发布 JAR，不应看到 Dockerfile 就盲改；只有在线 Pod 确认由它构建时才纳入。

明确排除：

- `03zhaocai-start/scm-cloud-starter-vue` 和 `Dockerfile-Nginx*`：前端静态资源。
- `03zhaocai-start/scm-cloud-starters-elasticsearch`：Elasticsearch 镜像，不是公司 Spring Boot 业务应用。
- `03zhaocai-start/mybatis-plus-generate`：代码生成工具。
- 没有在线 Deployment、没有 Jenkins 启动任务的历史目录。

### 5.3 需要运维提供的最终清单

最终不要靠仓库目录猜，应该从 test、UAT、prod 的 Kubernetes 反查：

| 环境 | Deployment | 镜像 | Java/非Java | Fastjson JAR 版本 | 对应 Jenkins任务 | SafeMode |
|---|---|---|---|---|---|---|
| test | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 |
| UAT | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 |
| prod | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 | 待盘点 |

---

## 6. 推荐实施步骤

### 阶段一：Source test 灰度

当前 Source Dockerfile 已准备好一行改动，但还在 `prod` 工作区，不能直接作为正式交付提交。

正式实施时：

1. 按团队约定从正确基线建立或使用本需求长期 feature 分支。
2. 保留：

   ```dockerfile
   ENV JAVA_TOOL_OPTIONS="-Dfastjson2.parser.safeMode=true"
   ```

3. 本地提交说明用一行：

   ```text
   fix: 开启Fastjson安全模式
   ```

4. 用户按公司流程把变更送入 test。
5. 点 `scm-source-web-test`，必须执行“重新构建镜像 + 推送 + 部署”，不是只重启旧 Pod。
6. 完成第 7 节的运行参数、安全探针和业务回归。

这次只改启动镜像，不需要重新发布 01 的 `scm-source-all` 业务 JAR，也不需要先点 `scm-source-all-test`。

### 阶段二：全量 test

1. 用 K8s 在线清单确定全部后端 Java Deployment。
2. 选择统一 K8s 模板或逐服务 Dockerfile，避免两套方式混乱。
3. 先推广网关、认证、IFS、Source 等入口面较大的服务。
4. 再推广其余 Java 服务。
5. 每个服务都必须产生新 Pod，并逐个验证环境变量。
6. 观察普通 JSON、登录、缓存、MQ、批处理是否异常。

### 阶段三：UAT 和生产

1. test 通过后进入 UAT。
2. UAT 通过后按生产变更窗口推广。
3. 生产保留回退镜像 tag。
4. WAF 可增加 `@type` 相关规则作为纵深防御，但不能代替 SafeMode。
5. 上线后重新拉取全部 Deployment/Pod 清单对账，不能只数 Jenkins 绿灯。

### 阶段四：官方正式版升级

正式版发布后：

1. 确认新版本 tag 包含修复提交。
2. 修改：

   ```text
   01zhaocai-end/scm-cloud-parent/pom.xml:65
   ```

3. 发布新版 parent/BOM 到 Nexus。
4. 重新构建受影响的 01 `*-all` 业务 JAR。
5. 重新构建并部署所有受影响的 03 `*-web` 镜像。
6. 从实际 Pod 中核对最终 JAR 版本。
7. 做完整兼容回归，特别关注此前 Fastjson2 升级已经暴露过的 Date/String 转换问题。
8. SafeMode 继续保留，作为纵深防御。

---

## 7. 怎么验证漏洞前置路径和修复是否生效

验证分五层，缺一层都不能说“已经修好”。

### 7.1 第一层：有效依赖版本

源码版本和 Maven 有效依赖都要看。

当前 Source 预期：

```text
fastjson:2.0.62
fastjson2-extension:2.0.62
fastjson2:2.0.62
```

正式升级后，这三个坐标都要变成包含官方修复的新版本，不能只升级其中一个。

### 7.2 第二层：本轮无害探针结果

本轮制作了一个无网络、无远程类、无武器化碰撞的回归探针：

- 人工模拟“哈希白名单命中”。
- 使用记录型 ClassLoader 截获 URL 形态的测试类型名。
- ClassLoader 一旦看到该名称就立即抛异常。
- 不下载 JAR，不打开网络，不执行远程代码。

Fastjson2 2.0.62 默认配置实测：

```text
safeMode.property=null
testType.reachedContextClassLoader=true
resolvedClass=null
```

说明危险形式的类型名能够到达上下文类加载器。

使用与 Dockerfile 相同的环境变量后实测：

```text
Picked up JAVA_TOOL_OPTIONS: -Dfastjson2.parser.safeMode=true
safeMode.property=true
testType.reachedContextClassLoader=false
resolvedClass=null
```

说明：

- JVM 已读取环境变量。
- SafeMode 已阻断危险类加载前置路径。
- 这不是完整 RCE PoC，不会联网或执行恶意代码。

正式修复版的验收标准：

| 场景 | SafeMode | 预期 |
|---|---|---|
| 当前 2.0.62 基线 | 关闭 | 探针可记录到危险名称到达 ClassLoader |
| 当前 2.0.62 临时缓解 | 开启 | 不到达 ClassLoader |
| 官方修复正式版验证修复本身 | 临时关闭，仅限隔离环境 | 不到达 ClassLoader |
| 官方修复正式版生产运行 | 开启 | 不到达 ClassLoader，且保留纵深防御 |

如果正式版测试时一直开着 SafeMode，只能证明缓解仍有效，不能单独证明新版本修复代码生效。

### 7.3 第三层：新 Pod 是否真正拿到启动参数

进入新 Pod 检查：

```bash
tr '\0' '\n' </proc/1/environ | grep '^JAVA_TOOL_OPTIONS='
```

预期：

```text
JAVA_TOOL_OPTIONS=-Dfastjson2.parser.safeMode=true
```

启动日志预期出现：

```text
Picked up JAVA_TOOL_OPTIONS: -Dfastjson2.parser.safeMode=true
```

如果镜像内有 `jcmd`：

```bash
jcmd 1 VM.system_properties | grep '^fastjson2.parser.safeMode='
```

预期：

```text
fastjson2.parser.safeMode=true
```

只看到 Dockerfile 或 YAML 有这行，不算运行验证。

### 7.4 第四层：实际运行包中的 JAR

检查 Spring Boot fat jar：

```bash
jar tf /opt/app/<APP_NAME>/<JAR_FILE> |
grep -E 'BOOT-INF/lib/(fastjson|fastjson2|fastjson2-extension).*\.jar'
```

当前预计看到 2.0.62。正式升级后必须看到新版本。

实际镜像路径和 JAR 文件名由对应 Jenkinsfile中的 `APP_NAME`、`JAR_FILE` 确认，不要照抄占位符直接执行。

### 7.5 第五层：业务回归

SafeMode 会关闭 AutoType，但普通“明确目标类型”的 JSON 解析应该继续正常。

至少验证：

- 登录、Token、网关转发。
- Source 常用列表、详情和日期转换。
- IFS 外部接收普通 JSON 报文。
- Redis 旧缓存读取。
- MQ 消息生产、消费和历史消息兼容。
- 定时任务、批处理和导出。
- 日志中是否新增 `safeMode not support autoType`、`autoType is not support` 或反序列化错误。

特别注意：

- 代码扫描没有发现主动使用 AutoType，只能说明兼容风险较低，不能证明 Redis/MQ 历史数据里绝对没有 `@type`。
- Fastjson2 日期变 String 是另一项兼容问题，SafeMode 不会修复它，也不要把两项问题的验收结果混在一起。

### 7.6 禁止的验证方式

不要在共享 test、UAT、prod：

- 运行来源不明的完整 RCE PoC。
- 让测试服务器下载远程 JAR。
- 尝试启动命令、写文件、反弹连接等武器化验证。
- 只发一个普通 `@type` 字段就宣布漏洞或修复验证完成。

安全验证以无害探针、官方回归测试、运行参数和业务回归为主。

---

## 8. 回退方案

### Dockerfile 方式

1. 删除 `ENV JAVA_TOOL_OPTIONS=...`。
2. 重新构建并部署回退镜像，或者切回上一个已知正常镜像 tag。
3. 确认新 Pod 中已经没有该变量。

### K8s Deployment 方式

1. 从正式 Deployment 模板移除 `JAVA_TOOL_OPTIONS`。
2. 重新应用 YAML并滚动重启。
3. 防止下次 Jenkins 再次把旧模板覆盖回来。

安全提醒：

> 回退 SafeMode 会重新打开已知风险路径。只有发生明确业务故障时才能回退，并应同步安全/运维，临时加强 WAF、网络和接口访问控制，不能悄悄撤掉。

---

## 9. 还需要确认的事项

| 问题 | 当前事实 | 谁来确认 |
|---|---|---|
| 公司是否有统一 Helm/K8s Java Deployment 模板 | 代码仓中每个服务有独立 YAML，平台侧统一模板未知 | 运维 |
| test/UAT/prod 实际有哪些 Java Deployment | 尚未全量盘点 | 运维 |
| `scm-cloud-starters-wfproduct` 是否仍在线 | 源码直接依赖 fastjson，但运行状态未知 | 运维/后端负责人 |
| 01 中少量独立 Dockerfile 是否仍被使用 | 当前主线 web 启动来自 03，但历史特殊服务未知 | Jenkins/运维负责人 |
| 是否已有 WAF `@type` 规则 | 未核实 | 安全/网关团队 |
| 官方正式修复版本号 | 尚未发布，不能猜 | 后续查官方 release/Maven Central |

---

## 10. 可以直接拿去沟通的话术

### 给领导/项目负责人

> “公司当前统一使用 Fastjson 2.0.62，Source 的实际依赖树也确认落到 Fastjson2 2.0.62。官方已经确认 AutoType 路径存在安全问题，修复代码今天进了主干，但 Maven 还没发布正式修复版。建议先在 test 给所有在线 Java 服务开启 SafeMode，验证正常后推广；正式版出来再统一升级和重建服务。”

### 给运维

> “请帮忙导出 test、UAT、prod 所有在线 Java Deployment 清单，包括镜像、对应 Jenkins任务和应用包内 Fastjson版本。临时缓解参数是 `JAVA_TOOL_OPTIONS=-Dfastjson2.parser.safeMode=true`，必须在 JVM 启动前设置并滚动新 Pod。请确认有没有统一 Helm/K8s 模板能全量加；如果没有，我们就逐个 Java 服务修改正式部署模板，避免下次 Jenkins 覆盖。”

### 对面问“是不是只改 Source 就全平台生效”

> “不是。每个后端服务都是独立镜像和独立 JVM，Source 的 Dockerfile只影响 `scm-source-web`。必须让每个实际在线、包含 Fastjson2 的 Java Deployment 都拿到这个参数。”

### 对面问“为什么不直接升级”

> “修复代码已经进入官方主干，但正式 Maven 包还没发。现在自行用 SNAPSHOT 风险更大，所以先用官方建议的 SafeMode 封住攻击路径，等正式包出来再升级。”

---

## 11. 证据索引

### 公司仓库

- 统一版本：`01zhaocai-end/scm-cloud-parent/pom.xml:65`
- 统一依赖管理：`01zhaocai-end/scm-cloud-parent/pom.xml:306-310`
- Source SafeMode 本地试点：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Dockerfile:7-8`
- Source test 镜像构建：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Jenkinsfile-Test:46-50`
- Source test 部署：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Jenkinsfile-Test:67-75`
- Source prod 部署模板入口：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Jenkinsfile-Prod:67-75`
- Source K8s 容器定义：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/deploy-docker.yaml:20-29`
- IFS SAP 外部解析入口：`SapPlanController.java:37-51`
- IFS OA 合同解析入口：`ContractReceiveController.java:34-48`
- IFS 通用外部接口解析入口：`ApiController.java:40-43,91-94`

### 官方来源

- [问题跟踪 issue #7702](https://github.com/alibaba/fastjson2/issues/7702)
- [维护者确认和 SafeMode 建议](https://github.com/alibaba/fastjson2/issues/7702#issuecomment-5088553122)
- [维护者给出的启动期配置方法](https://github.com/alibaba/fastjson2/issues/7702#issuecomment-5089668138)
- [正式修复 PR #7703](https://github.com/alibaba/fastjson2/pull/7703)
- [修复提交 ec47e24](https://github.com/alibaba/fastjson2/commit/ec47e24c487fdc864bfe0d18e1850398de634cef)
- [官方 AutoType 文档](https://github.com/alibaba/fastjson2/blob/main/docs/autotype_cn.md)
- [官方 AutoType 安全回归测试](https://github.com/alibaba/fastjson2/blob/main/core/src/test/java/com/alibaba/fastjson2/autoType/AutoTypeValidationTest.java)
- [`com.alibaba:fastjson` Maven metadata](https://repo.maven.apache.org/maven2/com/alibaba/fastjson/maven-metadata.xml)
- [`com.alibaba.fastjson2:fastjson2` Maven metadata](https://repo.maven.apache.org/maven2/com/alibaba/fastjson2/fastjson2/maven-metadata.xml)

---

## 12. 30 秒复述

> “当前公司父 POM 锁在 Fastjson 2.0.62，实际底层是 Fastjson2 2.0.62，代码里没开 AutoType，但存在大量解析点和外部输入入口。官方确认 AutoType 路径存在安全问题，修复已经合入主干却还没发布正式 Maven 包，所以现在先给每个在线 Java JVM 加 `JAVA_TOOL_OPTIONS=-Dfastjson2.parser.safeMode=true`。Source Dockerfile已经本地试加并用无害探针验证能阻断危险类加载路径，但还没提交部署。后续要先 Source 灰度，再全量 test、UAT、prod；正式修复版出来后改 01 的 parent 并重建所有业务 JAR和启动镜像。”
