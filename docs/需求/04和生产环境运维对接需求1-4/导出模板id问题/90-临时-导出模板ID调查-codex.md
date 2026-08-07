# 导出模板 ID 调查

> 日期：2026-08-04  
> 工具：Codex  
> 当前状态：test 坑口模板和 UAT 四套模板均已迁移为正 19 位数字 ID；两环境的数据库事务校验、提交后独立反查及回滚脚本事务试跑均通过。test 模板详情接口通过，UAT 接口因现有 `UAT_TOKEN` 过期尚未完成应用层验证。  
> 下一阶段：刷新 `UAT_TOKEN` 后查询四套模板详情，并在 test/UAT 页面实际下载 Excel，确认列数分别为 test 14 列、UAT 9 / 11 / 14 / 9 列；生产仍不直接重放这些模板 ID。

## 0. 先说结论

1. **UAT 的四套模板确实都是 2026-07-30 那次 SQL 直接插入的。**4 条主记录和 43 条明细记录都是英文固定 ID，创建人是“系统”，创建时间均为 `2026-07-30 10:41:01`。
2. **test 不是四套都由 SQL 插入。**
   - 日金额、日计划：页面保存，主表和明细都是自动生成的正 19 位数字 ID。
   - 煤炭坑口：SQL 直接插入，仍是英文固定 ID。
   - 价格趋势：test 当前没有模板。
3. **英文 ID 目前不是功能故障。**数据库字段是 `varchar(32)`，代码把 ID 当内部钥匙，不解析数字、不比较大小。真正用于四个业务页面取模板的是稳定的 `template_code`。
4. **2026-08-04 用户决定统一 ID 外观。**目标是无业务含义的正 19 位数字唯一 ID，不宣称这些 ID 是 UAT 页面现场生成；UAT 当前生成器与 test 不同的问题仍需单独治理。
5. **发现了一个比英文 ID 更需要先处理的问题：UAT 的旧自定义 UID 生成器已经越过源码标注的可用年限。**在决定统一 ID 前，应先让负责 UBM/Nacos 的同事确认 UAT 是否要关闭这套自定义生成器或升级其位数/纪元配置。
6. 如果最终仍要求统一，技术上可以直接改，但必须一次事务同步改主表和明细。只改主表的 `template_id` 会让导出找不到任何列。

最新执行决定：

- test 先迁移坑口模板，实际导出 14 列通过后再动 UAT。
- UAT 再一次事务迁移四套模板，实际导出必须为 9 / 11 / 14 / 9 列。
- 生产环境仍不重放模板 INSERT，继续在“导出 Excel 模板”页面逐项新增。
- UAT 自定义 ID 生成器的过期风险继续作为独立问题治理，本次迁移不改 Nacos。

执行进度：test 与 UAT 迁移均已于 2026-08-04 提交。test 模板详情接口已按 `template_code` 返回全部 14 列；UAT 数据库验收通过，但接口调用返回 `900301/访问未授权`，需刷新 UAT 登录令牌后继续。两环境的页面实际下载 Excel 均尚待验收。

## 1. test 和 UAT 当前到底是什么样

### 1.1 四个主模板

| 环境 | 模板编码 | 当前主 ID | ID 形态 | 创建证据 | 判断 |
|---|---|---|---|---|---|
| test | `collection-daily-ledger-export` | `2075056892705947650` | 正 19 位数字 | 张雨，2026-07-09 11:18:11；ID 内时间与创建时间一致 | 符合页面生成特征 |
| test | `centralPurchaseStatistics` | `2076476381372792834` | 正 19 位数字 | 张雨，2026-07-13 09:18:43；ID 内时间与创建时间一致 | 符合页面生成特征 |
| test | `coal-pit-daily-export` | `jckk_daily_export_template` | 英文固定值 | 系统，2026-07-10 15:44:00；与部署 SQL 完全一致 | SQL 插入 |
| test | `priceTrend` | 不存在 | — | 主表、明细均为 0 | 尚未配置 |
| UAT | `collection-daily-ledger-export` | `jcrje_daily_export_template` | 英文固定值 | 系统，2026-07-30 10:41:01 | SQL 插入 |
| UAT | `centralPurchaseStatistics` | `jcplan_daily_export_template` | 英文固定值 | 系统，2026-07-30 10:41:01 | SQL 插入 |
| UAT | `coal-pit-daily-export` | `jckk_daily_export_template` | 英文固定值 | 系统，2026-07-30 10:41:01 | SQL 插入 |
| UAT | `priceTrend` | `price_trend_export_template` | 英文固定值 | 系统，2026-07-30 10:41:01 | SQL 插入 |

