# 运维体系扫盲 + SafeMode 到底配几处

> 日期：2026-07-29 ｜ 工具：cc
> 状态：讲解文档，不改代码、不部署。回答用户两个问题——① SafeMode 变量配一处还是两处；② Docker / Jenkins / K8s / yaml 到底是干什么的、为什么有的项目有 Dockerfile 有的没有。
> 关系：本文是**扫盲/讲解**，不重复漏洞分析。漏洞成因、暴露面、完整处置步骤、验证方法、话术，见同目录：
> - `02漏洞问题/90-临时-Fastjson2漏洞调研与处置总结-codex.md`（最全，处置正史）
> - `90-临时-2.0.62安全漏洞处置-cc.md`（方案+话术）
> 本文如与上面两篇有出入，以本文对"属性名带不带2""配几处"的结论为准（下面有源码级证据），其余以 codex 那篇为准。

---

## 0. 30 秒结论

1. **SafeMode 配一处就够，你配两处是重复的**（不报错，但没必要）。推荐只保留 Dockerfile 顶部那一行 `ENV JAVA_TOOL_OPTIONS=...`，把启动命令里那个 `-Dfastjson.parser.safeMode=true` 删掉。
2. **带不带"2"都生效**。我把 fastjson 2.0.62 的源码拆开看了，它两个名字都认，而且不带 2 的还是**优先**读的。你昨天改成不带 2 的没问题；codex 文档里写的带 2 的也没问题。
3. **Docker/Jenkins/K8s 是一条流水线**：Dockerfile 是"做菜配方"，Jenkins 是"自动照配方做菜的机器人"，Harbor 是"菜品仓库"，K8s 是"餐厅后厨（真正把菜端上桌、坏了自动重做）"。deploy-docker.yaml 是给 K8s 的"上菜说明书"。
4. **为什么有的有 Dockerfile 有的没有**：只有"能独立跑起来的启动服务"才需要 Dockerfile（因为要做成镜像上线）；纯"零件库"模块不做镜像，只把 jar 发到公司 Nexus 仓库被别人引用，所以没有 Dockerfile。**你说的 `01zhaocai-end/scm-source-all` 其实是有的**，在它的子目录 `scm-cloud-source/Dockerfile`，你在根目录没看到而已。

---

## 1. SafeMode 到底配一处还是两处

### 1.1 你现在 Dockerfile 里的两处长这样

文件：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/Dockerfile`

```dockerfile
# 第 8 行：第一处
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"

# 第 19 行：第二处（藏在很长的启动命令里）
&& echo  "exec java -jar -server ... -Dfastjson.parser.safeMode=true ... ${JAR_FILE}" >> /docker-entrypoint.sh
```

这两处**做的是同一件事**：都是往 JVM（Java 虚拟机）启动时塞一个系统参数 `fastjson.parser.safeMode=true`。

- **第一处 `JAVA_TOOL_OPTIONS`**：这是 JVM 官方认的一个"万能环境变量"。只要容器里启动任何 java 进程，JVM 会自动把这个变量的内容当成启动参数读进去，并在日志里打印一行 `Picked up JAVA_TOOL_OPTIONS: -Dfastjson.parser.safeMode=true`（相当于自带一个"我生效了"的回执）。
- **第二处启动命令里的 `-D`**：直接写在真正的 `java -jar` 命令行上，跟 `-Xms1g`、`-Dfile.encoding=UTF-8` 那些参数并排。

两个渠道最后都归结成同一个系统参数、同一个值 `true`。**设两遍 = 同一个开关按了两次，结果一样**。

### 1.2 源码级证据：fastjson 只在启动时读一次，两个名字都认

fastjson 2.0.62 的核心类 `com.alibaba.fastjson2.reader.ObjectReaderProvider` 在**类加载时**（静态代码块，全程只跑一次）这样决定要不要开 SafeMode：

```java
String property = System.getProperty("fastjson.parser.safeMode");        // ① 先读【不带2】的系统参数
if (空) property = JSONFactory.Conf.getProperty("fastjson.parser.safeMode"); // ② 配置文件里【不带2】的
if (空) property = System.getProperty("fastjson2.parser.safeMode");       // ③ 再读【带2】的系统参数
if (空) property = JSONFactory.Conf.getProperty("fastjson2.parser.safeMode"); // ④ 配置文件里【带2】的
SAFE_MODE = "true".equals(property);                                      // 只要有一个 = "true" 就开
```

从这段代码能确定三件事：

1. **`fastjson.parser.safeMode`（不带2）和 `fastjson2.parser.safeMode`（带2）都被读**，而且不带 2 的还排在前面优先。→ 你写哪个都生效。
2. **只读一次**（static，类加载时）。→ 配一处就够，配两处不会"更保险"，纯重复。
3. **必须是启动前就设好**（JVM 参数/环境变量），因为 fastjson 类一旦被加载就定死了。→ **不能**放到 Nacos、`application.yml` 里，那些加载得太晚，读不到。

> 依赖背景：公司代码 import 的是老写法 `com.alibaba.fastjson.*`，但父 POM（`01zhaocai-end/scm-cloud-parent/pom.xml:65`）把版本锁成 `2.0.62`，实际底层引擎就是上面这个 fastjson2 2.0.62 的兼容包。所以"看起来用的是老 fastjson，其实是 fastjson2"，漏洞和这个开关对它都适用。

### 1.3 推荐怎么配（最终形态）

**只保留顶部一行，删掉启动命令里那个 `-D`。** 理由：

- 顶部这一行短、清爽，20 多个服务要一个个加时，复制这一行最不容易出错（不用去动那条又长又带引号的启动命令，那条改错一个引号整个容器就起不来）。
- 它启动时自带一行 `Picked up JAVA_TOOL_OPTIONS: ...` 日志，等于**免费给你一个"确实生效"的肉眼回执**，排查时特别有用。
- 用 `grep JAVA_TOOL_OPTIONS` 一扫就知道哪些服务加了、哪些没加，方便全平台对账。

推荐的最终写法（二选一）：

```dockerfile
# 写法一：够用（已验证不带2就生效）
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"

