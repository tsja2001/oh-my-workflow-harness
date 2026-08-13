# 集采业务管理报表和取值 · Git 交付复盘与后续规范

> 日期：2026-08-11  
> 工具：codex  
> 当前状态：本次 UAT 已发版；已根据团队规范、历史日志和 5 个实际仓库提交图完成复盘，并把通用规则及检查脚本落地。  
> 下一步：下一个新需求开工时，先按本文第 5 节做仓库体检和分支选型；test 验收通过当天冻结发布清单，不再临近 UAT 时反查提交。

## 1. 一句话结论

这次慢，不是因为 Git 命令难，而是到了准备 UAT 时才开始回答三个本应在开发初期就固定的问题：

1. 这个需求到底涉及哪些仓库、哪些功能，哪些明确不发？
2. test 上真正验过的是哪几个提交，顺序是什么，有没有本地未推送提交？
3. 每个仓的 prod/test/uat 是一条直线，还是已经分叉多年？

以后把“本需求可发布的提交集合”当成交付物：开发前确定分支模式，test 验完立即冻结提交和文件清单，UAT/prod 只按这份清单从目标环境基线重放。这样 AI 仍负责全部技术动作，但不需要每次重新考古。

## 2. 当前仓库的真实情况

2026-08-11 对本次 5 个仓的 `origin/prod|test|uat` 做了祖先关系和左右独有提交实查。计数格式为“左分支独有 / 右分支独有”。source、order、procurementScheme 本轮 fetch 成功；report fetch 超时、HPC 凭据失效，后两者使用本地缓存引用，不能把哈希表述成远端最新。

| 仓库 | prod...test | test...uat | prod 是否为 test 祖先 | 判定 |
|---|---:|---:|---|---|
| `scm-source-all` | 4 / 1208 | 1208 / 6 | 否 | 环境历史严重分叉 |
| `scm-report-all` | 0 / 34 | 35 / 0 | 是 | prod/test 较直，但缓存中的 UAT 不是同一条最新线；按分叉模式更安全 |
| `scm-order-all` | 20 / 1084 | 1084 / 18 | 否 | 环境历史严重分叉 |
| `scm-vue-all-procurementscheme` | 6 / 575 | 567 / 41 | 否 | 环境历史严重分叉 |
| `scm-vue-hpc` | 0 / 86 | 0 / 1 | 是，且 test 是 uat 祖先 | 当前可按同源模式处理 |

这直接推翻了旧规范中“所有新需求统一从 prod 开 feature”的机械说法：

- 在 source/order/procurementScheme 上从 prod 开分支再 MR 到 test，会分别夹带 prod 独有的 4、20、6 个提交。
- 从 test 开 feature 虽然最容易进 test，但这个 feature 自带大量 test 历史，不能原样拿去 MR 到 uat/prod。
- 所以多数业务仓真正适用的是：**开发分支服务 test，环境交付分支服务 uat/prod，两者靠冻结提交清单连接。**

证据可随时用以下命令复查：

```bash
bash scripts/git-release.sh audit --fetch \
  01zhaocai-end/scm-source-all \
  01zhaocai-end/scm-report-all \
  01zhaocai-end/scm-order-all \
  02zhaocai-front/scm-vue-all-procurementscheme \
  02zhaocai-front/scm-vue-hpc
```

## 3. 这次具体遇到了什么

### 3.1 发版范围临近 UAT 才重新圈定

最初按 `03集采业务管理报表 + 06取值` 分析，随后才明确 `06_2` 的日计划四率和对应前端也属于本轮。与此同时，`centerHeader/categoryAmount/situA/doRate` 并没有新的完整实现提交。

结果是“需求文件夹名称”“产品认为要发的内容”“远端 test 上存在的提交”三者不是同一张清单。准备 UAT 时必须重新逐仓找代码，且容易把“本次已发的 06_2 日计划部分”误说成“06_2 全部完成”。证据见：

- `10-UAT部署方案2-codex.md` 第 1、2 节；
- `20-UAT部署执行2-codex.md` 第 4 节；
- `30-UAT代码评审-codex.md` 第一节。

### 3.2 test 是共享集成分支，不能整条搬到 UAT

source/order/procurementScheme 的 test 各自比 uat 多几百到上千个独有提交，其中包含大量别人的需求。整条 `test → uat` 不只是冲突风险，而是确定会夹带未计划功能。