数据库反查还确认：

| 环境 | 主模板总数 | 正 19 位数字 | 其他数字 | 非纯数字 |
|---|---:|---:|---:|---:|
| test | 54 | 50 | 3 | 1 |
| UAT | 53 | 39 | 3 | 11 |
| 生产库（只用于分布对照） | 26 | 23 | 3 | 0 |

所以“正常 ID 一定是正 19 位数字”只对 test 当前默认生成器大体成立，不能直接套到 UAT。

### 1.2 明细

| 环境 | 模板 | 明细数 | 明细主键形态 |
|---|---|---:|---|
| test | 日金额 | 9 | 9 个正 19 位数字 |
| test | 日计划 | 4 | 4 个正 19 位数字 |
| test | 坑口 | 14 | 14 个英文固定 ID |
| test | 价格趋势 | 0 | 不存在 |
| UAT | 日金额 | 9 | 9 个英文固定 ID |
| UAT | 日计划 | 11 | 11 个英文固定 ID |
| UAT | 坑口 | 14 | 14 个英文固定 ID |
| UAT | 价格趋势 | 9 | 9 个英文固定 ID |

UAT 四套合计是 **4 条主记录 + 43 条明细记录**。

## 2. 页面新增时 ID 到底怎么生成

### 2.1 页面不传新增 ID

模板新增页保存时只在“修改模式”才传路由里的 `templateId`；新增模式传 `undefined`：

- `02zhaocai-front/scm-vue-all-platform/src/views/xlsMgt/add.vue:198-214`

后端发现主 ID 为空时调用 MyBatis-Plus 插入主表；每条明细先把 `tmpId` 清空，再逐条插入：

- `01zhaocai-end/scm-template-all/scm-template-temp/src/main/java/com/pcitc/scm/template/temp/service/impl/SimpleTemplateServiceImpl.java:132-180`

主表和明细实体都把主键标成 `IdType.ASSIGN_ID`：

- `SimpleTemplate.java:28-30`
- `SimpleTemplateSub.java:28-30`

大白话：页面只交“模板内容”，后端发号器给主模板和每一列各发一个内部号码。

### 2.2 test 当前规则

test 的 `global-config.yaml` 和 `scm-ubm-web-test.yaml` 都没有 `seq.share.config` 覆盖项，因此 `SeqWebConfig` 使用默认 `DefaultIdentifierGenerator`：

- `SeqWebConfig.java:34-38`：自定义开关默认关闭。
- `SeqWebConfig.java:46-52`：关闭时使用 MyBatis-Plus 默认生成器。

默认生成器是常见的 Snowflake（雪花）分布式 ID：时间 + 数据中心 + 机器 + 同毫秒序号，最后表现为正 19 位数字。test 日金额和日计划的主 ID 可以按该算法解出与创建时间一致的时间：

- `2075056892705947650` → 2026-07-09 11:18:10（北京时间）
- `2076476381372792834` → 2026-07-13 09:18:43（北京时间）

### 2.3 UAT 当前规则与风险

UAT Nacos 的 `scm-ubm-web-uat.yaml` 当前明确开启：

```yaml
seq.share.config:
  enableUidGenerator: true
  enableCusIdentifier: true
```

因此 UAT 不走 test 的默认 Snowflake，而是：

```text
MyBatis ASSIGN_ID
  → DefaultSeqIdentifierGeneratorImpl
  → UidGeneratorService
  → CachedUidGenerator
```

代码证据：

- `DefaultSeqIdentifierGeneratorImpl.java:16-24`
- `UidGeneratorConfig.java:20-49`
- `DefaultUidGenerator.java:35-57`

这套旧 UID 的默认分配是“28 位秒数 + 22 位机器 + 13 位序号”，纪元为 `2016-05-20`。源码注释直接写明默认可用到 `2024-11-20` 左右。缓存版生成器在分配 ID 时没有走普通版的超期拒绝检查：

