# DeepSeek Harness × work-wsl 工作流迁移方案（架构规划 v1）

> 日期：2026-08-14 ｜ 工具：dsh ｜ 当前状态：两侧调研完成，方案 v1 待用户审阅 ｜ 下一步：用户确认第 8 节待确认问题后进入 Phase 0 试点
> 本文取代之前所有零散讨论记录，作为该主题唯一需要看到的版本。
> 需求原件：00-需求原件/01需求.md ｜ 调查底稿：本文第 1 节所列两侧文件（结论均落文件:行号，两条推断已显式标注）

---

## 0. 一分钟结论（先看这里）

**这套工作流不需要"搬"，需要"装"。** 给 DeepSeek Harness（下称 DSH）装一个专用组合包（bundle），work-wsl 原封不动——所有文档、脚本、skill、数据全部原地复用，cc / codex / oc 照常用，互不影响。

**为什么不是平移：** work-wsl 现在的模式是"文档约束行为 + 脚本提供能力 + skill 编排流程"，靠模型读过文档后自觉遵守。DSH 的模式是"一切皆插件 + 会话日志 + 确定性拦截"。同样一条红线，在旧模式里是"模型记得就不违反"，在 DSH 里是"管道里直接被 deny"——这是质的升级，不是换皮。

**四个去向：**

| 资产 | 去向 | 一句话理由 |
|---|---|---|
| 六条红线、凭据边界、prod 边界 | **升级为护栏插件**（ctx.tools.guard） | 从"自觉"变"不可能" |
| 14 个脚本 | **包装为 schema 化工具** | 参数校验 + Web 表单 + 输出脱敏渲染 |
| 2 个 skill | **零改写接入**（customSkillDirs 直指 skills/） | DSH 原生 skill 注册表，frontmatter 兼容 |
| 9 阶段流程、文档纪律、活文档 | **升级为状态机 + 模板工具** | 从"靠自觉"变"会话日志里的事实" |

**试点策略：** 每个阶段用一个真实历史需求回放验收，跑不通就退（回退成本为零，因为 work-wsl 没动过）。预计 Phase 0~4 共 4~6 个工作日。

**你要变的习惯（也只有这些）：** 一个需求 = 一个 DSH 会话（配 goal）；拆解/问题清单由状态机推动、话术照旧生成；"攒清单"、"点 Jenkins"、"问同事"全部不变。

---

## 1. 调研依据

### 1.1 work-wsl 侧（逐字读过）

- AGENTS.md（99 行）、CLAUDE.md、ai-docs/ 全部 11 份 .md（协作规矩/团队规矩/安全红线/系统地图/代码库地图/工具箱/本地运行手册/前端页面定位/经验教训/工作日志）、creds.env.example
- skills/enterprise-dev-workflow/SKILL.md（206 行）及 references 四件（doc-templates/prompts/env-playbook/export-template-playbook）、evals/evals.json
- skills/diagnose-scm-project/SKILL.md（116 行）及 references（evidence-rules/modules.json/platform-index/scenarios）、scripts 四件（project.sh 745 行 / platform.sh 1380 行 / safe-output.js / kubesphere-password.js）
- scripts/ 下 14 个脚本 + lib/ 2 件 + browser/ 2 件、.claude/skills 加载器、.agents/skills/playwright-cli、docs/需求/ 实际形态

### 1.2 DSH 侧（逐字读过）

- /home/t/projects/deepseek-harness 的 AGENTS.md、README.zh.md
- docs/：architecture.zh.md、cordis-primer.zh.md、capability-seams.zh.md、tool-execution-pipeline.zh.md、subsystems/{skills,extensions,commands,permission-presets}.zh.md、user/develop/basic/{index,config,publish}.zh.md、user/guide/index.zh.md
- 源码抽查：packages/core/tools/src/index.ts（guard API，704-717、1101-1114 行）、packages/context/agent-instructions/src/{files,config}.ts（AGENTS.md 自动加载机制）、packages/skill/skill-filesystem/src/index.ts（发现根与 rank）、packages/guard/、packages/hooks/README.md

### 1.3 两条显式推断（其余结论都有出处）

