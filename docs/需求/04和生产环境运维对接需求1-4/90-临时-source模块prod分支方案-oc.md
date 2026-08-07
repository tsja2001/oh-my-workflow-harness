# Source 模块 Prod 分支方案（集采四页面）

> 日期：2026-08-06  
> 工具：OpenCode  
> 当前状态：✅ prod 交付分支 `feature/jicai-taizhang-prod-yang` 已本地准备好：基于 `origin/prod@557b29c19`，cherry-pick uat 台账提交（本地新提交 `4081f2122`），内容与 uat 完全一致（24 文件），隔离编译 0 报错，尚未推送。  
> 下一阶段：用户推送分支 → GitLab 提 MR（源 `feature/jicai-taizhang-prod-yang`，目标 `prod`）→ 指派宇 兰/运维审批 → 合并后点 `scm-source-all-prod`。

## 1. 先回答：为什么"不能从 uat 合并到 prod"

不是代码冲突问题，而是**权限与流程问题**。证据：

1. source 仓库 `prod` 分支的所有合并提交都是"宇 兰"（LANYU）通过 GitLab MR 完成的，格式统一为 `Merge branch 'xxx' into 'prod'`（例：`8eef3668f` 2026-07-02、`0a99a66ab` 2026-06-25、`557b29c19` 2026-08-04）。
2. 你（杨卓然）对 `test` 有直接合并权限（例：8-06 你自己合了 `feature/jicai-portal-yang` 进 test），但对 `uat`/`prod` 没有直接 push 权限——你的台账代码进 uat 也是通过 MR（`be490ec24 Merge branch 'uat-taizhang-yang' into 'uat'`，宇 兰 操作）。
3. 所以"不能从 uat 合并到 prod"的准确含义是：**你自己不能直接在本地/远程执行 prod 的合并推送，必须准备分支提 MR，由宇 兰（或运维）审批合并**。order 模块是同事自己负责，他直接操作，所以你不用管。

技术上也验证过：`uat→prod` 内容合并**无任何冲突**（`git merge-tree` 输出干净）。

## 2. 现状核对（2026-08-06 实查）

| 项 | 值 |
|---|---|
| 台账代码所在分支 | `origin/uat`（提交 `7b105a8e7 feat(source): 增加台账功能`，含日金额/坑口/价格趋势全部 24 文件，价格趋势已是 V3 RequestBody 版） |
| uat 相对 prod 的内容差异 | 仅台账功能（24 个新增文件 + pom 1 处），无其他未上线的业务代码 |
| prod 相对 uat 的差异 | 仅 `features/bbmgbip`、`features/pushDealToHTLY` 两个 feature 的 prod 合并提交（uat 上也有同内容合并，只是提交不同） |
| test 相对 uat | 多 1198 个提交（含其他需求），**禁止** test→uat/prod 整分支合并 |
| prod 合并人 | 全部为"宇 兰"（GitLab MR） |
| Jenkins prod 任务 | 有 `scm-source-all-prod`（发 jar，`GIT_BRANCH=prod`，`1.0.0-JDSN-PROD-SNAPSHOT`）；**没有** `scm-source-web-prod`（生产部署由运维负责） |
| 价格趋势 V3 修复 | 已包含在 uat 的 `7b105a8e7` 中（Controller 已是 `@RequestBody` 版本），不需要额外带 `a8045d94b` |

## 3. 方案

### 方案 A：直接从 uat 提 MR 到 prod（最简单，历史常态）

1. GitLab 打开 `scm-zc/scm-web/scm-source-all` → 新建合并请求。
2. 源分支 `uat`，目标分支 `prod`。
3. MR 差异会显示台账功能 24 文件（无冲突），但提交列表里会带出 `pushDealToHTLY`、`bbmgbip` 的 uat 合并提交（内容 prod 已有，只是历史不同，不影响上线）。
4. 指派宇 兰 审批合并。

### 方案 B：干净的 prod 单提交分支（推荐，MR 最干净）

理由：`7b105a8e7` 是 UAT 合入用的单提交，已在 UAT 验收通过，把它原样迁到 prod 交付分支，MR 只显示 1 个提交、24 个文件。

1. 从 `origin/prod` 拉分支：`git checkout -b feature/jicai-taizhang-prod-yang origin/prod`
2. `git cherry-pick 7b105a8e7`（已验证在 prod 上干净应用、无冲突）
3. 隔离编译验证（`bash scripts/jc.sh`）
4. 用户推送远程 → GitLab 提 MR（源 `feature/jicai-taizhang-prod-yang`，目标 `prod`）→ 指派宇 兰/运维审批
5. 合并后：点 Jenkins `scm-source-all-prod` 发 jar；生产服务部署交运维（无 web-prod 任务）

