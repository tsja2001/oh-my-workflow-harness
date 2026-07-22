# 集采管理业务统计报表（第一期：非平台录入）· 任务拆解计划文档

> 日期：2026-07-20
> 工具：codex
> 当前状态：FP 写入、历史补数和定时入口已进入 test；report 查询/导出与正确前端项目 `scm-vue-all-procurementscheme` 的页面已完成本地开发和验证，尚未推送、部署及配置菜单。
> 下一阶段：用户推送 report/front 两个本地提交并点 Jenkins；配置 report 索引名和“我的工作台（企业端）-报表查询”菜单后，AI 继续做 test 查询、导出和页面联调验收。
>
> **本文取代 `10-拆解规划-cc.md` 和 `10-拆解规划-oc.md`，作为后续唯一主规划。**
> 旧文档保留作分析过程，不再作为开发依据。

## ⭐ 执行进度

**已完成：**

1. ✅ 已吸收 `需求描述2-更新.md`：数据起算日从 **2026-07-01 改为 2026-01-01**，恢复“是否集采”“采购业务类型”两列。
2. ✅ 已吸收 `12-问题答复.md`：主键采用“采购业务编号+物料编码”；类目允许空；内部、外部供应商都统计；新报表单独建 ES、单独跑定时任务；审批结束时间暂用 `update_time`；所属板块按 `bu_code` 查 `Owningplate` 字典标准名。
3. ✅ 已重新核实非平台数据源：主表 `sc_supplier_green_channel` 已有 `is_jc`、`purchase_business_type`，明细表已有物料、类目和含税金额字段。
4. ✅ 已重新核实完整技术链路：`scm-source-all` 负责往 ES 写，`scm-report-all` 负责从 ES 查询/导出，`scm-vue-all-productmgt` 有可复用的交易数据报表页面。旧规划只写了写入侧，现已补齐。
5. ✅ 已查询 test 数据：按“审批通过 + 采购业务分类 101/102/103 + `update_time >= 2026-01-01`”只有 5 单；其中 `is_jc=1` 有 2 单、`is_jc=0` 有 3 单。当前 5 条物料的“业务编号+物料编码”都唯一且物料编码不空，但数据库本身没有非空/唯一约束。
6. ✅ 已再次检查 test ES：旧的 `index_web_trade_data_test` 和 `index_order_report_test` 都不是本需求索引；所有现有索引的 mapping 中均未出现新字段 `isCentralized`，说明同事发来的 Model 目前还是代码合同，尚未在当前 test ES 落成实际 mapping。
7. ✅ 用户确认主键不做异常兜底：直接拼“采购业务编号 + 物料编码”，不追加物料明细 ID。
8. ✅ 用户确认交易金额按物料明细取值：一行一条物料，取明细含税总金额 `total_price`，不重复使用整单金额。
9. ✅ 用户明确“是否集采”以指定详情页展示语义为准：本期非平台取其详情接口返回的 `is_jc`；采购业务类型由它派生，不再由采购业务分类反推。
10. ✅ 用户决定交付边界和 ES 交接当前暂不追问；二者从“立即待确认”降为“正式开发前核实”。
11. ✅ 已收到同事版 `CentralizedProcurementReportModel`：公共字段统一为 `id/buName/buCode/purchaseCompanyName/purchaseCompanyCode/supplierName/supplierCode/planCode/planName/materialName/materialCode/categoryName/categoryCode/taxTotal/bookTime/isCentralized/purchaseType/dataSource`，后续不再沿用旧规划里的 `documentId/businessCode/businessName/materialDesc/dealTime/isCollection/purchaseBusinessType`。
12. ✅ 已核实同项目使用 Spring Data Elasticsearch 4.3.4：`@Document` 默认允许 Repository 初始化时自动建索引和 mapping；但 **Model 只定义数据长什么样，不会自己抽数**，真正有数据仍要求某个同步接口查询业务数据并调用 Repository 的 `save/saveAll`。
13. ✅ 用户确认五类公共来源编码：`ZC` 招采平台、`FP` 非平台录入、`YC` 云采平台、`MT` 煤炭-SAP、`JD` 机电四大类；本期非平台固定写 `FP`，查询/导出层转成中文。
14. ✅ 已执行 `git fetch origin prod test`：`scm-source-all` 最新 `prod` 为 `8eef3668f`，工作区干净；当前仍停在旧台账分支 `feature/taizhang-yang`，它比 `prod` 多 1214 个历史提交，不能用于本需求。远端旧 `features/jicai` 已经合入 `prod` 且落后 93 个提交，也不能复用。
15. ✅ 用户最终确认公共主键不再讨论跨来源碰撞：严格使用 `id = planCode + materialCode`，不加 `dataSource`、分隔符或明细 ID。
16. ✅ Phase 4 开工探针通过：
    - Git：工作区干净，`origin/prod@8eef3668f` 和 `origin/test@0db2a589e` 已同步。
    - 工具链：Java `1.8.0_492`、Maven `3.6.3` 可用。
    - 代码样板：prod 上的 Model、Repository、ServiceImpl、Controller、Config 和两个绿色通道 Mapper 均存在；`scm-source-chase` 已依赖 `scm-source-source`。
    - MySQL：test 中符合口径的 5 个主单、5 条物料可正常查询，物料编码、金额、`is_jc` 和 `update_time` 均有真实样例。
    - ES：当前 test 尚无 `isCentralized` mapping；这是部署联调前置，不阻塞本地代码和隔离编译。
