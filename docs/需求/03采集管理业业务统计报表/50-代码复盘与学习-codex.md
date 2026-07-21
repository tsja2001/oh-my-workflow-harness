# 集采管理业务统计报表 · 相似代码逻辑跟读手册

> 日期：2026-07-21
> 工具：codex
> 当前状态：已核实现有“交易数据报表”的写入、定时、ES、查询、导出和页面链路；本文按“先业务电影、再核心方法、最后框架零件”的顺序重写。
> 下一阶段：第一轮只学第 1～3 章，读到 3.6 就停；能复述 OUT 的“定时间→查数据→转字段→存 ES”后，再进入第 4 章。
> 深度：深度 ｜ 最终代码基线：source `origin/prod@8eef3668f`、order `origin/prod@b834ffca9`、report `origin/prod@14d10a5`、前端 `prod@75c270d`

## 0. 先约定学习方法

这次先不从 Model、注解、配置开始，也不一上来跳三个仓库。

第一遍只研究一个问题：

> 一张已经审批通过的“非平台采购单”，究竟怎样从 MySQL 复制成一条 ES 报表数据？

先把这一条链路看懂，再解释：

1. 谁每天自动触发它；
2. 页面以后怎样从 ES 查出来；
3. 招采平台和内部协同怎样套同一个模式；
4. 当前新需求在旧模式上要改什么。

文中出现的示例单号、企业和金额都是为了教学虚构的，不是运行数据。

## 1. 宏观总览：这个旧功能到底在干什么

### 1.1 它解决的问题

旧“交易数据报表”要在一个页面同时展示三类交易：

- `ZC`：招采平台中标；
- `OUT`：非平台录入，也就是绿色通道；
- `IN`：内部协同订单。

三类数据原来分散在不同表、甚至不同微服务里。页面如果临时跨库现查，逻辑会很乱。因此同事用了一个中间报表库 ES：

```text
各业务自己的 MySQL
        ↓ 每天复制并翻译字段
同一个 ES 报表索引
        ↓ 统一查询
report 后端
        ↓
报表页面 / Excel
```

这里的“同步”是复制，不是搬走：

- MySQL 里的原业务数据仍然保留，是业务事实来源；
- ES 保存一份为报表准备的副本；
- 报表页面只查 ES，不反过来修改采购业务。

### 1.2 整套系统其实只有两条大链路

#### 链路 A：写入链路

```text
定时任务或手动接口
  → 业务 Service 查询 MySQL
  → 筛选符合统计口径的数据
  → 改造成统一的 ES 字段
  → saveAll 写入 ES
```

#### 链路 B：读取链路

```text
用户打开报表页面
  → 前端请求 report 服务
  → report 服务带查询条件和数据权限查 ES
  → 返回分页数据，或生成 Excel
```

这两条链路不要混在一起读：

- source/order 负责“往 ES 里放”；
- report 负责“从 ES 里拿”；
- Vue 页面负责“展示和下载”。

### 1.3 先只看 OUT 非平台这一条数据的完整电影

假设 MySQL 已经有一张绿色通道业务：

```text
采购业务编号：FPT-001
审批状态：101（通过）
是否内部企业：1
创建时间：2026-07-20 10:00
审批更新时间：2026-07-20 16:00
采购企业：A 公司
供应商：B 公司
含税总金额：1000
```

第二天凌晨 02:40，系统按以下顺序工作：

| 顺序 | 发生什么 | 输入 | 输出 |
|---|---|---|---|
| 1 | XXL-JOB 到点触发 | 任务 238，参数 `{}` | 找到 `syncGreenChannelData` |
| 2 | 计算扫描日期 | 没传日期 | 2026-07-20 00:00～23:59:59.999 |
| 3 | 查询 MySQL | 日期 + 审批通过 + 内部企业 | 得到绿色通道主单列表 |
| 4 | 转换字段 | 一张 `SupplierGreenChannel` | 一张 `TradeDataReportModel` |
| 5 | 写入 ES | Model 列表 | `index_web_trade_data_test` 中的文档 |
| 6 | 用户打开页面 | 查询条件 | report 服务从 ES 返回记录 |
| 7 | 前端显示 | `dataSource=OUT` | 页面显示“非平台录入” |

