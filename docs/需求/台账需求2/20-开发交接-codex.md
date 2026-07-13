# 台账需求2 · 开发交接

> 日期：2026-07-10 ｜ 工具：codex ｜ 状态：台账后端、test 数据库和导出配置保留；驾驶舱实时接线已从 `feature/taizhang-yang` 撤回并合入远程 test
> 下一阶段：用户点 Jenkins；部署后测试 AI 按 `21-接口文档-codex.md` 验证台账管理接口，驾驶舱联动留到下一版本

> **最新变更覆盖说明：** `feature/taizhang-yang` 提交 `d4eb7d21b` 精确撤回 `3992bf54e`，并通过 merge `03a3117fe` 进入远程 `test`；`2f33fa77f` 不动。以下原开发记录中关于驾驶舱实时读取新台账的描述已失效，仅作为历史留存。

## 1. 本次改了什么

**改动简报（给用户）：** 在寻源 source 服务保留“煤炭重点坑口日指标台账”的分页查询、录入即发布、修改、逻辑删除、详情和 Excel 导出。驾驶舱原接口地址仍在，但本版本不读取新台账，继续走原有缓存查询路径；其他驾驶舱逻辑未改。

| 文件（仓库内路径） | 新增/修改 | 干什么用 | 证据/样板 |
|---|---|---|---|
| `scm-source-source-api/.../dto/CoalPitDailyIndicatorDTO.java` | 新增 | 页面、导出和接口统一字段，含坑口1~5平铺字段 | 台账1 DTO 样板；隔离编译通过 |
| `scm-source-source/.../model/CoalPitDailyIndicator.java` | 新增 | 台账主表实体、发布和审计字段 | test DDL `sc_coal_pit_daily_indicator` 已反查 |
| `scm-source-source/.../model/CoalPitDailyIndicatorItem.java` | 新增 | 每个坑口一行的明细实体 | test DDL `sc_coal_pit_daily_indicator_item` 已反查 |
| `scm-source-source/.../repositories/CoalPitDailyIndicator*Mapper.java` | 新增 2 个 | 主表、明细表 CRUD | MyBatis-Plus `BaseMapper` 样板 |
| `scm-source-source/.../seq/CoalPitDailyIndicatorCodeSequence.java` | 新增 | 生成 `JCKK-yyyyMMdd-NNN` 流水号 | 台账1 `CollectionDailyLedgerCodeSequence` |
| `scm-source-source/.../service/CoalPitDailyIndicatorService.java` | 新增 | 声明管理接口和驾驶舱查询 | 本需求服务契约 |
| `scm-source-source/.../service/impl/CoalPitDailyIndicatorServiceImpl.java` | 新增 | 分页、主子表事务、校验、防越权、最新记录转换 | 查询 `:60-85`；新增 `:88-103`；修改 `:106-138`；驾驶舱 `:172-198` |
| `scm-source-source/.../controller/CoalPitDailyIndicatorController.java` | 新增 | 5 个 HTTP 接口和统一导出入口 | 路由 `:30-68` |
| `scm-source-source/.../service/impl/SourceCollectionDataServiceImpl.java` | 修改 | `kengk` 直接走新台账实时查询 | 专属路由 `:46-50`，委托实现 `:88-89` |

关键保护：新增和修改由服务器填写发布时间/操作人；修改不能覆盖流水号、发布日期、创建信息和删除标记；主表与明细写入放在同一事务里，任一步失败都会整体回滚。

## 2. 分支与提交

- 仓库：`01zhaocai-end/scm-source-all`
- 基线：`origin/prod` 的 `8eef3668f`
- 长期 feature：`feature/taizhang-yang`（已推远端）
- 台账主体：`1f11538d2 feat(source): 新增煤炭重点坑口日指标台账`
- 共享驾驶舱改动：`3992bf54e feat(source): 驾驶舱坑口指标改为实时查询台账`
- 合入 test：`fcfbfd9ff Merge branch 'feature/taizhang-yang' into 'test'`（已推远端）
- 撤回提交：`d4eb7d21b revert(source): 撤回驾驶舱坑口指标实时查询台账`（已推送 `feature/taizhang-yang`）
- 撤回合入 test：`03a3117fe Merge branch 'feature/taizhang-yang' into 'test'`（已推送）
- 本地撤回前备份：`backup/test-before-revert-3992-20260710`（**禁止推送**）
- 合入前备份分支：`backup/taizhang-test-before-merge-20260710`
- 代码回退：在 test 执行 `git revert -m 1 fcfbfd9ff` 后正常推送；不 force push。业务表可暂留，不影响旧代码。

## 3. 数据库/配置动作（发版时交负责人重放）

| 动作 | 存档位置 | test 执行结果 | 生产处理 |
|---|---|---|---|
| 建主表和明细表 | `sql/01-create-coal-pit-daily-indicator.sql` | 已执行；`SHOW CREATE TABLE` 与脚本一致 | 必须在目标 `scm_source` 库执行 |
| 配 14 列导出模板 | `sql/02-export-template.sql` | 已在 `scm_ubm_test` 执行并反查 14 列启用 | 必须在目标 UBM 库执行 |
| 旧 5 条价格转 test 演示数据 | `sql/03-test-demo-kengk-data.sql` | 已执行；主表 1 条、明细 5 条 | **禁止生产执行** |

test 演示记录：流水号 `JCKK-20251208-001`，单位明确标成“水泥北分（测试）”，缺失的日期和操作人使用测试值。旧 `sc_collection_data` 数据没有删除，但新代码不会读取它。

## 4. 编译验证证据

- 一级 `mvn -pl scm-source-source-api,scm-source-source -am compile -DskipTests`：本需求 API 模块已成功；随后在无关老文件 `scm-source-scheme/.../SchemeServiceImpl.java` 因私服 DTO 版本漂移失败。
- 二级 `mvn -pl scm-source-source-api,scm-source-source compile -DskipTests`：API 模块成功；业务模块在无关旧文件 `SourceCollectionServiceImpl.java`、`SourceEnrollServiceImpl.java` 因兄弟模块/私服类缺失失败。
- 三级：用 Maven 真实依赖 classpath，`javac -source 8 -target 8` 隔离编译本需求全部新增文件、`SourceCollectionData` 和共享服务修改；feature 与 test 合并态各跑一次，退出码均为 0，test 合并态生成 15 个 `.class`。
- 开发中首次编译发现 prod API 模块没有 Fastjson 注解依赖，已删除多余 `JSONField` 用法，没有为了一个日期格式额外改 POM；修复后本需求文件零错误。

## 5. 遗留与风险

- 代码尚未 Jenkins 部署，因此本轮没有声称 HTTP 接口已跑通；部署后必须按接口文档独立测试。
- 新管理页面由前端同事开发；菜单和岗位权限由张雨配置，后端不硬编码。
- 当前 `ai-docs/creds.env` 的 TOKEN 为空时，运行态测试需要用户从浏览器 F12 刷新。
- 驾驶舱联动已延期到下一版本；当前本地撤回态继续走原有 `sc_collection_data` 缓存查询，不验证新台账联动。