17. ✅ 已判定 `centralizedProcurementBusinessManagementStatistics` 不是 test 物理索引名：
    - 该字符串含大写字母，不能原样作为 ES 索引名。
    - 同事的 `@Document` 实际读取 `orderESConfig.getCentralizedProcurementReportIndex()`，说明真实索引名来自 Nacos，不是写死的该字符串。
    - 运行态按 `*centralized*/*procurement*/*statistics*` 反查均无索引，全部 mapping 也未发现 `isCentralized`。
    - 因此把它当作“业务英文标识”，不写死进 source 代码。
18. ✅ 已明确跨服务代码组织方式：
    - 双方共享的是同一套字段名和字段类型合同，不是跨仓库共用同一个 `.java` 文件。
    - 同事订单侧 Model 保留 `orderESConfig`；我方 source 侧 Model 使用 `sourceChaseConfig`，字段和类型逐项保持一致。
    - FP 由 `scm-source-all` 独立抽数和写入，不调用同事的同步接口；仍需确认同事接口负责哪些 `dataSource`，避免重复写同一来源。
19. ✅ 同事确认索引创建方式：不提前在 ES 后台手工建索引；订单侧应用部署启动后，由 Spring Data Elasticsearch 根据 `@Document`、Model 和 Repository 自动创建物理索引及 mapping，随后调用一次同步接口查询业务数据并通过 `save/saveAll` 写入首批文档。当前 test 查不到新索引与“代码尚未部署”的状态一致。
20. ✅ 跨服务协作冻结已完成：
    - test 实际物理索引名确认为 `index_centralized_procurement_report_test`。
    - `scm-order-all` 与 `scm-source-all` 是两个独立 Git 仓库，双方各自在本服务新增 Model，不会发生同一文件的 Git 合并冲突；不再要求先拿到同事分支/commit 才能开始 FP 开发。
    - 双方共享的是当前已确认的字段名、字段类型、`id = planCode + materialCode` 和同一个物理索引名；Git 不冲突不等于字段合同可以各自修改。
    - 订单侧按已确认方式先部署并自动创建索引；我方 source Model 设置 `createIndex=false`，只负责写 `FP`。
21. ✅ 已接受同事提出的分阶段顺序，并形成 `90-临时-整体分阶段开发流程-codex.md`：
    - 第一阶段只做手动小批量写 ES，并核对字段、数量和幂等。
    - 第二阶段补齐批量能力并执行历史补数。
    - 第三阶段才配置每天自动同步。
    - ES 数据可信后，再依次做 report 查询导出、前端页面和菜单权限。
22. ✅ report 查询和导出已完成本地提交：`scm-report-all` `feature/jicai-report-yang@9130a66`，读取统一 ES 索引，支持企业、供应商、板块、时间筛选和 15 列导出；读模型明确 `createIndex=false`。
23. ✅ 前端已按同事要求迁移到 `scm-vue-all-procurementscheme`：固定路由 `/reportForms/centralizedProcurement` 放在通用动态路由 `/reportForms/:purchaseRepot` 前，页面本地提交为 `features/jicai-report-yang@c019cc0e`；错误项目 `scm-vue-all-productmgt` 已恢复干净。
24. ✅ 前端 `npm run build` 通过；后端隔离编译成功生成本需求 class，全量 81 个源码只剩 1 个未改动驾驶舱类的既有依赖漂移错误。
25. ✅ test 现状已核实：采集同步接口可正常调用，ES 有 5 条 FP 数据且筛选 DSL 验证通过；report 新查询/导出接口因尚未部署均为真实 404，需部署后完成运行时验收。

**需要你做的：**

