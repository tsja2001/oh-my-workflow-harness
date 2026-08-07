# SCM 高频排障场景

以下步骤都是只读查询。优先执行一个项目级命令拿到主证据，再按需补平台细节。出现需要发布、重启、改配置、执行任务的步骤时，停下来让用户或运维操作。

命令前缀：

```bash
PROJECT="skills/diagnose-scm-project/scripts/project.sh"
PLATFORM="skills/diagnose-scm-project/scripts/platform.sh"
```

## 1. 发布后接口 404

先确认发布链和运行态，不要先猜 ES 或数据库。

```bash
bash "$PROJECT" diagnose api uat '/d/business/order/接口资源/方法'
bash "$PROJECT" diagnose release uat order

# 需要单独补某个平台的细节时：
bash "$PLATFORM" jenkins build scm-order-all-uat lastBuild
bash "$PLATFORM" jenkins builds scm-order-web-uat 5
bash "$PLATFORM" jenkins build scm-order-web-uat lastBuild
bash "$PLATFORM" jenkins evidence scm-order-web-uat lastBuild
bash "$PLATFORM" k8s deployment uat scm-order-web
bash "$PLATFORM" k8s pods uat scm-order-web
```

判断：

- `all` 成功但没有新的 `web` 构建：下游未触发、排队或任务链配置有问题。
- `web` 成功但 Deployment 镜像仍旧：构建/推镜像/`kubectl apply` 证据不完整，或查错环境/namespace。
- Deployment 是新镜像但新 Pod 不 Ready：继续 `k8s diagnose`，问题已经从网关路由转到应用启动。
- 新 Pod Ready 且接口仍 404：核实请求路径、网关前缀、Controller 是否进入该构建 revision，再看网关运行态。

Jenkins 的 `kubectl apply` 成功不等于 rollout 成功。一定核对 K8s。

## 2. Jenkins 绿了，页面还是旧版本

```bash
bash "$PLATFORM" jenkins jobs '<模块关键词>'
bash "$PLATFORM" jenkins builds '<web-job>' 10
bash "$PLATFORM" jenkins evidence '<web-job>' lastBuild
bash "$PLATFORM" k8s deployment <环境> '<deployment>'
bash "$PLATFORM" k8s pods <环境> '<deployment>'
```

对比：

- Jenkins 构建时间、上游原因、revision。
- 控制台中的镜像 tag。
- Deployment/Pod 实际镜像 tag 与 Pod 创建时间。

同名 SNAPSHOT jar 会随时间变化，不能只比较版本字符串；要结合 Jenkins 构建号、revision、镜像时间戳。

## 3. 新 Pod CrashLoopBackOff 或反复重启

```bash
bash "$PROJECT" diagnose runtime uat order
bash "$PLATFORM" k8s diagnose uat scm-order-web
bash "$PLATFORM" k8s logs uat scm-order-web --previous --tail 800 --errors
```

优先看：

1. previous container 的第一个启动异常与最底层 `Caused by`。
2. Nacos placeholder/bind failure、bean creation failure、端口、连接拒绝。
3. Pod events 中的拉镜像、探针、调度、OOM。

若 Pod 已被滚动更新删掉（原日志在 `k8s logs` 不可见），改用 ES 检索：

```bash
bash "$PLATFORM" k8s eslogs uat scm-order-web --since 3h --match 'Caused by|BeanCreationException' --tail 500
```

如果异常指向缺少配置：

```bash
bash "$PLATFORM" nacos compare test scm-order-web-test.yaml uat scm-order-web-uat.yaml common
```

只补证据，不直接发布 Nacos。给用户准备“缺少哪些键、test 的结构、UAT 应由谁确认值”的清单。

## 4. test 正常，UAT 配置疑似缺项

```bash
bash "$PROJECT" compare config source test uat
bash "$PLATFORM" nacos compare test scm-source-web-test.yaml uat scm-source-web-uat.yaml common
bash "$PLATFORM" nacos keys uat scm-source-web-uat.yaml common
```

`compare` 比较完整层级键名，适合发现：

- ES index 配置漏项。
- MQ、Redis、业务开关的环境差异。
- YAML 缩进导致的层级变化。

不能只复制 `_test` 的值到 UAT。先确认 UAT 资源是否存在，尤其是 ES index、topic、数据库 schema 和外部地址。

## 5. 接口不再 404，但页面没有数据

按照“代码运行 → 配置指向 → 数据生产 → 数据存储 → 查询权限”检查：