本轮最后采用的正确做法是：4 个仓都从各自最新 `origin/uat` 开 `jicai-uat-yang`，只搬本需求已进入远端 test 的提交；最终提交数为 source 9、report 2、order 2、procurementScheme 3。HPC 已经在 UAT，不重复提 MR。证据见 `20-UAT部署执行2-codex.md` 第 1 节。

### 3.3 “代码在我本地”不等于“test 验过、可以发 UAT”

order 的 `beab9ac09` 是“已完结月取当月最后有数据日期”的修复，当时只在本地 feature 上领先远端 test 1 个提交，没有进入远端 test。本轮按“只发 test 已验代码”明确排除。

这个决定是对的，但发现得太晚。以后 test 验收完成时必须同时检查：

- feature 是否还有本地 ahead；
- 每个待发提交是否已经进入远端 test 或有明确的 test squash/merge 映射；
- 文档中列出的“已完成”是否真的有提交和测试证据。

### 3.4 工作区同时存在 Fastjson 改动，靠肉眼排除风险太高

source 工作区同时有另一项 Fastjson 未提交修改。本轮最终没有夹带，但如果使用 `git add -A`、在原工作区来回 checkout，或者从整个工作树复制文件，极易把它带进集采提交。

正确办法不是提醒自己“小心”，而是开发和交付都用独立 `git worktree`，提交时只 `git add <本需求路径>`。本轮 UAT 交付分支就是在独立临时 worktree 中完成，因而 Fastjson 文件没有进入任何 MR。

### 3.5 前端 router 是共享文件，整文件复制 test 状态导致构建失败

procurementScheme 第一次把 test 的 router 文件整体带到 UAT 基线后，路由引用了 UAT 中不存在的另外 4 个页面。最终用 `9aa0760a fix: 收窄集采报表路由交付范围` 只保留本需求的 `/reportForms/centralizedProcurement` 路由，生产构建才通过。

这个提交不是删除集采功能，而是删除被误带的其他需求路由。根因是按“文件最新版本”搬运，而不是按“本需求补丁”搬运。

### 3.6 前端依赖锁和环境配置曾经夹带或存在误提交风险

- 8 月 6 日 HPC 合 test 时曾带入 `package-lock.json`，后来重做合并排除；证据见 `06取值需求/20-开发交接-cc.md` 头部更新记录。
- `public/statics/config.js` 是已跟踪文件，本地又可能放 token/环境地址，历史上多次需要提交前还原。

因此这些文件不能仅靠 `.gitignore` 解决，必须在每次发布清单和 MR 净差异中显式扫描。

### 3.7 分支名、收口提交和 GitLab squash 降低了可追溯性

4 个仓统一叫 `jicai-uat-yang`，虽然操作方便，但看名字不知道是集采报表、首页取值还是驾驶舱四率。用户看到 `fix: 收窄集采报表路由交付范围` 也需要重新解释上下文。

另外 source、procurementScheme 合入 UAT 后由 GitLab 收口为新的提交，原来的逐提交关系不再能只靠 UAT 日志还原。内容最终核对一致，但 UAT→prod 仍要再次追溯原提交。

以后分支名至少带“需求 + 环境”，例如：

- `feature/jicai-cockpit-yang`
- `jicai-cockpit-uat-yang`
- `jicai-cockpit-prod-yang`

MR 能关闭 squash 时关闭；平台或审核人需要收口时，把“原业务提交 → test 合并/收口提交 → UAT 合并/收口提交”写进发布清单。

### 3.8 全工作区 fetch 太慢，检查范围没有跟需求绑定

本轮 `doctor.sh --fetch` 会扫描整个工作区几十个仓，内网慢时一个仓就可能拖很久；但本需求实际只涉及 5 个仓。以后先在需求文档固定仓库清单，再用 `git-release.sh audit --fetch` 只 fetch 这些仓，单仓超时 25 秒后明确降级为缓存数据。

## 4. 根因分析

| 表面现象 | 真正原因 | 应对机制 |
|---|---|---|
| 每次 UAT 前都要找半天提交 | test 验完没有冻结“可发布提交集合” | test 验收当天生成发布清单 |
| 从 prod/test/uat 哪个开分支总要重查 | 不同仓历史形态不同，旧规范却只有一个答案 | 开工先跑祖先关系体检，按同源/分叉选型 |
| 怕漏提交，也怕夹带别人代码 | 需求范围、提交范围、文件范围没有一一映射 | 每仓记录有序提交 + 允许文件 + 明确排除项 |
| UAT 能跑但 prod 又要重新研究 | UAT 合并后原提交映射丢失 | 清单记录各环境基线、交付头和 GitLab 收口哈希 |
| 未提交 Fastjson、配置、锁文件总要手工躲 | 多需求共用同一工作区 | 独立 worktree + 路径暂存 + 风险文件自动扫描 |
| router 进 UAT 后才发现引用缺页 | 按 test 整文件状态搬运，不是按需求补丁搬运 | cherry-pick 本需求提交；共享文件逐段复核并构建 |