1. 「DSH 无项目级自动 cordis.yml，项目级自动发现的只有 skill 目录」——推断自 publish.zh.md 的层序描述，Phase 0 用 --dump-config 实测确认。
2. 「cc 的 SKILL.md frontmatter 与 DSH 兼容」——推断自 frontmatter 子集一致；**但注意下面这条是实测不是推断**：

### 1.4 本会话已实测的事实（迁移可行性的直接证据）

1. **本 DSH Web 会话工作区就是 work-wsl，AGENTS.md + CLAUDE.md 内容已自动进入我的上下文**（DSH 的 agent-instructions 插件：发现 AGENTS.md/CLAUDE.md → 注入持久上下文 → 模型读/写文件后自动刷新嵌套指令，见 packages/context/agent-instructions）。
2. **work-wsl/.agents/skills/playwright-cli 已自动出现在本会话的可用技能目录**（DSH skill 发现 rank 200 就是 .agents/skills）。即：跨 CLI 共享 skill 的机制今天已经生效，不需要做任何事。
3. 本机 DSH 服务器：pnpm dsh web 从 /home/t/projects/deepseek-harness 源码启动，home=~/.dsh，profile=web（dsh-base + dsh-web-app），Web UI 在 127.0.0.1:3080。

---

## 2. 两边的本质

### 2.1 work-wsl 的本质：三层结构，每层都有明确动机

| 层 | 组成 | 解决什么问题 |
|---|---|---|
| **约束层** | AGENTS.md（唯一入口）+ ai-docs 11 份 | 用户不懂 Java、不审查代码 → AI 行为必须被约束成"像同事随手写的、可验证、可回退"；多 AI 接力 → 文档是唯一交接媒介（AGENTS.md:86「阶段之间只靠文档交接，不靠会话记忆」） |
| **能力层** | 14 个脚本 + 2 个 skill | 每个脚本都是一次真实事故的固化（工具箱.md:82-94 逐条记录）；判据是 AGENTS.md:97-98「同一类操作做到第二遍还要翻文档 = 工具缺口」 |
| **记忆层** | 工作日志 + docs/需求/<主题>/ | 共享记忆、滚动收敛（协作规矩.md:71-73「多轮聊天必然发散，文档是收敛器」） |

关键认知：**这套工作流的价值不在文件本身，在于它把真实事故固化成约束**。迁移方案如果丢了这些约束背后的"为什么"，就是把精华丢了。

### 2.2 DSH 的本质：一切皆插件，所见皆已记录

- **无特权内核**：模型适配器、工具注册表、会话日志、agent loop 本身都是插件，都能被配置替换（architecture.zh.md:11-13）。
- **扩展 = 挂插件**：插件向 ctx 贡献服务/事件/注册，全部是可逆副作用，卸载自动清理（cordis-primer.zh.md:13）。
- **模型可见 ⟺ 已记录**：抵达模型的一切都必须能从会话日志重建（deepseek-harness/AGENTS.md:107）。会话日志是 append-only 事件流，fork/恢复/回放/遥测都从它派生（architecture.zh.md:96-100）。
- **确定性拦截管道**：工具执行走 pre-execute waterfall → 单调守卫（deny 或 abstain，无 allow，不可被排序撤销）→ 审批 → execute → post-execute（packages/core/tools/src/index.ts:704-717、tool-execution-pipeline.zh.md:10-60）。
- **组装式交付**：profile（具名组合）= bundles（组合包）逐层叠加 + 用户 patch，后层按行覆盖前层（publish.zh.md:112-120）。

### 2.3 模式差异对照表