- 普通版检查：`DefaultUidGenerator.java:179-183`
- 缓存版直接分配：`CachedUidGenerator.java:103-114`

UAT 模板表与该现象互相印证：2025～2026 年带真实用户创建信息的 7 个模板主 ID 已是负数，例如：

- `plan_chase_line`：`-9076410041375915173`
- `purchase-centralize-export`：`-8788368506346272994`
- `scheme-export-sourceFpt`：`-7915714508524355575`

这意味着现在去 UAT 页面新建模板，目标 ID 大概率是负数，不会是 test 那种正 19 位数字。**因此不能把“改成正 19 位数字”描述为“恢复 UAT 页面生成结果”。**

## 3. 改 ID 会不会影响四个页面

### 3.1 正常导出只认模板编码

四个前端分别传：

- 日金额：`collection-daily-ledger-export`，`dailyAmountStatisticsLedger/index.vue:561-573`
- 日计划：`centralPurchaseStatistics`，`dailyPlanStatisticsLedger/index.vue:574-585`
- 坑口：`coal-pit-daily-export`，`coalPitDailyIndicator/index.vue:488-499`
- 价格趋势：`priceTrend`，`maintenancePriceTrend/index.vue:493-504`

导出公共组件把这个编码传给模板服务：

- `DefaultSimpleTemplateExportServiceImpl.java:19-25`
- `SimpleTemplateExportFeignService.java:9-12`

模板服务的真实查询顺序是：

```text
template_code
  → 找 scm_simple_template 主记录
  → 取主记录 template_id
  → 按 template_id 找 scm_simple_template_sub 明细列
```

证据：`SimpleTemplateServiceImpl.java:49-78`。

所以：

- 主 ID 是英文、正数还是负数，本身不影响导出。
- 只要主表 ID 与所有明细的 `template_id` 保持一致，改 ID 后业务页面不需要改代码。
- 如果只改主表 ID、不改 43 条明细外键，四个导出都会变成“模板存在但没有列”。
- 明细自己的 `tmp_id` 只用于明细行主键；不改它不影响导出，但外观仍不统一。

### 3.2 全库引用扫描

我对当前 MySQL 中所有 `scm_%` 库、所有名为 `template_id` / `tmp_id` 的字符字段做了精确值扫描：

| 位置 | 命中 |
|---|---:|
| `scm_ubm_uat.scm_simple_template.template_id` | 4 |
| `scm_ubm_uat.scm_simple_template_sub.template_id` | 43 |
| `scm_ubm_uat.scm_simple_template_sub.tmp_id` | 43 |
| UAT 之外的业务引用 | 0（test 自己的坑口同名配置除外） |

代码全仓搜索也只在部署 SQL 文档中找到这些英文 ID，业务 Java/Vue 没有硬编码它们。

表结构方面：

- 两张表的 ID 都是 `varchar(32)`。
- 只有各自主键，没有数据库外键。
- `template_code` 没有唯一索引，唯一性由保存服务代码检查。

结论：**原子地同步替换可以做到不影响业务逻辑；但没有任何功能收益，主要是数据外观与配置流程一致性收益。**

## 4. 为什么不建议通过页面“删掉再重建”

模板修改页面不会更换主 ID，只会保留主 ID、删除旧明细并给新明细生成 ID。要让主 ID 也变化，只能先删主模板再新增。

但当前删除服务只删除主表，没有同步删除明细：

- `SimpleTemplateServiceImpl.java:202-211`

数据库也没有外键级联。只读反查显示，UAT 当前已经有 30 条其他模板留下的孤儿明细；本次四套模板目前没有孤儿。

因此：

- 页面“修改”不能解决主 ID。
- 页面“删除后新增”会留下旧的 43 条孤儿明细，中间还有模板不可用窗口。
- 如果真要改，数据库事务内同步更新比页面删除重建更安全；但这属于一次明确的数据迁移，不要伪装成普通页面配置。

## 5. 已确认的迁移决策（2026-08-04）

用户选择：把固定英文 ID 原子替换为无业务含义的正 19 位数字唯一 ID。

边界：