这就是全部主线。后面的 Java 类都只是为这七步服务。

## 2. 先把核心逻辑翻译成伪代码

同事的核心代码都集中在：

```text
TradeDataReportServiceImpl.syncGreenChannelData(Date startTime, Date endTime)
```

去掉 Java 语法后，它实际就是：

```js
function syncGreenChannelData(startTime, endTime) {
  // 第一步：决定查哪一天
  const range = normalizeDateRange(startTime, endTime)

  // 第二步：从 MySQL 查符合口径的绿色通道主单
  const channels = mysql.query({
    approveStatus: 101,
    isInner: 1,
    createTimeBetween: range
  })

  // 第三步：把业务表字段翻译成报表字段
  const esDocuments = channels.map(channel => ({
    sourceCode: channel.purchaseBusinessCode,
    buName: channel.buName,
    purchaseCompanyName: channel.companyName,
    purchaseCompanyCode: channel.companyCode,
    supplierName: channel.supplierName,
    taxTotal: channel.totalAmount,
    dealTime: channel.updateTime,
    dataSource: 'OUT',
    createTime: channel.createTime
  }))

  // 第四步：批量写进 ES
  esRepository.saveAll(esDocuments)

  return esDocuments.length
}
```

你以后读任何“多表抽取到 ES”的代码，都先找这四块：

```text
定时间 → 查数据 → 转字段 → 存 ES
```

框架、注解和 Java 语法只是包在这四块外面的壳。

## 3. IDEA 第一遍：只读一个核心方法

当前只打开 `scm-source-all`，不要打开 order、report 和前端。

### 3.1 找到主方法

1. 在 IDEA 按 `Ctrl+N`。
2. 输入 `TradeDataReportServiceImpl` 并打开。
3. 按 `Ctrl+F12` 打开当前类的方法目录。
4. 搜索并选择参数为两个 `Date` 的：

```java
syncGreenChannelData(Date startTime, Date endTime)
```

它位于：

```text
scm-source-chase/src/main/java/
com/pcitc/scm/source/chase/service/impl/
TradeDataReportServiceImpl.java:273-363
```

第一次先忽略文件顶部的 import、`@Autowired` 和其他方法。

### 3.2 第一块：决定查哪段时间

看 `TradeDataReportServiceImpl.java:277-293`。

它处理三种情况：

| 传参情况 | 最终查询范围 |
|---|---|
| 开始、结束都没传 | 昨天一整天 |
| 只传一个日期 | 那个日期一整天 |
| 两个都传 | 使用传入的区间 |

例如任务在 7 月 21 日执行且没有参数：

```text
actualStartTime = 7 月 20 日 00:00:00.000
actualEndTime   = 7 月 20 日 23:59:59.999
```

这一块只回答：**今天要扫描哪段业务数据？**

### 3.3 第二块：从 MySQL 查哪些单

看 `TradeDataReportServiceImpl.java:295-302`。

Java 写法是：

```java
LambdaQueryWrapper<SupplierGreenChannel> channelQuery = Wrappers.lambdaQuery();
channelQuery.eq(SupplierGreenChannel::getApproveStatus, 101);
channelQuery.eq(SupplierGreenChannel::getIsInner, 1);
channelQuery.ge(SupplierGreenChannel::getCreateTime, actualStartTime);
channelQuery.le(SupplierGreenChannel::getCreateTime, actualEndTime);
List<SupplierGreenChannel> channels = supplierGreenChannelMapper.selectList(channelQuery);
```

把它当成 Node query builder 即可，含义接近：

```sql
SELECT *
FROM sc_supplier_green_channel
WHERE approve_status = 101
  AND is_inner = 1
  AND create_time >= :actualStartTime
  AND create_time <= :actualEndTime;
```

这里有三个对象不要混：

