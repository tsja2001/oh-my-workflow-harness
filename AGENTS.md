# AGENTS.md — 所有 AI 的总入口

任何 AI 工具（Claude Code=`cc` / Codex=`codex` / OpenCode=`oc` / 其他）接到本工作区的任务，先读完本文件再动手。

## 一句话协作模式

用户是 Node 背景开发者，不懂 Java。AI 负责**全部技术执行**（读代码、查库、写代码、编译验证、git 提交推送、curl 测试、写文档）；
用户负责**人的接口**（拿 AI 准备好的问题和话术去问产品/领导/同事、点 Jenkins 构建、找人开权限、管理页面点配置）。
对用户只说大白话；要用户去问人的，给逐字话术。完整工作流见 `skills/enterprise-dev-workflow/SKILL.md`。

**无论是当前项目的git，还是子项目的git`（01zhaocai-end/**,02zhaocai-front/**,03zhaocai-start/**）`未经用户运行，绝对不可以提交到远程，绝对不可以操作远程分支。仅允许拉取代码和本地提交，**

**Git 提交说明要像同事随手写的：只用 `feat: 简短表述` 或 `fix: 简短表述`，只写一行；禁止 `(模块)`、正文要点、完成清单和 `Co-Authored-By`，不要写得过度完整。**

## 目录地图

| 位置 | 是什么 | 谁维护 |
|---|---|---|
| `AGENTS.md` / `CLAUDE.md` | AI 入口（本文件） | AI |
| `skills/enterprise-dev-workflow/` | 完整工作流规范：需求到验证 + 代码复盘与理解交接 + 命令手册/模板/提示词（独立 git） | AI |
| `ai-docs/` | AI 自维护公用知识：`工作规范与习惯.md`（活文档，必读）、`工作日志.md`（共享记忆：所有改动的流水账）、`creds.env`（凭据，**禁止提交**） | AI |
| `scripts/` | 公用工具：`dbq.sh` 查库、`esq.sh` 查 ES、`api.sh` 调 test 接口 | AI+用户 |
| `docs/需求/<需求名>/` | 每个需求一个文件夹：需求原件 + 各阶段交接文档（命名规范见下） | AI |
| `docs/工作文档日常记录/` | 用户自己的笔记 + 同事发来的文档（AI 可读，未经用户同意不改） | 用户 |
| `note/` | 代码库结构知识（`project-ai-context.md`、`backend-env-setup.md`），查代码结构问题先看这里 | AI（主要 codex） |
| `01zhaocai-end` `02zhaocai-front` `03zhaocai-start` | 公司代码（各自独立 git 仓库，顶层 git 不管理它们） | 公司 |

## 接手任务时的阅读顺序

1. 本文件。
2. `ai-docs/工作规范与习惯.md` —— 公司规矩 + 用户习惯 + 问题分级 + 编译分级，持续更新。
3. `skills/enterprise-dev-workflow/SKILL.md` + 你所处阶段对应的 `references/prompts.md` 提示词。
4. `docs/需求/<需求名>/` 下前序阶段的交接文档（按编号从小到大读）。
5. 涉及代码库结构（哪个模块、怎么启动、依赖关系）再看 `note/project-ai-context.md`。

## 任务分级（先判断量级，再决定流程重量）

- **查任务**（找代码/查数据/答疑，只查不改）：读够背景就干，**不写**交接文档和日志。
- **复盘学习**（只读核实代码/数据，但要把理解交给用户）：按 skill Phase 9，默认不改代码/数据库，产出 `50-代码复盘与学习-<工具>.md`；不因写学习文档额外制造开发日志。
- **小改**（改几行/几个文件）：不必走完整需求流程，但收工必须在 `ai-docs/工作日志.md` 顶部追加一条（≤4 行：日期 工具｜干了什么｜分支/提交｜坑），所属需求的主文档进度块同步更新。
- **完整需求**：走 skill Phase 1～8 + 全套开发/测试交接文档 + 工作日志一条；Phase 9 理解交接按需触发。

## 阶段交接文档命名规范（强制）

