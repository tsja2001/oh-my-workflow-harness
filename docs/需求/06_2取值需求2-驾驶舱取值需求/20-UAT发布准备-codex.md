# 驾驶舱取值需求 · UAT 发布准备

> 日期：2026-08-14
> 工具：codex
> 当前状态：已完成代码、UAT 配置、ES、接口和定时任务的只读核查；结论是只需发布 `scm-source-all` 两个提交，不新增表、字典、菜单、前端或任务。
> 下一步：取得用户当次 `fetch` 授权后，从最新 `origin/uat` 准备需求专属 UAT 交付分支；用户推送、提 MR、合并并点 Jenkins 后，再按本文第六节验收。

> 本文在“UAT 发布范围”上取代 `20-开发交接-cc.md` 的单提交说明。取代原因：test 联调后又补了提交 `26a5c4e38`，UAT 必须和 `d9f68dd74` 一起带上；原开发原理、口径和回退说明仍以旧交接为准。

## 一、结论

这次传 UAT，环境侧**不用新增任何东西**：

- 不建表、不跑业务 SQL；
- 不新增或修改数据字典；
- 不新增菜单、岗位权限、前端路由或前端构建；
- 不新增 Nacos 配置值；
- 不新增、启停或手动执行定时任务；
- 不配置导出模板。

真正要做的是：从最新 UAT 基线准备一个只包含本需求的 `scm-source-all` 交付分支，按顺序带上两个提交，然后发布 `scm-source` 后端并验四个接口。

唯一尚未通过 Nacos 页面直接读到的证据是 `scm.feign.order.web` 键本身：只读登录失败。代码明确复用这个既有前缀，不要求新增值；正式交付前只确认 UAT 已有该键，**不要把 test 的地址复制到 UAT**。

## 二、发布范围冻结

### 2.1 必须带入 UAT 的代码

仓库：`01zhaocai-end/scm-source-all`

开发基线：`a73ebcae5`

候选头：`feature/jicai-cockpit2-yang@26a5c4e386a9`

提交顺序：

1. `d9f68dd74 feat: 集采管理驾驶舱四个取值接口改为实时计算`
2. `26a5c4e38 feat: 处理驾驶舱跳转`

第二个提交是 test 部署后的联调修正，实际改的是 source 调 order 时的 token 传递方式。不能只按旧交接搬第一个提交。

净变更只有 6 个 Java 文件：

- 新增 `CockpitCollectionProviderImpl.java`
- 新增 `CockpitCollectionProvider.java`
- 新增 `CentralPurchaseFeignConfig.java`
- 新增 `CentralPurchaseFeignService.java`
- 新增 `CentralPurchaseRateDTO.java`
- 修改 `SourceCollectionDataServiceImpl.java`

没有 YAML、properties、POM、SQL、Mapper XML、依赖锁、前端配置或构建产物。

本地已用缓存的 `origin/uat@2cf37e7b8` 做过临时 worktree 预演：两个提交按顺序可无冲突应用，净差异仍只有上述 6 个文件。这个 UAT 引用最后更新时间是 2026-08-12，正式建分支前仍必须在用户当次授权后 `fetch` 并重跑检查。

### 2.2 不需要跟着发的仓库/提交

| 对象 | 结论 | 证据 |
|---|---|---|
| `scm-vue-all-cockpit` | 不发前端 | 本地缓存的 `origin/test` 与 `origin/uat` 最终 `src` 树无差异；类目和右上三格都是按接口数组映射，不依赖 `category1` 或 `1001` 的固定值 |
| `scm-order-all` | 本次不发 | UAT 已有等价提交 `c3e97840e`（四率公式）和 `7f0788844`（云采日计划同步幂等）；UAT `calculateRates` 已能返回本次所需全部字段 |
| `scm-vue-all-procurementscheme` | 本次驾驶舱发布不需要 | 驾驶舱只读取 order 后端接口；不依赖台账维护页本身重新发布 |
| `beab9ac09` | 明确排除 | “累计取每月最后有数据日”尚未进入 test/UAT；test 当前验收值 `planQuantity=10508` 也没有使用它，不能未经 test 冻结越级带到 UAT |
| `sql/20-test清理云采重复数据备份-cc.sql` | 严禁在 UAT 执行 | 文件头明确是 `scm_order_test` 的 2026-08-04 重复数据备份，里面是 test 原始 ID 和流水号，不是 UAT 发布脚本 |

### 2.3 正式 UAT 分支做法

