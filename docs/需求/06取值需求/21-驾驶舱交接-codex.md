# 集采首页取值（06）· 驾驶舱接口开发交接

> 日期：2026-08-05  
> 工具：codex  
> 当前状态：**本次范围已锁定为 06 的 `kengk/mt/gc` 三接口；后端已接台账、HPC 空值和钢材月指标已修并随前端 `292fbcd` 提交，本地编译、打包、启动、真实接口和前端构建全部通过。**  
> 下一阶段：部署后通过 test 网关复验三个接口，并在老驾驶舱与新集采门户各做一次页面联调；原四台账的其他驾驶舱链路不在本次范围。

---

## 一、先说结论：cockpit 这块到底要开发什么

是的，这里说的 **cockpit 开发，就是把现有驾驶舱的三个查询接口接到新台账**，不是再新建一套驾驶舱服务。

现在有两个页面共用这三份数据：

1. 老驾驶舱 `scm-vue-all-cockpit`；
2. 新集采门户 `scm-vue-hpc`。

正确做法是：**三个接口路径和返回格式不变，只把接口内部从“查旧缓存”切换成“查已发布台账”**。这样台账一更新，老驾驶舱和集采门户同时看到同一份数据。

不应采用下面几种做法：

- 不让集采门户去抓驾驶舱页面；
- 不给集采门户另造一套重复接口；
- 不把台账数据定时复制到旧缓存表；
- 不在 `PriceTrendController` 再注册同路径接口，否则会和现有通用接口撞路由；
- 不改现有接口地址，否则老驾驶舱也要跟着改。

### 1.1 原产品有四个台账，但 06 cockpit 只直接涉及其中两个

用户补充的原产品文档中，四个台账各自对应一个驾驶舱区域：

| 台账 | 原产品要求影响的驾驶舱区域 | 代码/配置事实 | 是否属于 06 cockpit 三接口 |
|---|---|---|---|
| 1. 集采日金额统计台账 | 集采类目分项金额、机电公司金额等 | 代码已经把 `categoryAmount/situA` 的机电四类金额改读日金额台账，但 test 的两个 `collectionShow` 开关仍为 `0`，实际仍读旧缓存；实时 SQL还没有按 `statistic_date=前一日` 过滤，而是累计全部有效历史 | **不属于三个接口**；但它通过 JD/统一 ES 参与 06 首页交易金额计算 |
| 2. 集采日计划统计台账 | 集采计划分析（响应率、执行率、完成率、滞后率） | order 服务已有 `calculateRates()`，但驾驶舱调用的是 source 的 `doRate`；source 目前没有路由到 order，`queryDoRate()` 还是空实现，test 仍有 4 条旧缓存 | **不属于 06 首页** |
| 3. 煤炭重点坑口日指标 | 煤炭重点坑口指标 | 台账查询转换原已存在；本次已恢复接口接线 | **属于：`kengk`，已完成** |
| 4. 价格趋势维护 | 煤炭/钢材近 12 月趋势及钢材品种指标 | 台账 CRUD 原已存在；本次已完成驾驶舱查询和拼月 | **属于：`mt`、`gc`，已完成** |

因此要分两层理解：

- **按 `docs/需求/06取值需求` 的定稿范围**：本次 cockpit 只需要台账 3、4，共三个接口 `kengk/mt/gc`。
- **按最初“四个台账都要更新驾驶舱”的总需求**：四个都有关，而且台账 1、2 也没有完整达到原产品口径，不能算全部完成。

新集采门户代码只调用 `kengk/mt/gc`，没有调用 `centerHeader/categoryAmount/situA/doRate`。用户已最终确认：**只按 06 定稿开发，不补原四台账的日金额和日计划驾驶舱链路。**

---

## 二、当前真实状态