# 写法二：两个名字都写上，纯属"以防万一"的保险（将来万一换依赖也不慌），代价几乎为零
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true -Dfastjson2.parser.safeMode=true"
```

然后把第 19 行启动命令里的 ` -Dfastjson.parser.safeMode=true` 那一小段删掉即可。

> 小知识：为什么真正的 `java -jar` 命令不在 `docker-entrypoint.sh` 里、而是 Dockerfile 用 `echo ... >> /docker-entrypoint.sh` 追加进去的？因为 entrypoint 脚本顶部那一大段 `export CATALINA_OPTS=...` 其实是历史遗留、对这种 `java -jar` 的 Spring Boot 应用**不生效**（CATALINA_OPTS 是给 Tomcat 用的，这条 java 命令根本没引用它）。真正的 JVM 参数全在 Dockerfile 那条 `exec java -jar ...` 里——所以 SafeMode 也应该待在这套体系里（命令行 `-D` 或顶部 `JAVA_TOOL_OPTIONS`），而不是塞进那段没用的 CATALINA_OPTS。

### 1.4 一个必须知道的副作用（别踩坑）

SafeMode = **彻底关掉 AutoType**（就是那个"根据 JSON 里的 `@type` 字段自动 new 出对应 Java 类"的功能，也正是漏洞走的路）。

- 前人已扫过代码：公司业务**没有主动开 AutoType、没有主动用 `@type`**，所以理论上关了不影响功能，副作用极低。
- 但"代码里没写"不等于"运行时绝对没有"——比如 Redis 老缓存、MQ 历史消息里可能残留带 `@type` 的旧数据。所以上线前**必须在 test 跑一轮回归**，重点看日志里有没有 `autoType is not support` 之类的报错。详细验证清单见 codex 那篇的第 7 节。

---

## 2. 从零扫盲：Docker / 镜像 / 容器是什么

先用大白话把三个最基础的词讲清楚，后面才好串。

| 术语 | 大白话 | 类比 |
|---|---|---|
| **镜像 image** | 一个打包好的"只读安装盘"，里面装好了：一个精简 Linux + JDK8 + 你的 jar + 启动脚本 | 一张刻好的**光盘 / 装机 U 盘** |
| **容器 container** | 用镜像"装"出来的、正在运行的一份实例 | 用那张光盘**装好并开机运行的一台电脑** |
| **Dockerfile** | 一张"怎么刻这张光盘"的配方文本 | **做菜的菜谱** |
| **Docker** | 执行这套"打包→运行"的引擎/工具 | 厨房里那台**灶** |

关键点：**一个镜像 = 一个服务**。`scm-source-web`、`scm-order-web`、`scm-auth-web` 各是各的镜像、各是各的容器、各自一个独立 JVM。**所以改了 source 的 Dockerfile，只影响 source，绝不会自动让 order、auth 也带上 SafeMode**——这也是为什么 fastjson 这事得一个服务一个服务地铺。

### 逐行看懂你这个 Dockerfile

```dockerfile
FROM dockerhub.kubekey.local/public/openjdk:8   # 打底：基于公司仓库里的 openjdk8 基础镜像
ENV TZ Asia/Shanghai                             # 设时区
ENV JAVA_TOOL_OPTIONS="-Dfastjson.parser.safeMode=true"  # ← SafeMode（你加的第一处）
ARG JAR_FILE / APP_NAME / PRO_FILE               # 构建时传进来的变量（谁来传？下面 Jenkins 传）
ADD docker-entrypoint.sh /                       # 把启动脚本拷进镜像
RUN mkdir ... && echo "exec java -jar ... ${JAR_FILE}" >> /docker-entrypoint.sh  # 把真正的启动命令追加到脚本末尾
ADD ./target/${JAR_FILE} /opt/app/${APP_NAME}/   # 把 Maven 编出来的 jar 拷进镜像
ENTRYPOINT ["/docker-entrypoint.sh"]             # 容器一启动就跑这个脚本 → 脚本最后一行把 Java 应用拉起来
```

`ARG JAR_FILE / APP_NAME / PRO_FILE` 这几个空的变量，是**构建镜像时由 Jenkins 传进来的**（见下一节 Jenkinsfile 的 `docker build --build-arg`）。所以同一个 Dockerfile 配方，能被 source 服务用、也能被别的服务用，靠的就是这几个变量填不同的值。

---

## 3. 这套项目里每个文件/工具，分别干什么

你在每个服务目录（比如 `scm-cloud-source/`）会看到这一套文件，它们是一条流水线上的不同环节：

| 文件 / 工具 | 角色（大白话） | 在这个项目里具体是 |
|---|---|---|
| `pom.xml` + Maven | 把 Java 源码编译打包成一个能跑的 jar | `mvn clean install` 产出 `target/scm-source-web.jar` |
| **`Dockerfile`** | 把上一步的 jar + JDK 打包成一个镜像 | 你正在改的这个文件 |
| **`docker-entrypoint.sh`** | 容器开机时执行的启动脚本 | 最后一行 `exec java -jar ...` 把应用拉起来 |
| **`Jenkinsfile`** | 流水线机器人的剧本：拉代码→编译→做镜像→推仓库→部署，全自动 | 有 4 个版本，对应 4 套环境（见 3.1） |
| **Harbor（镜像仓库）** | 存放做好的镜像，供 K8s 拉取 | `dockerhub.kubekey.local`，命名空间如 `si-scm-product-test` |
| **Kubernetes（K8s）** | 真正的"后厨"：把镜像跑成 Pod，挂了自动重启、能滚动更新、能扩容 | 公司的容器云（KubeSphere/KubeKey） |
| **`deploy-docker.yaml`** | 给 K8s 的"上菜说明书"：跑哪个镜像、几个副本、给多少 CPU/内存 | 里面 `APP_NAME`、`IMAGE_URL` 是占位符，部署时被替换 |
| **Nacos（配置中心）** | 应用运行时去哪拿数据库地址、Redis 地址等配置 | test 命名空间 `scm-jdsn-test` 等；配置在 Nacos 网页上改，不在代码里 |

### 3.1 为什么有 Jenkinsfile、Jenkinsfile-Test、Jenkinsfile-Uat、Jenkinsfile-Prod 四个？

因为公司有四套环境，一套环境一个剧本（推到不同的镜像仓库命名空间、部署到不同的 K8s 空间、用不同的 profile）：

| 环境 | 是什么 | 谁用 | 对应文件 |
|---|---|---|---|
| dev | 开发自测 | 开发 | `Jenkinsfile`（默认） |
| **test** | 测试环境 | 测试同事验收 | `Jenkinsfile-Test` |
| **uat** | 仿真/预生产 | 业务方验收 | `Jenkinsfile-Uat` |
| **prod** | 正式生产 | 真实用户 | `Jenkinsfile-Prod` |

代码从 test → uat → prod 一层层验证着往上走。**SafeMode 也要按这个顺序灰度**：先 test 开、观察没事，再 uat，最后 prod，不能一步到位直接上生产。

### 3.2 拿你的 `Jenkinsfile-Test` 举例，机器人到底干了 4 件事

（对应 `scm-cloud-source/Jenkinsfile-Test`）

1. **编译**：进 `scm-cloud-source` 目录，`mvn clean install` 打出 jar。
2. **构建镜像**：`docker build --build-arg JAR_FILE=... -f Dockerfile -t <Harbor地址>/<命名空间>/scm-source-web:SNAPSHOT-<时间戳> .`（← 这里把 `JAR_FILE` 等变量传给了 Dockerfile）。
3. **推送镜像**：`docker push` 把镜像推到 Harbor 仓库。
4. **部署**：`envsubst < deploy-docker.yaml | kubectl apply -f -`（把 yaml 里的占位符换成真实镜像地址，交给 K8s 去滚动出新 Pod）。

**重点**：SafeMode 想生效，必须让 Jenkins **重新走一遍"构建镜像 + 推送 + 部署"**，产出带新参数的新镜像、并让 K8s 换成新 Pod。**只重启旧 Pod、或只点了编译没做镜像，都不算数**。

---

## 4. 为什么有的项目有 Dockerfile、有的没有？

这是你最大的困惑，答案在于**这套后端是"两段式"结构**，两拨仓库分工完全不同：

```
01zhaocai-end/scm-cloud-parent   ← 统一管版本（fastjson 2.0.62 就锁在这）
        │
