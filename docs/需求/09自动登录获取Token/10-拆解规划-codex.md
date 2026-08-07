# 自动登录获取 Token · 任务拆解计划文档

> 日期：2026-08-04
> 工具：codex
> 当前状态：test/UAT 双账号、双平台自动登录与接口调用均已实现并实测通过。
> 下一阶段：日常直接使用 `scripts/api.sh`；账号密码或验证码规则变化时再维护 `creds.env`/登录适配层。

> **本文档的定位**：整合并取代本需求之前的零散讨论记录，是后续唯一主文档。原始敏感笔记只作只读证据，不再传播。

## ⭐ 执行进度

**已完成：**

1. ✅ 方案定型为“脚本发动机 + skill/AGENTS 使用规范”，不是只写说明书（`scripts/auth.sh`、`scripts/lib/scm-auth.sh`）。
2. ✅ `scripts/api.sh` 保持旧命令兼容，并支持 test/UAT、招采/云采、管理员/供应商。
3. ✅ 稳定账号迁入 `ai-docs/creds.env`；运行 token 进入 `ai-docs/.auth-cache/`，权限分别为目录 700、文件 600，均不进 Git。
4. ✅ 四种登录组合、八种跨平台接口组合、真实过期 JWT 自动重登、坏缓存恢复、prod 拦截全部通过（见 `30-测试报告-codex.md`）。
5. ✅ `AGENTS.md`、活文档和 `enterprise-dev-workflow` 已改为默认自动登录流程。

**需要你做的：** 当前没有。以后只有账号密码变更或测试环境重新启用真实验证码时，才需要你提供新信息。

**今天做不到的：** prod 按需求明确不配置；脚本也做了硬拦截，避免 AI 误触生产。

---

# 第一部分：写给你看的

## 1. 这个需求到底做了什么

以前每次 token 过期，都像门禁卡失效后要你亲自去前台补卡。现在增加了一个“自动门禁员”：AI 调接口前自己检查卡，没卡就登录领卡，卡失效就重新领一次；你不再反复打开浏览器复制 token。

## 2. 产品需求逐条翻译

| 产品原话 | 大白话翻译 | 谁来做 |
|---|---|---|
| 自动登录获取 token | 用稳定账号密码调用统一登录接口，取回临时通行证 | 公用脚本 |
| test/UAT 都要支持 | 命令明确选择环境，不能把 token 串环境 | 公用脚本 + `creds.env` 配置 |
| 招采/云采 token 可复用 | 同一环境、同一账号只登录一次，两个网关共用一枚 token | 公用脚本 |
| 管理员和供应商账号 | 按测试场景选择身份，缓存互相隔离 | 公用脚本 |
| 不再手动粘 TOKEN | 正常流程只维护稳定账号密码，临时 token 自动缓存 | 公用脚本 |
| prod 暂不配置 | 代码层明确拒绝 prod，不靠“大家记得别用” | 公用脚本 |
| skill 还是脚本 | 脚本负责真正执行，skill/AGENTS 负责让每个 AI 都知道怎么用 | 脚本 + 工作流文档 |

## 3. 为什么不是纯 skill，也不是浏览器自动化

| 选择 | 结论 | 原因 |
|---|---|---|
| 只写 skill | 不采用 | skill 是说明书，不能替所有 shell 调用安全地保存和刷新 token |
| Playwright 模拟页面登录 | 不采用 | 登录接口可直接调用，浏览器方案更慢、更脆，还会处理 Cookie/页面状态 |
| 每次 API 都重新登录 | 不采用 | 会制造登录日志、浪费请求，也可能让旧 token 失效 |
| `auth.sh` + 公共库 + `api.sh` | 采用 | 逻辑集中、可复用、能做并发锁和失败重试，旧命令也不变 |
| 同步更新 skill/AGENTS | 采用 | 让新 session 和不同 AI 自动走同一条正确路径 |

## 4. 系统里现成的样板

| 这次要做的 | 已核实样板 | 参考内容 |
|---|---|---|
| 密码包装 | `02zhaocai-front/scm-vue-all/scm-vue-compnents/scm-request/index.js:275` | 前 6 位随机字符 + Base64 密码 + 后 5 位随机字符 |
| 服务端拆密码 | `01zhaocai-end/scm-auth-all/scm-auth/src/main/java/com/pcitc/scm/auth/service/impl/OAuth2AuthenBuilder.java:38` | 去掉盐后 Base64 解码，证明脚本算法不是猜的 |
| 统一登录接口 | `01zhaocai-end/scm-auth-all/scm-auth-support/src/main/java/com/pcitc/scm/auth/controller/LoginController.java:475` | `authUnity` 接收账号、包装密码和验证码字段并签发 token |
| 失效 token 错误 | `01zhaocai-end/scm-cloud-dependencies/scm-cloud-dependencies-user/src/main/java/com/pcitc/scm/web/user/impl/UserResolverServiceImpl.java:61` | 项目会返回 `ERROR_JWT_INVALIDITY`，API 脚本据此触发重登 |
| 原接口工具 | `scripts/api.sh` | 保留 `METHOD PATH [BODY]` 旧调用形态，在内部接自动登录 |