| 维度 | 文档+skill（work-wsl 现状） | 插件+事件+日志（DSH） |
|---|---|---|
| 红线执行 | 模型读过 AGENTS.md 并遵守 | 守卫在管道里 deny，确定性、留痕 |
| 凭据保护 | 靠红线自觉 + 脚本内部不打印 | 宿主侧加载 + 路径守卫 + 结果脱敏 |
| 脚本调用 | 模型拼 bash 命令 | schema 化工具，参数枚举校验 |
| 流程阶段 | 写在 SKILL.md，靠自觉推进 | 会话事件状态机，可回放、可注入自检 |
| 规范（六段制/四要素/一行提交） | 靠自觉 | 模板工具 + guard 校验 |
| 知识按需查 | 模型记得去读索引表 | 目录自动进上下文 + 路由工具 |
| 断点续作 | 靠文档交接 | 会话日志天然回放 + goal 续跑 |
| 智力分层 | 协作规矩.md:80 的口号 | subagent/workflow 按阶段指定 provider/model |
| 用户待办 | 主文档进度块 | goal/todo/plan 状态 + 问题面板 |

---

## 3. 迁移总原则与去向判定

### 3.1 三条总原则

1. **尝试期内不动 work-wsl 一个字节**（唯一例外：写工作日志/经验教训这类本就由 AI 负责的活文档回流）。你的要求「不能删除当前文档和技能，不能影响其他 CLI 的效能」落实为：DSH 侧只**读** work-wsl，不**写**、不**删**、不**改**。
2. **文档服务"人要理解"，插件服务"机器要重复与禁止"**（AGENTS.md:99 判据的延伸）。凡是"人决策、问谁、话术、业务口径"的内容留在文档；凡是"机器该做第二遍、机器该禁止"的内容做成插件。
3. **能升级的不平移。** 平移 doc 进插件是浪费；把"靠自觉"升级成"靠机制"才是迁移的意义。

### 3.2 去向判定总表（细则见第 9 节附录）

| 去向 | 资产 | 决策要点 |
|---|---|---|
| **保留为文档（只读引用）** | AGENTS.md、CLAUDE.md、团队规矩、协作规矩、系统地图、代码库地图、本地运行手册、经验教训 | DSH 自动加载 AGENTS.md/CLAUDE.md；其余经 M1 知识路由按需取 |
| **包装为工具** | 全部 14 个脚本 + diagnose 场景命令 | M2/M7，脚本本体原地不动，工具是壳 |
| **升级为插件** | 六条红线、凭据边界、9 阶段流程、文档纪律、活文档回流 | M3/M4/M5/M6 |
| **零改写接入** | 2 个 skill + references + evals | DSH skill 注册表，customSkillDirs 直指 skills/ |
| **复用为数据** | 4 张 TSV、modules.json、platform-index、creds.env | 数据原地，消费方换成工具 |

---

## 4. 目标架构：dsh-work-wsl 组合包

### 4.1 物理布局

/home/t/projects/
├── work-wsl/                    # 【不动】文档+脚本+skill 正史
├── deepseek-harness/            # 【不动】DSH 上游 checkout（跑服务器用）
└── dsh-work-wsl/                # 【新增】本方案的全部代码
    ├── package.json             # dsh.bundle 声明
    ├── cordis.patch.yml         # 插入各插件行
    └── src/
        ├── docs/                # M1 知识路由
        ├── toolbox/             # M2 脚本工具
        ├── creds/               # M3 凭据与脱敏
        ├── guards/              # M4 红线护栏
        ├── phases/              # M5 流程状态机
        ├── conventions/         # M6 文档纪律
        ├── diagnose/            # M7 排障平台
        └── commands/            # M8 slash 命令

- **为什么独立目录**：不污染 DSH checkout（它会跟随上游 rebase/升级）；不污染 work-wsl（文档仓，没有 node 环境）；未来要私有 git 仓化只改安装来源（dsh plugin add github:...）。
- **安装方式（Phase 0 实测确认）**：dsh plugin --profile work add ./dsh-work-wsl，profile work = dsh-base + dsh-web-app + dsh-work-wsl。开发期更轻：pnpm dsh web --patch ./dsh-work-wsl/cordis.yml 直接指源码。
- **DSH checkout 本身在 Phase 0~3 不做任何修改**。若后续发现某能力需要上游配合，再单独立项（见 8.7）。

### 4.2 模块清单

#### M1 知识路由（dsh-work-wsl-docs）