- 推送并部署 `scm-report-all`、`scm-vue-all-procurementscheme` 的本地提交；按 `20-开发交接-codex.md` 配 report 索引名和菜单。完成后告诉 AI，继续跑页面、查询和 Excel 导出验收。

**当前不能承诺的：**

- 不能把“本地构建通过”说成“test 页面已经可用”：report 和前端代码尚未部署，菜单尚未配置，当前新接口实测仍是 404。
- 不能把 `centralizedProcurementBusinessManagementStatistics` 硬编码成索引名；真实物理索引必须以部署后的 Nacos/ES 为准。
- 不能在当前 `feature/taizhang-yang` 上直接开发，也不能复用旧 `features/jicai`；二者都不是本需求的干净最新基线。

---

# 第一部分：写给你看的

## 1. 这个需求现在到底是什么

最终目标是一张汇总 5 类采购来源的“大账本”。共享的是同一个 ES 字段合同和物理索引，不是跨服务共用同一份 Java 文件：

```text
ZC 招采服务 ─┐
FP source服务 ├─ 各自的 Model + 抽数代码 ─→ 同一个 ES 索引
YC order服务 ┤                               ↓
MT 煤炭服务 ┤                       report 查询/导出
JD 机电服务 ┘                               ↓
                                           前端页面
```

ES 就像中间的“公共货架”：五个来源各有自己的“搬运工代码”，但都按同一张货品标签往同一个货架摆货。`scm-report-all` 再统一取货。**统一 Model 是标签模板，不是完整搬运程序。**

## 2. 最新需求逐条翻译

| 产品要求 | 大白话 | 谁来做 |
|---|---|---|
| 报表管理下新增《集采管理业务统计报表》 | 增加菜单和页面 | 前端 + 菜单配置 |
| 支持查询、导出 | 按 4 个条件查 ES，能下载 Excel | `scm-report-all` + 前端 |
| 第一批接非平台录入 | 从绿色通道主表和物料明细表抽数据 | `scm-source-all` |
| 数据存 ES，同事提供公共 Model | 各来源按同一套字段写入同一个索引；当前收到的是代码合同，实际索引尚待部署核验 | 同事 + 各来源后端 |
| 审批结束日期从 2026-01-01 起 | 第一次补数从 2026-01-01 00:00:00 到上线前一天 | 后端同步任务 |
| 上线后每天按审批结束时间同步前一天 | 默认任务按 `update_time` 扫昨天，不再照抄旧任务的 `create_time` | 后端 + XXL-JOB 配置 |
| 支持指定日期补跑 | 留一个手动接口/任务参数，可重跑任意日期范围 | 后端 |
| 主键=采购业务编号+物料编码 | 同一物料重复跑时覆盖自己；空值或重复也直接按拼接结果写入 | 后端；规则已确认 |
| 恢复“是否集采”“采购业务类型” | 报表从 13 列增加为 15 列 | ES mapping + 写入 + 查询 + 前端 + 导出 |

## 3. 12 答复与需求描述 2 的合并结果

| 主题 | 最终采用的当前结论 | 状态 |
|---|---|---|
| 数据起算日 | **2026-01-01**；这是后出的需求描述 2，覆盖 12 第 6 条里的旧日期 2026-07-01 | ✅ 已定 |
| 数据范围 | `approve_status=101` 且 `purchase_business_type IN ('101','102','103')` | ✅ 需求原文已定 |
| 供应商范围 | 内部、外部供应商全量统计；不加旧交易报表的 `is_inner=1` | ✅ 已定 |
| 增量时间 | `sc_supplier_green_channel.update_time` 暂作为审批结束时间 | ✅ 已定，有已知边界 |
| 定时策略 | 首次补历史；上线后每天同步昨天；允许指定日期补跑；不改旧交易报表 | ✅ 已定 |
| ES 关系 | 新建独立索引，不碰 `index_web_trade_data_test` | ✅ 已定 |
| 主键正常规则 | 采购业务编号 + 物料编码 | ✅ 已定 |
| 主键异常规则 | 不做空值/重复兜底，不追加物料明细 ID，按拼接结果直接写 ES | ✅ 用户已定 |
| 类目为空 | 允许空着展示 | ✅ 已定 |
| 所属板块 | 查询传 `bu_code`；展示名按 `Owningplate` 字典标准名写入 ES | ✅ 已定 |
| 是否集采/采购业务类型 | 本期非平台取 `is_jc`；是→集团集采，否→分散采购；采购业务分类只负责筛选数据范围 | ✅ 用户已定 |
| 金额 | 每个物料取该明细自己的含税总金额 `total_price`，不重复使用整单 `total_amount` | ✅ 用户已定 |