## 5. 关键链路

```text
AI 调 api.sh
  ├─ 读取 test/UAT + 招采/云采 + 管理员/供应商
  ├─ 公共登录库检查对应 token 缓存
  │    ├─ 有效：直接复用
  │    └─ 缺失/过期：加文件锁 → authUnity 登录 → 原子写缓存
  ├─ 带 token 请求业务接口
  └─ 若返回明确鉴权失效码：加锁重登 → 只重试一次 → 原样返回业务响应
```

文件锁相当于“只允许一个 AI 去补门禁卡”：多个 AI 同时发现过期时，第一个负责登录，后面的复用新 token，避免登录风暴。

## 6. 需要确认的事

当前没有阻塞问题。需求给出的环境、账号、验证码规则和 prod 边界都已用真实接口核验。

未来只有两种变化需要重新确认：测试环境启用真实验证码；prod 要正式纳入自动化。这两项都不能自动猜。

## 7. 你的日常用法

```bash
# 看四种账号环境是否配置好，不显示任何秘密
bash scripts/auth.sh doctor

# 老命令继续可用：默认 test + 招采 + 管理员
bash scripts/api.sh POST /e/business/source/xxx '{"a":1}'

# UAT 云采管理员
bash scripts/api.sh --env uat --platform cloud --account admin GET /c/business/xxx

# test 招采供应商
bash scripts/api.sh --env test --platform procurement --account supplier POST /e/business/xxx '{}'
```

---

# 第二部分：给执行开发 AI 的技术计划与最终落点

## 0. 总体纪律

1. 不打印、不 `cat`、不记录密码/token/Cookie；严禁 `bash -x` 跑任何会 source `creds.env` 的脚本。
2. prod 当前必须拒绝；不可通过随便传 URL 绕过环境白名单。
3. 鉴权失败最多自动重试一次，第二次结果原样交给调用者，不能死循环。
4. 不修改公司代码仓；本功能只改顶层公用工具、规范和文档。

## 1. 改动落点

| 文件 | 作用 |
|---|---|
| `scripts/lib/scm-auth.sh` | 环境/账号解析、密码包装、登录、缓存、并发锁、刷新 |
| `scripts/auth.sh` | 给人和 AI 用的 `doctor/status/login` 管理入口，永不输出 token |
| `scripts/api.sh` | 业务调用入口，兼容旧参数并支持自动重登一次 |
| `ai-docs/creds.env` | 稳定账号与四个网关；gitignored，权限 600 |
| `ai-docs/.auth-cache/` | 四份运行 token 缓存；gitignored，目录 700、文件 600 |
| `.gitignore` | 忽略 token 缓存和含敏感内容的原始需求笔记 |
| `AGENTS.md` / 活文档 / skill references | 让所有 AI 默认走自动登录 |

## 2. 配置键（只列名称，不列值）

| 类型 | 配置键 |
|---|---|
| 管理员 | `SCM_ADMIN_USER`、`SCM_ADMIN_PASS` |
| 供应商 | `SCM_SUPPLIER_USER`、`SCM_SUPPLIER_PASS` |
| test 网关 | `SCM_TEST_PROCURE_GATEWAY`、`SCM_TEST_CLOUD_GATEWAY` |
| UAT 网关 | `SCM_UAT_PROCURE_GATEWAY`、`SCM_UAT_CLOUD_GATEWAY` |
| 旧流程兼容 | `TOKEN`、`UAT_TOKEN`（只兜底，不再要求手工刷新） |

## 3. 自行拍板记录

| 决定 | 理由 | 猜错的返工代价 |
|---|---|---|
| 默认 `test + procurement + admin` | 完全兼容现有 `api.sh` 用法，绝大多数后端接口测试也是管理员场景 | 低，只改默认参数 |
| token 不回写 `creds.env`，单独放缓存 | 稳定配置和短期运行态分离，避免脚本并发改人维护的文件 | 低，缓存目录可重建 |
| 不保存 refresh token | 稳定账号可直接重新登录，少存一份高敏感凭据 | 低，未来确需降低登录次数再扩展 |
| 登录固定走同环境招采网关 | 已实测同环境 token 可跨招采/云采复用，入口更少、更稳定 | 低，环境差异出现时调整网关映射 |
| 识别四类失效信号后只重试一次 | 覆盖 HTTP 401、`900301` 和项目 JWT 错误，同时避免权限不足时循环登录 | 低，错误码变化时加白名单 |
| prod 硬拦截 | 用户明确暂不配置，属于高风险环境 | 低，未来书面确认后显式新增 |

## 4. 验收标准

1. `bash -n` 三个脚本零错误。
2. 四种 `环境 × 账号` 登录均成功且不输出 token。
3. 八种 `环境 × 平台 × 账号` 只读请求均返回业务成功码。
4. 真实失效 JWT 能自动登录并重试成功；坏缓存不会直接污染网关调用。
5. 老命令不加新参数仍能成功。
6. prod 返回明确拒绝且不发网络请求。
7. Git diff 和文档中不存在新增密码、token、Cookie。