- **职责**：把 AGENTS.md 的索引表（AGENTS.md:36-52）从"模型要记得去读"变成"可调用的路由"。
- **注册**：工具 work_doc，schema { topic: enum(10 个主题), query?: string }，execute 返回对应 ai-docs 文档（query 存在时只返回命中段落）。输出上限受 config maxBytes 控制（防 token 烧）。
- **为什么比现在好**：新会话模型不知道读哪份时不再猜路径；工具枚举本身就是索引。

#### M2 脚本工具（dsh-work-wsl-toolbox）

- **职责**：14 个脚本的 schema 化外壳。**脚本本体不动**，工具 execute 内部执行 bash scripts/<名>.sh ...（工作目录=config.workspacePath，默认 /home/t/projects/work-wsl）。
- **工具清单与 schema 要点**：

| 工具 | 参数（enum 化） | 备注 |
|---|---|---|
| doctor | { fetch?: bool, auth?: bool } | 30 秒开工探针 |
| fe_find / fe_api / fe_url / fe_json / fe_repo | { q: string } | 离线 TSV 秒回 |
| db_query | { sql: string, db?: enum } | 只 SELECT 白名单（见 M4） |
| es_query | { verb: enum(indices/mapping/count/head/one/search/agg/get/post), ... } | 省 token 原则固化进 schema |
| field_check | { table, field, db? } | Phase 4 数据体检 |
| api_call | { method, path, body?, env?, platform?, account? } | 401 自动重登一次（脚本自带） |
| auth_check | { action: enum(doctor/status/login), ... } | 不输出 token |
| jc_compile | { repo, files: string[] } | 长任务→后台 job |
| git_release | { action: enum(audit/manifest/check), fetch?: bool } | 只读 |
| export_template | { action: enum(validate/inspect/verify/diff/apply), file } | apply 加 confirm 双确认 |

- **输出渲染**：长文本用 terminal 意图、表格用 generic；所有 stdout 过 M3 脱敏。
- **为什么比现在好**：今天模型拼 bash scripts/fe.sh find 坑口，动词/参数靠自觉；schema 把动词变 enum、参数带校验，Web UI 直接生成参数表单。同时保留 bash 工具作为逃生舱（工具不存在才手拼）。

#### M3 凭据与脱敏（dsh-work-wsl-creds）

- **职责**：把红线 2（凭据只存 creds.env、不进上下文）从自觉变成不可能。
- **实现**：
  1. apply 时宿主侧读取 creds.env（值集只驻留在插件内存，**绝不出现在任何会话事件**）；
  2. ctx.tools.guard()：read/grep/bash 的路径或 pattern 指向 ai-docs/creds.env、.auth-cache/、~/.npmrc、~/.m2/settings.xml、~/.docker/config.json、.git-credentials → deny「红线第 2 条，凭据文件不可读」；
  3. 监听 tools/post-execute：所有工具结果对照凭据值集精确匹配 + safe-output.js 同款正则（password/token/cookie/authorization）→ 替换为 [REDACTED]。**即使某命令意外打出了密码，模型也永远看不到明文**；
  4. 监听 fs/write-intent：写入目标命中凭据文件 → deny；写入 docs/、工作日志、提交信息的内容含凭据值 → deny。
- **为什么比现在好**：今天防泄漏靠「读过安全红线.md 的模型」（2026-07-20、2026-07-21 两次真实泄漏事故就是证据，安全红线.md:18-19）；脱敏器是确定性的，与模型无关。

#### M4 红线护栏（dsh-work-wsl-guards）

- **职责**：六条红线里可机械判定的部分，全部 ctx.tools.guard(exec) => string | undefined（拒绝理由直接进 tool/result，模型能读到理由并改口——比事后纠正便宜）。
- **规则表**（全部 deny + 理由）：