### 方案 C：等宇 兰 直接帮你合

直接问同事：

> source 的台账代码已经在 uat（MR !1145 已合）。我没有 prod 分支权限，是你在 GitLab 从 uat 直接帮我合到 prod，还是我准备一个干净的 prod 交付分支提 MR 给你？你更希望哪种？

## 4. 合入 prod 后

1. Jenkins 发 jar：`scm-source-all-prod`（分支 prod）。
2. 生产服务部署：运维操作（当前没有 `scm-source-web-prod` 任务）。
3. 生产配置：按 `90-临时-生产集采四页面配置交付清单-codex.md` 执行（SQL、导出模板、菜单、任务 240），其中 source 相关 = 4 张表 + 3 个导出模板（日金额 9 列、坑口 14 列、价格趋势 9 列）+ 3 个 Controller 接口。
4. 四页面生产验收：日金额、坑口、价格趋势（source 侧）+ 日计划（order 侧，同事负责）。

## 5. 边界与红线

- 不执行 `test → prod` 或 `test → uat` 整分支合并。
- 不直接 push `prod`/`uat`（无权限，且是受保护分支）。
- 不操作 Jenkins 构建、不操作生产部署（只能看，不点 build）。
- 临时 worktree 验证已清理，未留下任何本地改动。

## 6. 交付依据

- `git merge-tree --write-tree origin/prod origin/uat`：无冲突。
- worktree 模拟：`origin/prod` 上 cherry-pick `7b105a8e7` 干净应用（24 文件，无冲突）。
- uat/prod 提交差异：`origin/uat --not origin/prod` = 4 提交（台账 MR + 2 个 feature 的 uat 合并），`origin/prod --not origin/uat` = 2 提交（同 2 个 feature 的 prod 合并）。
- Jenkins 任务清单：`90-临时-配置部署平台索引-codex.md` §2.2。
- 生产配置清单：`90-临时-生产集采四页面配置交付清单-codex.md`。

## 7. 上生产前全量验证记录（2026-08-06，OpenCode）

交付分支 `feature/jicai-taizhang-prod-yang@4081f2122` 逐项核查全部通过：

| # | 验证项 | 方法 | 结果 |
|---|--------|------|------|
| 1 | 分支基线正确 | `HEAD` = `origin/prod@557b29c19` 的直系子提交，merge-base = prod | ✓ |
| 2 | 改动范围无夹带 | 相对 prod 仅 24 个文件：23 新增 Java + 1 pom 修改，全部在台账 3 个模块内 | ✓ |
| 3 | 与 uat 测过内容 100% 一致 | `git diff origin/uat HEAD -- 台账3模块` 为空 | ✓ |
| 4 | uat 后续无遗漏修复 | `7b105a8e7..origin/uat` 无台账文件提交 | ✓ |
| 5 | 价格趋势 V3 删除修复已含 | Controller 为 `@RequestBody` 版，与 V3 提交 `a8045d94b` 逐字一致 | ✓ |
| 6 | test 上的修复无遗漏 | `CollectionDailyAmountLedgerServiceImpl`（组织下拉修复 5a54c009b）test=uat 一致 | ✓ |
| 7 | 接口路径齐全 | 三个 Controller 共 16 个 `/e/business/source/...` 端点，与前端调用一一对应 | ✓ |
| 8 | 导出模板编码正确 | `collection-daily-ledger-export`、`coal-pit-daily-export`、`priceTrend` 与生产配置清单一致 | ✓ |
| 9 | 实体与建表 SQL 字段匹配 | 4 张表实体字段（驼峰→下划线）与 SQL 列双向比对：24/16/12/19 全部一致 | ✓ |
| 10 | 序列号不依赖外部配置 | 流水号由代码内 `IDGeneratorConfig` 动态注册（JCRJE/JCKK），与现有 FPT/LS 同机制 | ✓ |
| 11 | pom 改动安全 | 仅加 `fastjson` 依赖（父 pom 管理版本），DTO 使用 `JSONField` 注解 | ✓ |
| 12 | 隔离编译 | `scripts/jc.sh` 全部目标文件 0 报错 | ✓ |
| 13 | 工作区终态 | 干净，仅 1 个本地提交，未推送 | ✓ |

补充说明（F1 排查结论）：test 分支上 7 月以来的台账相关提交（驾驶舱接入、组织下拉修复等）要么已包含在 uat 的整理提交里，要么属于需求 06 驾驶舱（`PriceTrendCockpitProvider` 等不在本次 24 文件内），不进入本次 prod 交付。
