# 集采管理业务统计报表 · 导出模板改造交接

> 日期：2026-08-12
> 工具：codex
> 当前状态：前后端改造已在本地分支提交，test/uat 导出模板已创建并回查通过；代码尚未推送、部署。
> 下一步：前后端分支合入 test 并部署后，实际下载 Excel 验证 15 列内容。

## 1. 本次改了什么

导出已从“单独接口里用 Java 写死表头和字段”切换为平台导出模板：前端携带模板编码调用原分页查询接口，后端分页接口声明模板编码，平台按 UBM 模板生成 Excel。原有 15 列顺序和名称不变，`是否集采`、`数据来源`、`公示/下单时间`仍输出原来的中文展示值和时间格式。

模板编码为 `centralized-procurement-export`，分组为 `source / 寻源模块`。该分组已在 test、uat 的同类集采/非平台导出模板中回查确认。

| 仓库/文件 | 改动 |
|---|---|
| `01zhaocai-end/scm-report-all/.../SourceMetaQueryController.java` | 分页接口绑定模板编码，移除原手写 Excel 下载接口 |
| `01zhaocai-end/scm-report-all/.../CentralizedProcurementReportMetaModel.java` | 增加 3 个导出展示字段 |
| `01zhaocai-end/scm-report-all/.../SourceMetaQueryService.java` | 移除原手写导出服务声明 |
| `01zhaocai-end/scm-report-all/.../SourceMetaQueryServiceImpl.java` | 列表结果补齐时间、是否集采、数据来源的导出展示值；移除手写表头和 EasyExcel 行组装 |
| `02zhaocai-front/scm-vue-all-procurementscheme/.../centralizedProcurementReport/index.vue` | 导出改调分页接口，并传 `exportRequest`、`exportFileName`、`exportTemplateCode` |

## 2. 分支与提交

| 仓库 | 分支 | 本地提交 | 状态 |
|---|---|---|---|
| `01zhaocai-end/scm-report-all` | `fix/jicai-export-yang` | `09dcc57 fix: 集采统计报表改用模板导出` | 基于 `origin/test`，领先 1 个提交，未推送 |
| `02zhaocai-front/scm-vue-all-procurementscheme` | `fix/jicai-export-yang` | `5629c0e0 fix: 集采统计报表改用模板导出` | 基于 `origin/test`，领先 1 个提交，未推送 |

## 3. 数据库配置

| 环境 | 数据库 | 模板 ID | SQL | 执行结果 |
|---|---|---|---|---|
| test | `scm_ubm_test` | `2087449952601423873` | `docs/需求/03采集管理业业务统计报表/sql/01-test-导出模板.sql` | 1 条启用主模板、15 条启用字段，无重复 |
| uat | `scm_ubm_uat` | `2087450011992768513` | `docs/需求/03采集管理业业务统计报表/sql/02-uat-导出模板.sql` | 1 条启用主模板、15 条启用字段，无重复 |

主子表字段按同环境真实页面模板配置：19 位 Snowflake ID，状态 `1`，逻辑删除 `0`，版本 `1`，校验开关 `false`，审计字段与现有同类模板一致。test 和 uat 使用不同 ID。

15 列依次为：`INDEX`（序号）、板块名称、采购企业、供应商、采购方案/订单编号、业务名称、物料编码、物料描述、类目编码、类目描述、交易金额（含税）、公示/下单时间、是否集采、采购业务类型、数据来源。

## 4. 验证结果

- 后端：`mvn -pl scm-report-source -am -DskipTests compile`，`BUILD SUCCESS`，77 个 source 源文件编译通过。
- 前端：`npm run build`，构建成功；只有项目原有 CSS 顺序和包体积告警。
- 数据库：test/uat 均回查到 1 个启用主模板、15 个启用字段、0 个无效字段，字段顺序一致。
- 静态检查：两个代码仓 `git diff --check` 均无问题；旧下载路径已从前端和 report 后端移除。

## 5. 部署与风险

- 未执行 push、MR、Jenkins 或任何生产操作；prod 未创建模板。
- 后端新版本已移除旧下载接口，前端新版本才会调用模板导出接口，前后端应同批部署；如果只能分开，先部署前端，再尽快部署后端。
- 实际 Excel 下载需等 test 部署后验收，重点检查 15 列、查询条件、中文来源、是否集采和时间格式。

回退代码可分别 revert `09dcc57`、`5629c0e0`。模板需要回退时，在对应环境将 `centralized-procurement-export` 的主表和明细表 `delete_sign` 置为 `1`，不要物理删除。