| # | 拦截条件 | 红线依据 |
|---|---|---|
| 1 | bash 命令含 git push、git remote 写类（add/set-url 等）、gitlab MR 创建 / gh pr create 等**远端写**操作（本地 merge、cherry-pick 是 Phase 7 合法操作，不拦） | 红线 1（远程 git 要用户当次点头） |
| 2 | git checkout <分支> -- .（把别分支文件整体写进工作区） | 安全红线.md:41-43（138 文件事故；恢复用的 git reset / clean 不拦） |
| 3 | git commit 的 message 含 scope 括号、多行正文、Co-Authored-By | 红线 6（一行提交信息） |
| 4 | 命令/参数命中 prod 库、prod K8s namespace、mvn deploy、Jenkins 构建触发 | 红线 3（生产不碰） |
| 5 | db_query 的 SQL 不是 SELECT | 安全红线.md:34-37（DB 写纪律） |

- **为什么比现在好**：红线执行从"读过文档的模型"变成"运行时确定性拦截"；deny 理由是给模型的纠正信号，模型会当场改口。这正是 DSH 相对传统 CLI 最本质的优势（传统 CLI 只能事后审查）。
- 红线 4（同事分支只读）和红线 5（核实不猜）是**认知纪律**，留在文档（AGENTS.md 自动加载已覆盖），不强行机械化。

#### M5 流程状态机（dsh-work-wsl-phases）

- **职责**：把 enterprise-dev-workflow 的 9 阶段（SKILL.md:38-49）从"写在文档里靠自觉走"升级为"会话日志里的事实"。
- **实现**：
  1. 扩展 SessionEventMap：phase/change { phase: 1..9, note? }（模型可见 ⇒ 已记录，满足 DSH 不变量）；
  2. agent/pre-step 注入当前阶段自检清单（checklist 数据从 SKILL.md 提炼成 JSON，config 可覆盖）；
  3. 工具 phase：{ set?: 1..9, status?: true }；
  4. Web 节点渲染阶段进度条（对应主文档"进度块"，协作规矩.md:71）；
  5. Phase 1 拆解完成时建议 create_goal（一个需求一个 goal）。
- **试点期边界**：只做「记录阶段 + 注入自检 + 展示进度」，**不做强制门禁**（门禁是 Phase 5 的事，先把数据攒起来）。
- **为什么比现在好**：断点续作从"新会话按段号重读文档"变成"会话日志回放 + 阶段恢复"；用户第一眼看到进度条而不是翻文档。

#### M6 文档纪律（dsh-work-wsl-conventions）

- **职责**：六段制、头部四要素、只增不覆盖、活文档回流——从自觉变模板。
- **工具**：topic_new { 主题名 }（建 docs/需求/<主题>/ 骨架）、doc_new { 段号, 短名, 类型 }（按 doc-templates.md 生成带头部四要素的骨架）、worklog_add { 内容 }（工作日志.md 顶部插一条，自动加日期+工具代号 dsh+≤4 行校验）、lesson_add { 内容 }（经验教训.md 追加一行）。
- **Phase 3+ 可选**：conventions_check 扫主题文件夹校验命名/四要素（机器 lint，对应"无机器校验"痛点）。
- **为什么比现在好**：命名漂移（"无工具后缀=用户写的"已是现实）从源头堵住；活文档义务（AGENTS.md:88-95）从"模型记得"变"工具存在"。

#### M7 排障平台（dsh-work-wsl-diagnose）

- **职责**：diagnose-scm-project 的场景命令（trace/diagnose/compare/ownership）schema 化为工具，内部调 project.sh/platform.sh。
- **只读性 = 结构性**：这些工具**只有查询动词、没有写动词**——比文档禁令更强：模型根本拿不到写入口（对比今天的"skill 里写只读边界"，SKILL.md:25-29）。
- **输出**：按 evidence-rules.md 的模板渲染（结论/直接证据/判断/还缺的证据/下一步）。
- **为什么比现在好**：「症状驱动，先跑命令别先猜」（工具箱.md:48）变成「症状 → 工具 schema」；安全边界从 skill 文本变成 API 形状。

#### M8 slash 命令（dsh-work-wsl-commands）

- **职责**：给用户的一键入口，不经模型回合（ctx.commands，commands.zh.md）。
- /doctor（跑 doctor.sh --fetch，结果直接渲染）、/diag <场景>、/doc <主题>。
- **为什么比现在好**：用户自己也能 30 秒拿到环境状态，不用等模型。

#### M9（Phase 4 可选）UI 节点