核心认识：`test`、`uat`、`prod` 是共享环境总线，不是天然可晋级的发布包；真正能逐级晋级的是“本需求的有序提交与配置清单”。

## 5. 下一个新需求的标准操作

### 第 0 步：先定一个发布编号和仓库清单

在需求 `10-拆解规划` 中先写：

- 需求简称，例如 `jicai-cockpit`；
- 涉及的仓库和前后端模块；
- 明确不属于本次的功能；
- SQL、字典、导出模板、菜单、定时任务是否涉及；
- 每个仓的分支模式。

没有这张清单时先不写代码，因为后续分支名、提交边界和测试范围都依赖它。

### 第 1 步：只对涉及仓库做 fetch 和分支选型

```bash
bash scripts/git-release.sh audit --fetch <仓库1> <仓库2> ...
```

按输出二选一：

| 模式 | 开发分支从哪开 | test 怎么进 | UAT/prod 怎么进 |
|---|---|---|---|
| 同源模式 | `origin/prod` | feature → test | feature 保持独立时可沿用同一提交序列；提 MR 前仍做目标基线检查 |
| 分叉模式 | 本需求实际依赖的 `origin/test` | feature → test | UAT 从 `origin/uat`、prod 从 `origin/prod` 各建干净交付分支，按冻结清单 cherry-pick |

当前 source/order/procurementScheme 默认按分叉模式，不再每次争论“为什么不能直接从 prod 开”。

### 第 2 步：用独立 worktree 开发，一个需求每仓一个长期 feature

原则：

1. feature 名在各仓保持同一需求关键词，如 `feature/jicai-cockpit-yang`。
2. Fastjson 等其他需求留在原工作区；新需求在独立 worktree，不来回覆盖用户未提交文件。
3. 不把 test/uat/prod merge 或 rebase 回 feature。
4. 同事分支只读。

### 第 3 步：提交从一开始就按“能否单独发版”拆

一个提交只做一件可以独立上线或独立回退的事。例如：

- `feat: 增加集采报表查询`
- `fix: 调整日计划统计口径`
- `fix: 修复云采同步幂等`

提交时只暂存明确路径，前端特别检查：

- `public/statics/config.js`
- `package-lock.json` / `yarn.lock`
- router 中其他页面的改动
- 构建产物、`.env`、token 和环境配置

如果一个提交混有“本轮要发”和“以后再发”，应在进 test 前拆开；到了 UAT 再拆已经晚了。

### 第 4 步：进 test 前做一次净差异预检

AI 负责完成：

1. fetch 本需求仓库；
2. 查看 feature 相对开发基线的全部提交和文件；
3. `merge-tree` 预演 feature → test；
4. Java 隔离编译、前端生产构建、接口/数据自测；
5. 风险文件扫描；
6. 用户最后只做 push、提 MR、点 test Jenkins。

test 上发现 bug 后，修复继续提交到原 feature 或清晰的补丁分支，再合 test；不能直接在 test 写，也不能只修 UAT。

### 第 5 步：test 验收通过当天冻结发布清单

每仓运行一次，开发基线应填写 feature 刚创建时的精确提交；如果要把第一个业务提交也包含进去，基线填它的父提交：

```bash
bash scripts/git-release.sh manifest <仓库> <开发基线hash> <feature分支>
```

然后把输出补进 `20-开发交接`，至少包含：

| 字段 | 必填内容 |
|---|---|
| 仓库/模块 | 仓库路径、Jenkins 工程 |
| 开发基线 | feature 创建时的 hash |
| 业务提交 | 按应用顺序列 hash + 一行说明 |
| test 证据 | test MR/merge/squash hash、部署版本、测试报告 |
| 允许文件 | 本需求净变更文件 |
| 明确排除 | 未完成功能、本地未推提交、Fastjson、配置、锁文件等 |
| 非代码动作 | SQL、字典、模板、菜单、任务、Nacos |
| 验证 | 编译/构建/接口/对账结果 |
| UAT/prod 映射 | 后续补交付分支头、MR 和收口 hash |