## 4. 代码和数据库已经证明的业务事实

### 4.1 “是否集采”按指定页面语义落到各来源自己的后端字段

- 用户指定的《供应商参与企业业务统计表》链路已经核实：
  1. `/aggregation_supplier` 做供应商维度汇总；
  2. `/pageList_supplier` 返回明细及 `schemeId`；
  3. 前端用 `schemeId` 打开采购方案详情并调用 `/e/business/source/scheme/getSchemeDetail`；
  4. 详情页“是否集采”展示 `dataObj.isCollection`，后端实际读取 `sc_scheme.is_collection`。
- 代码证据：
  - `scm-report-source/SourceMetaQueryController.java:46-58,90-101`
  - `scm-report-source/SupplierMetaModel.java:75-77`
  - `scm-vue-all-procurementscheme/src/views/reportForms/showTable.vue` 的 `clickLink`
  - `procurementSourcingProcessMgt/procurementSchemeInfo.vue:96`
  - `SchemeServiceImpl.java:1200-1233`
  - `Scheme.java:524-526`
- 但本期来源是“非平台录入”。`sc_supplier_green_channel` 没有 `scheme_id`，符合本期条件的 5 单按业务编号也都匹配不到 `sc_scheme`，因此不能拿非平台记录去调用采购方案详情。
- 非平台自己的详情链路已经提供同一业务含义：
  - `/e/business/source/greenChannel/getGreenChannelDetail?channelId=...`
  - 页面 `supplier/detail/index.vue:19` 直接展示 `baseInfo.isJc`
  - 后端 `SupplierGreenChannelServiceImpl.getGreenChannelDetail` 从 `sc_supplier_green_channel` 查询并复制返回
  - 对应字段为 `sc_supplier_green_channel.is_jc`，1 是、0 否

因此按用户指定的页面展示逻辑落地：**招采平台来源用 `sc_scheme.is_collection`；本期非平台来源用 `sc_supplier_green_channel.is_jc`。** 采购业务分类 101/102/103 只负责筛选哪些业务进入报表，不负责改写“是否集采”。

### 4.2 一行报表就是一条物料

- 主表：`sc_supplier_green_channel`，一单一行。
- 明细表：`sc_supplier_channel_projects`，一单可有多条物料，以 `channel_id` 关联。
- 现有详情页“合作项目”逐行展示：
  - 物料编码 `productCode`
  - 物料描述 `productDesc`
  - 类目 `categoryCode/categoryName`
  - 含税总金额 `totalPrice`
  - 证据：`supplier/detail/index.vue:126-141`

因此本报表必须把一单展开成 N 条物料记录，不能把主表总金额复制 N 次。

### 4.3 完整开发实际跨 3 个仓库

| 责任 | 仓库/模块 | 已核实样板 |
|---|---|---|
| 从 MySQL 抽数、写 ES、定时任务、补跑接口 | `01zhaocai-end/scm-source-all/scm-source-chase` | `TradeDataReportServiceImpl.syncGreenChannelData`、`TradeDataReportModel`、`TradeDataReportController` |
| 从 ES 查询、分页、导出 | `01zhaocai-end/scm-report-all/scm-report-source` | `origin/prod` 的 `TradeDataMetaModel`、`SourceMetaQueryController:226-272`、`SourceMetaQueryServiceImpl:1494-1613` |
| 页面、筛选、表格、下载 | `02zhaocai-front/scm-vue-all-productmgt` | `views/reportMgt/nbxtTransactionDataReport/index.vue` |
| 菜单岗位权限 | 管理页面 | 找张雨配置 |
| 每天自动执行 | XXL-JOB 管理页面 | 需要同事/用户配置任务 |

旧规划把查询接口也放进了 `scm-source-all`。从现有交易报表的真实最终代码看，这不符合当前分工；新版按“source 写、report 读”执行。

## 5. 15 个展示列的字段映射