| 名字 | 是什么 |
|---|---|
| `channelQuery` | 尚未执行的查询条件 |
| `supplierGreenChannelMapper` | MySQL 数据访问入口 |
| `channels` | SQL 执行后得到的业务主单列表 |

如果 `channels` 为空，`307-310` 行直接返回 0，后面不会写 ES。

这一块只回答：**哪些业务单有资格进入报表？**

### 3.4 第三块：一张业务单怎样变成一张 ES 文档

看 `TradeDataReportServiceImpl.java:312-350`。

循环每取到一张 `channel`，就创建一张空的报表对象：

```java
TradeDataReportModel model = new TradeDataReportModel();
```

然后逐字段填写：

| 原业务字段 `channel` | ES 报表字段 `model` | 业务意思 |
|---|---|---|
| `buName` | `buName` | 板块名称 |
| `companyName` | `purchaseCompanyName` | 采购企业名称 |
| `companyCode` | `purchaseCompanyCode` | 采购企业编码 |
| `supplierName` | `supplierName` | 供应商名称 |
| `purchaseBusinessCode` | `sourceCode` | 展示编号，同时作为旧报表 ES ID |
| `totalAmount` | `taxTotal` | 整单含税金额 |
| `updateTime` | `dealTime` | 旧代码认定的审批结束时间 |
| 固定值 `OUT` | `dataSource` | 说明来自非平台录入 |
| `createTime` | `createTime` | 原单创建时间 |

字段转换完成后，`models.add(model)` 把它加入待保存列表。

这一块只回答：**业务表的一列，应该放到报表的哪一列？**

### 3.5 第四块：批量写 ES

看 `TradeDataReportServiceImpl.java:353-358`：

```java
tradeDataReportRepository.saveAll(models);
```

这行就是实际写入动作。

`saveAll` 会逐个查看每张 Model 的 ES ID：

- ID 不存在：新增；
- ID 已存在：覆盖更新；
- 所以同一天重复执行通常不会再增加一份相同 ID 的数据。

这一块只回答：**转换好的报表对象最终在哪里落地？**

### 3.6 到这里先停一下

现在你应该能把这个方法复述为：

> “先算日期，再按审批状态、内部企业和创建时间查绿色通道主表；然后循环把每张业务单翻译成报表 Model，最后一次 saveAll 写 ES。”

如果这句话还说不顺，先不要继续点其他文件，重新看 3.2～3.5。

## 4. 第二遍：核心方法周围的五个零件分别干什么

理解核心方法后，再看周围文件就不会像盲人摸象。

### 4.1 一张调用关系图

```text
TradeDataReportController        手动按钮
              │
TradeDataReportService           能力目录
              │
TradeDataReportServiceImpl       查 → 转 → 存的核心逻辑
              │
     ┌────────┴────────┐
TradeDataReportModel   TradeDataReportRepository
ES 文档长什么样         把文档写进 ES
              │
SourceChaseConfig       告诉 Model 真实索引名
```

### 4.2 Model：目的地的数据结构

1. `Ctrl+N` 搜 `TradeDataReportModel`。
2. 打开 source 包下的类。

它不是取数逻辑，只是规定“一张 ES 文档长什么样”：

- `@Document`：指向哪个索引；
- `@Id`：哪个字段是 ES ID；
- `@Field`：各字段在 ES 中是什么类型。

`TradeDataReportModel.java:56-59` 把 `sourceCode` 标为 `@Id`。因此前面 `model.setSourceCode(...)` 不只是赋展示编号，也决定重复写入时覆盖哪条数据。

### 4.3 Repository：ES 数据访问入口

1. `Ctrl+N` 搜 `TradeDataReportRepository`。
2. 打开 source 包下只有 8 行的接口。

它继承：

```java
ElasticsearchRepository<TradeDataReportModel, String>
```

Spring Data 自动生成实现，所以你看不到 `saveAll` 的方法正文。它类似已经由框架生成好的数据访问对象。

### 4.4 Controller：人工触发入口

1. `Ctrl+N` 搜 `TradeDataReportController`。
2. 找 `syncGreenChannelToEs`，位于 `60-65` 行。

