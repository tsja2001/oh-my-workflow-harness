# 集采业务管理报表和取值 · UAT 代码评审报告

> 日期：2026-08-11  
> 工具：codex  
> 当前状态：4 个 `jicai-uat-yang` 交付分支的差异、编译结果和关键口径已复核；搬运范围干净，但完整需求仍有 2 个确定缺口，UAT 还有 1 个配置阻断项。  
> 下一步：本次部署可继续用于 UAT 冒烟；先补 source/report 的 UAT 索引配置，06_2 完整验收前补齐四个驾驶舱接口和“已完结月取最后一条”提交。

## 一、结论

不能直接下结论说“这几个 MR 全部逻辑都没问题”。准确结论是：

1. **MR 搬运本身没夹带**：4 个分支只包含已经进入远端 `test` 的集采业务代码；Fastjson 未提交修改、前端环境配置和依赖锁没有进入差异。
2. **03 报表 + 06 首页主体逻辑可进入 UAT 验收**：source/report/order 的改动均已隔离编译通过，procurementScheme 已生产构建通过；报表前后端字段和路径一致，06 首页口径已有 test 对账报告。
3. **06_2 不能报“完整交付”**：`centerHeader/categoryAmount/situA/doRate` 没有新的完整实现；本次只带了类目前缀修复、日计划四率公式和台账页面展示。
4. **日计划累计仍少一条已确认修复**：当前 MR 仍要求命中自然月末；用户已改口径为“已完结月取当月有数据的最后一天”，对应提交 `beab9ac09` 没进远端 `test`，所以本次按交付规则没有带入。
5. **部署生效前必须核 UAT 配置**：截至本轮已有只读实查证据，source/report 的统一 ES 索引键缺失；特别是 report 会回退到 `_test` 索引，属于阻断项。

## 二、评审对象

| 仓库 | UAT 交付分支头 | 评审提交数 | 主要内容 |
|---|---:|---:|---|
| `scm-source-all` | `2baf3e0782` | 9 | FP/ZC/MT/JD 写统一 ES、06 overview、坑口/价格趋势、类目前缀和集团率分母修复 |
| `scm-report-all` | `717c58b` | 2 | 集采报表分页、筛选和导出 |
| `scm-order-all` | `7f0788844` | 2 | 日计划四率新公式、云采同步幂等 |
| `scm-vue-all-procurementscheme` | `9aa0760a` | 3 | 集采报表页面、台账完成率/滞后率、单一路由收口 |

远端状态复核：order 的交付提交已成为 `origin/uat@5212e8275` 的直接父链；source 和 procurementScheme 由 GitLab 收口成单提交合入，但对 MR 业务文件做内容差异检查为 0。report 远端读取本轮受内网 Git 服务超时影响，本文只对已准备并编译通过的 `717c58b` 内容负责，不猜部署状态。

## 三、发现清单

| # | 文件:行 / 查询证据 | 问题描述 | 建议处理 | 严重程度 | 把握度 |
|---:|---|---|---|---|---|
| 1 | `scm-source-source/.../SourceCollectionDataServiceImpl.java:51-95` | `centerHeader/categoryAmount/situA` 仍走旧 Mapper/缓存逻辑，`queryDoRate()` 仍直接 `return null`，而且 `doRate` 没有接入分流。这四块不是新的完整 06_2 实现。 | 另开补充提交：前三块改读统一 ES，`doRate` 接 order 的 `calculateRates`；保持既有接口路径和返回结构。 | **阻塞完整 06_2 验收** | 高 |
| 2 | `scm-order-report/.../CentralPurchaseDailyStatisticsMapper.xml:71-95`；本地已确认提交 `beab9ac09` | MR 中已完结月仍用 `statistics_date = LAST_DAY(statistics_date)`。test 真实数据 2026-07 最后一条为 07-16，旧 SQL会把 7 月整月漏掉；用户后来已拍板改成“该月有数据的最后一天”。 | 把 `beab9ac09 fix: 集采日计划累计不再要求命中自然月末` 先合入 test，再单独补 UAT MR；不要在正在部署的分支上临时改。 | **阻塞日计划最终口径** | 高 |
| 3 | `20-UAT部署执行-oc.md:55-65`；report `SourceChaseConfig.java:98-100`；source `SourceChaseConfig.java:93-97` | 最后一次可核实的 UAT Nacos 结果是 source/report 两个索引键缺失。report 缺失时默认读 `index_centralized_procurement_report_test`；source 缺失时没有安全默认值。 | UAT 只补两处 `centralizedProcurementReportIndex=index_centralized_procurement_report_uat`；order 已有，不整段复制 test 配置。 | **阻塞 UAT 正确取数** | 高 |
| 4 | `CentralPurchaseDailyStatisticsMapper.xml:48-68`；只读 UAT SQL：2026 年订单商品连接后 66 行、实际 61 单 | 云采统计先把订单与商品明细连接，再用 `COUNT(*)` 数“单”。真实 UAT 已存在一单多商品，全年样本会多算 5；当前 8 月截至 08-10 恰好是 22 行/22 单，所以当前月暂未受影响。 | 无类目筛选时按 `COUNT(DISTINCT t1.order_id)`；若未来按类目统计，也要按订单去重。先在 test 对五个状态公式逐项对账后再改。 | 建议尽快修，生产前处理 | 高 |
| 5 | report `SourceMetaQueryServiceImpl.java:1691-1698` | Excel 导出固定只取前 10000 条，超过后会静默少数据。UAT 统一索引当前只读计数为 0，本轮验收暂不触发。 | 后续改成 `search_after`/scroll 分批导出，并增加“导出总数=查询总数”用例。 | 建议 | 高 |
| 6 | order `CentralPurchaseDailyStatisticsServiceImpl.java:163-173` | 滞后率严格按“响应率−执行率−完成率”计算；录入数据不自洽时可出现负数。 | 这是产品明确公式，本次不擅自夹 0；UAT 用一组不自洽数据确认页面是否接受负数表现。 | 已知业务边界 | 高 |