| 项目 | 当前情况 | 结论 |
|---|---|---|
| 开发范围 | 只按 06 做 `kengk/mt/gc`；不补 `categoryAmount/situA/doRate` | 已确认，无待问项 |
| 三个接口 | 路径和返回契约保持不变，内部已从旧缓存切到台账 | 不新增、不改地址 |
| 坑口 `kengk` | 已恢复到既有 `queryCockpitData()`，读取最新有效坑口主表和明细 | 本地实调返回 5 条最新台账数据 |
| 煤价 `mt` | 已实现 12 月拼装、去重、过滤和空点 | 本地实调返回 12 个月，2026-07 环渤海价 500 |
| 钢价 `gc` | 已实现三个指标映射；中厚板无数据按空点返回 | 本地实调 12 个月均为空点，符合现有数据 |
| HPC 前端 | 已保留 null，并补螺纹钢/中厚板月指标表 | 生产构建通过 |
| Git | 后端本地提交 `1f419cc84` 仅含 3 个目标文件；D2 和前端既有修改未夹带 | 无直接冲突、未推送 |

一句大白话：**原来的接口地址没动，只把接口后面的旧仓库换成了业务台账；台账一保存，两个页面下次查询就会读到新结果。**

---

## 三、开发前后链路

### 3.1 开发前

```text
老驾驶舱 / 集采门户
        ↓ 调同一批 GET 接口
SourceQueryController
        ↓
SourceCollectionDataServiceImpl
        ↓ 默认分支
sc_collection_data（旧静态缓存，数据停在 2024-12～2025-11）
```

### 3.2 开发后（当前）

```text
坑口台账页面 ─→ sc_coal_pit_daily_indicator + item ─┐
                                                     ├→ 原三个 cockpit 接口 ─→ 老驾驶舱
价格趋势台账 ─→ sc_price_trend ─────────────────────┘                    └→ 集采门户
```

`SourceQueryController` 现在已经用 `{typeCode}` 统一接收类型，所以本期不用动 Controller。真正改动点在接口后面的路由和台账组装逻辑。

---

## 四、三个接口的处理结果

| 接口 | 页面用途 | 开发前 | 当前数据源 |
|---|---|---|---|
| `GET /e/business/source/source/cockpit_collection_data_kengk` | 煤炭重点坑口指标 | 旧缓存 5 条 | 最新一批有效坑口台账及明细 |
| `GET /e/business/source/source/cockpit_collection_data_mt` | 近 12 月煤价趋势 | 旧缓存 12 条 | 价格趋势台账中的煤炭指标 |
| `GET /e/business/source/source/cockpit_collection_data_gc` | 近 12 月钢价、螺纹和中厚板 | 旧缓存 12 条 | 价格趋势台账中的钢材指标 |

### 4.1 坑口 `kengk`

这块逻辑已经在 `CoalPitDailyIndicatorServiceImpl.queryCockpitData()` 里写好了：

1. 只查 `delete_sign=0`；
2. 按 `publish_date`、`publish_time`、`create_time` 倒序；
3. 只取最新一张主表；
4. 再查该主表的有效坑口明细，按 `sort_no` 排序；
5. 转成驾驶舱认识的 `SourceCollectionData`。

返回字段对应关系：

| 返回字段 | 含义 |
|---|---|
| `dataType` | 固定 `kengk` |
| `dataCode` | `kengk` + 坑口排序号 |
| `dataDesc` | 坑口名称 |
| `dataValue` | 含税坑口价 |
| `dataRank` | 排序号 |

无有效台账时返回空数组，不能回退到老缓存；否则页面会把旧价格误认为最新价格。

### 4.2 煤价 `mt`

价格台账需要把“按指标一条一条存的数据”横向拼成“一个月份一行”：

| 台账 `indicator_name` | 驾驶舱字段 |
|---|---|
| `煤炭月成交价格` | `dataValue` |
| `煤炭月环渤海价格` | `ext02` |
| 年、月 | `dataCode=YYYY-MM`、`dataDesc=YYYY年`、`ext01=M月` |

例如同一个月两种指标都有值时，返回结构应类似：

```json
{
  "dataType": "mt",
  "dataCode": "2026-07",
  "dataDesc": "2026年",
  "ext01": "7月",
  "dataValue": "560",
  "ext02": "500"
}
```

### 4.3 钢价 `gc`

同样按年、月拼成一行：