冻结前必须回答“有没有本地 ahead”。本次 `beab9ac09` 就应该在这里被标成“未进远端 test，本轮排除”，而不是准备 UAT 时才发现。

### 第 6 步：UAT 只按冻结清单准备

分叉模式的固定动作：

1. 从最新 `origin/uat` 在独立 worktree 新建 `需求-uat-yang`；
2. 按清单顺序 `cherry-pick <提交>`，不加 `-x`，原始 hash 已在清单中记录；
3. 冲突只解决本需求文件，不能顺手把 test 整文件覆盖进来；
4. 运行：

```bash
bash scripts/git-release.sh check --fetch <仓库> uat <UAT交付分支>
```

5. 对照允许文件、排除项、编译/构建和配置清单复核；
6. AI 整理最后一张表，用户只负责逐仓 push、提 MR 给兰宇、点 Jenkins 和做页面配置。

MR 合入后立刻把 UAT MR、合并/收口 hash 和部署结果补回发布清单。源 feature 和交付分支至少保留到 prod 完成。

### 第 7 步：UAT 验收后准备 prod

先判断整个 `uat → prod` 差异是否只属于本次发布：

- 如果是，而且兰宇沿用整条 UAT 晋级：由兰宇提/合 `uat → prod` MR。
- 如果不是或历史分叉：从最新 `origin/prod` 建 `需求-prod-yang`，搬入 UAT 已验收的同一逻辑提交，逐文件与 UAT 验收版比对，再提 MR 给兰宇。

prod 交付分支上不临时开发。任何新改动先回 feature/test 验证，更新发布清单后再走 UAT。生产 SQL、配置、Jenkins 和部署仍交负责人/运维，AI 不碰生产环境。

## 6. 提 MR 前的硬检查

每个仓必须同时满足：

- [ ] 交付分支基于目标环境最新远端基线；
- [ ] 提交数和顺序与发布清单一致；
- [ ] 净变更文件全部在允许清单中；
- [ ] 本地未提交/未推送内容没有进入；
- [ ] 前端环境配置、依赖锁、其他页面路由没有夹带；
- [ ] Java 隔离编译或前端生产构建通过；
- [ ] test 验收过的逻辑没有在 UAT/prod 分支临时改写；
- [ ] SQL、Nacos、菜单、字典、模板、任务有独立交付清单；
- [ ] MR 标题能直接说清仓库和需求；
- [ ] GitLab 如果 squash/收口，映射 hash 已回填。

`git-release.sh check` 只证明 Git 基线和常见夹带项合格，不代替业务测试、编译构建和配置核对。

## 7. 本次哪些地方其实做对了

本轮虽然前期慢，但最终交付动作是安全的：

1. 没有整条合并 test，而是从各仓 UAT 最新基线准备需求交付分支；
2. 只带当时已进入远端 test 的已确认提交，`beab9ac09` 没有越级；
3. 未提交 Fastjson、`config.js` 和依赖锁都没有进入 MR；
4. 前端 router 的夹带在 push 前被构建发现并收窄；
5. source/report/order 隔离编译通过，procurementScheme 生产构建通过；
6. source/procurementScheme 被 GitLab 收口后又做了业务文件内容核对，而不是只看“MR 已合”。

所以问题不是本次最终几个 MR 做错，而是这些正确检查全挤到了 UAT 前，导致慢且高度依赖 AI 临时记忆。新流程把同样的检查拆到“开工、进 test、test 验收、进 UAT、进 prod”五个固定节点。

## 8. 用户以后只需要做什么

按新流程，AI 应该完成分支体检、worktree、代码提交、编译构建、发布清单、UAT/prod 本地交付分支和 MR 差异复核。用户只在最后一次性处理人的接口：

1. 执行 AI 给出的精确 push 清单；
2. 在 GitLab 提 MR、选择目标分支和审核人兰宇；
3. 点对应 Jenkins；
4. 在管理页面做菜单/字典/模板/任务配置，或把 SQL/生产动作交负责人。

下次可以直接对 AI 说：

> 按《50-Git交付复盘-codex.md》的流程处理这个需求：先只体检涉及仓库并确定分支模式，开发过程维护发布清单；test 验收后按冻结清单准备 UAT，最后只把 push、MR、Jenkins 和页面配置清单一次性给我。