- 环境状态卡：session 创建时后台 job 跑 doctor.sh，结果进上下文 + UI 卡（自动化 AGENTS.md:38「刚接手先跑 doctor.sh」）。
- 护栏驳回卡：deny 结果渲染为醒目卡片 + 纠正建议。

### 4.3 一条完整需求在 DSH 里怎么走（端到端）

以历史需求「驾驶舱取值」回放为例：

1. 用户：粘贴需求原文 → 模型进 plan mode 做拆解（逐条翻译表 + 样板对照表，SKILL.md:55-63），样板路径用工具实查。
2. 模糊点 → 模型用模板生成话术清单（≤7 个，问谁+逐字话术+反问应答表）→ ask_user_question 面板/主文档展示 → 用户拿去问人。
3. 答案带回 → 口径写回 → 模型 phase set 3。
4. 开工侦察：doctor + 需求字段 field_check（填充率<50% 红灯），结果留痕。
5. 开发：topic_new + doc_new 骨架 → 照样板写码 → 建表 SQL 入 sql/ → jc_compile（后台 job）。
6. 提交：guard 校验一行 message → 推远端被 guard 拦截 → 模型向用户要点头 → 用户同意后放行（试点期人工放行，Phase 5 可接 ask_user_question）。
7. 部署：api_call 链路验证（add→list→detail→update→delete）→ 用户点 Jenkins → 对账（数量/幂等/空值率/编码域，SKILL.md:166-173）。
8. 收尾：worklog_add 一条 + 主文档进度块由模板生成 + 交接话术。

### 4.4 用户的新习惯（只增不减）

| 现在 | 迁移后 |
|---|---|
| 三 CLI 接力，断点靠读文档 | 一个 DSH 会话一个需求，goal 续跑 |
| 主文档进度块靠模型自觉更新 | 阶段进度条（phase 事件投影） |
| 红线靠模型自觉 | 被拦了模型会主动来问你要授权 |
| 攒清单/点 Jenkins/问同事 | **完全不变** |

---

## 5. 与 cc / codex / oc 的共存

1. **work-wsl 零改动**：DSH 侧只读引用 skills/、scripts/、ai-docs/、docs/需求/。唯一写入是 AI 本就负责的活文档（工作日志等），且经由 M6 工具、格式与现在完全一致。
2. **skill 双端共享**：cc 经 .claude/skills 加载器、codex 经 agents/openai.yaml、DSH 经 customSkillDirs——同一份正史，三个消费者，互不干扰（本会话已实测 .agents/skills 被 DSH 发现）。
3. **脚本单源**：脚本只在 work-wsl/scripts/ 维护，M2 是壳不是副本。
4. **可选的桥（试点期不做）**：DSH 自带 hooks-claude-code / hooks-codex 桥（可让 DSH 忠实执行 cc/codex 的 hooks.json）和 subagent-claude-code / subagent-codex 提供方（DSH 可委派任务给那两 CLI）。反向场景才用，不折腾。
5. **回退**：dsh-work-wsl 全部代码在独立目录，整体删除即回到纯 cc/codex 时代，work-wsl 无任何残留。

---

## 6. 分阶段落地路线