| 台账 `indicator_name` | 驾驶舱字段 |
|---|---|
| `钢材月成交价格` | `dataValue` |
| `螺纹月成交价格` | `ext02` |
| `中厚板月成交价格` | `ext03` |
| 年、月 | `dataCode=YYYY-MM`、`dataDesc=YYYY年`、`ext01=M月` |

这个结构必须保留，因为老驾驶舱和集采门户都已经按 `dataValue/ext01/ext02/ext03` 取数。

---

## 五、价格趋势必须处理好的逻辑问题

### 5.1 同月重复录入：取发布时间最新的一条

`sc_price_trend` 没有“年 + 月 + 指标名”的唯一约束，test 里已经出现有效重复数据：

- 2025-01 的煤炭月成交价格同时有 `850.50` 和 `860`；
- 2025-02 同时有 `855` 和 `865`。

所以不能直接查出来就画图。正确口径应是：

```text
同一类别 + 同一指标 + 同一年月
→ 按 publish_time 倒序
→ 只保留最新一条
```

如果 `publish_time` 一样，再用 `update_time/create_time` 和主键兜底，保证每次结果稳定。

### 5.2 一个月某条线没数据：返回空，不补 0

例如 2026-07 目前只有环渤海价，没有煤炭成交价。这里应返回：

- `ext02=500`；
- `dataValue=null`。

不能补 `0`，因为 0 表示“真实价格是零”，会造出一条错误折线。集采门户当前使用 `Number(item.ext02)`，而 `Number(null)` 会变成 0，前端开发时也要一起改成“空值仍为 null”。

### 5.3 过滤脏数据和删除数据

至少过滤：

- `delete_sign != 0`；
- `price` 为空；
- 年、月不是合法数字；
- 月份不在 1～12；
- 类别和指标名不属于本接口目标集合。

test 中确实有 `year=1`、`month=1`、`category_name=1` 的脏记录，不能让它进入图表。

### 5.4 返回顺序

数据库筛选/去重可以先倒序取最近数据，但最终返回给页面必须按业务年月正序排列，否则折线会从新月份倒着画到旧月份。

### 5.5 “近 12 个月”已确认

用户确认缺月显示空点；原产品文档明确“取系统中当前月份前 12 个月的指标数据”。据此技术口径定为：

1. 当前月不纳入，取当前月之前连续 12 个自然月；
2. 例如查询发生在 2026-08，则返回 2025-08～2026-07；
3. 始终按月份正序返回 12 个点；
4. 整月无记录也保留月份，所有价格字段为 `null`；
5. 某月只有部分指标，已有指标正常返回，缺的指标为 `null`；
6. 绝不拿 0 补空点。

---

## 六、“发布”在现有系统里是什么意思

当前两个台账都没有单独的“草稿/已发布”状态：

- 坑口台账新增或修改时会刷新发布人、发布时间；
- 价格趋势新增或修改时也会直接刷新 `publish_time`；
- 非删除记录会直接成为驾驶舱候选数据。

也就是说，按现有设计是 **保存即发布，修改后驾驶舱立即跟着变**。用户已确认这个行为没问题，不新增草稿状态、审批状态或第二个发布动作。

价格趋势维护页面按钮本身写的是“发布”，后端新增/修改又会刷新 `publish_time`，所以这里的“保存即发布”与产品文案一致。

---

## 七、实际后端落法

### 7.1 路由顺序

在 `SourceCollectionDataServiceImpl.queryCollectionData(typeCode)` 最前面单独处理：

```text
typeCode = kengk → 坑口台账服务
typeCode = mt/gc → 价格趋势驾驶舱查询提供者
其他 typeCode → 完整保留当前字典开关、实时查询和旧缓存逻辑
```

要放在 UBM 字典查询之前。这样三个台账接口不再依赖 `collectionShow` 字典，也不会因为无关的 Feign/字典故障查不到价格。

### 7.2 价格趋势的模块边界

价格趋势表和 Mapper 属于 `scm-source-ssc`；现有驾驶舱路由属于 `scm-source-source`。依赖方向目前是：

```text
scm-source-ssc → scm-source-source
```

因此 **不能再让 `scm-source-source` 依赖 `scm-source-ssc`**，否则 Maven 会循环依赖。

实际采用：