这个接口只做两件事：

```text
接收 startTime/endTime
  → 调刚才已经读懂的 syncGreenChannelData(Date, Date)
```

所以 Controller 不是业务核心，只是“人工按一下同步按钮”的门口。

### 4.5 Service 接口：给 Controller 和定时平台看的能力目录

1. 在 Controller 的 `syncGreenChannelData` 调用上按 `Ctrl+B`。
2. 会进入 `TradeDataReportService.java`。

接口里有两个同名方法：

```java
syncGreenChannelData(SyncParam param)
syncGreenChannelData(Date startTime, Date endTime)
```

关系是：

```text
XXL-JOB/AIM 传一个 SyncParam
  → 实现类把字符串日期解析成 Date
  → 再调用真正的 Date, Date 核心方法

Controller 已经拿到 Date
  → 直接调用 Date, Date 核心方法
```

两种入口最后汇合到同一套查、转、存逻辑，不会维护两份算法。

### 4.6 Config：告诉 Model 到底写哪个物理索引

Model 上写的是：

```java
@Document(indexName = "#{@sourceChaseConfig.getTradeDataReportIndex()}")
```

正确文件是：

```text
scm-source-all/scm-source-chase/.../config/SourceChaseConfig.java
```

里面没有手写 getter，只有：

```java
@ConfigurationProperties(prefix = "source.chase.es")
@Data
public class SourceChaseConfig {
    private String tradeDataReportIndex;
}
```

完整逻辑是：

```text
Nacos 中 source.chase.es.tradeDataReportIndex 的值
  → Spring 填入字段 tradeDataReportIndex
  → Lombok @Data 自动生成 getTradeDataReportIndex()
  → @Document 调 getter得到物理索引名
```

所以搜不到 getter 正文不是 Git 错了；它由 Lombok 在编译时生成。

项目里还有 report 包的同名 `SourceChaseConfig`，读取方法叫 `getTradeDataMateIndex()`。判断是否打开正确类，要看包名是不是：

```text
com.pcitc.scm.source.chase.config.SourceChaseConfig
```

## 5. 第三遍：每天自动执行是怎样接上核心方法的

前面已经知道手动接口怎样触发。定时任务只是另一个开关：

```text
XXL-JOB 管理台
  → 公共 simpleJobHandler
  → AIM 按名字找到 Service 方法
  → SyncParam 版本
  → Date, Date 核心版本
  → 查、转、存
```

### 5.1 业务方法怎样登记自己的名字

打开 `TradeDataReportService.java`：

```java
@TypeMapping("tradeDataReportService")
public interface TradeDataReportService {

    @MethodMapping("syncGreenChannelData")
    int syncGreenChannelData(SyncParam param);
}
```

大白话：

- `TypeMapping` 是业务能力组名；
- `MethodMapping` 是组里的方法名；
- AIM 可以根据这两个字符串找到 Java 方法。

### 5.2 test 管理台实际传了什么

任务 238 的配置已经从 test 调度库核实：

```text
执行时间：每天 02:40
handler：simpleJobHandler
参数：source-tradeDataReportService-syncGreenChannelData-{}
```

四段分别是：

```text
source                         应用名
tradeDataReportService         @TypeMapping
syncGreenChannelData           @MethodMapping
{}                             空 JSON 参数
```

空 JSON 最终让核心方法使用“昨天一整天”。

### 5.3 公共入口怎样分发

如果想继续深挖，再打开公共组件：

```text
scm-assemblies-all/scm-scheduling-all/
xxl-job-executor/.../XxlJobComponent.java:57-60
```

它取到任务参数后，交给：

```text
XxlJobExecutorServiceImpl.java:25-40
```

后者拆出四段，再让 AIM 调业务方法。

这部分属于公司公共能力。开发当前报表时通常只需要：

1. 在 Service 接口加 `@TypeMapping/@MethodMapping`；
2. 在管理台按约定填写参数；
3. 不需要自己重写一个 XXL-JOB 执行器。

