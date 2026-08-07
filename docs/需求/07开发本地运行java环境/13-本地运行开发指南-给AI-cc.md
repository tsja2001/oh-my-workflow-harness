# 本地运行 scm-source 开发指南（写给 AI）

> 给谁看：接手本地开发/运行 scm-source（及同构 Java 服务）的 AI。
> 与他文关系：**可复现的机械步骤以《10 号 §A》为准**；本篇讲**心智模型、铁律、副作用管控、排障信号、工具坑**——即"怎么想、别踩什么"。用户侧说明见《11》《12》。

---

## 0. 场景与前提
- 用户是 Node 背景、不懂 Java，AI 全包技术执行；对用户只说大白话，技术细节写文档。
- 目标：让 `scm-source-web` 在本机启动、连**目标环境（默认 test）**的配置/中间件，跑**当前分支源码**，用于本地开发验证。
- 硬约束：**不改任何 git 跟踪文件**（业务代码 / pom / 仓库内配置）。所有适配只走三处：① 本机 `~/.m2` 缓存；② 外部 `-D`/环境变量；③ 分支切换（用户确认）。

---

## 1. 心智模型（三层，别混）
1. **源码层** `01zhaocai-end/scm-source-all`（反应堆 47 模块，主业务）。当前分支 `feature/taizhang-yang`。
2. **启动壳层** `03zhaocai-start/scm-cloud-starters-web/scm-cloud-source`，主类 `com.pcitc.scm.source.starter.SourceApp`，打出可运行 fat jar（`target/scm-source-web.jar` ~242MB），端口 `8110`，context `/scm-source-web`。
3. **运行环境层**：配置/DB/ES/Redis/MQ 全在 Nacos `scm-jdsn-<env>`，本机 resources 只有 bootstrap，没有 `application-*.yml`。**跨服务（auth/dict/order/gateway 等）不在本地起**——它们在目标环境集群里跑，pod IP `172.50.x` 从本机实测可达，本地实例作为消费者带 token 直接调。

---

## 2. 铁律（DO / DON'T）

**DON'T**
- ❌ 不改仓库任何跟踪文件。别用改 pom / 改 `application.yml` 来"修"问题。
- ❌ 别幻想一条 `mvn clean install` 全量编过——**必然撞跨团队 SNAPSHOT 漂移**（同事从不本地编译，plain `1.0.0-JDSN-SNAPSHOT` 坐标里的跨团队包是陈旧版）。
- ❌ 别启动后用 `-U` 把已对齐的跨团队包刷回 plain 陈旧版。
- ❌ 点火**绝不能**漏 `register-enabled=false`（否则本机被登记进目标环境服务发现，可能劫持真实流量）。

**DO**
- ✅ **把跨团队依赖对齐到目标环境版本**：Nexus 每个 `com.pcitc` 包并存 `plain / -TEST-SNAPSHOT / -UAT-SNAPSHOT / -PROD-SNAPSHOT`。把目标环境版（test→`-TEST-SNAPSHOT`）用 `install:install-file` 装进 **plain 坐标**（`.orig-bak` 备份）。脚本 `/tmp/align_test.sh <artifactId>`。
- ✅ **对齐"捆绑的全部"，不是只补编译报错的那几个**——因为**编译过 ≠ 能启动**：Feign 启动解析整个接口、Spring 实例化全部 bean，会暴露编译期没碰到的缺类。从**已打好的 fat jar 的 `BOOT-INF/lib/`** 枚举它真正捆绑的跨团队包（约 120 个，其中 ~75 有 TEST 版）一次性对齐（`/tmp/comprehensive_align.sh`），排除本地从源码构建的 `scm-source-*`。
- ✅ **分支线要与依赖环境线自洽**：`feature/*`、`uat-*` 分支的源码可能用到只在某环境版才有的跨团队方法/类。切分支前，先确认目标环境版的关键包是否含所需符号（`javap`/`unzip -l` 验证），再决定对齐到哪个 env。本次实测：`feature/taizhang-yang` 的代码在 **test** 版跨团队包上可编可跑（该分支已并入 test）。
- ✅ 点火固定参数：`APP_PROFILE=<env>` + `-Dnacos.ip=10.0.54.16:30996` + `-Dspring.cloud.nacos.discovery.register-enabled=false`（+ `-Dfastjson.parser.safeMode=true` 缓解 fastjson2 风险，见 note）。

---

## 3. 副作用管控（对共享环境有影响，按需用外部参数关闭，仍不改代码）
运行一台**完整实例**会触发下列对共享环境有影响的行为。默认能跑，但做本地开发建议尽量收敛：