1. 在 `scm-source-source` 定义一个很小的读取接口，例如 `PriceTrendCockpitProvider`；
2. 在已经依赖 source 的 `scm-source-ssc` 中实现该接口，用 `PriceTrendMapper` 查表、去重、拼月份；
3. `SourceCollectionDataServiceImpl` 只依赖这个接口，不直接认识 SSC 的实体和 Mapper；
4. `scm-source-web-jar` 本来就同时装载 source 和 ssc，所以运行时能完成注入。

这个方案顺着现有依赖方向走，也不会把 SSC 所属表重复映射到 source 模块。

本地启动已证明 Spring 能找到 ssc 的实现并注入 source，没有 Bean 缺失或循环依赖。

### 7.3 实际改动文件

| 文件/模块 | 动作 | 说明 |
|---|---|---|
| `SourceCollectionDataServiceImpl.java` | 修改 | 只增加 `kengk/mt/gc` 早期路由；其他类型逻辑不动 |
| `PriceTrendCockpitProvider.java` | 新增 | 在 source 定义跨模块读取契约 |
| `PriceTrendCockpitProviderImpl.java` | 新增 | 在 ssc 查询、去重、固定拼 12 个月并转换返回结构 |
| `CoalPitDailyIndicatorServiceImpl.java` | 未改 | 直接复用现有 `queryCockpitData()` |
| `SourceQueryController.java` | 不改 | 通用接口路径已经存在 |
| 老驾驶舱前端 | 未改 | 接口地址与字段契约不变 |
| 集采门户 `CoalTransaction.vue`、`SteelTransaction.vue` | 修改 | 保留 null；钢材月指标表赋值 |

后端已形成独立本地提交 `1f419cc84 feat: 驾驶舱接入台账`，只含上述 3 个后端目标文件，未推送。HPC 两个组件所在工作区原本已有本需求 overview 等未提交修改，因此没有把整文件强行提交，避免夹带。

---

## 八、冲突情况复核

### 8.1 旧文档里的“高冲突”结论已过时

旧交接曾写 `feature/jcrje-cockpit-switch` 正在平行修改驾驶舱公共文件，甚至描述成几千行删除。2026-08-04 重新 `git fetch` 并查提交后，事实是：

- 该分支关键提交为 `2f33fa77f`；
- 实际只改了 `SourceCollectionMapper.java`，10 行增加、10 行删除；
- 合并提交 `b7fcf7cff` 和上述提交都已经是当前开发分支的祖先；
- 当前远端没有发现更新的并行分支在修改本期目标链路。

所以现在不存在“必须等对方分支落定才能开发”的阻塞。

### 8.2 真实风险

| 风险 | 等级 | 怎么避开 |
|---|---|---|
| `SourceCollectionDataServiceImpl` 是多个驾驶舱类型共用路由 | 中 | 只给 `kengk/mt/gc` 加早期分支，其他逻辑一字不动，并做回归 |
| `SourceQueryController` 是大公共文件 | 低 | 本期完全不改它 |
| source 与 ssc 形成 Maven 循环依赖 | 高（设计错误时） | 用 source 定义接口、ssc 实现；禁止 source 依赖 ssc |
| 原四台账其他链路容易被误纳入本期 | 已消除 | 用户确认只按 06，`categoryAmount/situA/doRate` 不改 |
| D2 与 cockpit 在同一后端分支 | 低 | D2 在 `scm-source-chase`，cockpit 在 source/ssc；已分开形成历史提交，方便独立回退 |
| HPC 前端业务改动较多 | 中 | 最终统一整理为 `292fbcd`，只含门户 9 个业务文件；敏感配置未进提交 |
| 历史坑口接线“加了又撤回” | 低 | 这是历史延期，不是代码冲突；恢复时单独提交、可独立回退 |

后端 cockpit 已按该原则形成独立本地提交 `1f419cc84`，没有夹带 D2；前端 cockpit 修改随后随门户整组业务改动整理为本地提交 `292fbcd`。前端仓 `git fetch` 因现有 GitLab 凭据失效仍无法确认远端最新状态；所有提交均未推送，也未操作远程分支。

---

## 九、test 数据现状：能测什么、不能测什么

### 9.1 旧缓存