| 阶段 | 做什么 | 改哪些文件 | 验收标准 | 回退 |
|---|---|---|---|---|
| **0（0.5 天）** | 零代码验证：profile work 建立、customSkillDirs 指 skills/、AGENTS.md 自动加载实测、doctor.sh 手工跑通、--dump-config 确认层序 | ~/.dsh/profiles/work/（DSH home 配置） | ①新会话技能目录出现两个 skill ②AGENTS.md 内容在上下文中 ③doctor.sh 输出正常 | 删 profile |
| **1（1~2 天）** | M2 第一批（doctor/fe/fieldcheck/dbq/esq）+ M3 脱敏 | dsh-work-wsl/src/（下同） | 完成一次真实"查任务"：比如用 DSH 会话复现一次前端页面定位+一次字段体检，输出与脚本直跑一致 | 删包 |
| **2（1~2 天）** | M4 规则 1/2/3（git 类）+ M3 路径守卫 + M6（topic_new/doc_new/worklog_add）+ M8 | 同上 | 拦截测试用例全过：push/危险 checkout/两行 commit/读 creds.env 均被 deny，理由清晰；worklog_add 产出格式与人工一致 | 删包 |
| **3（2~3 天）** | M5 状态机 + M1 路由 + goal/plan 联动 + M2 第二批（api/auth/jc/git-release/export-template） | 同上 | 回放一个历史完整需求（候选：06取值需求），对照原 cc 记录：阶段推进留痕、拆解/话术/提交/对账产出齐全，不劣于原流程 | 删包 |
| **4（2~3 天）** | M7 排障 + M9 UI 节点 + conventions_check | 同上 | 回放一个历史排障案例（候选：08jsonBUG），证据链输出符合 evidence-rules 模板 | 删包 |
| **5（持续）** | 阶段门禁、evals 扩充（evals.json 从 3 条扩到 10+，双向跑）、决定私有 git 仓化/发 bundle、评审是否需要上游 DSH 配合 | — | 稳定跑 2 周零红线事故 | — |

每个阶段结束写一份 3x-测试报告-dsh.md 进本主题文件夹（只增不覆盖）。

---

## 7. 风险与未知

| 风险 | 说明 | 对策 |
|---|---|---|
| DSH 是 pre-release | 上游 AGENTS.md 自述「首个 tagged release 前无兼容承诺，可自由重命名/重打包」（deepseek-harness/AGENTS.md:7） | 插件只依赖文档化的 seam（tools.guard/skill 目录/事件），薄壳原则；升级上游后跑一遍拦截测试用例 |
| 模型行为差异 | DeepSeek 模型在长流程、Java 代码、话术生成上的表现未知 | 试点即评测；智力分层（贵模型拆解、便宜模型执行）本就是工作流既有习惯（协作规矩.md:80），DSH 的 subagent/workflow 按阶段指定模型正好落地 |
| 当前权限设置 | 本会话 approval=never + danger-full-access（用户改的），试点期没有审批安全垫 | 试点期建议改回 ask（见 8.4），护栏正好补上"没有审批"时最危险的远程写/凭据两条 |
| token 成本 | 目录注入、文档加载会耗 token | agent-instructions 的 maxBytes 预算、M1 工具输出上限、esq 省 token 原则固化进 schema |
| Windows/WSL | 传统 CLI 有 wsl 边界吞变量/引号问题（AGENTS.md:57-62） | DSH 服务器就跑在 WSL 里，bash 工具直接在 WSL 执行，该问题不存在 |
| 凭据误入日志 | 插件自身日志、异常栈可能含凭据 | M3 脱敏覆盖工具结果；插件自身异常信息不含配置值（开发纪律） |
| 服务器重启 | 本机 DSH 是源码启动（tsx），改配置/插件需重启才能生效 | Phase 0 记录重启步骤；正式化后按 bundle 安装流程 |

---

## 8. 待确认问题（逐字，供你拍板）

1. **「一个需求 = 一个 DSH 会话 + goal」是否接受？** 主文档仍由模板工具生成（给同事/审计看），但"滚动主文档"从唯一事实源降级为投影——真正的源是会话日志。我推荐接受，这是 DSH 模式最大的效率点。
2. **插件代码位置**：/home/t/projects/dsh-work-wsl（推荐，独立目录）｜ 直接放 deepseek-harness checkout 的 packages/ 下（享受 monorepo 开发环境，但污染上游 clone）｜ 现在就建私有 git 仓。
3. **profile 名**：work（推荐）还是别的名字？home 沿用 ~/.dsh 还是另设 DSH_HOME？
4. **试点期权限**：建议改回 approval=ask（settings → 权限预设选 workspace-write）；我同时会把最危险的远程写/凭据两条做成确定性护栏，双保险。你现在的 never 保留也可以，但试点期出事的兜底就只剩护栏了。
5. **模型与 Key**：继续用本机 settings.yaml 里已配的模型，还是试点期指定模型组合（如拆解用强模型、执行用便宜模型）？
6. **回放案例**：Phase 3 用哪个历史需求（我推荐 06取值需求，数据类需求能完整走完 Phase 1~8 全链路）；Phase 4 用 08jsonBUG。
7. **DSH 上游跟进**：若 Phase 5 发现需要上游配合的能力（如某处缺事件），是否接受我以你名义在 deepseek-ai/deepseek-harness 提 issue/PR？（涉及远程 git，等你点头才动。）