| 报表列 | 非平台来源 | 当前结论 |
|---|---|---|
| 序号 | 前端按当前页行号生成 | 不存 ES |
| 板块名称 | 主表 `bu_code` → `Owningplate` 字典标准名 | 写入 `buName` |
| 采购企业 | 主表 `company_name` | 写入 `purchaseCompanyName` |
| 供应商 | 主表 `supplier_name` | 写入 `supplierName` |
| 采购方案/订单编号 | 主表 `purchase_business_code` | 写入 `planCode`，不能拿拼接后的 ES 主键展示 |
| 业务名称 | 主表 `purchase_business_name` | 写入 `planName` |
| 物料编码 | 明细 `product_code` | 写入 `materialCode` |
| 物料描述 | 明细 `product_desc` | 写入 `materialName`；现有详情页显示的就是 `productDesc`，不是 `product_name` |
| 类目编码 | 明细 `category_code` | 写入 `categoryCode`，可空 |
| 类目描述 | 明细 `category_name` | 写入 `categoryName`，可空 |
| 交易金额（含税） | 明细 `total_price` | 写入 `taxTotal` |
| 公示/下单时间 | 主表 `update_time` | 写入 `bookTime`（Java `Date` / ES `date`） |
| 是否集采 | 主表 `is_jc` | 写入 `isCentralized` |
| 采购业务类型 | 由 `is_jc` 派生：是→集团集采，否→分散采购 | 写入 `purchaseType` |
| 数据来源 | 非平台录入 | 固定写 `FP`，页面/导出显示“非平台录入” |

查询还必须存但不直接展示的字段：

- `id`：ES 真正主键，固定为 `planCode + materialCode` 直接拼接，不加前缀、分隔符或其他兜底字段
- `buCode`：板块下拉精确筛选
- `purchaseCompanyCode`：公司权限过滤
- `supplierCode`：非平台主表没有独立供应商编码，本期写 `three_in_one_id_code`（统一社会信用代码）

## 6. 为什么 ES “建完”不一定等于能开工

### 6.1 当前 ES 实查

2026-07-20 使用 `scripts/esq.sh` 查询 test：

- `index_web_trade_data_test`：存在，39 条，是旧交易报表，不能改。
- `index_web_collection_meta_test*`：是已有集采元数据索引族，不是本需求确认过的新索引。
- `index_order_report_test`：存在，1110 条，是旧订单报表，字段是 `orderId/totalMoney/...`，不是本需求。
- 对全部索引反查 `isCentralized` mapping：没有任何索引包含该字段。
- 按 `*centralized*`、`*procurement*`、`*statistics*` 查索引：均为空。

结论：同事发来的是“准备部署的模型定义”，不是已在当前 test ES 生效的证据。`centralizedProcurementBusinessManagementStatistics` 作为业务英文标识保留，但不能当物理索引名写死。

### 6.2 ES 交接验收清单

同事建完后，下面各项全部满足，才叫“ES 前置完成”：

1. test 物理索引名已确认为 `index_centralized_procurement_report_test`，且是本需求独立索引。
2. 提供 `GET /<index>/_mapping` 的实际结果，不是聊天里手写字段表。
3. mapping 必须与同事版 Model 一致，`dynamic=false` 时不能让各来源自行改字段名：

| 同事已定义字段 | ES 类型 | 用途 |
|---|---|---|
| `id` | `keyword` / ES `_id` | 隐藏主键 |
| `buName` | `text`（IK） | 板块展示 |
| `buCode` | `keyword` | 板块精确筛选 |
| `purchaseCompanyName` | `text`（IK） | 采购企业查询/展示 |
| `purchaseCompanyCode` | `keyword` | 公司权限 |
| `supplierName` | `text`（IK） | 供应商查询/展示 |
| `supplierCode` | `keyword` | 供应商编码 |
| `planCode` | `keyword` | 采购方案/订单编号 |
| `planName` | `text`（IK） | 业务名称 |
| `materialName` | `text`（IK） | 物料描述 |
| `materialCode` | `keyword` | 物料编码 |
| `categoryName` | `text`（IK） | 类目描述，可空 |
| `categoryCode` | `keyword` | 类目编码，可空 |
| `taxTotal` | `double` | 含税金额 |
| `bookTime` | `date` | 时间范围、排序 |
| `isCentralized` | `integer` | 1 是、0 否 |
| `purchaseType` | `keyword` | 集团集采/分散采购 |
| `dataSource` | `keyword` | 固定存 `ZC/FP/YC/MT/JD`，查询/导出转中文 |

4. 写入服务和读取服务都指向同一个物理索引：
   - 同事订单侧：`orderESConfig.centralizedProcurementReportIndex` → `index_centralized_procurement_report_test`
   - `scm-source-all`：拟新增 `source.chase.es.centralizedProcurementReportIndex` → `index_centralized_procurement_report_test`
   - `scm-report-all`：拟新增对应读取配置
