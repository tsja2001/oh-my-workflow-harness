# 自动登录获取 Token · 开发交接

> 日期：2026-08-04
> 工具：codex
> 当前状态：顶层公用脚本与工作流文档已实现，test/UAT 真实验证通过；未提交、未推送。
> 下一阶段：日常直接使用；若后续提交顶层文档仓，先做敏感信息扫描再本地提交，远程操作必须由用户发起。

## 1. 本次改了什么

**改动简报：** 新增了一个统一认证层，负责按环境和账号自动登录、缓存 token、并发防重；原 `api.sh` 升级为 test/UAT 和招采/云采都能调。token 失效会自动重登一次，正常情况下不再找用户复制浏览器 token。prod 在代码里明确禁止，所有公司业务代码仓均未修改。

| 文件 | 新增/修改 | 用途 |
|---|---|---|
| `scripts/lib/scm-auth.sh` | 新增 | 自动登录核心、缓存、文件锁、安全错误处理 |
| `scripts/auth.sh` | 新增 | `doctor/status/login` 管理入口 |
| `scripts/api.sh` | 修改 | 兼容旧命令，新增环境/平台/账号与自动重登 |
| `ai-docs/creds.env.example` | 修改 | 增加脱敏配置键模板 |
| `ai-docs/creds.env` | 修改（不进 Git） | 已迁入稳定账号和四网关，权限改为 600 |
| `.gitignore` | 修改 | 忽略 token 缓存和敏感原始需求笔记 |
| `AGENTS.md`、`ai-docs/工作规范与习惯.md` | 修改 | 全局默认流程切到自动登录 |
| `skills/enterprise-dev-workflow/` | 修改（独立 Git） | skill、提示词、命令手册、模板同步更新 |
| `docs/需求/09自动登录获取Token/` | 新增 | 标准需求、交接、接口和测试文档 |

## 2. 分支与提交

- 顶层文档仓：当前 `main` 脏工作区中实施，存在大量用户/其他任务改动；本次没有擅自提交，也没有远程操作。
- skill 独立仓：`main` 工作区修改，未提交、未推送。
- 公司代码仓：零修改、零提交。
- 后续回退：有正式提交后用 `git revert <该提交>`；运行 token 缓存可安全重建，不是业务数据。

## 3. 配置和运行态

| 对象 | 位置 | 状态 |
|---|---|---|
| 稳定登录账号/网关 | `ai-docs/creds.env` | 已配置，权限 600，不进 Git |
| token 缓存 | `ai-docs/.auth-cache/*.json` | 四组合均已生成，权限 600，不进 Git |
| 并发锁 | `ai-docs/.auth-cache/*.lock` | 权限 600，不进 Git |
| prod | 无配置 | 脚本硬拦截 |

## 4. 验证证据

1. `bash -n scripts/lib/scm-auth.sh scripts/auth.sh scripts/api.sh`：exit 0。
2. `bash scripts/auth.sh doctor`：test/UAT × admin/supplier 全部 credentials、gateway 为 configured。
3. 强制登录四组合：全部成功，命令输出未包含 token。
4. `getLoginSuccUrl` 八组合只读调用：全部 HTTP 200、业务 `status=true/code=000000`。
5. 旧命令形态：test 招采管理员调用通过。
6. 真实旧 JWT 返回 `ERROR_JWT_INVALIDITY` 后，`api.sh` 自动重登并重试成功。
7. 故意写入不成形缓存后，脚本拒绝坏缓存并恢复成功。
8. prod 请求：本地直接拒绝，未发网络请求。
9. `git diff --check`：通过。

这是 Bash 工具和文档改动，没有 Java 文件、新依赖或方法签名变化，按编译分级无需 Maven/javac；真实网络链路验证比 Java 编译更对应风险。当前机器未安装 `shellcheck`，已用 `bash -n`、真实请求和边界测试覆盖。

## 5. 风险与边界

- 测试环境若重新启用真实验证码，自动登录会明确失败，不能绕过；需要测试专用认证方案。
- 同一账号在别处重新登录/登出可能让缓存提前失效；`api.sh` 已按项目真实错误码自动恢复。
- 业务接口本身权限不足不会无限重试，只尝试一次后返回真实结果。
- 原始需求笔记仍含历史敏感内容，已加入 `.gitignore`；不要 force-add。