---

## 9. 附录：work-wsl 资产 → DSH 去向映射总表

| 资产 | 类型 | 去向 | 决策 | 理由 |
|---|---|---|---|---|
| AGENTS.md / CLAUDE.md | 约束文档 | 保留 + 自动加载 | 不动 | 已实测自动进上下文（agent-instructions 插件） |
| ai-docs/团队规矩.md | 人决策知识 | 保留，M1 路由 | 不动 | 分支/发版/审批人是"人的接口" |
| ai-docs/协作规矩.md | 行为准则 | 保留 + 提示片段候选 | 不动 | 话术/问题分级是认知纪律 |
| ai-docs/安全红线.md | 约束细则 | 保留 + M4 机械化 | 不动 | 文档留"为什么"，guard 做"禁止" |
| ai-docs/系统地图.md / 代码库地图.md | 事实知识 | 保留，M1 路由 | 不动 | 中间件/分层事实，按需查 |
| ai-docs/本地运行手册.md | 事实知识 | 保留，M1 路由 | 不动 | 编译坑由 jc.sh 工具承载 |
| ai-docs/前端页面定位.md | 原理文档 | 保留，M1 路由 | 不动 | fe_* 工具是入口，文档讲原理 |
| ai-docs/工具箱.md | 索引 | 保留 | 不动 | M2 工具 schema 即活索引，文档同步更新 |
| ai-docs/工作日志.md / 经验教训.md | 活文档 | M6 工具写入 | 只经工具写 | 格式由工具保证，其他 CLI 继续读 |
| ai-docs/*.tsv ×4 | 数据 | 原地，fe_* 消费 | 不动 | 离线索引契约（前端页面定位.md:38） |
| ai-docs/creds.env(.example) / .auth-cache | 凭据 | M3 宿主侧加载 + 守卫 | 不动 | 单点凭据源（红线 2） |
| scripts/*.sh ×14 + lib/ + browser/ | 脚本 | M2 工具壳 + M4 守卫 | 不动 | 单源，工具是壳不是副本 |
| skills/enterprise-dev-workflow/ | skill | customSkillDirs 接入 + M5 状态机 | 不动 | 正史留 cc；DSH 零改写消费；状态机是 DSH 侧增量 |
| skills/diagnose-scm-project/ | skill | customSkillDirs 接入 + M7 工具 | 不动 | 场景命令 schema 化；只读性升级为结构性 |
| skills/*/evals.json | 数据 | Phase 5 扩充 + 双向跑 | 增（试点期只读） | 自动化验收的薄起点 |
| .claude/skills/ 加载器、settings.local.json | cc 专属 | 不动 | 不动 | 尝试期 cc 照常用 |
| .claude/worktrees/（prunable） | cc worktree | 不动 | 不动 | 已失效的历史产物，与迁移无关 |
| .agents/skills/playwright-cli | 通用 skill | DSH 原生发现（已实测） | 不动 | rank 200 自动发现 |
| .workbuddy/、.playwright/ | 其他工具配置 | 不动 | 不动 | 浏览器只读通道照旧（browser-ro.sh 工具承载） |
| docs/需求/<主题>/ | 主题文档 | M6 工具写入 + 只读 | 只经工具写 | 六段制/四要素由模板保证 |
| note/、docs/工作文档日常记录/ | 用户资料 | 只读 | 不动 | 未经用户同意不改（AGENTS.md:52） |

---

## 附：文档维护说明

- 本文件是 10 段规划文档；Phase 0 开始后，每个阶段的实测结果、命令、配置文件样本写入 20-开发交接-dsh.md（只增不覆盖）。
- 若后续发现重大事实错误需要重做方案，新开 10-迁移方案2-dsh.md 并首行声明取代关系，不改本文。