5. test 的 source 服务有写权限、report 服务有读权限；不需要把账号密码发到聊天。
6. 由一个明确负责人先创建索引并交付实际 mapping；其余服务复制相同字段合同，不能各自改类型。我们的 source Model 不能原样复制 `orderESConfig`，必须改为本服务的 `sourceChaseConfig`。
7. `id` 严格按用户最终确认的 `planCode + materialCode` 直接拼接，各来源不得自行增加前缀或兜底字段。
8. 订单侧先部署并作为索引创建方；我方 source Model 使用
   `@Document(indexName = "#{@sourceChaseConfig.getCentralizedProcurementReportIndex()}", createIndex = false, dynamic = Dynamic.FALSE)`。
   这样可以避免两个服务同时启动时争抢创建同一索引。

### 6.3 直接开发结论

| 情况 | 能否直接开发 | 原因 |
|---|---|---|
| 当前：Model、ID、来源编码和 test 索引名均已确认 | **可以开始非平台写入侧本地开发** | 双方在独立 Git 仓库开发，不共享同一 Java 文件；公共字段合同已冻结 |
| 准备部署/联调 | **等待同事先部署索引** | 部署后 AI 自动搜索 `isCentralized` mapping、识别物理索引并验收 |
| ES 已交接，但交付边界未答 | 可完成写入侧，不能承诺整页交付 | 查询/导出/前端/菜单分工不明 |
| 自动搜索仍找不到新索引 | 只在此时问同事一句 | 询问 test 物理索引名和 Nacos 值 |
| 完整交付边界已答且索引验收通过 | **可以按第二部分端到端开发** | 范围、数据、ES 均收敛 |

## 7. 正式开发前再核实什么

FP 写入侧当前没有必须继续问人的开发前问题：

1. test 索引统一使用 `index_centralized_procurement_report_test`。
2. 双方在独立 Git 仓库开发各自的 Model；字段名和类型以已收到的公共 Model 为准。
3. 订单侧先创建索引；我方 source Model 使用相同字段、`sourceChaseConfig` 和 `createIndex=false`。
4. 我方只写 `FP`，不调用或修改同事的同步接口。
5. 若以后要求我们继续做查询、导出和前端，再单独确认完整交付边界。

## 8. 你接下来的行动顺序

1. 阶段一：AI 从 `scm-source-all` 最新 `prod` 新建 `feature/jicai-report-yang`，完成 Model、Repository、FP 查询转换、手动同步接口和 source 索引配置。
2. 阶段一验收：同事先部署订单侧创建索引；用户运行远程 Git 命令并点 source Jenkins；AI 用一个小日期核对 MySQL 与 ES，并重跑验证幂等。
3. 阶段二：小数据通过后补齐分批能力，执行 2026-01-01 至上线前一天的历史补数。
4. 阶段三：历史补数通过后新增并配置独立 XXL-JOB，每天同步昨天，同时保留手动日期补跑。
5. 阶段四：确认交付人后，在 `scm-report-all` 开发查询和 15 列导出，先用接口独立验收。
6. 阶段五：report 接口通过后开发前端页面，再配置菜单和岗位权限。
7. 每个阶段做隔离编译/构建、测试和本地提交；未经用户运行，不推送或操作远程分支。

---

# 第二部分：给执行开发 AI 的技术计划

## 0. 总体纪律和范围

1. 先读根 `AGENTS.md`、活文档、workflow skill、本文和最新 `12-问题答复.md`。
2. 本期业务数据范围默认只有“非平台录入”。不得顺手改旧 `TradeDataReport*` 或 `index_web_trade_data_test`。
3. 共享代码尽量不改；新报表采用独立 Model、Repository、Service、Controller 和配置项。
4. `scm-source-all` 从已同步的 `origin/prod@8eef3668f` 建长期分支 `feature/jicai-report-yang`；不复用台账需求的 `feature/taizhang-yang`，也不复用已合入 prod 的旧 `features/jicai`。
5. 不操作远程分支、不推送；用户明确发起后才可执行远程动作。
6. 新 Java 文件和跨模块引用必须隔离 javac 验证；前端必须 `npm run build`。

## 1. 开工前 Phase 4 探针

| 探针 | 验证方式 | 通过标准 |
|---|---|---|
| source 仓库基线 | `git status`、`git fetch origin prod test` | ✅ 工作区干净；最新 `origin/prod@8eef3668f` |
| MySQL | `scripts/dbq.sh` 只读查询 | ✅ 主表/物料表可查；当前 5 单、5 条物料 |
| ES | `scripts/esq.sh mapping/count/head` | ⏳ 新索引未部署；不阻塞本地开发，部署前必须验 mapping |
| Java/Maven | `java -version`、`mvn -version` | ✅ Java 8、Maven 3.6.3 |
| 代码和依赖 | `git cat-file`、prod POM | ✅ 样板与 Mapper 存在；chase 已依赖 source 模块 |
| 鉴权 | 复用现有登录鉴权结论 | ✅ 登录 token 可直接测接口；实际测试时再检查是否过期 |