- `kengk`：5 条；
- `mt`：12 条；
- `gc`：12 条。

这些数据正是当前三个接口还在返回的旧数据，不能再作为“接口已接台账”的证据。

### 9.2 坑口台账

- 主表共 5 条，其中有效 3 条；
- 有效明细 15 条；
- 当前按既有规则选中的最新批次是 2026-07-12 16:15 左右发布的一批；
- 该批名称是测试式的“坑口1～坑口5”，价格为 750/770/750/780/770。

这能验证“接口是否真正读台账、是否取最新批次”，但数据名称本身仍需业务人员维护成正式内容。

### 9.3 价格趋势台账

- 表内总共 15 条；排除逻辑删除后只有 11 条有效数据；
- 有效数据只覆盖 5 个业务月份，不足 12 个月；
- 有 2 组有效的同月同指标重复记录，可用于验证“取最新”；
- 有效螺纹数据为 0 条；
- 中厚板数据为 0 条；
- 2026-07 只有煤炭环渤海价，没有同月煤炭成交价和钢材系列。

因此当前 test 能验证：过滤、去重实现、固定 12 月拼装、排序和空值处理；不能验收一张有完整业务价格的 12 月图。用户已明确“有字段就先开发，不用管数据”，所以中厚板按空点验收，不补共享 test 数据。

---

## 十、已确认的三个逻辑问题

| 问题 | 结论 | 是否还要问产品 |
|---|---|---|
| 近 12 月怎么取 | 当前月之前连续 12 个自然月，缺月/缺指标返回空点 | 不用 |
| 是否保存即发布 | 是；新增、修改刷新发布时间后立即可见 | 不用 |
| 中厚板取什么 | `indicator_name=中厚板月成交价格` → `gc.ext03` | 不用问字段；只缺 test 数据 |

中厚板的两个“字段”都已经查明：台账侧读通用列 `indicator_name/price`，驾驶舱响应写 `ext03`。价格趋势维护前端 `origin/test` 的 `CATEGORY_INDICATOR_MAP` 已把钢材三个标准指标列为“钢材月成交价格、螺纹月成交价格、中厚板月成交价格”。因此 test 没数据只会导致中厚板折线和月指标没有价格，不会阻塞编码。

---

## 十一、开发与验证结果

| 验证项 | 结果 |
|---|---|
| 范围 | 已确认只做 06 三接口；原四台账其他驾驶舱链路不改 |
| Java 隔离编译 | 3 个改动 Java 文件生成 class，0 错误 |
| 后端模块打包 | `scm-source-source`、`scm-source-ssc` 均打包成功 |
| Spring 运行 | `scm-source-web` 本地 8110 启动成功，Provider 注入正常 |
| `kengk` 实调 | `code=000000/status=true`，最新 5 条为 750/770/750/780/770 |
| `mt` 实调 | 固定返回 2025-08～2026-07 共 12 条；只有 2026-07 `ext02=500`，其余空点为 null |
| `gc` 实调 | 固定返回同期 12 条；当前三个价格字段均为 null，与 test 台账无有效窗口内钢价一致 |
| 数据库独立反查 | `COAL/STEEL` 类别码和五个标准指标名与实现一致；删除记录、脏记录和历史窗口外数据未进入返回 |
| HPC 前端 | `null` 不再转成 0，钢材月指标表已接 `ext02/ext03`；`npm run build` 成功 |
| Git | 后端 cockpit 提交 `1f419cc84`；前端门户提交 `292fbcd`（含本节两个组件）；均仅本地未推送，敏感配置未纳入 |

---

## 十二、验收清单

以下清单只对应已经确认的 06 三接口范围：

