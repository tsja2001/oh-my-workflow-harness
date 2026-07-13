# 台账需求2 · 开发交接

> 日期：2026-07-13 ｜ 工具：codex ｜ 状态：后端、test 数据库/导出配置和前端管理页面均已完成；前端主体 `9eba1111`、输入性能修复 `3b896244` 均为本地提交且尚未推送，驾驶舱联动仍已撤回
> 下一阶段：用户明确发起推送后再推前端分支并点 Jenkins；张雨配置菜单岗位后，测试 AI 按 `21-接口文档-codex.md` 验证管理页面全链路

> **最新变更覆盖说明：** `feature/taizhang-yang` 提交 `d4eb7d21b` 精确撤回 `3992bf54e`，并通过 merge `03a3117fe` 进入远程 `test`；`2f33fa77f` 不动。以下原开发记录中关于驾驶舱实时读取新台账的描述已失效，仅作为历史留存。

## 1. 本次改了什么

**改动简报（给用户）：** “煤炭重点坑口日指标管理”现在前后端都齐了。前端新页面支持按流水号、执行单位和发布时间查询，录入/修改 1～5 组坑口价格，删除和 Excel 导出；提交前会先拦住“名称价格只填一半”和“5 组全空”。驾驶舱原接口地址仍在，但本版本不读取新台账，继续走原有缓存查询路径。

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
| `scm-source-source/.../service/impl/SourceCollectionDataServiceImpl.java` | 修改后撤回 | 曾将 `kengk` 接到新台账，最终由 `d4eb7d21b` 精确撤回 | 当前大屏仍读旧缓存 |
| `src/views/businessManagementLedgerJC/coalPitDailyIndicator/index.vue` | 前端新增 | 查询、5 组坑口列表、录入/修改弹窗、删除、导出和前端成对校验 | 参考 `dailyAmountStatisticsLedger/index.vue`；正式构建通过 |
| `src/router/index.js` | 前端修改 | 注册 `/businessManagementLedgerJC/coalPitDailyIndicator` 路由 | 本地提交 `9eba1111` |

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

前端：

- 仓库：`02zhaocai-front/scm-vue-all-procurementscheme`
- 当前分支：`prod-feature-jcmh-yangzhuoran`（用户已确认分支无问题）
- 本地提交：`9eba1111 feat(台账): 新增煤炭重点坑口日指标管理页面`
- 本地修复：`3b896244 fix(台账): 修正坑口名称输入框长度属性`
- 远程状态：**未推送，未操作远程分支**
- 回退方法：如尚未共享可在后续提交前调整；一旦共享，用 `git revert 9eba1111`，不改写公共历史。
- 用户既有改动：`public/statics/config.js` 保持未提交，未进入 `9eba1111`。

## 3. 数据库/配置动作（发版时交负责人重放）

| 动作 | 存档位置 | test 执行结果 | 生产处理 |
|---|---|---|---|
| 建主表和明细表 | `sql/01-create-coal-pit-daily-indicator.sql` | 已执行；`SHOW CREATE TABLE` 与脚本一致 | 必须在目标 `scm_source` 库执行 |
| 配 14 列导出模板 | `sql/02-export-template.sql` | 已在 `scm_ubm_test` 执行并反查 14 列启用 | 必须在目标 UBM 库执行 |
| 旧 5 条价格转 test 演示数据 | `sql/03-test-demo-kengk-data.sql` | 已执行；主表 1 条、明细 5 条 | **禁止生产执行** |

test 演示记录：流水号 `JCKK-20251208-001`，单位明确标成“水泥北分（测试）”，缺失的日期和操作人使用测试值。旧 `sc_collection_data` 数据没有删除；管理台账不读取它，当前驾驶舱仍继续读取它。

## 4. 编译验证证据

- 一级 `mvn -pl scm-source-source-api,scm-source-source -am compile -DskipTests`：本需求 API 模块已成功；随后在无关老文件 `scm-source-scheme/.../SchemeServiceImpl.java` 因私服 DTO 版本漂移失败。
- 二级 `mvn -pl scm-source-source-api,scm-source-source compile -DskipTests`：API 模块成功；业务模块在无关旧文件 `SourceCollectionServiceImpl.java`、`SourceEnrollServiceImpl.java` 因兄弟模块/私服类缺失失败。
- 三级：用 Maven 真实依赖 classpath，`javac -source 8 -target 8` 隔离编译本需求全部新增文件、`SourceCollectionData` 和共享服务修改；feature 与 test 合并态各跑一次，退出码均为 0，test 合并态生成 15 个 `.class`。
- 开发中首次编译发现 prod API 模块没有 Fastjson 注解依赖，已删除多余 `JSONField` 用法，没有为了一个日期格式额外改 POM；修复后本需求文件零错误。
- 前端在 `scm-vue-all-procurementscheme` 执行两次 `npm run build`，均 `exit 0`；只有仓库既有 CSS 顺序和包体积警告，没有本次页面编译错误。
- 输入属性修复后再次执行 `npm run build`，`exit 0`；代码库已不存在本页面的 `:maxlength` 错误写法。
- `npm run lint -- --no-fix` 无法执行：项目未安装 Vue CLI lint 插件，报 `command "lint" does not exist`，不是本次代码的 lint 报错。

## 5. 遗留与风险

- 前端提交尚未推送、未 Jenkins 部署，因此本轮没有声称页面已在 test 跑通；部署后必须按接口文档独立测试。
- 新管理页面已完成；菜单和岗位权限仍由张雨配置，后端不硬编码。菜单路由为 `/businessManagementLedgerJC/coalPitDailyIndicator`。
- 2026-07-13 只读调用分页接口返回 `访问未授权`（`900301`），说明现有 TOKEN 已过期；运行态测试前需要用户从浏览器 F12 刷新。
- 驾驶舱联动已延期到下一版本；当前本地撤回态继续走原有 `sc_collection_data` 缓存查询，不验证新台账联动。