## 2. 样板对照表（已核实）

| 要实现的能力 | 样板 | 参考点 |
|---|---|---|
| 非平台按日期写 ES | `scm-source-all/scm-source-chase/.../TradeDataReportServiceImpl.java:262-363` | 参数、默认昨天、查询、转换、`saveAll` |
| writer ES Model/Repository | `TradeDataReportModel.java`、`TradeDataReportRepository.java` | `@Document`、`@Id`、字段类型 |
| 手动补跑接口 | `TradeDataReportController.java:60-65` | 日期范围请求 |
| XXL-JOB AIM 方法 | `TradeDataReportService.java:8,45` | `@TypeMapping`、`@MethodMapping` |
| reader ES Model | `scm-report-all origin/prod` 的 `TradeDataMetaModel.java` | 读取侧 `@Document` 与 mapping |
| reader 分页/导出 | `scm-report-all origin/prod` 的 `SourceMetaQueryController.java:226-272`、`SourceMetaQueryServiceImpl.java:1494-1613` | 查询条件、权限过滤、分页、EasyExcel |
| 前端列表/导出 | `scm-vue-all-productmgt/src/views/reportMgt/nbxtTransactionDataReport/index.vue` | 查询表单、表格、分页、下载 |
| 板块字典接口 | `CollectionDailyAmountLedgerController.java:91-93` | `queryOwningplateDict` |
| 非平台详情字段 | `scm-vue-all-procurementscheme/src/views/supplier/detail/index.vue:19,126-141` | `isJc`、`productDesc`、`totalPrice` |

## 3. `scm-source-all`：写入侧

新增独立能力，ES Model 名和字段优先与同事合同一致：

- `CentralizedProcurementReportModel`
- `CentralizedProcurementReportRepository`
- `CentralizedProcurementReportService`
- `CentralizedProcurementReportServiceImpl`
- `CentralizedProcurementReportController`
- `SourceChaseConfig.centralizedProcurementReportIndex`

同步算法：

```sql
SELECT g.*, p.*
FROM sc_supplier_green_channel g
JOIN sc_supplier_channel_projects p ON p.channel_id = g.channel_id
WHERE g.approve_status = 101
  AND g.purchase_business_type IN ('101','102','103')
  AND g.update_time >= :startTime
  AND g.update_time <= :endTime
```

实现要求：

1. 默认无参数时取昨天 00:00:00～23:59:59.999。
2. 手动传日期时支持首次回填 `2026-01-01` 到上线前一天，也支持以后补跑任意区间。
3. 不加 `is_inner=1`。
4. 按 `channel_id` 批量取物料，避免一单查一次造成 N+1；数据量大时分批查询和 `saveAll`。
5. `buCode` 写原值，`buName` 按 `Owningplate` 标准名转换后写入。
6. ES 主键封装成单独方法，严格返回 `purchaseBusinessCode + productCode`；不加 `FP`、分隔符或 `projectsId`，不做空值/重复兜底。
7. 严格按同事字段合同赋值：业务编号/名称写 `planCode/planName`，供应商编码写 `threeInOneIdCode`，物料描述写 `materialName`，时间写 `bookTime`，集采字段写 `isCentralized/purchaseType`。
8. `dataSource` 暂按同事注释使用 `FP`；若同事确认存中文，则只改这一处常量。
9. 返回实际读取主单数、物料行数、写入数、跳过数，方便验收。
10. 不提供“删除整个索引”的生产接口；如测试确需清数据，只允许受控的日期/来源删除方案。

## 4. `scm-report-all`：读取和导出侧

若确认查询、导出也由我们交付：

1. 从 `origin/prod` 最新基线开发；本地 `dev` 分支缺少最新交易报表代码，不能拿旧 `dev` 当样板最终状态。
2. 新建独立 ES Model，对应同一个新索引配置。
3. 新增分页查询接口，四个查询条件：
   - 采购企业：`purchaseCompanyName` 文本匹配
   - 所属板块：`buCode` 精确
   - 供应商：`supplierName` 文本匹配
   - 公示/下单时间：`bookTime` 范围
4. 保留现有报表的数据权限：按 `purchaseCompanyCode` 限制可见企业。
5. `purchaseCompanyName/supplierName` 已定义为 `text`，查询使用 `match/matchPhrase`，不能照抄旧 `keyword` 字段的 wildcard 写法。
6. 默认按 `bookTime DESC` 排序。
7. 新增独立导出接口，15 列与页面一致；日期格式 `yyyy-MM-dd HH:mm:ss`，金额保留两位；`dataSource` 若存编码则在这里转中文。
8. 不复用旧交易报表 Model 和接口，避免改变现有页面。