1. 用户明确同意本次远程只读 `fetch` 后，刷新 `scm-source-all` 的 `origin/uat`。
2. 从最新 `origin/uat` 建需求专属分支，建议名：`jicai-cockpit-uat-yang`。
3. 按冻结顺序搬 `d9f68dd74`、`26a5c4e38`，不能整条 `test → uat` 合并。
4. 隔离编译并执行：

   ```bash
   bash scripts/git-release.sh check 01zhaocai-end/scm-source-all uat jicai-cockpit-uat-yang
   ```

5. 用户推送分支，在 GitLab 提 MR 到 `uat`，审核人兰宇；不 squash 更容易保留两步来源。

## 三、配置与数据准备核查

| 类别 | 是否要处理 | 已核实事实 | 发布动作 |
|---|---|---|---|
| MySQL 表/DDL | 否 | 两个提交只改 Java；驾驶舱金额读既有 ES，计划数量/四率读既有 order 接口 | 不执行 SQL |
| 业务初始化数据 | 否 | UAT ES 已有 160 条，order 接口已有计划数据 | 不造演示数据 |
| `collectionShow` 字典 | 否 | 新代码在 `SourceCollectionDataServiceImpl.queryCollectionData()` 中对四个 typeCode 提前返回，绕过旧字典/缓存；test 已实调生效 | 旧字典行保留原样，不改 0/1、不删除 |
| 其他字典 | 否 | 本次七类编码和三执行单位由代码固定口径生成，没有新增下拉框 | 不配置 |
| 菜单/岗位权限 | 否 | 是既有驾驶舱页面和既有四个 GET 接口，没有新页面、新路由或新菜单 | 不找张雨补菜单 |
| 前端静态资源 | 否 | cockpit 的 test/UAT 源码最终树一致；接口路径和返回数组结构不变 | 不点前端 Jenkins |
| 导出模板 | 否 | 本需求没有导出能力 | 不配置模板 |
| ES 索引 | 否 | `index_centralized_procurement_report_uat` 存在且有 160 条；UAT 既有 overview 接口可从该索引正常汇总 | 不建索引、不重同步 |
| Nacos：ES 索引 | 否 | UAT overview 接口返回 2026-08-13 的真实汇总，证明 source 已能读 UAT 统一货架；新 Provider 复用同一模型和 RestTemplate | 不新增/复制索引配置 |
| Nacos：order Feign | 不新增，只核键 | `CentralPurchaseFeignConfig.java:19-48` 明确复用 `scm.feign.order.web`；UAT order 目标接口可用，但本次 Nacos 只读登录失败，未直接看到键 | MR 前只确认 `scm-source-web-uat.yaml` 中该键已存在，不改值 |
| XXL-JOB | 否 | UAT 六个依赖任务都已配置、启用，并在 2026-08-14 最近一轮执行成功 | 不新增、不手动补跑 |

## 四、UAT 定时任务实查

驾驶舱自己没有“汇总定时任务”：打开页面时实时聚合 ES。下面任务只负责把明细送进 ES，或生成日计划台账数据。

| UAT 任务 | ID | 时间 | 状态 | 最近直接证据 |
|---|---:|---|---|---|
| 集采业务统计报表-非平台采购 | 220 | 03:10 | RUNNING | 08-12、08-13、08-14 均 trigger/handle=200 |
| 集采业务统计报表-招采平台 | 219 | 03:20 | RUNNING | 08-12、08-13、08-14 均 200 |
| 集采业务统计报表-煤炭 SAP | 218 | 03:30 | RUNNING | 08-12、08-13、08-14 均 200 |
| 集采业务统计报表-机电四大类 | 217 | 03:40 | RUNNING | 08-12、08-13、08-14 均 200 |
| 集采管理业务统计报表-云采 | 221 | 05:01:01 | RUNNING | 08-12、08-13、08-14 均 200 |
| 集采日统计服务 | 216 | 03:03 | RUNNING | 08-10 至 08-14 连续 200 |

任务成功只代表同步调用成功，不代表每路一定有业务数据。UAT ES 当前来源分布是 `YC=69、ZC=68、FP=21、JD=2、MT=0`，所以发布后煤炭为 0 是数据现状，不是漏配煤炭任务。

## 五、发布后预期值（2026-08-14 发布前基线）

下面是按新代码完全相同的时间、来源、类目前缀和 `isCentralized=1` 条件直接从 UAT ES 算出的基线。若发布前夜间任务又同步了新业务，绝对值会变，以“同源相等关系”为最终判定。