```bash
# 1. 服务是否正常、是否有查询异常
bash "$PLATFORM" k8s logs uat scm-order-web --tail 500 --errors

# 2. Nacos 是否有相关索引/开关键
bash "$PLATFORM" nacos keys uat scm-order-web-uat.yaml common | rg -i 'elastic|index|report'

# 3. 任务是否配置并启用
bash "$PLATFORM" scheduling jobs uat --executor "订单中心" --desc "集采" --status all

# 4. 今天是否执行成功
bash "$PLATFORM" scheduling logs uat --executor "订单中心" --status all

# 5. 再查 ES/数据库
bash scripts/esq.sh indices '*centralized*'
bash scripts/esq.sh count <确认后的索引>
bash scripts/dbq.sh "SELECT COUNT(*) FROM <确认后的表>" <确认后的库>
```

常见结论：

- 表刚建且 0 行、ES 索引也 0：空页面可能符合现状，需要任务产数或业务录入。
- 任务不存在：代码和页面发布成功并不会自动创造调度配置。
- 任务 RUNNING 但没有成功日志：继续看调度执行记录与应用日志。
- ES 有数据、列表仍空：检查登录人数据权限、筛选条件、字段名/mapping，不要直接认定 ES 发布失败。
- 汇总有数据、分页无数据：本项目某些报表分页会额外套登录人公司权限。

## 6. 定时任务没跑或结果不对

```bash
bash "$PROJECT" diagnose task uat order <任务ID>

# 需要补调度页面列表时：
bash "$PLATFORM" scheduling executors uat
bash "$PLATFORM" scheduling jobs uat --executor "订单中心" --desc "任务描述关键词" --status all
bash "$PLATFORM" scheduling logs uat --executor "订单中心" --job <任务ID> --status all
bash "$PLATFORM" scheduling logs uat --executor "订单中心" --status failed
```

`diagnose task` 直接读取任务配置和最近 5 次数据库执行记录，优先看 `module_group_check` 与 `deepest_cause`。

核对：

- 任务 ID、执行器、描述、Cron/FIX_RATE、handler、RUNNING/STOP。
- 当天调度结果和执行结果。
- 失败时间是否与服务重启或配置发布重合。

`simpleJobHandler` 参数由应用、服务映射、方法映射和 JSON 组成。包含短横线的日期可能被旧解析逻辑错误拆分；指定日期补跑要先核对代码协议，不要直接点“执行一次”。

## 7. 前端已发布但页面或静态资源没更新

```bash
bash "$PROJECT" trace page '/procurementScheme/index.html#/页面路由'
bash "$PROJECT" diagnose release uat procurement-scheme

# 单项细查时必须按 PROJECT 找构建，不能直接把共享 Job 的 lastBuild 当成当前前端：
bash "$PLATFORM" jenkins parameter-build scm-vue-statics-uat PROJECT procurementScheme 50
bash "$PLATFORM" jenkins evidence scm-vue-statics-uat <上一步构建号>
bash "$PLATFORM" k8s deployment uat scm-statics-web
bash "$PLATFORM" k8s pods uat scm-statics-web
```

核对 Jenkins 参数中的 `PROJECT`、`GIT_BRANCH`，以及 K8s 的静态站镜像 tag。业务前端通常部署进统一 `scm-statics-web`，不要按前端 Git 仓名猜 Deployment。

## 8. 请求 401/403

先区分：

- Jenkins/Nacos/KubeSphere 登录失败：运行 `doctor`，只报告缺哪个变量，不显示值。
- 业务 API 401：token 过期或环境不匹配，用现有 `scripts/api.sh`，不要在命令行打印 token。
- 业务 API 403：服务已命中，通常是角色/菜单/数据权限，不是路由 404。
- K8s API 403：生产与非生产凭据或集群可能不同，不循环猜密码。

## 9. 不知道服务、Job 或内部文档名称

```bash
bash "$PLATFORM" jenkins jobs source
bash "$PLATFORM" k8s deployments uat source
bash "$PLATFORM" docs search "部署"
bash "$PLATFORM" docs headings "pages/c82752/"
```

先用实时名称缩小范围，再进入代码。服务入口与代码仓映射可读 `references/platform-index.md`。

## 10. 标准交付证据

排障结论至少包含：

```text
环境：
Jenkins：上游/下游 Job、构建号、结果、revision、关键时间
K8s：namespace、Deployment、镜像 tag、Pod、Ready、重启次数、创建时间
配置：Data ID、group、缺失键（不写敏感值）
任务：执行器、任务 ID、状态、最近结果
数据：目标库/表或 ES index 的 count
结论：已证实 / 高概率推断 / 尚缺哪条证据
下一步：需要用户点哪个平台动作，或需要找谁确认什么
```

不要把几十屏日志当结论。只保留能连接“构建 → 镜像 → Pod → 配置 → 任务 → 数据”的关键证据。
