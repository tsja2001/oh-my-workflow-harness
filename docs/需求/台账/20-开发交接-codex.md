# 集采日金额统计台账 · 开发交接

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：组织机构搜索已在新分支恢复并推送，未合并 `test`
> 下一阶段：等待用户提供新的修改需求，直接在 `jcrje-ledger-yangzhuoran` 继续开发

## 1. 本次改了什么

撤销上一次对 `queryOrgForSelect` 的删除，恢复集采执行单位和采购企业共用的组织机构搜索功能。传入空关键字返回全部组织，传入关键字按组织名称模糊查询。

| 文件（仓库内路径） | 修改 | 用途 |
|---|---|---|
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/controller/CollectionDailyAmountLedgerController.java` | 恢复 | 恢复 `queryOrgForSelect` HTTP 路由和入口方法 |
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/service/CollectionDailyAmountLedgerService.java` | 恢复 | 恢复组织查询服务声明 |
| `scm-source-source/src/main/java/com/pcitc/scm/source/source/service/impl/CollectionDailyAmountLedgerServiceImpl.java` | 恢复 | 恢复 UBM 组织查询实现、Feign 注入和依赖 |

## 2. 分支与提交

- 仓库：`01zhaocai-end/scm-source-all`
- 基线：远程 `test` 提交 `0ada19d59f36962b31df9132a55f861c15657c21`
- 开发分支：`jcrje-ledger-yangzhuoran`（已推送远程）
- 恢复提交：`73ffeea3ebd3957fc3f00f170d414f351d4e89dc`
- `test` 状态：本次未合并，等待下一步需求完成后再统一合入
- 回退本次恢复：在该开发分支上执行 `git revert 73ffeea3e`

## 3. 数据库/配置动作

无。本次没有改表、SQL、字典或菜单配置。

## 4. 编译验证证据

- 用 Maven 离线生成 `scm-source-source` 的真实依赖 classpath。
- 用 `javac -encoding UTF-8` 隔离编译台账 DTO、Model、Mapper、流水号、Service、ServiceImpl、Controller 共 7 个 Java 类。
- 编译退出码为 0，生成 7 个 `.class` 文件。
- 恢复后的三个文件与原功能合入提交 `6b362576c` 逐字一致。
- 未运行接口测试；本次分支未部署。

## 5. 遗留与风险

- 当前远程 `test` 仍不包含 `queryOrgForSelect`；只有开发分支 `jcrje-ledger-yangzhuoran` 已恢复。
- 下一步需求完成前不要点 Jenkins 期待恢复功能生效，因为 Jenkins 构建 `test` 时仍会拉取未恢复的 `test`。