### 5.4 一个已确认的公共参数坑

公共代码使用 `commonStr.split("-")`。日期 `2026-07-20` 自己也有横线，因此不能安全把带日期的 JSON 塞进这套任务参数。

- 每天自动任务传 `{}` 没问题；
- 指定日期补跑先走手动 HTTP 接口更稳妥；
- 不要以为 Service 支持日期字符串，就等于 XXL 管理台这层也安全支持。

## 6. 第四遍：数据写入 ES 后，页面怎样读出来

现在切换到读取链路：

```text
Vue 页面
  → SourceMetaQueryController
  → SourceMetaQueryServiceImpl
  → ElasticsearchOperations 查 ES
  → PageList / Excel
```

### 6.1 为什么不让 source 自己提供报表查询

source 和 order 是数据生产者，各自只懂自己的业务表。report 服务是统一读取者，它不关心一条数据原来来自哪张 MySQL 表，只认公共 ES 字段。

好处是：以后增加第四、第五个来源，只要继续写同一个 ES 合同，页面查询入口不需要跨五个服务拼结果。

### 6.2 report 的三个入口

`scm-report-all` 当前本地 `dev` 比最终代码旧。用 IDEA `Alt+9` 打开 Git Log，搜索提交 `ca42a46`，在 Changes 中打开 `SourceMetaQueryController.java`：

| 方法 | 行号 | 用途 |
|---|---:|---|
| `getTradeDataSummary` | 226-229 | 算昨日、当月、当年、累计金额 |
| `getTradeDataPageList` | 237-247 | 查分页列表 |
| `downloadTradeData` | 257-275 | 下载 Excel |

### 6.3 分页方法的完整逻辑

在同一提交打开 `SourceMetaQueryServiceImpl.java:1494-1556`：

```text
先取当前用户可看的采购企业编码
  → 再加供应商、采购企业、板块、来源、时间条件
  → 设置页码、每页数量
  → 按 dealTime 倒序查 ES
  → 把 ES SearchHit 转成 PageList
```

这里的核心仍然是“先组条件，再查询”，只是数据源从 MySQL 换成了 ES。

### 6.4 汇总和列表为什么可能对不上

2026-07-21 实测：

- ES 有 39 条；
- 汇总接口返回累计金额 2,953,786.55；
- 当前登录账号的分页列表成功返回，但可见 0 条。

原因不是 ES 丢数据：

- 汇总方法 `1393-1490` 没加采购企业权限，算全索引；
- 分页方法 `1498-1504` 加了当前用户可见企业权限。

所以“汇总有钱、列表没行”是旧功能当前逻辑造成的。

### 6.5 Excel 是怎样生成的

`SourceMetaQueryServiceImpl.java:1559-1613`：

```text
复用分页查询并把上限设为 10000
  → 定义 Excel 表头
  → 循环把每个 Model 变成一行单元格
  → EasyExcel 写到 HTTP 输出流
```

它复用了分页查询，所以继承相同查询条件和数据权限。

### 6.6 前端最后做什么

在 `scm-vue-all-productmgt` 按 `Ctrl+Shift+N` 搜：

```text
nbxtTransactionDataReport/index.vue
```

只看四处：

| 行号 | 逻辑 |
|---:|---|
| 98-103 | 把 `ZC/OUT/IN` 转成中文 |
| 141-158 | 定义页面表格列 |
| 176-205 | 组查询参数并请求分页接口 |
| 245-254 | 请求下载接口 |

前端不查 MySQL、不写 ES，也不懂定时任务。它只负责把查询条件交给 report，并把结果显示出来。

## 7. 主链路懂了以后，再看另外两个来源

三个来源使用同一个四步骨架：

```text
定时间 → 查业务数据 → 转公共 Model → saveAll
```

区别只在“查哪些表、怎样映射字段”。

### 7.1 ZC 招采平台为什么要查两张表

核心方法：

```text
TradeDataReportServiceImpl.syncZcDealData(Date, Date)
```

两张表各自掌握不同信息：

