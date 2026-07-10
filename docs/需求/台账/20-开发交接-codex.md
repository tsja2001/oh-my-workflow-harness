# 集采日金额统计台账 · 开发交接

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：台账专用组织查询接口已删除并合并远端 `test`
> 下一阶段：按用户要求无需测试；如需让 test 运行版本生效，由用户在 Jenkins 构建 `scm-source-all` 的 `test`

## 1. 本次改了什么

台账专用的 `queryOrgForSelect` 已不再需要，本次只删除该接口的入口、服务声明、实现和专属依赖。原提交里同时增加的两个字典接口仍有用，已完整保留。

| 文件（仓库内路径） | 修改 | 用途 |
|---|---|---|
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/controller/CollectionDailyAmountLedgerController.java` | 删除 | 删除 `queryOrgForSelect` HTTP 路由和 Controller 方法 |
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/service/CollectionDailyAmountLedgerService.java` | 删除 | 删除组织查询服务声明 |
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/service/impl/CollectionDailyAmountLedgerServiceImpl.java` | 删除 | 删除实现、组织 Feign 注入及专属 import |

## 2. 分支与提交

- 仓库：`01zhaocai-end/scm-source-all`
- 开发分支：`feature/jcrje-ledger-remove-org-query`（已推送远端）
- 开发提交：`435d0f6b5fb6151dc6fc8569e8ab559fcd1a4e9d`
- `test` 合并提交：`0ada19d59f36962b31df9132a55f861c15657c21`
- 回退删除：在新的修复分支上执行 `git revert -m 1 0ada19d59`，再按团队流程合入 `test`

## 3. 数据库/配置动作

无。本次没有改表、SQL、字典或菜单配置。

## 4. 验证证据

- 按用户明确要求，未运行编译和接口测试。
- `git diff --check` 通过。
- 合并前模拟 `merge --no-commit --no-ff` 无冲突，只有 3 个目标文件、43 行删除。
- 全库 Java 源码引用检查中已无 `queryOrgForSelect`。
- 两个仍需要的字典接口 `queryCategoryDict` / `queryOwningplateDict` 的 Controller、Service 和 ServiceImpl 链路均保留。

## 5. 遗留与风险

- 前端不能再调用 `/gateway/e/business/source/collectionDailyAmountLedger/queryOrgForSelect`，应按同事最新方案复用现有组织接口。
- 现有组织接口的具体路径不在本次任务信息内，本次不猜测、不改前端。