1. 只改 `scm_simple_template.template_id`、`scm_simple_template_sub.template_id` 和明细主键 `tmp_id`。
2. 四个稳定 `template_code`、模板字段、排序、状态、创建信息均不改。
3. test 影响 1 条主模板 + 14 条明细；UAT 影响 4 条主模板 + 43 条明细。
4. 不通过页面删除重建，避免当前删除服务遗留孤儿明细。
5. 本次数字 ID 按 Snowflake 位结构离线生成并全库查重，但不冒充 UAT 当前页面生成器的结果。
6. UAT 自定义 UID 生成器问题后续单独处理，不与本次数据迁移混在一起。

## 6. 最终 ID 映射与执行文件

新 ID 按 Snowflake 位结构离线生成。2026-08-04 已重新扫描当前所有 `scm_%` 库的 `template_id/tmp_id` 字段，候选区间 `2084540332552220673`～`2084540332552220734` 命中 0 条。

它们是本次数据规范化使用的无业务含义唯一 ID，不是 UAT 当前页面现场生成结果。

### 6.1 test 坑口模板

| 模板编码 | 旧主 ID | 新主 ID | 明细映射 |
|---|---|---|---|
| `coal-pit-daily-export` | `jckk_daily_export_template` | `2084540332552220673` | `_field_01`～`_14` → `2084540332552220674`～`2084540332552220687` |

执行文件：

- `sql/03-test-导出模板ID规范化.sql`
- `sql/04-test-导出模板ID回滚.sql`

执行状态：`03` 已提交；`04` 已在事务内试跑到 `ready_to_commit=1` 后回滚试跑事务，证明回滚链路可用且 test 最终仍保持新 ID。

### 6.2 UAT 四个主 ID

| 模板编码 | 旧 ID | 新 ID |
|---|---|---|
| `collection-daily-ledger-export` | `jcrje_daily_export_template` | `2084540332552220688` |
| `centralPurchaseStatistics` | `jcplan_daily_export_template` | `2084540332552220689` |
| `coal-pit-daily-export` | `jckk_daily_export_template` | `2084540332552220690` |
| `priceTrend` | `price_trend_export_template` | `2084540332552220691` |

### 6.3 UAT 43 个明细主键

规则是按字段后缀顺序一一对应：

| 模板 | 旧明细 ID | 新 ID |
|---|---|---|
| 日金额 | `jcrje_daily_export_field_01` ～ `_09` | `2084540332552220692` ～ `2084540332552220700` |
| 日计划 | `jcplan_daily_export_field_01` ～ `_11` | `2084540332552220701` ～ `2084540332552220711` |
| 坑口 | `jckk_daily_export_field_01` ～ `_14` | `2084540332552220712` ～ `2084540332552220725` |
| 价格趋势 | `price_trend_export_field_01` ～ `_09` | `2084540332552220726` ～ `2084540332552220734` |

执行文件：

- `sql/05-uat-导出模板ID规范化.sql`
- `sql/06-uat-导出模板ID回滚.sql`

执行状态：`05` 已提交；`06` 已在事务内试跑到 `ready_to_commit=1` 后回滚试跑事务，证明四套模板均可恢复旧 ID，UAT 最终保持新 ID。

### 6.4 实际字段改动量

| 目标 | 行数 | 要改的字段值数 |
|---|---:|---:|
| 四个主模板主键 | 4 | 4 个 `template_id` |
| 43 条明细对主表的引用 | 43 | 43 个 `template_id` |
| 43 条明细自身主键 | 43 | 43 个 `tmp_id` |
| 合计 | 47 条记录 | 90 个字段值 |

功能最小改法只需改前两项；完整外观统一需要三项都改。

## 7. test 执行结果与 UAT 后续步骤

test 于 2026-08-04 完成：

1. 首次试跑发现目标 MySQL 8.0.18 不允许在一条复合查询中重复打开同一临时表，且临时表默认排序规则与业务表不同；更新行数为 0，随即在同一连接回滚并确认旧 ID 未变。
2. 修正脚本后重新执行，`precheck_ok=1`、`updated_main=1`、`updated_sub_parent=14`、`updated_sub_id=14`、`ready_to_commit=1`，随后提交。
3. 新连接独立反查：主 ID 为 `2084540332552220673`，14 条明细均为正 19 位数字 ID，排序仍为 1～14，旧 ID 残留 0，孤儿明细 0。
4. test 模板详情接口按 `coal-pit-daily-export` 查询成功，返回 14 个原字段；回滚脚本也已事务试跑通过后撤销试跑，最终数据库保持新 ID。