- [x] 三个接口路径不变，老驾驶舱无须改地址。
- [x] `kengk` 返回最新有效坑口台账，不再返回旧缓存坑口。
- [x] `mt` 正确映射煤炭成交价和环渤海价。
- [x] `gc` 正确映射钢材成交价、螺纹和中厚板。
- [x] 同月同指标重复时按发布时间、更新时间、创建时间和主键依次取最新一条。
- [x] 删除数据、脏年月、空价格不会进入结果。
- [x] 返回当前月之前连续 12 个自然月，月份按时间正序排列。
- [x] 某条线缺值时为 null，HPC 不再伪造成 0。
- [x] 坑口无有效台账时代码返回空数组；煤价/钢价无窗口内数据时仍返回 12 个月份，价格字段全部为 null；不回退旧缓存。
- [x] `centerHeader/categoryAmount/situA` 等其他驾驶舱分支代码未改。
- [ ] 部署后在老驾驶舱和集采门户各做一次页面验收，确认同一月份、同一指标显示一致。
- [ ] 有真实螺纹/中厚板数据后自然验证具体价格；当前按用户答复只验空点，不造数、不阻塞上线。

---

## 十三、核查证据

| 结论 | 证据位置 |
|---|---|
| 三接口通用入口 | `scm-source-source/.../SourceQueryController.java:555` |
| 三接口已提前分流到台账 | `scm-source-source/.../SourceCollectionDataServiceImpl.java` |
| 坑口台账转换代码已存在 | `scm-source-source/.../CoalPitDailyIndicatorServiceImpl.java:172-198` |
| 价格趋势驾驶舱实现 | `scm-source-ssc/.../PriceTrendCockpitProviderImpl.java` |
| ssc 已依赖 source，不能反向依赖 | `scm-source-ssc/pom.xml:97-101` |
| 主 Web 同时装载 source 与 ssc | `scm-source-web-jar/pom.xml:37-40,147-150` |
| 老驾驶舱字段消费契约 | `scm-vue-all-cockpit/.../dashboardUtils.js:143-158,259-275` |
| 集采门户空点与钢材月指标修正 | `CoalTransaction.vue`、`SteelTransaction.vue` |
| 06 新门户只消费三个 cockpit 类型 | `CoalTransaction.vue:90-121`、`SteelTransaction.vue:89-103` |
| 日金额已改实时 SQL但 test 开关为 0 | `SourceCollectionMapper.java:112-143`；`scm_ubm_test.ubm_dict` 的 `categoryAmount/situA` 均为 0 |
| 日计划尚未接 source 驾驶舱 | `SourceCollectionDataServiceImpl.java:43-82`；order 的 `CentralPurchaseDailyStatisticsController.java:47-55` |
| 中厚板标准指标名 | `scm-vue-all-procurementscheme` 的 `origin/test:.../maintenancePriceTrend/index.vue:172-176` |
| 坑口接线历史增加/撤回 | 提交 `3992bf54e`、`d4eb7d21b` |
| 旧 cockpit 分支已进入当前历史 | 提交 `2f33fa77f`、合并 `b7fcf7cff` 均为当前 HEAD 祖先 |

> 本次已修改驾驶舱业务代码和 HPC 组件，没有修改数据库或环境配置。后端已本地提交 `1f419cc84`，前端已本地提交 `292fbcd`；所有仓库均未推送。

## 十四、用户已确认的信息（无待问项）

### 14.1 本次 cockpit 的开发范围

此前需要在下面两种范围中确认：

1. **只按 06 集采首页定稿**：只做坑口和价格趋势，对应 `kengk/mt/gc` 三个接口；
2. **按原四台账总需求补齐驾驶舱**：除上述三个接口外，还要修日金额 `categoryAmount/situA` 和日计划 `doRate`。

当时准备的话术是：

> “我核了一下，06 集采首页只用坑口和价格趋势，对应 kengk、mt、gc 三个接口；但原四台账需求还要求日金额和日计划更新驾驶舱。目前日金额的 test 开关没开且没有按前一日过滤，日计划也还在读旧缓存。请确认这次说的 cockpit 是只做 06 这三个接口，还是四个台账的驾驶舱联动全部补齐？”

**最终答复：只按照 06 取值需求定稿，不需要补齐原来的四个台账的驾驶舱需求。已按此开发。**

### 14.2 中厚板 test 数据（不阻塞编码）

标准指标名已经确定，不需要再问产品字段。此前只需确认联调时是否补至少一条 `中厚板月成交价格` 测试数据。

**最终答复：有了字段就行，先开发，不用管数据。已按空点完成验证，没有向共享 test 库造数。**