01zhaocai-end 各业务 *-all 仓库    ← 【业务源码】写 controller/service/mapper
        │   出口：mvn deploy 把 jar 发布到公司 Nexus 仓库（不做镜像！）
        ▼
03zhaocai-start/scm-cloud-starters-web  ← 【启动壳工程】每个服务一个空壳，引入上面的业务 jar
        │   出口：每个服务有自己的 Dockerfile，做成镜像
        ▼
   各服务独立 Docker 镜像 → 推 Harbor → K8s 跑成 Pod
```

一句话规律：

> **能独立启动、要上线跑的"服务"才需要 Dockerfile；只是被别人引用的"零件库"不需要 Dockerfile，它只把 jar 发到 Nexus。**

具体到两拨仓库：

- **`03zhaocai-start/scm-cloud-starters-web/*`**：这里每个子目录（source、order、auth、gateway…）都是一个**能跑的微服务启动工程**，所以**每个都有 Dockerfile + Jenkinsfile + deploy-docker.yaml**。这是当前主线部署入口。
- **`01zhaocai-end/*-all`**：这里绝大多数是**业务源码/零件库**，出口是 `mvn deploy` 发 jar 到 Nexus，**所以大多没有 Dockerfile**。

### 关于你说的"`01zhaocai-end/scm-source-all` 没有 Dockerfile"

其实**它有**，只是不在你看的那一层。它在子目录里：

```
01zhaocai-end/scm-source-all/scm-cloud-source/Dockerfile   ← 在这
```

`scm-source-all` 这个仓库里，大部分模块（`scm-source-source`、`scm-source-*-api` 等）是业务零件库、没 Dockerfile；只有 `scm-cloud-source` 这个"启动子模块"有 Dockerfile。**Dockerfile 永远跟着"能启动的那个模块"走，不在仓库根目录。**

⚠️ 补一个坑：`scm-cloud-source/Dockerfile` **有两份**——`01zhaocai-end/...` 一份、`03zhaocai-start/...` 一份。据项目笔记（`note/project-ai-context.md`，同事在线核实过），**当前主线走 03 这份**。你昨天改的正是 03 那份（对的）。01 那份是历史/并行副本，动之前最好跟点 Jenkins 的人确认一句"source 服务实际用的是哪个 Jenkins 任务、构建的是哪份 Dockerfile"。

### 哪些"有 Dockerfile"反而不用加 SafeMode

不是所有 Dockerfile 都要加。加不加看它**跑的是不是 Java（含 fastjson）**：

- ✅ 要加：`scm-cloud-starters-web` 下的各 Java 微服务（source、order、auth、gateway、ifs、srm、contract、workflow、report…）。
- ❌ 不用加：`scm-cloud-statics`（Nginx 前端静态服务，`Dockerfile-Nginx`，根本没 Java）、`scm-cloud-elasticsearch`（ES 镜像）、`mybatis-plus-generate`（代码生成器，不上线）。

---

## 5. 一次完整上线，从改代码到用户能用，是怎么走的

把上面串起来，一条完整链路（以后端业务改动为例）：

```
①改代码(01业务*-all)
   └─ Jenkins 跑 scm-<模块>-all-<env>：mvn clean deploy → 业务 jar 发到 Nexus
②改/引用(03 starter)
   └─ Jenkins 跑 scm-<模块>-web-<env>：
        mvn 编译(从 Nexus 拉①的新 jar) → docker build 出镜像 → push 到 Harbor → kubectl apply
③K8s 拿到新 deploy-docker.yaml → 滚动拉起新 Pod（旧 Pod 平滑下线）
④新 Pod 启动时去 Nacos 拿数据库/Redis 等配置 → 服务就绪
⑤curl / 页面验证接口通了
```

（这套"后端两段式：先 `*-all-*` 发 jar、再 `*-web-*` 出镜像"是同事在 Jenkins 上核实过的，见 `note/project-ai-context.md` 的"构建、部署和 CI"节。）

**对 SafeMode 这件事的意义**：SafeMode 只改运行启动层（Dockerfile / K8s），**不碰业务代码**。所以只需要走②③——重建 03 的 `*-web` 镜像并让 K8s 换新 Pod 就行，**不需要**重新发布 01 的业务 jar（不用点 `*-all-*`）。这点前人文档也确认了。

### 另一条更省事的路（运维视角，供参考）

SafeMode 也可以**不改 Dockerfile**，改成在 K8s 的 `deploy-docker.yaml` 里给容器注入环境变量：

```yaml
containers:
  - name: container-APP_NAME
    image: IMAGE_URL
    env:
      - name: JAVA_TOOL_OPTIONS
        value: "-Dfastjson.parser.safeMode=true"
```

好处：如果公司运维有**统一的 K8s/Helm 模板**，可能一次就给所有 Java 服务加上，不用一个个改 Dockerfile。这条要问运维"有没有统一模板"。两条路二选一，别混着来（否则乱）。详见 codex 那篇第 4.1 节。

---

## 6. 回到 fastjson：全平台现在铺到哪一步了

我扫了三个仓库所有 Dockerfile，看谁已经配了 SafeMode：

| 状态 | 服务 |
|---|---|
| ✅ **已配**（你昨天加的，共 2 处/重复） | `03zhaocai-start/.../scm-cloud-source/Dockerfile` |
| ❌ **未配**（约 20+ 个 Java 服务） | auth、gateway、gateway-mall、ubm、ubm-mall、order、product、contract、fee、ifs、ifs-schedule、srm、workflow、report、professor、scheduling、devops、file… 以及 01 侧的 ifs/workflow/source 等历史 Dockerfile |

**含义**：fastjson 2.0.62 是父 POM 全局锁的，所以**每个 Java 服务都有这个漏洞**，不是只有 source。目前只挡住了 source 一个。

**但别急着照着这张表去把 20 个 Dockerfile 全改**——正确做法（前人已定）是：**按运维给出的"实际在线运行的 Java Deployment 清单"来铺**，不按"目录里有 Dockerfile"盲改（会误改没上线的、漏改用外部模板的）。这一步需要你去找运维要清单。完整推广步骤、验证方法、回退方案、给领导/运维/同事的逐字话术，都在：

- `02漏洞问题/90-临时-Fastjson2漏洞调研与处置总结-codex.md`（第 5、6、7、8、10 节）

---

## 7. 你（用户）接下来要做/要问的事

技术执行我来干；需要你去对接人的，攒成这几条：

1. **拍板**：SafeMode 缓解方案能不能现在推进（先 test 灰度 source，再全量）。问领导/技术负责人。
2. **要清单**：请运维导出 test/uat/prod **实际在线的 Java 服务清单**（服务名、镜像、对应 Jenkins 任务）。这是"到底要给哪些服务加"的唯一准绳。
3. **问模板**：问运维"有没有统一的 K8s/Helm 部署模板能一次性给所有 Java 服务加环境变量"——有的话比一个个改 Dockerfile 省太多。
4. **确认 source 用哪份**：source 有两份 Dockerfile（01/03），跟点 Jenkins 的人确认一句"实际构建用的是哪个任务、哪份 Dockerfile"，免得改了没用上。

（话术模板直接抄 codex 那篇第 10 节，已经写好了逐字版。）

---

## 8. 一句话复述给别人听

> "fastjson 这个高危漏洞的临时缓解，就是给每个 Java 服务的 JVM 加一个启动开关 `-Dfastjson.parser.safeMode=true`，把危险功能焊死。这个开关一个服务配一处就够（我们放在 Dockerfile 顶部的 `JAVA_TOOL_OPTIONS` 里，带不带'2'都生效，我看过源码）。每个后端服务是独立镜像、独立进程，所以得一个个服务铺，按运维给的在线服务清单来，先 test 再 uat 最后 prod。"