```text
sc_deal_detail
  中标供应商、含税金额、schemeId

sc_source
  寻源编号、板块、采购企业、公示时间、schemeId
```

代码顺序：

1. `90-95`：从字典取得内部企业编码；
2. `116-121`：查符合条件的中标明细；
3. `130-137`：收集 schemeId，一次批量查 Source；
4. `146-153`：做成 `schemeId → Source` 的 Map；
5. `156-182`：把中标明细和 Source 字段拼成 Model；
6. `185-188`：`saveAll`。

为什么先批量查再做 Map？

如果循环每条中标明细再查一次 Source，N 条数据会多查 N 次数据库。现在是两次批量 SQL，再在内存配对，性能更稳定。

### 7.2 IN 内部协同为什么在 order 服务写

order 服务最懂订单表，因此它自己负责抽取：

```text
to_order
  + exists(to_order_product.is_internal = 1)
  + 组织服务补板块
  → TradeDataReportModel(dataSource=IN)
  → 同一个 index_web_trade_data_test
```

最终代码在 order 的 `origin/prod`，本地 `dev` 没有。用 IDEA `Alt+9` 搜提交 `fbca40ec8`：

- `MallReportMapper.java:129-142`：订单 SQL；
- `InOrderReportServiceImpl.java:73-102`：查、转、存；
- `InOrderReportServiceImpl.java:227-247`：字段转换；
- `TradeDataReportRepository`：写同一个 ES 索引。

test 任务 236 每天 00:10 执行，2026-07-21 返回 200。ES 里的 21 条 `IN` 数据与这一路唯一写 `dataSource=IN` 的代码和运行配置相互印证。

### 7.3 为什么三个仓库可以写同一个 ES

source、order 各有自己的写入 Model `TradeDataReportModel.java`，report 有自己的读取 Model `TradeDataMetaModel.java`，它们不是共用同一个 Java 文件。

它们能协作，依靠的是：

```text
相同物理索引名
+ 相同 ES 字段名
+ 相同字段类型
+ 一致的 ID 规则
```

这叫“数据合同”。Java 文件可以分开，合同不能各写各的。

## 8. 现在把旧逻辑迁移到当前 FP 需求

### 8.1 先看最关键的变化

| 四步骨架 | 旧 OUT | 当前 FP |
|---|---|---|
| 定时间 | 默认昨天 | 默认昨天，历史支持指定范围 |
| 查数据 | 主表；审批通过、内部企业、创建时间 | 主表 + 明细；审批通过、分类 101/102/103、审批结束时间；内外全量 |
| 转字段 | 一张主单变一条 ES | 一条物料变一条 ES |
| 存 ES | 旧索引，ID=业务编号 | 新索引，ID=业务编号+物料编码 |

当前真正新增的复杂度只有一个：**主表一单要展开成多条物料。**

### 8.2 当前需求核心算法

开发时真正要实现的是：

```js
function syncFp(startTime, endTime) {
  // 1. 查符合口径的主单
  const channels = queryGreenChannels({
    approveStatus: 101,
    purchaseBusinessTypeIn: ['101', '102', '103'],
    updateTimeBetween: [startTime, endTime]
  })

  // 2. 一次查出这些主单的全部物料
  const projects = queryProjectsByChannelIds(
    channels.map(item => item.channelId)
  )

  // 3. 按 channelId 把物料归到各自主单下面
  const projectMap = groupBy(projects, 'channelId')

  // 4. 一单 N 条物料，就生成 N 条 ES 文档
  const documents = []
  for (const channel of channels) {
    for (const project of projectMap[channel.channelId] || []) {
      documents.push({
        id: channel.purchaseBusinessCode + project.productCode,
        planCode: channel.purchaseBusinessCode,
        planName: channel.purchaseBusinessName,
        materialCode: project.productCode,
        materialName: project.productDesc,
        categoryCode: project.categoryCode,
        categoryName: project.categoryName,
        taxTotal: project.totalPrice,
        bookTime: channel.updateTime,
        isCentralized: channel.isJc,
        purchaseType: channel.isJc === 1 ? '集团集采' : '分散采购',
        dataSource: 'FP'
      })
    }
  }

  repository.saveAll(documents)
}
```