## 5. `scm-vue-all-productmgt`：页面侧

若确认前端页面也由我们交付：

1. 以 `nbxtTransactionDataReport` 新建独立页面和路由。
2. 所属板块改为下拉框，调用现有 `queryOwningplateDict`，提交 `buCode`。
3. 查询条件只按需求保留 4 个；序号前端生成。
4. 表格显示 15 列；`isCentralized` 显示“是/否”，不直接显示 1/0。
5. `rowKey` 使用隐藏 `id`，不能使用会重复展示的 `planCode`。
6. 导出调用新报表下载接口。
7. `npm run build` 验证。

## 6. 外部配置

| 配置 | 谁做 | 必须留档 |
|---|---|---|
| ES test/prod 索引与 mapping | 同事 | 索引名、mapping JSON、环境 |
| source 写入索引配置 | Nacos 配置负责人 | 配置键和值（不含凭据） |
| report 读取索引配置 | Nacos 配置负责人 | 配置键和值（不含凭据） |
| XXL-JOB 每日任务 | 同事/用户页面配置 | handler、参数、cron、负责人 |
| 首次历史补数 | 开发 AI 调手动接口或任务 | 起止时间、写入数、跳过数 |
| 菜单/岗位权限 | 张雨 | 菜单路径、前端路由、岗位 |

## 7. 验收顺序

1. [ ] ES mapping 验收通过。
2. [ ] 手动同步一个有数据的小日期，MySQL 物料行数 = ES 成功写入数 + 明确跳过数。
3. [ ] 重跑同一区间，ES 总数不增加，证明主键幂等。
4. [ ] 首次补数从 2026-01-01 到上线前一天完成。
5. [ ] 分页按采购企业、板块编码、供应商、时间分别可筛。
6. [ ] 板块名称与 `Owningplate` 字典一致。
7. [ ] 是否集采、采购业务类型、金额抽样与 MySQL 原记录一致。
8. [ ] 导出 15 列，金额、日期、空类目显示正确。
9. [ ] 前端构建通过，页面查询和下载通过。
10. [ ] XXL-JOB 跑昨天数据，并能指定日期补跑。

## 8. 自行拍板记录

| 决定 | 理由 | 猜错返工代价 |
|---|---|---|
| 后出的 `需求描述2-更新.md` 覆盖 12 中旧的 7 月起算日，采用 2026-01-01 | 明确写了“改为”，时间顺序和措辞都无歧义 | 改一个参数，低 |
| 物料描述取 `product_desc`，不是 `product_name` | 产品指定的现有详情页“物料描述”列真实绑定 `productDesc` | 换字段，低 |
| ES 隐藏主键和展示业务编号分字段存 | 拼接主键不能直接给页面展示；同类报表已有展示单号需求 | Model/mapping 改动，中 |
| `dataSource` 只存公共来源编码，查询/导出层转中文 | 同事 Model 只有一个 `dataSource` 字段，注释已给 `ZC/FP/YC/MT/JD`；避免各来源直接写不同中文 | 改一处常量和展示转换，低 |
| 新报表不修改旧交易报表和旧定时任务 | 12 明确旧报表及历史数据不处理；新旧粒度不同 | 无 |
| 查询端放 `scm-report-all`，写入端放 `scm-source-all` | 现有交易数据最终代码就是这个分工 | 若团队另有新架构需移动，中 |

## 9. 已知边界

- `update_time` 只是当前约定的审批结束时间。审批通过后若还能修改主表，它会漂移；12 已选择沿用，本期不另查工作流表。
- 按当前 test 数据，2026-01-01 后符合主过滤的只有 5 单；页面初始数据仍可能很少，这不是同步代码自动能解决的。
- “采购业务分类”和“是否集采”在 test 已出现矛盾，不能用代码悄悄修正业务数据。
- ES 里同一个 `id` 后写覆盖前写。用户已确认不处理空物料编码或同单重复编码的异常，因此这类数据若以后出现，可能覆盖前一行；按已确认口径执行。
- 非平台主表没有独立 `supplier_code` 字段；本期 `supplierCode` 使用 `three_in_one_id_code`（统一社会信用代码）。该字段不参与当前页面筛选和展示，若公共合同以后要求平台供应商编码，可单独替换。
- 完整上线不只有 Java：两个 Nacos 配置、XXL-JOB、前端、菜单都要完成。