## 四、确认没有问题的部分

- 四率分母已统一为计划总数量，代码在 `CentralPurchaseDailyStatisticsServiceImpl.java:136-172,217-223`；完成率/滞后率已由前端卡片展示。
- 云采同步入口把日期截到当天 00:00，并按“日期 + `YC_PLATFORM`”查已有记录，重复跑不再继续新增；旧重复只取最早一条更新，不会因 `getOne` 多行而打挂。
- 集采报表页面请求 `/e/business/report/source/centralizedProcurementPageList`，导出请求 `/centralizedProcurementDownload`，与 report controller 一致；19 个字段的前后端命名一致。
- source 的 FP/ZC/MT/JD 均按稳定主键 `saveAll`，同一范围重跑会覆盖而非新增；ZC 已包含标段和供应商维度，MT 已包含业务日期，规避此前真实出现过的覆盖问题。
- 价格趋势固定返回当前月之前连续 12 个自然月，缺月返回 `null`；坑口改读最新有效台账，符合 06 已定口径。
- 06 overview 的时间窗统一为 `[起点, 查询日当天 00:00)`，金额从 2026-01-01 起，类目使用四位前缀，集团率分母使用各集团自己的平台总额；这些口径此前已有 test 真数据对账通过。
- 前端最终只新增 `/reportForms/centralizedProcurement` 这一条路由；`9aa0760a` 是为避免把 test 中 UAT 尚不存在的其他页面路由一起带入，不会减少本需求页面。

## 五、验证记录

| 验证项 | 结果 |
|---|---|
| source 13 个变更 Java 隔离编译 | 0 错误 |
| report 5 个变更 Java 隔离编译 | 0 错误 |
| order 2 个变更 Java 隔离编译 | 0 错误 |
| procurementScheme 生产构建 | Build complete；仅既有 CSS/体积告警 |
| Fastjson/环境配置/依赖锁夹带检查 | 未进入 4 个 MR |
| UAT 统一 ES 索引 | 索引存在、19 字段；2026-08-11 只读 `_count=0`，尚未补数 |
| UAT 云采订单计数抽查 | 2026 年商品连接 66 行、去重订单 61 单；2026-08 截至 08-10 为 22/22 |
| test 月末抽查 | 2026-07 最后数据日 07-16，不是自然月末 07-31；证明旧累计 SQL 会漏月 |

## 六、部署后的验收顺序

1. 先确认 source/report 两处 Nacos 索引都指向 `_uat`，否则不要测报表数字。
2. 确认 4 个服务/前端的新版本都已滚动完成，再测页面 404、接口 5xx 和空白页。
3. 创建 5 个 ES 同步任务但先保持 STOP，按 FP/ZC/MT/JD/YC 顺序做历史补数；每路重跑一次验证 ES 总数不增加。
4. 对账报表总数、五路来源分布、overview 核心金额和集团率。
5. 日计划台账只验本次已进 UAT 的四率显示/公式和幂等；完整 06_2 驾驶舱四接口、月度最后一条口径在补充 MR 后再验，不能提前打勾。

## 七、检查过的维度

- [x] 正确性：时间边界、空值、分母、累计、幂等、ES 主键、分页/导出上限
- [x] 前后端契约：接口路径、请求字段、响应字段、路由和卡片展示
- [x] 安全与交付边界：未提交 Fastjson、环境配置、依赖锁和其他 test 路由均未夹带
- [x] 影响面：共享 source/report/order 服务、统一 ES、UAT Nacos 和调度任务
- [ ] 运行验收：部署仍在进行，且 UAT ES 尚为 0；必须等配置、部署和补数完成后执行