这就是当前阶段一的业务核心。Java 代码会比伪代码长，但不能改变这条顺序。

### 8.3 为什么当前不能原样复制旧代码

| 旧代码 | 原样复制的后果 | 当前做法 |
|---|---|---|
| 按 `create_time` 扫 | 创建早、审批晚的单永远漏掉 | 按已确认的 `update_time` 扫 |
| `is_inner=1` | 漏掉外部供应商 | 不加该条件 |
| 只查主表 | 没有物料、类目和明细金额 | 批量查 `sc_supplier_channel_projects` |
| 金额取 `total_amount` | 一单多物料会重复整单金额 | 取每条明细 `total_price` |
| ID=业务编号 | 同单物料互相覆盖 | `planCode + materialCode` |
| 直接用 `bu_name` | 同板块出现多个脏名称 | 按 `bu_code` 转 `Owningplate` 标准名 |
| 来源 `OUT` | 不符合新公共合同 | 固定写 `FP` |
| 默认自动建索引 | 多服务可能同时争抢建索引 | order 创建，source `createIndex=false` |
| 提供清空整个索引接口 | 会把其他来源一起删除 | 新功能不提供全索引删除接口 |

### 8.4 阶段一各文件为什么存在

| 新文件 | 只负责什么 |
|---|---|
| `CentralizedProcurementReportServiceImpl` | 上面的核心算法：查主单、查物料、转字段、保存 |
| `CentralizedProcurementReportService` | 给手动入口声明同步能力；以后再加定时注解 |
| `CentralizedProcurementReportModel` | 新索引 18 个字段和 ID 类型 |
| `CentralizedProcurementReportRepository` | 执行 `saveAll` |
| `CentralizedProcurementReportController` | 第一阶段手动传小日期范围验证 |
| `SourceChaseConfig` 新字段 | 从 Nacos 获取新索引名 |

第一阶段只做到：

```text
手动接口
  → 小日期 MySQL 数据
  → 转成新 Model
  → 写入新 ES
  → 对账数量和字段
```

这一步通过前，不做历史补数、定时任务、report 或前端。

## 9. 最后再理解框架名词

| 名词 | 在本流程中的唯一作用 | Node 类比 |
|---|---|---|
| `@RestController/@PostMapping` | 声明手动 HTTP 入口 | Express route |
| `@Service` | 让 Spring 管理业务实现对象 | service 容器注册 |
| `@Autowired` | 把需要的 Mapper/Repository 自动放进来 | 依赖注入 |
| `LambdaQueryWrapper` | 组装 MySQL WHERE 条件 | query builder |
| `@Document/@Field/@Id` | 声明 ES 索引、字段类型和 ID | Mongoose schema |
| `ElasticsearchRepository` | 提供 `save/saveAll` | ODM 数据访问对象 |
| `@Data` | 编译时生成 getter/setter | 自动生成访问器 |
| `@ConfigurationProperties` | 把 Nacos/Spring 配置填入 Java 字段 | 配置对象绑定 |
| `@TypeMapping/@MethodMapping` | 让 AIM 能按字符串找到业务方法 | RPC 方法注册表 |
| EasyExcel | 把 Java 行列表写成 xlsx | Excel 导出库 |

先理解业务顺序，再记这些名字。它们不会改变“定时间、查数据、转字段、存 ES”的核心。

## 10. 事实、归属、风险和运行证据

### 10.1 归属边界

| 归属 | 内容 |
|---|---|
| source 业务代码 | ZC/OUT 的筛选、字段映射、写 ES |
| order 业务代码 | IN 订单筛选、字段映射、写 ES |
| report 业务代码 | ES 汇总、权限分页、Excel |
| 前端业务代码 | 查询表单、列表、来源中文、下载动作 |
| 公司公共能力 | AIM、数据权限、请求/响应转换、XXL 通用执行器 |
| 第三方能力 | MyBatis-Plus、Spring Data Elasticsearch、EasyExcel |
| 外部配置 | Nacos 索引名、XXL-JOB cron、菜单权限 |