| 行为 | 现状 | 影响 | 收敛办法（只加 -D / 覆盖 Nacos 配置键，不改代码） |
|---|---|---|---|
| 服务注册 | **已关**（register-enabled=false） | 无 | 保持关 |
| xxl-job 执行器 | 启动即起 EmbedServer(9999)，**可能注册到调度台被派活** | 定时任务可能落到本机跑 | 覆盖执行器的 admin 地址为空 / 把执行器端口设为 `-1` 禁用（**确认实际配置键后**再用）；或确保本机连不回调度台 |
| MQ 消费者 | **未确认**（该次日志尾巴未抓全、日志已清） | 可能加入共享消费组分走 test 消息 | 禁用 MQ 监听自启（对应开关键需从 Nacos 配置/代码确认）；或不触发消费类流程 |
| DB/ES 写 | 真写共享 test 数据，按 token 用户留痕 | 破坏性操作影响他人 | 破坏性操作前与用户确认 |

> ⚠️ xxl-job/MQ 的确切"关闭键"依赖该服务从 Nacos 读的配置项名，**用前先核实键名**（别照抄假设的 flag）。若用户要做长期本地开发，主动提出默认关掉 xxl-job 注册与 MQ 消费最稳。

---

## 4. 操作流程
直接照《10 号 §A》：A.0 中和 Maven http-blocker → A.1 切分支 → A.2 对齐跨团队依赖到 test → A.3 `mvn -pl scm-source-web-jar -am install -DskipTests` → A.4 `mvn -pl scm-cloud-source clean package -DskipTests` → A.5 点火 → A.6 改码闭环 → A.7 边界。改单模块后：`mvn -pl <模块> -am install -DskipTests` 再回 A.4/A.5。

---

## 5. 排障：日志信号 → 病因 → 处置
| 日志/现象 | 含义 | 处置 |
|---|---|---|
| `Started SourceApp` / `启动成功` + `8110` LISTEN | 成功 | 业务接口返回 `900301`＝正常鉴权，带 token 再调 |
| 编译期 `cannot find symbol` / `package X does not exist` | 跨团队包陈旧（编译期漂移） | 定位该包 artifactId（`unzip -l` 找含该包的 jar），`align_test.sh` 对齐到 TEST，`-rf :<module>` 续编 |
| 启动期 `ClassNotFoundException` / `TypeNotPresentException` / `NoSuchBeanDefinitionException` | 捆绑的跨团队包陈旧（运行期漂移） | 跑 `comprehensive_align.sh` 把捆绑包全量对齐，重打包重启 |
| `UnknownHostException: nacos-headless...` 或起不来 | 没带 `-Dnacos.ip` | 补 `-Dnacos.ip=10.0.54.16:30996` |
| 服务名册里出现本机 IP | 漏了 register 关闭 | 补 `-Dspring.cloud.nacos.discovery.register-enabled=false` |

---

## 6. 工具坑（本环境实测，务必避开）
- **wsl.exe 内联吞变量/引号**：`bash -lc '... $VAR ...'`、`for`/`awk "{print \$5}"`、嵌套双引号，经 wsl.exe 边界会被吞或翻译出错。→ **一律把逻辑写进 `/tmp/xx.sh` 脚本文件，再 `MSYS_NO_PATHCONV=1 wsl.exe -d ubuntu-24.04 -- bash /tmp/xx.sh`**。
- **pkill 自匹配**：`pkill -f "关键字"` 若关键字出现在 pkill 自己的命令行里会杀掉自身（exit 15）。→ 用不含于命令行的模式，或按 PID 杀，或用 TaskStop 停后台任务。
- **读大日志**：UNC 路径用 Grep 工具（ripgrep）比 wsl.exe 里 `sed|tail` 稳；后台构建的真实退出码别用 `mvn | tee | tail`（拿到的是 tail 的码），单独 `echo mvn-exit=$?` 落文件。
- **别对全 `.m2` 批量对齐**：`~/.m2/com/pcitc` 有数百个无关 artifact（如 scm-devops-*），全量对齐极慢且无意义。只对齐**目标服务真正依赖/捆绑**的那批（从 fat jar `BOOT-INF/lib` 枚举）。

---

## 7. 交接义务
- 有新发现（新的漂移包、新的关闭键、别的服务的跑法）→ 更新《10 §A》与本篇。
- 把"可复现结论"写进 AI 记忆（本会话已存 `work-wsl-local-run-java`）。
- 对用户永远大白话；需要用户去问人/给 token 的，攒成清单一次性给。