### 5.1 头部和中间

| 指标 | 预期 |
|---|---:|
| 集采企业数量 | 485 |
| 集采累计总金额 | 2.17 万 |
| 日集采 | 0.00 万 |
| 月度集采 | 0.00 万 |
| 季度集采 | 1.80 万 |
| 年度集采 | 2.17 万 |
| 集采计划累计数量 | 19305 |

### 5.2 左上七格 / 右上三格

| 左上类目 | 预期 |
|---|---:|
| 煤炭 | 0.00 万 |
| 钢材 | 1.80 万 |
| 润滑剂 | 0.00 万（原始金额只有 19 元，换万元两位小数后为 0.00） |
| 电线电缆 | 0.00 万 |
| 轴承及备件 | 0.00 万 |
| 办公设备 | 0.37 万 |
| 办公文具 | 0.00 万 |

右上预期：水泥北分 `0.00`、机电公司 `1.80`、金隅云采 `0.37` 万。

### 5.3 左下四率

2026-08-14 直接调用 UAT order 接口得到：

| 指标 | 预期 |
|---|---:|
| 响应率 | 98.86% |
| 完成率 | 94.66% |
| 滞后率 | **-1.29%** |
| 执行率 | 5.49% |

负滞后率是 UAT 台账数据不守恒的已知问题，不是本次发布故障。可以带到 UAT 供产品确认，但在产品拍板最终口径前，不能据此宣布可以继续上生产。

## 六、MR 合并后的部署与验收

### 6.1 用户要做的发布动作

1. MR 合入 `uat` 后，点 Jenkins `scm-source-all-uat`。
2. 确认下游 `scm-source-web-uat` 也成功，不能只看上游打包绿灯。
3. 不点 order、cockpit 前端或定时任务的构建/执行按钮。

### 6.2 AI 立即做的四接口验收

```bash
bash scripts/api.sh --env uat GET /e/business/source/source/cockpit_collection_data_centerHeader
bash scripts/api.sh --env uat GET /e/business/source/source/cockpit_collection_data_categoryAmount
bash scripts/api.sh --env uat GET /e/business/source/source/cockpit_collection_data_situA
bash scripts/api.sh --env uat GET /e/business/source/source/cockpit_collection_data_doRate
```

验收标准：

1. `centerHeader.companyCount=485`，且 `sumCount` 与 UAT order 的 `planQuantity` 一致；旧代码现在返回 483，可用这一点判断新代码是否生效。
2. `categoryAmount` 返回 7 条，dataCode 为 `1001/1501/1701/2302/2502/2102/2113`；旧 UAT 返回的是 `category1~category7`。
3. `centerHeader.taxTotal` ＝七个类目**原始元金额合计后转万元**＝`situA` 三项合计；不要把每格显示值先四舍五入再相加制造 0.01 误差。
4. `doRate` 四项与直接调用 UAT order 接口一致，尤其允许出现已知的 `-1.29%`，不能被误判成 Nacos/Feign 失败。
5. 驾驶舱页面刷新后 7 个类目、3 个执行单位、4 个率均有位置且无空白；本次不需要重新发布前端。
6. 发布后不手动补跑任务；若第二天数据没有自然更新，再按任务 ID 查精确执行记录。

## 七、给验收人的提前说明话术

> 这次 UAT 是把驾驶舱从旧缓存切到 2026 年以来七个指定集采品类的实时数据。按 UAT 现在的数据，发布后累计金额预计约 2.17 万，煤炭为 0；这是 UAT 统一货架当前没有 MT 煤炭数据，不是任务漏配。左下滞后率会显示约 -1.29%，这是已经查清的台账录入不守恒问题，本次代码只原样展示台账结果。请按已确认的七品类口径验收；滞后率最终怎么处理仍需产品确认，确认前不继续上生产。

## 八、本次调查边界

- 已只读调用 test/UAT 接口、查询 UAT ES、查询 UAT XXL-JOB 数据库执行记录、检查本地 Git 历史并做临时 worktree 冲突预演。
- 未 `fetch`、未 `push`、未新建远程分支、未提 MR。
- 未修改 test/UAT 数据、字典、Nacos、任务、K8s 或 Jenkins。
- Jenkins 只读浏览器本次未启动，无法读取当前构建号；任务名称按已验证的项目映射为 `scm-source-all-uat → scm-source-web-uat`，正式部署后再查实际构建号和镜像。