UAT 于 2026-08-04 完成：

1. 执行前确认四套模板各只有一条主记录，明细为 9 / 11 / 14 / 9，新 ID 碰撞为 0。
2. 迁移事务内结果为 `precheck_ok=1`、`updated_main=4`、`updated_sub_parent=43`、`updated_sub_id=43`、`ready_to_commit=1`，随后提交。
3. 新连接独立反查：四个主 ID 与第 6 节一致，43 个明细主键均为正 19 位数字，旧 ID 残留 0，孤儿明细 0，排序范围分别为 1～9 / 1～11 / 1～14 / 1～9。
4. UAT 回滚脚本在事务内试跑同样得到 `4 / 43 / 43 / ready_to_commit=1`，随后撤销试跑；最终 UAT 保持新 ID。
5. 应用接口复核使用现有 `UAT_TOKEN` 时四次均返回 `900301/访问未授权`，因此尚不能宣称 UAT 应用层和实际 Excel 已验收。

模板服务每次导出都会按编码重新查数据库，代码中没看到这条链路的模板缓存，所以正确同步更新后不要求清缓存或重启。

## 8. 生产环境怎么避免重演

生产发布包应拆成两类：

- 业务表 DDL：继续交运维执行 SQL。
- Excel 模板：由负责人在“导出 Excel 模板”页面新增，保存后用只读 SQL 反查并实际导出验收。

当前仍含固定模板 ID、不能原样交生产执行的文件：

- `docs/需求/01台账/sql/00-prod-deploy.sql:80-102`
- `docs/需求/02台账需求2/sql/00-prod-deploy.sql:88-116`
- `docs/需求/04和生产环境运维对接需求1-4/sql/01-uat-集采四页面部署.sql:174-314`

其中需求 04 文件是已经执行过的 UAT 历史脚本，建议保留作为事实记录，不要悄悄改写历史；后续另做“生产业务表 SQL”和“页面配置清单”。

生产页面需配置的仍是这四个稳定编码和 9 / 11 / 14 / 9 列。生产生成出的内部 ID 不需要和 test/UAT 一样。

## 9. 给负责 UBM/Nacos 同事的逐字话术

> 我在排查导出模板 ID 时发现，test 的 UBM 没开自定义序列，模板页面生成的是 MyBatis-Plus 默认正 19 位 Snowflake ID；UAT 的 `scm-ubm-web-uat.yaml` 还开着 `enableUidGenerator=true` 和 `enableCusIdentifier=true`，走的是项目内置的旧 Cached UID。这个实现默认 28 位秒数、纪元 2016-05-20，源码写的可用期到 2024-11 左右，UAT 2025～2026 新建的模板已经出现负数 ID。麻烦确认一下：UAT 这套自定义 UID 是否还应该继续用？如果要继续，timeBits/workerBits/seqBits/epochStr 应该怎么调整；如果不用，是否可以关闭 `enableCusIdentifier`，和 test 统一走默认 Snowflake？我这边在答案确认前先不改现有四套模板 ID。

对面如果说“负数能用就不用管”，可以接：

> 现在 varchar 主键确实还能存，业务也没按正负判断；我担心的不是显示，而是默认时间位已经越界，缓存实现仍继续移位生成，后续唯一性和可维护性没有明确保证。至少需要负责人书面确认这是可接受的长期配置，或者给出新的位数/纪元方案。

## 10. 本次未做的事情

- 未修改生产数据库；test 修改了 1 条主模板和 14 条明细，UAT 修改了 4 条主模板和 43 条明细，范围均仅限三个 ID 字段。
- 未修改 Nacos。
- 未修改 Java/Vue 代码。
- 未修改已经执行过的 UAT SQL。
- 未调用新增、修改、删除模板接口；只调用了模板详情查询接口，其中 test 成功、UAT 因令牌过期未授权。
- 未推送或操作任何远程 Git 分支。
