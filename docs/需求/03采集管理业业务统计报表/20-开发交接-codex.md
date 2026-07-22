# 集采管理业务统计报表 · 查询与前端开发交接

> 日期：2026-07-22
> 工具：codex
> 当前状态：report 查询/导出和采购方案前端页面已完成本地提交与静态验证；未推送、未部署，test 新接口当前为 404。
> 下一阶段：用户推送两个提交、配置 report 索引名并点 Jenkins，随后配置菜单；AI 再完成 test 页面和 Excel 导出联调。
>
> 本文接续并取代 `20-开发交接-cc.md` 中“阶段三：report + 前端”部分；FP 写入、历史补数和定时入口仍以原文为准。

## 一、交付结果

这次把页面从错误的 `scm-vue-all-productmgt` 迁到了同事指定的 `scm-vue-all-procurementscheme`。菜单只负责告诉浏览器跳到哪里，页面是否能打开仍由前端路由决定，因此代码里新增了固定路由：

```text
/reportForms/centralizedProcurement
```

它必须写在通用路由 `/reportForms/:purchaseRepot` 前面，否则会被通用报表页面抢先匹配。

最终菜单 URL：

```text
/procurementScheme/index.html#/reportForms/centralizedProcurement
```

## 二、本地提交

| 仓库 | 分支 | 本地提交 | 状态 |
|---|---|---|---|
| `01zhaocai-end/scm-report-all` | `feature/jicai-report-yang` | `9130a66 feat: 增加集采统计报表查询` | 干净，未推送 |
| `02zhaocai-front/scm-vue-all-procurementscheme` | `features/jicai-report-yang` | `c019cc0e feat: 增加集采统计报表` | 需求代码已提交，未推送 |
| `02zhaocai-front/scm-vue-all-productmgt` | `features/jicai-report-yang` | 无 | 错误页面和路由已撤销，仓库干净 |

正确前端仓库的 `public/statics/config.js` 另有一处既有本地敏感配置变化，已原样保留并排除在提交之外。

## 三、后端改动

都在 `scm-report-all/scm-report-source`：

| 文件 | 内容 |
|---|---|
| `model/CentralizedProcurementReportMetaModel.java` | 新增 ES 只读模型，18 个公共字段与写入侧一致，`createIndex=false` |
| `config/SourceChaseConfig.java` | 增加统一索引名读取方法 |
| `controller/SourceMetaQueryController.java` | 增加分页查询和 Excel 导出接口 |
| `service/SourceMetaQueryService.java` | 增加两个服务声明 |
| `service/impl/SourceMetaQueryServiceImpl.java` | 数据权限、4 类筛选、倒序分页、15 列导出和枚举中文转换 |

审查旧实现时修正了企业/供应商名称查询：字段使用 `ik_max_word` 分词，零间距的短语查询会漏掉合法简称；现改成“输入分出的词全部命中”，ES 实测企业简称和供应商简称均可查询，同时不存在名称返回 0 条。

## 四、前端改动

| 文件 | 内容 |
|---|---|
| `src/router/index.js` | 在动态报表路由前增加 `/reportForms/centralizedProcurement` 固定路由 |
| `src/views/reportForms/centralizedProcurementReport/index.vue` | 新增查询、重置、分页、15 列表格和导出页面 |

查询条件：采购企业、所属板块、公示/下单时间、供应商名称。所属板块复用现有字典接口；前端向 report 接口发送 `buCode` 和北京时间当天起止的毫秒时间戳。

## 五、已完成验证

- `npm run build`：通过；仅有项目原有的 CSS 顺序和包体积告警。
- 后端隔离 `javac`：本需求模型、控制器和服务均生成 class；全量 81 个源码仅 `SourceCockpitQueryServiceImpl.java:368` 有既有 SNAPSHOT 依赖漂移错误，与本需求无关。
- 进入 `origin/test` 前的 `merge-tree` 模拟：两个仓库均无冲突；report 相对 test 只带本需求 5 个文件，前端只带本需求 2 个文件。
- 采集同步接口：用 2099 年空窗口实调，返回成功、写入 0 条，没有改动现有 ES 数据。
- ES：18 个字段 mapping 正常，现有 5 条 FP 数据；企业简称、供应商简称、板块、来源、日期范围和倒序分页 DSL 均验证通过。
- test report 新分页和导出接口：当前均为真实 404，符合“代码尚未部署”的现状。

完整结果见 `30-测试报告-codex.md`。

## 六、用户需要一次完成的外部操作

1. 推送 `scm-report-all` 的 `feature/jicai-report-yang` 和 `scm-vue-all-procurementscheme` 的 `features/jicai-report-yang`，按团队流程合入 test。AI 没有操作远程。
2. report 的 test 配置中，在 `commonConfigs.source.settings` 与 `tradeDataMateIndex` 同级增加：

   ```yaml
   centralizedProcurementReportIndex: index_centralized_procurement_report_test
   ```

   test 有代码默认值，但 uat/prod 必须配置各自索引名，不能沿用 `_test`。
3. 点 Jenkins 构建并部署 report 后端和采购方案前端。
4. 在菜单管理的“我的工作台（企业端）-报表查询”下新增“集采管理业务统计报表”，URL 填：

   ```text
   /procurementScheme/index.html#/reportForms/centralizedProcurement
   ```

5. 完成后通知 AI，继续验证真实分页响应、数据权限、查询组合、Excel 文件和页面交互。

给菜单配置同事的逐字话术：

> 麻烦在“我的工作台（企业端）-报表查询”下面新增菜单“集采管理业务统计报表”，URL 配 `/procurementScheme/index.html#/reportForms/centralizedProcurement`，菜单和岗位权限照同级现有报表配置。配置好后把可见岗位告诉我，我这边做联调验收。