### 10.2 五态和运行证据

| 能力 | 已实现 | 已配置/部署 | 已验证 | 证据 |
|---|---|---|---|---|
| ZC 每日写入 | 是 | 是 | 2026-07-21 任务 237 返回 200 | `syncZcDealData`、test 调度库 |
| OUT 每日写入 | 是 | 是 | 2026-07-21 任务 238 返回 200 | `syncGreenChannelData`、test 调度库 |
| IN 每日写入 | 是 | 是 | 2026-07-21 任务 236 返回 200 | `syncInOrderToEs`、test 调度库 |
| 旧公共索引 | 是 | 是 | 39 条：IN 21 / OUT 9 / ZC 9 | test ES 查询 |
| 汇总接口 | 是 | 是 | 累计 2,953,786.55 | test API |
| 分页接口 | 是 | 是 | 接口成功，当前账号因权限可见 0 条 | test API + 权限代码 |
| 当前新索引 | 代码尚未开发 | 尚未部署 | test 尚不存在 | `scripts/esq.sh indices` |

任务 200 只证明调用没报错；当天没业务时写入 0 条也可能是正常成功。

### 10.3 变更时间线

| 提交 | 变化 | 当前状态 |
|---|---|---|
| source `5d4386bae` | 加入 ZC/OUT 同步主体 | 保留 |
| source `bb67dec85` | 从专用 Job 改为公共 AIM 调度 | 最终方式 |
| order `fbca40ec8` | 加入 IN 订单同步主体 | 保留 |
| order `1d80536b0` | 删除专用 Job，改公共 AIM 调度 | 最终方式 |
| report `ca42a46` | 加入汇总、分页和导出 | 保留 |
| 前端 `ee23c50`、`1f3d812` | 加入交易报表页面 | 保留 |

### 10.4 旧功能已确认的边界

1. OUT 按创建时间扫描会漏掉跨天审批单；当前新功能不得照搬。
2. ZC 循环中标明细却用 `sourceCode` 作 ID，一寻源多明细可能覆盖；这是旧代码风险，不在本轮修复。
3. 汇总无企业权限、分页和导出有企业权限，数字可能看起来不一致。
4. 前端把来源转中文，旧后端导出仍直接写编码。
5. order 转换每条订单都远程查一次板块，存在 N+1；当前 FP 应一次取字典后做 Map。
6. 公共 XXL 参数用横线切割，不能安全承载带横线的日期 JSON。

## 11. 掌握度验收

### 11.1 30 秒复述

> “旧交易数据报表分写入和读取两条链。source 服务每天从绿色通道主表筛审批通过、内部企业、昨天创建的单子，把业务字段转成 TradeDataReportModel，再用 Repository.saveAll 写 ES。XXL-JOB 和手动 Controller 只是两个触发入口，最终都进同一个核心方法。order 服务用相同合同写 IN 数据，report 服务统一从 ES 做汇总、权限分页和 Excel，Vue 只调用 report。当前 FP 继续用这个骨架，但要改成按审批结束时间查主单、批量查物料、一物料一条、金额取明细，并写新索引。”

### 11.2 不看文档回答

1. OUT 核心方法的四个步骤是什么？
2. `channels` 和 `models` 分别装的是什么？
3. 哪一行真正写 ES？
4. Controller 和 XXL-JOB 的区别是什么？共同点是什么？
5. Model、Repository、ServiceImpl 分别负责什么？
6. 为什么 getter 源码里找不到？
7. 为什么 report 不直接查三个业务库？
8. 当前 FP 为什么必须再查物料明细表？
9. 一张主单有三条物料，应该生成几张 ES 文档？
10. 为什么当前不能照搬旧 OUT 的 `create_time` 和 `is_inner=1`？

如果前五题能说顺，说明旧流程主链路已经懂了；十题都能说顺，就具备进入当前需求阶段一开发所需的整体认知。
