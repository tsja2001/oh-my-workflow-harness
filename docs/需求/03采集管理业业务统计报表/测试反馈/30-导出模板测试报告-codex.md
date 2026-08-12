# 集采管理业务统计报表 · 导出模板测试报告

> 日期：2026-08-12
> 工具：codex
> 当前状态：test 环境导出模板链路验证通过，未发现业务缺陷。
> 下一步：用户可继续走 test 验收；准备上 UAT 时携带前后端两个提交，UAT 模板已提前配置。

## 1. 环境

- 环境：test 招采平台。
- 后端开发提交：`01zhaocai-end/scm-report-all@09dcc57`。
- 前端开发提交：`02zhaocai-front/scm-vue-all-procurementscheme@5629c0e0`。
- 页面：`/procurementScheme/index.html#/reportForms/centralizedProcurement`。
- 测试账号：供应商账号，自动登录成功且拥有报表数据权限；admin 接口成功但因数据权限返回 0 条。
- 导出模板：`centralized-procurement-export`，test 库回查为 1 条启用主模板、15 条启用字段、0 条无效字段。

## 2. 用例执行表

| # | 用例 | 请求/操作 | 关键结果 | 判定 |
|---|---|---|---|---|
| 1 | 确认后端新版本生效 | 分页查询 `centralizedProcurementPageList`，每页 3 条 | 返回新增字段 `bookTimeStr=2026-08-11 16:23`、`isCentralizedDesc=是`、`dataSourceDesc=云采平台` | 通过 |
| 2 | 确认前端新版本生效 | 检查 test 实际加载的 `chunk-14350ce4.c4c4acc7.js` | 新模板编码出现 1 次，旧路径 `centralizedProcurementDownload` 出现 0 次 | 通过 |
| 3 | 页面导出请求 | 页面点击“导出”并读取请求 | POST 分页接口，携带 `exportRequest=true`、`exportFileName=集采管理业务统计报表`、`exportTemplateCode=centralized-procurement-export` | 通过 |
| 4 | 全量模板导出 | 同页面请求体调用分页接口导出 | HTTP 200，`application/octet-stream`，文件为 Microsoft Excel 2007+，大小 51,281 字节 | 通过 |
| 5 | 全量数量对账 | 无筛选分页查询与 Excel 数据行数比较 | 接口 `totalCount=608`，Excel 数据 608 行 | 通过 |
| 6 | 表头与结构 | 解包检查 Excel 工作表 | 15 列表头与原导出顺序完全一致；609 行（1 表头+608 数据），每行均 15 个单元格 | 通过 |
| 7 | 序号 | 检查 Excel A 列 | 1～608 连续，0 条异常 | 通过 |
| 8 | 时间格式 | 检查“公示/下单时间”列 | 所有非空值均符合 `yyyy-MM-dd HH:mm`，0 条异常 | 通过 |
| 9 | 中文转换 | 检查“是否集采”和“数据来源”列 | 是否集采：是 569、否 14、空 25；来源：云采 45、招采 11、机电 15、煤炭 503、非平台 34，均为中文展示值 | 通过 |
| 10 | 筛选导出 | 页面选择“云采平台”后导出，并用同请求实际下载 | 请求模型携带 `dataSource=YC`；列表 45 条，Excel 45 条，且 45 条来源全部为“云采平台” | 通过 |

Excel 表头实测顺序：

```text
序号、板块名称、采购企业、供应商、采购方案/订单编号、业务名称、物料编码、物料描述、类目编码、类目描述、交易金额（含税）、公示/下单时间、是否集采、采购业务类型、数据来源
```

首行数据与分页接口逐字段一致，包括金额 `39858.54`、时间 `2026-08-11 16:23`、是否集采“是”和数据来源“云采平台”。

## 3. Bug 清单

未发现本次导出模板改造相关 bug。

## 4. 测试说明

浏览器自动化工具本身会以 `ERR_BLOCKED_BY_CLIENT.Inspector` 阻止该页面的 POST 请求，因此浏览器步骤用于验证 test 静态包、选择项和点击后生成的真实请求体；随后把完全相同的请求体通过 test 网关实际执行，成功下载并解析 Excel。该拦截只发生在测试工具的 Inspector 会话，不是 test 页面或接口报错。

本次测试只读页面、接口、模板配置和报表数据，没有修改业务数据。