多 AI 接力**只靠文档、不靠会话记忆**。位置：`docs/需求/<需求名>/`。文件名 = `编号-阶段名-工具.md`，工具代号 `cc`/`codex`/`oc`。

| 编号 | 文件名示例 | 产出者 |
|---|---|---|
| 00 | `00-需求原件/`（文件夹：产品 excel、截图） | 用户放入 |
| 10 | `10-拆解规划-cc.md`（主文档：大白话+技术方案+顶部进度块） | 拆解阶段 AI |
| 11 | `11-待确认问题-cc.md`（问题清单+逐字话术） | 拆解阶段 AI |
| 12 | `12-问题答复.md`（用户带回的答案，无工具后缀） | 用户 |
| 20 | `20-开发交接-cc.md`（改了什么/分支提交号/遗留） | 开发阶段 AI |
| 21 | `21-接口文档-cc.md`（接口清单+请求示例） | 开发阶段 AI |
| 30 | `30-测试报告-oc.md`（用例+结果+bug） | 测试阶段 AI |
| 40 | `40-评审报告-oc.md`（review 发现+建议） | 评审阶段 AI |
| 50 | `50-代码复盘与学习-codex.md`（全景+关键链路+跟读+掌握度验收） | 复盘学习 AI |
| 90 | `90-临时-<主题>-cc.md`（规范外的临时文档一律走 90 段） | 任意 |

规则：同阶段同工具重做 → **覆盖同名文件**；换工具重做 → 新文件（后缀换工具代号），并在文档开头声明"本文取代 xx 文件"。
每份交接文档头部必须有：日期、工具、当前状态一句话、下一阶段该做什么。模板见 `skills/enterprise-dev-workflow/references/doc-templates.md`。

## 凭据与安全（红线）

- 数据库、网关、token、K8s 等全部凭据只存 `ai-docs/creds.env`（已 gitignore）。**禁止**把密码/token 写进代码、提交、其他文档、聊天记录。
- 公司代码仓库纪律：新需求从 prod 拉 feature 分支；未上线功能的补丁从 test 基线拉子分支；开发完 merge --no-ff 进 test。不 force push 保护分支、不 `mvn deploy`、不动 K8s 部署。
- 分支命名**像人写的**：一个大需求只开一个长期分支，之下所有修改都用它（如台账相关 `feature/taizhang-yang`，姓氏后缀 `-yang`）；参考团队既有风格（同事惯用拼音/缩写+姓名缩写），不要一个小改动开一个新分支。
- 顶层文档 git（本仓库）随时可提交；公司代码提交前必须遵守 skill Phase 7。

## 环境要点（WSL 双模式）

- 文件在 WSL：`/home/t/projects/work-wsl`（Windows 侧 UNC：`\\wsl.localhost\ubuntu-24.04\...`）。
- **Windows 侧 AI**（桌面 app / Windows 终端）：执行命令一律 `wsl.exe -d ubuntu-24.04 -- bash /tmp/xx.sh`——
  凡是带变量、引号、循环的命令**先写成脚本文件再执行**，内联会被边界吞掉（`$VAR` 变空、引号丢失）。UNC 路径上禁止全树搜索（会超时）。
- **WSL 终端里的 AI**：直接跑 bash，无以上限制。
- 查库：`bash scripts/dbq.sh "SELECT ..." [库名]`。查 ES：`bash scripts/esq.sh indices|mapping|count|head|one|search|agg|get|post ...`（详见脚本头注释）。调 test 接口：`bash scripts/api.sh POST /e/business/... '{json}'`。
- 全量 mvn 编译是坏的（SNAPSHOT 漂移，同事也从不本地编译）；验证自己代码用隔离 javac，见 skill env-playbook 第 6 节。

## 活文档义务

发现新的公司规矩、用户习惯、失败命令的复盘、能提效的工具建议 → 当场追加到 `ai-docs/工作规范与习惯.md`（带日期和工具代号）。
学到代码库结构类的持久事实 → 更新 `note/project-ai-context.md`。不要把这些散落在聊天里。
