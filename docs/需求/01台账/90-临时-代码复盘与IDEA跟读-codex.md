# 台账1（集采日金额统计台账）· 代码复盘与 IDEA 跟读手册

> 日期：2026-07-13<br>
> 工具：codex<br>
> 当前状态：已根据 2026-07-08 至 2026-07-10 的 Git 提交、`origin/test` 最终代码和 test 库真实数据完成复盘。<br>
> 下一阶段：你按本文在 IDEA 中跟读；和负责人确认驾驶舱的日期口径和开关时，可直接使用本文第 11 节话术。

> 本文只讲“台账1：集采日金额统计台账”。“台账2：煤炭重点坑口日指标”在 `docs/需求/台账需求2/90-临时-代码复盘与IDEA跟读-codex.md`。

---

## 1. 先纵览：你这个需求到底改了什么

一句话：你在寻源服务里新增了一本“每行记一笔集采金额”的电子账本，补齐了增删改查、Excel 导出、组织/字典选项，并让驾驶舱的四个类目和“机电公司”行具备从新台账汇总金额的能力。

最终落地内容：

| 交付面 | 你做的事 | 最终证据 |
|---|---|---|
| 数据库 | 新建 `sc_collection_daily_amount_ledger` 单表 | test 库现有 10 条：6 条有效、4 条逻辑删除 |
| 标准台账接口 | 分页、新增、修改、删除、详情 | `CollectionDailyAmountLedgerController` 的 5 个主接口 |
| 业务流水号 | 自动生成 `JCRJE-yyyyMMdd-NNN` | test 库已有 `JCRJE-20260709-001` 等数据 |
| 查询条件 | 流水号模糊，执行单位/采购企业按名称模糊，类目/板块按编码，日期区间 | `ServiceImpl` 第 75～91 行 |
| 删除 | 从“手动更新删除字段”修正为 MyBatis-Plus 逻辑删除 | `350e3f2cd` |
| Excel | 分页接口同时承担导出，默认模板编码 `collection-daily-ledger-export` | UBM test 库有 1 个主模板 + 9 列配置 |
| 下拉数据 | 组织搜索、集采类目字典、所属板块字典 | `a4a245926`，后续用组织短名显示 |
| 驾驶舱 | 1501/1701/2302/2502 四类目与机电公司行改为可汇总台账 | `2f33fa77f`；test 字典开关当前仍为 0，尚未走新 SQL |

你没有修改前端页面，也没有用 Java 写菜单和岗位权限。这些是前端和平台配置的交付面。

---

## 2. 先建立一张全景图

用 Node/Koa 的经验对照，这套 Java 分层并不神秘：

```text
前端表单 / Postman
        ↓ JSON / 分页参数
Controller             ≈ Koa Router，定义 URL
        ↓
Service 接口        ≈ 业务函数的 TypeScript interface
        ↓
ServiceImpl            ≈ services/xxx.js，真正的业务逻辑
        ↓
Mapper                  ≈ ORM model/repository，与数据库交互
        ↓
Model ↔ 数据库表   ≈ Sequelize Entity ↔ MySQL Table

DTO 贯穿请求与返回   ≈ 接口的 JSON schema / TypeScript type
Seq 只负责编号       ≈ generateOrderNo()
```

请求能自动找到你的类，是因为：

1. `scm-cloud-source` 启动器的 `SourceApp` 导入 `SourceWebConfig` 和导出、序列号等公共组件。
2. `SourceWebConfig` 扫描 `controller` / `service` / `repositories` 包。
3. 因此你只新建标准包路径下的类，不需要去修改 `main()` 启动类。

这是微服务的“业务 jar + 启动壳”模式：`01zhaocai-end` 是真正业务代码，`03zhaocai-start` 负责把业务 jar 装进 Spring Boot 服务并跑起来。

---

## 3. Git 时间线：你从第一次提交后做了什么

| 时间 | 功能提交 | 含义 | 是否仍在最终代码中 |
|---|---|---|---|
| 07-08 18:50 | `aa4747310` | 新增 7 个文件，完成台账基础 CRUD 和 JCRJE 流水号 | 是 |
| 07-09 09:03 | `350e3f2cd` | 修复“删除接口返回成功但数据还在” | 是 |
| 07-09 11:46 | `49331ea2a` | 给分页接口加通用导出能力 | 是 |
| 07-09 14:05 | `2f33fa77f` | 驾驶舱四类目+机电公司行改查台账 | 是，但开关为 0 时不生效 |
| 07-09 14:09 | `ca52c5b8f` | 在代码里给导出模板设默认编码 | 是 |
| 07-09 14:45 | `dd910b1c4` | 让导出时的日期格式固定 | 是 |
| 07-09 15:49 | `a4a245926` | 新增组织搜索和两个字典接口 | 是 |
| 07-10 10:47 | `435d0f6b5` | 删除台账专用组织搜索 | 后来被恢复，不是最终状态 |
| 07-10 11:40 | `73ffeea3e` | 恢复组织搜索 | 是 |
| 07-10 13:56 | `8af713b45` | 组织显示改短名；分页的执行单位/采购企业改为名称 LIKE | 是 |

### 为什么你会看到“同样的提交有两个号”

`aa4747310` / `d005e32c3`、`350e3f2cd` / `0c71984ac`、`49331ea2a` / `6e38a4fbf` 是三组“内容基本相同，但父提交不同”的 Git 历史。这是 AI 在移动/挑拣提交时留下的，不代表功能写了两遍。

你和同事聊时不用背全部 hash，只需要记住“基础 CRUD → 删除修复 → 导出 → 驾驶舱 → 下拉与查询简化”这条业务时间线。

---

## 4. 数据库设计：为什么台账1用一张表

一条数据天然就是一笔可独立查询和汇总的金额：

```text
JCRJE-20260709-006
执行单位=机电公司
类目=钢材(1501)
统计日期=2026-07-08
采购企业=唐山分公司
金额=12800.50元
板块=水泥集团
```

它没有像“一次发布里包含多个坑口”那样的重复子项，所以单表最直接。如果强行拆主子表，查询和导出反而需要额外关联，没有收益。

字段可分五组：

| 字段组 | 例子 | 为什么这样存 |
|---|---|---|
| 技术身份 | `ledger_id` | 程序内部稳定主键，不给人看 |
| 业务身份 | `ledger_no` | 给人沟通、查询和对账；唯一索引防重号 |
| 业务维度 | 单位、类目、日期、企业、板块 | 以后筛选和分组汇总的依据 |
| 数值 | `tax_amount decimal(20,2)` | 金额不用 JavaScript/Java 浮点数，避免 0.1+0.2 精度问题 |
| 审计/删除 | `publish_*` / `create_*` / `update_*` / `delete_sign` | 知道谁发布、谁最后改，删除后仍可追溯 |

编码+名称同时存，是一种企业系统常用取舍：编码用于稳定查询，名称用于快速回显和保留当时的业务快照。如果组织以后改名，历史台账是否跟着改，就是一个要由业务确认的口径。

当前 test 真实数据：总计 10 条，6 条 `delete_sign=0`，4 条 `delete_sign=1`。这正好证明“删除”是隐藏而非物理抹掉。

---

## 5. IDEA 跟读前的准备

以下快捷键按 Windows/Linux 版 IDEA 写。

1. 在 IDEA 打开仓库根目录：`/home/t/projects/work-wsl/01zhaocai-end/scm-source-all`。
2. 右下角点 Git 分支，切到本地 `test`。原因：当前 `feature/taizhang-yang` 是台账2从 prod 建的分支，不包含台账1的全部历史；`test` 才能一次看全两个需求。
3. `Alt+1`：打开/收起 Project 文件树。
4. `Ctrl+Shift+N`：按文件名找文件，这是本文最常用的。
5. `Ctrl+N`：按 Java 类名找类。
6. `Ctrl+F12`：弹出当前文件的方法目录，输入 `add`/`modify` 直达方法。
7. `Ctrl+B` 或按住 `Ctrl` 点击：跳到类/方法定义。
8. `Alt+F7`：查看谁使用了这个方法或字段。
9. `Ctrl+Alt+H`：查看调用层级，特别适合追一个 Service 方法。
10. `Ctrl+Shift+F`：全仓搜文本，例如搜 URL 或表名。
11. `Ctrl+Alt+←`：回到刚才跳转前的位置。如果被 Windows 显卡快捷键占用，用顶部 `Navigate > Back`。
12. `Alt+9`：打开 Version Control，查看 Log 和文件变更。

跟读原则：每次只追一条请求，不要从第 1 行开始硬啃 200 行 Java。

---

## 6. 第一轮：15 分钟读懂“新增一笔台账”

### 第 1 步：从 URL 入口进

`Ctrl+Shift+N` 输入 `CollectionDailyAmountLedgerController`，找到 `add()`。

你只需要看三件事：

- `@PostMapping(.../add)`：这就是 Koa 里的 `router.post('/add', ...)`。
- `@RequestBody ...DTO`：把前端 JSON 转成 Java 对象。
- `service.add(dto)`：Controller 不算业务，只把事转给 Service。

把光标放在 `add` 上按 `Ctrl+B`，会先到 Service 接口；再按 `Ctrl+Alt+H` 或点实现图标，到 `CollectionDailyAmountLedgerServiceImpl#add`。

### 第 2 步：读 ServiceImpl#add

按顺序将 108～116 行翻译成 Node 思维：

```text
const entity = copy(dto)
entity.id = null                       // 不信前端传的主键
entity.ledgerNo = generateJCRJE()      // 服务器自己发号
entity.deleteSign = 0                 // 初始为未删除
fillPublisher(entity)                 // 发布时间和当前登录人
mapper.insert(entity)                 // INSERT
return entity.ledgerNo
```

这里最重要的设计是“服务端控制字段”：主键、流水号、删除状态、发布人不允许前端说了算，否则调接口的人可以伪造“张三发布”或自己指定流水号。

### 第 3 步：追流水号

在 `new CollectionDailyLedgerCodeSequence()` 上 `Ctrl+B`。

- `getPrefix()` 返回 `JCRJE-`。
- `getCenterStr()` 返回当天 `yyyyMMdd-`。
- `getSuffixLength()` 返回 3。
- `getSeqDate()` 把序列的重置边界定在当天 00:00。

合起来就是 `JCRJE-20260709-001`。注意：日期是“录入当天”，不是 `statisticDate`。

### 第 4 步：看 Model 如何落表

在 `CollectionDailyAmountLedger` 上 `Ctrl+B`：

- `@TableName` 指向 `sc_collection_daily_amount_ledger`。
- `@TableId` 指定主键。
- `@TableField("tax_amount")` 将 Java `taxAmount` 映射到 MySQL `tax_amount`。
- `@TableLogic` 告诉 MyBatis-Plus：删除不发 `DELETE`，而是将 `delete_sign` 改 1。
- `FieldFill.INSERT/UPDATE` 由公共组件自动填创建/更新人时间。

读到这里，你已经能完整解释一次 add：“路由收 JSON，Service 生成号码和发布信息，Mapper 按 Model 映射写表。”

---

## 7. 第二轮：读懂查询、修改和删除

### 分页查询

这个方法看起来长，主要是 Java 把“容器里装什么类型”写得很明确。先把尖括号和每个中间变量看懂，整段代码就只剩下“取参数→拼条件→查分页→转 DTO”四步。

#### 7.1 方法签名中的泛型

```java
public PageList<CollectionDailyAmountLedgerDTO> queryListByPage(
        DefaultPageBean<CollectionDailyAmountLedgerDTO> pageBean)
```

泛型就是 `<...>` 里的部分，意思是“这个通用容器里装什么”：

- `DefaultPageBean<CollectionDailyAmountLedgerDTO>`：请求分页容器，它的 `model` 是台账查询条件 DTO。
- `PageList<CollectionDailyAmountLedgerDTO>`：返回分页容器，当页列表中每一条是台账 DTO。

可以类比 TypeScript：

```typescript
type PageList<T> = {
  root: T[]
  total: number
  currentPage: number
  limit: number
}
```

前端大致传入：

```json
{
  "currentPage": 1,
  "limit": 10,
  "model": {
    "ledgerNo": "JCRJE-",
    "executeUnitName": "机电",
    "categoryCode": "1501",
    "statisticDateArr": ["2026-07-01", "2026-07-10"]
  }
}
```

`pageBean` 就是：

```text
pageBean
  ├─ currentPage = 第几页
  ├─ limit       = 每页几条
  └─ model       = 查询条件 DTO
```

#### 7.2 取出查询条件，并防空指针

```java
CollectionDailyAmountLedgerDTO param = pageBean.getModel();
if (param == null) {
    param = new CollectionDailyAmountLedgerDTO();
}
```

`param` 就是前端 `model` 中的查询条件。如果前端没传 `model`，就新建一个全部字段为空的 DTO，表示“没有筛选条件”。

如果不处理，后面执行 `param.getLedgerNo()` 就会对 `null` 调方法，出现 `NullPointerException`。对应 Node：

```javascript
const param = pageBean.model ?? {}
```

#### 7.3 创建查询条件拼装器

```java
LambdaQueryWrapper<CollectionDailyAmountLedger> wrapper = Wrappers
        .lambdaQuery(CollectionDailyAmountLedger.class);
```

`LambdaQueryWrapper<CollectionDailyAmountLedger>` 表示这个 wrapper 专门拼装台账 Entity 对应表的 SQL 条件。`CollectionDailyAmountLedger.class` 是把“这个类本身”传给框架，不是 new 一条台账。

可以把 wrapper 理解为一个还没执行的 SQL `WHERE` 构造器。

#### 7.4 固定条件和方法引用

```java
wrapper.eq(CollectionDailyAmountLedger::getDeleteSign, 0);
```

等价于：

```sql
WHERE delete_sign = 0
```

`CollectionDailyAmountLedger::getDeleteSign` 叫方法引用，这里可以读作“指向 Entity 的 deleteSign 字段”。它比手写字符串 `"delete_sign"` 安全：字段改名时 IDEA 能跟着改，写错时编译就会报错。

由于 Model 还有 `@TableLogic`，MyBatis-Plus 通常也会自动过滤已删数据；这里显式写出是一种保守写法。

#### 7.5 `like/eq/ge/le` 的三参数模式

以流水号为例：

```java
wrapper.like(
    StringUtils.isNotBlank(param.getLedgerNo()),
    CollectionDailyAmountLedger::getLedgerNo,
    param.getLedgerNo()
);
```

三个参数的意思是：

```text
like(是否添加这个条件, 查哪个字段, 查什么值)
```

- `ledgerNo` 有内容：生成 `ledger_no LIKE '%内容%'`。
- `ledgerNo` 为 null、空字符串或全是空格：整个条件跳过。

`StringUtils.isNotBlank()` 的判断：

| 值 | 结果 |
|---|---|
| `null` | false |
| `""` | false |
| `"   "` | false |
| `"机电"` | true |

其他条件只是操作符和字段不同：

| Java | 大白话 SQL |
|---|---|
| `like(ledgerNo)` | 流水号包含输入文字 |
| `like(executeUnitName)` | 执行单位名称包含输入文字 |
| `like(purchaseCompanyName)` | 采购企业名称包含输入文字 |
| `eq(categoryCode)` | 类目编码完全相等 |
| `eq(buCode)` | 板块编码完全相等 |
| `ge(beginStatisticDate)` | 统计日期大于等于开始日期 |
| `le(endStatisticDate)` | 统计日期小于等于结束日期 |

`eq` = equal，`ge` = greater than or equal，`le` = less than or equal。

这些方法连着写叫链式调用。它们每次都返回 wrapper 自己，当前只是累积 SQL 条件，还没有访问数据库。

#### 7.6 排序与真正执行分页查询

```java
wrapper.orderByDesc(CollectionDailyAmountLedger::getCreateTime);
```

即 `ORDER BY create_time DESC`，新创建的数据在前。注意这里不是按统计日期排序。

```java
IPage<CollectionDailyAmountLedger> page = collectionDailyAmountLedgerMapper
        .selectPage(new Page<>(pageBean.getCurrentPage(), pageBean.getLimit()), wrapper);
```

这一行才真正查数据库：

- `new Page<>(currentPage, limit)`：要第几页、每页几条。这里的空 `<>` 表示 Java 能从左边推断出类型。
- `wrapper`：上面拼好的 WHERE 和 ORDER BY。
- `IPage<CollectionDailyAmountLedger>`：MyBatis-Plus 的内部分页结果，里面装的是 Entity。

`page` 中的关键信息：

```text
page.getRecords() → 当页数据 List<Entity>
page.getTotal()   → 符合条件的总条数
page.getCurrent() → 当前页
page.getSize()    → 每页条数
```

例如前端传了流水号、机电、类目和日期，当页 SQL 可以理解为：

```sql
SELECT *
FROM sc_collection_daily_amount_ledger
WHERE delete_sign = 0
  AND ledger_no LIKE '%JCRJE-%'
  AND execute_unit_name LIKE '%机电%'
  AND category_code = '1501'
  AND statistic_date >= '2026-07-01'
  AND statistic_date <= '2026-07-10'
ORDER BY create_time DESC
LIMIT 0, 10;
```

没传的查询条件不会出现在 SQL 中。MyBatis 使用参数绑定，不是手工把前端文字拼进 SQL 字符串。

#### 7.7 为什么 Entity 还要转 DTO

```java
List<CollectionDailyAmountLedgerDTO> dtoList = new ArrayList<>();
List<CollectionDailyAmountLedger> records = page.getRecords();
```

- `List<Entity>`：数据库查出的当页列表。
- `List<DTO>`：准备返回给前端的列表。
- `new ArrayList<>()`：新建空列表，类似 JavaScript 的 `[]`。

```java
if (CollectionUtils.isNotEmpty(records)) {
    for (CollectionDailyAmountLedger entity : records) {
        CollectionDailyAmountLedgerDTO dto = new CollectionDailyAmountLedgerDTO();
        BeanUtils.copyProperties(entity, dto);
        dtoList.add(dto);
    }
}
```

翻译成 Node 就是：

```javascript
const dtoList = records.map(entity => ({ ...entity }))
```

Entity 代表数据库结构，DTO 代表接口合同。DTO 还有数据库不会保存的 `beginStatisticDate/endStatisticDate` 等查询辅助字段，所以不直接把 Entity 返回前端。

#### 7.8 包装项目统一分页格式

```java
return PageList.createPageList(dtoList, page.getTotal(), pageBean);
```

它把当页 DTO 列表、总条数、页码和每页条数合成前端认识的分页结果。Controller 外层再通过 `Result.success(...)` 加上业务成功码。

整个方法压缩后就是：

```text
取 pageBean.model，空就用空条件
  → 按有值字段动态拼 WHERE
  → 按 create_time 倒序做分页查询
  → 当页 Entity 逐条转 DTO
  → 包装成 PageList 返回
```

这次后续需求的关键变化是：执行单位和采购企业直接对名称做 LIKE，前端不需要先调组织接口换编码才查分页。

### 修改

`modify()` 的设计重点不是 `updateById`，而是它之前主动清空的字段：

- `ledgerNo=null`：不允许改流水号。
- `create*=null`：不允许把历史创建人改掉。
- `deleteSign=null`：不允许借修改接口删除/恢复数据。
- `fillPublisher()`：每次修改都算重新发布，刷新最后发布人和时间。

这叫“防字段越权”。前端 DTO 虽然有这些字段，业务层不会照单全收。

### 删除

最早实现是建一个 `deleteSign=1` 的对象后 `updateById`，实测发现只刷新了更新人/时间，数据仍可查。修复后是：

```java
mapper.deleteById(ledgerId);
```

配合 Model 的 `@TableLogic` 和启动配置 `logic-delete-field: deleteSign`，MyBatis-Plus 自动生成逻辑删除 SQL。这个 bug 很值得你记住：框架的“删除语义”不等于普通更新字段。

---

## 8. 第三轮：读懂导出、字典和跨服务调用

### Excel 导出

回到 Controller 的 `queryPageList()`，看 `@DataRequestTransfer`。

设计思路是“查询和导出共用同一套过滤逻辑”：前端普通查询时得到 JSON；传 `exportRequest=true` 时，通用导出组件拦截返回值，按 UBM 模板的 9 列生成 Excel。

为什么列配置放数据库？因为改列名/顺序可以只改配置，无需改 Java 再发版。`field_name` 必须对应 DTO 属性，例如 `statisticDate`，不是数据库列名 `statistic_date`。

### 组织搜索

`queryOrgForSelect()` 通过 `OrgManagerFeignService` 调 UBM 服务。Feign 可以理解成“Java 里封装好的内部 HTTP 客户端”。

最终返回的 `orgName` 取 `shortName`，不取全称 `orgName`。test 库真实例子：

- 全称：“北京金隅集团股份有限公司（总部）”
- 短名：“金隅集团”

这就是 7 月 10 日“下拉名称太长”的根因和修复。

### 数据字典

数据字典可以理解为“全公司下拉框选项的集中仓库”。代码只记住“我要哪一类选项”，具体有几项、显示什么名称、哪项停用，由 UBM 数据字典配置管理。

#### 8.1 为什么不在 Java 里写死选项

如果直接在 Java 中写：

```java
return Arrays.asList("钢材", "润滑剂", "电线电缆", "轴承及备件");
```

以后改名、增加类目或停用某一项，都要改代码、提交、Jenkins 构建和发布。放到字典后，有权限的人修改平台配置即可，后端下次查询就使用最新选项。

字典的典型三层结构是：

```text
字典分组 ubm_dict_group       例如：某个业务模块
  └─ 字典类型 ubm_dict_type   例如：collection_category（集采类目）
       ├─ 字典项 ubm_dict          1501 / 钢材
       ├─ 字典项 ubm_dict          1701 / 润滑剂
       └─ 字典项 ubm_dict          2302 / 电线电缆
```

页面真正需要的是最后一层“编码+名称”列表。

#### 8.2 这次提供了两个字典接口

Controller 中的入口：

```java
POST /e/business/source/collectionDailyAmountLedger/queryCategoryDict
POST /e/business/source/collectionDailyAmountLedger/queryOwningplateDict
```

它们都没有请求体，因为后端已经固定了要查的字典类型：

```java
public List<Map<String, String>> queryCategoryDict() {
    return queryDictByType("collection_category");
}

public List<Map<String, String>> queryOwningplateDict() {
    return queryDictByType("Owningplate");
}
```

两个公开方法复用同一个私有方法，区别只是：

```text
collection_category = 查“集采类目”下拉选项
Owningplate         = 查“所属板块”下拉选项
```

这样做的好处是：查字典、处理空数据和转换返回格式只写一次。

#### 8.3 `queryDictByType()` 逐步解释

```java
private List<Map<String, String>> queryDictByType(String cate) {
    Map<String, String> param = new HashMap<>();
    param.put("cate", cate);
```

`cate` 就是 category/type 的意思，它不是某个具体选项，而是字典类型编码。

例如：

```text
cate = collection_category
意思 = 请把集采类目这一类下的所有启用选项给我
```

然后调用 UBM 微服务：

```java
Result<List<DictDTO>> result = innerFeignService
        .execute(() -> dictFeignService.getDictByType(param));
```

这行可以拆成：

- `DictFeignService`：UBM 字典服务的 Java 内部 HTTP 客户端。
- `getDictByType(param)`：调 UBM 的按类型查字典接口。
- `innerFeignService.execute(...)`：项目统一的内部 Feign 调用包装方式。
- `Result<List<DictDTO>>`：UBM 返回的统一结果，`data` 里是字典 DTO 列表。

为什么 source 服务不直接查 `scm_ubm_test.ubm_dict`？

```text
source 服务负责寻源业务
UBM 服务负责字典、组织、用户等基础数据
```

微服务之间通过 Feign 调用对方接口，而不是业务服务随意跨库查别人的表。这样 UBM 以后改表结构、状态过滤或数据权限时，source 只要接口合同不变就不用跟着改。

#### 8.4 为什么还要把 `DictDTO` 转成 `code/name`

```java
List<Map<String, String>> list = new ArrayList<>();
if (result != null && CollectionUtils.isNotEmpty(result.getData())) {
    for (DictDTO dict : result.getData()) {
        Map<String, String> map = new LinkedHashMap<>();
        map.put("code", dict.getValue());
        map.put("name", dict.getLabel());
        list.add(map);
    }
}
return list;
```

UBM 返回的 `DictDTO` 是通用字典对象，可能还有状态、排序等字段。台账前端只需要两个值：

```json
{
  "code": "1501",
  "name": "钢材"
}
```

因此 Service 做了一层简化和隔离：

```text
UBM DictDTO.value → 台账接口 code
UBM DictDTO.label → 台账接口 name
```

`LinkedHashMap` 会保留放入顺序，因此 JSON 通常会按 `code` 后 `name` 输出；业务上字段顺序不影响取值。

如果 UBM 调用失败或没有数据，当前代码最终返回空列表，前端下拉框就没有选项。

#### 8.5 前端怎么使用 `code/name`

页面显示 `name`，提交和查询主要使用 `code`：

```text
下拉框显示：钢材
选中后保存：categoryCode=1501, categoryName=钢材
分页查询：category_code = '1501'
```

所属板块同理：

```text
下拉框显示：冀东水泥
选中后保存：buCode=BU002, buName=冀东水泥
分页查询：bu_code = 'BU002'
```

为什么库里同时存 code 和 name：

- code 适合关联和查询，不会因为中文改名就对不上。
- name 方便列表直接回显，也保留当时名称快照。

#### 8.6 test 库当前的真实字典数据

`scm_ubm_test.ubm_dict` 的关键字段是：

```text
dict_type_code = 属于哪一类字典
dict_code      = 选项编码
dict_name      = 选项名称
dict_status    = 1 启用 / 0 停用
delete_sign    = 0 有效 / 1 已删
sort_by        = 下拉显示顺序
```

注意：真实表里没有 `dict_value`，不能凭其他项目经验猜字段。

`collection_category` 当前启用项：

| code | name |
|---|---|
| 1001 | 煤炭 |
| 1501 | 钢材 |
| 1701 | 润滑剂 |
| 2302 | 电线电缆 |
| 2502 | 轴承及备件 |

`Owningplate` 当前启用项：

| code | name |
|---|---|
| BU001 | 金隅集团 |
| BU002 | 冀东水泥 |
| BU003 | 混凝土集团 |
| BU004 | 冀东集团 |
| BU005 | 新材产业化集团 |
| BU006 | 地产集团 |
| BU007 | 投资物业集团 |
| BU008 | 天津建材集团 |
| BU009 | 财务公司 |
| BU010 | 北京建研总院 |

一个需要注意的实际口径：原台账需求主要说的是机电公司四大类目 1501/1701/2302/2502，但当前 `queryCategoryDict()` 会返回 `collection_category` 中的全部启用项，包括 1001 煤炭。后端没有再过滤成四项；前端是否应该展示煤炭，要以最终业务口径为准。

#### 8.7 字典查询和台账保存之间的边界

当前字典接口只负责“给前端选项”，并不代表后端 add/modify 会再次去 UBM 验证。

当前实际保存逻辑是：

```text
前端从字典选 code/name
  → 前端将 categoryCode/categoryName 或 buCode/buName 传给 add/modify
  → BeanUtils.copyProperties 直接复制到 Entity
  → 写入台账表
```

也就是说：

- 字典接口解决了“下拉框数据从哪来”。
- 分页查询使用 `categoryCode/buCode` 做精确筛选。
- 当前 add/modify 没有拦住伪造的字典编码，也没有强制校验 code 与 name 是否配对。
- “选采购企业自动带出所属板块”在当前 add 中也没有后端重查组织并覆写，主要依赖前端选择后提交。

所以从更高视角看，现在完成的是“配置驱动的下拉和编码查询”；如果要做成严格后端数据防线，还应在 add/modify 中校验字典编码、名称和组织板块关系。

---

## 9. 第四轮：读懂台账如何影响驾驶舱

### 9.1 先说结论：你不是新做驾驶舱，而是给原驾驶舱换了两小块数据源

驾驶舱就是领导看的大屏。它的前端页面、后端接口、返回对象、开关分流、旧缓存表和大部分实时统计 SQL，都是同事在 2025 年 12 月至 2026 年 1 月已经做好的。

你这次没有新增驾驶舱接口，也没有修改驾驶舱前端。提交 `2f33fa77f` 只改了 `SourceCollectionMapper.java` 一个文件中的 10 行 SQL：

| 驾驶舱位置 | 原来从哪里算 | 你改成从哪里算 | 改动范围 |
|---|---|---|---|
| 左侧“集采类目分项金额” | 全部类目都从 `sc_source_collection` 算 | 只有 1501/1701/2302/2502 四项改查新台账 | 改了 4 个 SQL 分支 |
| 右侧“集采情况分析” | 机电公司从 `sc_source_collection` 算 | 机电公司改为合计新台账四个类目 | 改了 1 个 SQL 分支 |
| 顶部累计、日/月/季/年金额 | `sc_source_collection` | 没改 | 不受台账1影响 |
| 煤炭、办公设备、办公文具 | `sc_source_collection` | 没改 SQL 来源 | 不直接读台账1 |
| 执行率、坑口、趋势图 | `sc_collection_data` 等原逻辑 | 没改 | 不受台账1影响 |

所以最准确的话不是“驾驶舱全部改成读台账”，而是：

> 原驾驶舱在实时计算模式下，四个机电类目和机电公司汇总行被替换为读取台账1；其他指标仍保持原来的数据来源。

从 Git 证据看，驾驶舱接口和基础 Service 来自同事 `LANYU\\10679` 的 `144d296b49`、`76a63329a`、`2556b2ba7`、`391231cf1` 等提交；你的 `2f33fa77f` 只改 Mapper。这就是为什么你看自己提交时只看到 Mapper，却感觉上下文缺了一大块。

### 9.2 一张全链路图：用户打开驾驶舱后发生什么

```text
用户打开“金隅集团集采管理驾驶舱”
        ↓
Vue 页面 created() 同时请求多个板块
        ├─ ..._centerHeader       顶部累计/日/月/季/年
        ├─ ..._categoryAmount    左侧类目分项金额 ← 台账1可能影响
        ├─ ..._doRate            执行率
        ├─ ..._situA             右侧情况分析   ← 台账1可能影响
        ├─ ..._kengk             坑口指标
        └─ ..._mt / ..._gc       价格趋势
                    ↓
同一个 Controller 接口接收不同的 typeCode
                    ↓
SourceCollectionDataServiceImpl 查 UBM 字典 collectionShow
                    ↓
             判断这个 typeCode 的开关
              ┌────────┴────────┐
              │ 开关 = 1        │ 开关不是 1
              │ 实时计算         │ 读旧结果
              ↓                 ↓
SourceCollectionMapper     SourceCollectionDataMapper
手写聚合 SQL               查 sc_collection_data
              └────────┬────────┘
                       ↓
统一返回 List<SourceCollectionData>
                       ↓
Vue 把 dataDesc 当标题、dataValue 当金额显示
```

这是一种“同一个插座、后面可切两路电源”的设计。前端只认统一的返回格式，不需要知道金额是现场计算的，还是从缓存结果表拿的。

### 9.3 第一步：前端不是只发一个“大屏请求”，而是每个区域单独请求

在前端文件：

```text
02zhaocai-front/scm-vue-all-cockpit/
src/views/procurementCatalogMgt/index.vue
```

第 312～322 行 `created()` 是 Vue 页面创建时执行的生命周期方法，类似 React 组件初始化时触发加载：

```javascript
created() {
  this.getCenterHeaderData();
  this.getCategoryAmountData();
  this.getDoRateData();
  this.getSituAData();
  this.getKengkData();
  // 还会加载 mt、gc 趋势图
}
```

其中和台账1有关的是两个 GET 请求：

```javascript
/e/business/source/source/cockpit_collection_data_categoryAmount
/e/business/source/source/cockpit_collection_data_situA
```

URL 最后的 `categoryAmount`、`situA` 就是 `typeCode`，相当于前端告诉后端：“我要左侧类目列表”或者“我要右侧公司分析”。

`CollectionDataTypeEnum` 把这些固定字符串集中起来管理：

| typeCode | 大白话含义 | 台账1是否影响 |
|---|---|---|
| `centerHeader` | 顶部累计、日/月/季/年 | 否 |
| `categoryAmount` | 各集采类目金额 | 是，影响其中四项 |
| `doRate` | 集采计划执行分析 | 否 |
| `situA` | 按水泥北分/机电公司/金隅云采分析 | 是，只影响机电公司 |
| `kengk` | 煤炭重点坑口日指标 | 台账1不影响；属于台账2 |
| `mt` / `gc` | 煤炭/钢材价格趋势 | 否 |

这里的 Enum 类似 Node/TypeScript 中统一维护的常量对象，避免到处手写字符串。

### 9.4 第二步：所有驾驶舱板块进入同一个 Controller

后端入口在 `SourceQueryController.java` 第 555～559 行：

```java
@GetMapping("e/business/source/source/cockpit_collection_data_{typeCode}")
public Result<List<SourceCollectionData>> cockpitCollectionData(
        @PathVariable("typeCode") String typeCode) {
    return Result.success(
        sourceCollectionDataService.queryCollectionData(typeCode)
    );
}
```

逐句理解：

- `{typeCode}` 是 URL 中的变量部分。
- `@PathVariable` 把 URL 末尾的 `categoryAmount` 取出来放进 Java 参数。
- Controller 自己不算金额，只把任务交给 Service。
- `Result.success(...)` 套上公司统一响应外壳，最终前端从 `res.data` 取列表。
- `List<SourceCollectionData>` 表示返回多条驾驶舱指标；每一条都有编码、名称和数值。
- `@DataResponseTransfer` 是公司公共的“响应结果转换”标记，可按注解参数处理日期、金额、操作列或脱敏；这里没有配置任何转换参数，所以本接口不会额外改写这些驾驶舱字段。它也是同事原来留下的，不是台账1新增。

这段 Controller 是同事原来写的，你的提交没有碰它。

### 9.5 第三步：Service 先查“实时还是缓存”的开关

核心分流在 `SourceCollectionDataServiceImpl#queryCollectionData()`：

```java
Map<String,String> param = new HashMap<>();
param.put("cate", "collectionShow");
Result<List<DictDTO>> listResult = innerFeignService.execute(
    () -> dictFeignService.getDictByType(param)
);
```

这一步跨服务调用 UBM 数据字典，查字典类型 `collectionShow`。它不是台账表单使用的 `collection_category` 字典：

- `collection_category` 管“下拉框有哪些集采类目”。
- `collectionShow` 管“驾驶舱某个板块是否现场计算”。

然后把字典列表整理成 Map：

```java
for (DictDTO dictDTO : listResult.getData()) {
    dictMap.put(dictDTO.getValue(), dictDTO.getLabel());
}
```

在这套 UBM 返回格式里，可以把它读成：

```text
dict_code → DictDTO.value → categoryAmount
dict_name → DictDTO.label → 0
```

最后按 `typeCode + 开关值` 决定路线：

```java
if (typeCode 是 centerHeader && centerHeader 开关是 1) {
    现场查 queryCenterHeader()
} else if (typeCode 是 categoryAmount && categoryAmount 开关是 1) {
    现场查 queryCategoryAmount()
} else if (typeCode 是 situA && situA 开关是 1) {
    现场查 querySituA()
} else {
    从 sc_collection_data 查 data_type = typeCode
}
```

test 库在 2026-07-13 的真实配置是：

| dict_code | dict_name | 当前路线 |
|---|---:|---|
| `centerHeader` | 1 | 实时查 `sc_source_collection` |
| `categoryAmount` | 0 | 读 `sc_collection_data`，不会执行你改的 SQL |
| `situA` | 0 | 读 `sc_collection_data`，不会执行你改的 SQL |

这里用 `"1".equals(...)` 而不是 `dictMap.get(...).equals("1")`，还有一个 Java 小细节：即使 Map 中没这个键，前一种写法也只是返回 false，不会因 null 报错。

### 9.6 两条路线分别是什么

#### 路线 A：开关为 1，现场计算

```java
public List<SourceCollectionData> queryCategoryAmount() {
    return sourceCollectionMapper.queryCategoryAmount();
}
```

Service 调 `SourceCollectionMapper` 中写好的聚合 SQL。每次用户刷新驾驶舱，数据库就重新 `SUM(...)`，因此台账新增、修改、逻辑删除后，下次请求理论上就能看到新结果，不需要先跑同步任务。

可以类比 Node：

```javascript
if (switchValue === '1') {
  return db.query('SELECT SUM(...) FROM 明细表');
}
```

#### 路线 B：开关不为 1，读结果表

```java
LambdaQueryWrapper<SourceCollectionData> wrapper =
        new LambdaQueryWrapper<>();
wrapper.eq(SourceCollectionData::getDataType, typeCode);
return sourceCollectionDataMapper.selectList(wrapper);
```

`SourceCollectionData` 映射表 `sc_collection_data`。这张表不是业务明细，而像一张“提前算好答案的小抄”：

```text
data_type=categoryAmount
data_desc=钢材
data_value=23350
```

读缓存速度快、数字稳定，但前提是另有流程及时刷新这张结果表。当前代码仓库内只找到对它的查询，没有找到新增或更新 `sc_collection_data` 的 Java 逻辑，所以不能从现有代码断言它会每天自动刷新。

### 9.7 第四步：`categoryAmount` 为什么是一长串 `UNION ALL`

`queryCategoryAmount()` 要一次返回驾驶舱左侧的 7 行：煤炭、钢材、润滑剂、电线电缆、轴承及备件、办公设备、办公文具。

每一行的数据规则不同，SQL 就分别算一行，再用 `UNION ALL` 拼成一个列表：

```text
煤炭 SELECT
UNION ALL
钢材 SELECT
UNION ALL
润滑剂 SELECT
...
```

`UNION ALL` 可以理解为 JavaScript 的数组拼接：

```javascript
[煤炭结果].concat([钢材结果], [润滑剂结果], ...)
```

最终 7 行的来源是混合的：

| 行 | 数据来源 | 过滤条件 | 是否是你的改动 |
|---|---|---|---|
| 煤炭 1001 | `sc_source_collection.tax_total` | SAP + 指定供应商/采购方规则 | 否 |
| 钢材 1501 | `sc_collection_daily_amount_ledger.tax_amount` | 类目编码 + 未删除 | 是 |
| 润滑剂 1701 | 新台账同上 | 类目编码 + 未删除 | 是 |
| 电线电缆 2302 | 新台账同上 | 类目编码 + 未删除 | 是 |
| 轴承及备件 2502 | 新台账同上 | 类目编码 + 未删除 | 是 |
| 办公设备 2102 | `sc_source_collection.tax_total` | ORDER 来源 | 否 |
| 办公文具 2113 | `sc_source_collection.tax_total` | ORDER 来源 | 否 |

以钢材为例：

```sql
SELECT
    '40002'                         AS dataId,
    'categoryAmount'                AS dataType,
    '集采类目分项金额'               AS dataTypeDesc,
    '1501'                          AS dataCode,
    ROUND(IFNULL(SUM(tax_amount),0) / 10000, 0) AS dataValue,
    '钢材'                          AS dataDesc
FROM sc_collection_daily_amount_ledger
WHERE category_code = '1501'
  AND delete_sign = 0;
```

重点不是背 SQL，而是知道返回字段的用途：

| 返回字段 | 示例 | 谁使用 |
|---|---|---|
| `dataId` | 40002 | 这条指标的固定 ID |
| `dataType` | categoryAmount | 属于哪个驾驶舱板块 |
| `dataTypeDesc` | 集采类目分项金额 | 板块说明 |
| `dataCode` | 1501 | 指标编码 |
| `dataValue` | 2 | 页面最终展示的数值 |
| `dataDesc` | 钢材 | 页面展示名称 |

金额处理有三层：

1. `SUM(tax_amount)`：把同一类目的所有有效台账金额相加。
2. `/ 10000`：台账按“元”存，大屏按“万元”展示。
3. `ROUND(..., 0)`：四舍五入为整数万元，所以小于 5000 元可能显示 0。

`IFNULL(..., 0)` 保证没有该类目数据时也返回 0，而不是返回 null。

`delete_sign = 0` 必须手写，因为这里是 `@Select` 原生 SQL，不会自动触发 Entity 上的 MyBatis-Plus `@TableLogic`。

### 9.8 第五步：`situA` 为什么还要再算一次“机电公司”

`querysituA()` 返回的不是类目，而是三家业务主体的汇总：

| dataCode | 页面名称 | 来源 |
|---|---|---|
| `situA1` | 水泥北分 | 原集采表中的煤炭规则 |
| `situA2` | 机电公司 | 台账1四类目合计 |
| `situA3` | 金隅云采 | 原集采表中的办公类目规则 |

你改的是中间这一行：

```sql
SELECT ROUND(IFNULL(SUM(tax_amount),0) / 10000, 0)
FROM sc_collection_daily_amount_ledger
WHERE category_code IN ('1501','1701','2302','2502')
  AND delete_sign = 0;
```

为什么不让前端把四项相加？因为“机电公司”是一个独立的后端统计口径。后端统一算，可以保证网页、其他调用方都拿到同一个答案，也避免前端漏项。

理想情况下应满足：

```text
机电公司金额
≈ 钢材 + 润滑剂 + 电线电缆 + 轴承及备件
```

这里写“≈”是因为当前 SQL 对每个类目先分别换算并取整，而机电公司是先把四类元金额合计再取整；在临界值附近，四个整数万元之和可能和总额取整相差 1～2 万元。这是取整顺序造成的，不一定是数据错。

### 9.9 第六步：为什么后端换了表，前端却不用改

无论走实时 SQL 还是缓存表，后端最终都返回 `SourceCollectionData` 这种统一形状：

```json
{
  "dataType": "categoryAmount",
  "dataCode": "1501",
  "dataValue": "2",
  "dataDesc": "钢材"
}
```

Vue 的 `getCategoryAmountData()` 只做映射：

```javascript
this.categoryList = res.data.map(item => ({
  name: item.dataDesc,
  value: item.dataValue
}));
```

`getSituAData()` 同理，把 `dataDesc` 放到标题，把 `dataValue` 放到金额。前端根本不关心后端查了哪张表，这就是“统一返回模型”的价值：后端内部换数据源，不需要连带修改页面。

### 9.10 原来的集采数据、缓存表和新台账，是三种不同角色

这三张表很容易混淆：

| 表 | 角色 | 数据怎么来 | 本次怎么用 |
|---|---|---|---|
| `sc_source_collection` | 原集采业务明细仓库 | 原 `gatherData()` 汇集 SCM、SAP、ORDER、FPT | 仍支撑顶部、煤炭、办公等指标 |
| `sc_collection_data` | 驾驶舱预计算结果/静态结果表 | 当前仓库未找到写入逻辑，来源不能仅靠现有代码确认 | 开关为 0 时直接读取 |
| `sc_collection_daily_amount_ledger` | 这次新增的人工日金额台账 | 用户通过台账新增/修改接口维护 | 开关为 1 时，四类目和机电公司现场汇总 |

原来的 `SourceCollectionServiceImpl#gatherData()` 在未传日期时取昨天，然后依次执行：

```java
gatherSource(param);
gatherSap(param);
gatherOrder(param);
gatherFpt(param);
```

这些方法把多来源业务明细插入或更新到 `sc_source_collection`。它们不是在计算台账1，也没有写 `sc_collection_data`。

test 的 XXL-Job 数据库确实存在“集采收集数据”任务：

```text
executor_handler = simpleJobHandler
executor_param   = source-sourceCollectionService-gatherData-...
schedule_type    = FIX_RATE
schedule_conf    = 600
trigger_status   = 0
```

这说明它原本用于周期采集旧集采明细；当前 test 配置是停用状态，而且不是你这次新增的“每天 24 点台账任务”。

因此必须把两句话分开：

- “原系统有集采数据采集任务”——有代码和 test 配置证据。
- “台账1每天 24 点把前一天金额写入驾驶舱缓存”——最终代码没有实现，不能说已经完成。

### 9.11 AI 最终为什么采用实时查询，而不是再写一个定时任务

从最终提交可以反推出它采用了“复用原驾驶舱实时分支”的最小改法：

1. 原系统已经有 `collectionShow` 开关和实时 Mapper，接入点现成。
2. 只替换 5 个 SQL 分支，不需要新建驾驶舱接口和返回对象。
3. 台账增删改后，下次刷新即可重新统计，不存在“等凌晨任务”或“任务失败后缓存过期”的延迟。
4. 类目分项和机电公司汇总同时改，避免同一个台账在两个区域显示两套口径。
5. 有开关兜底，理论上发现实时 SQL 有问题时可切回旧缓存。

但这个最小改法也留下了明确边界：

1. **需求文字与实现路线不同**：需求说每日 24 点取前一日；最终代码是打开页面时实时 SUM，没有新增台账定时任务。
2. **日期口径缺失**：SQL 没有 `statistic_date` 条件，会累计所有未删除历史台账，不是“前一日”。
3. **开关不是只切四行**：`categoryAmount` 从 0 改 1 后，整组 7 行都会从缓存切到实时 SQL；煤炭和办公虽然 SQL 没改来源，显示值也可能与缓存旧值不同。
4. **顶部金额不含台账**：`centerHeader` 仍只汇总 `sc_source_collection`。因此左侧钢材可能包含台账，顶部累计金额却不包含同一笔台账。
5. **开关依赖 UBM**：每次请求先跨服务查字典；字典数据或 UBM 调用异常会影响分流。
6. **实时聚合有成本**：台账数据量小时问题不大；长期累计后，每次大屏刷新都要执行 SUM，需要关注索引和性能。

所以这段代码不是“写错了一个定时任务”，而是根本选择了另一种架构：**不落驾驶舱缓存，打开页面时实时算**。现在最需要负责人确认的是，这种架构和日期口径是否符合最终业务要求。

### 9.12 用 test 真实数据验证当前会看到什么

截至 2026-07-13，test 库的证据是：

- `collectionShow.categoryAmount = 0`
- `collectionShow.situA = 0`
- 所以驾驶舱当前仍显示 `sc_collection_data` 中的旧结果，例如钢材 23350 万元、机电公司 433562 万元。
- 当前有效台账中，1501 钢材合计 23945.93 元；1701/2302/2502 暂无有效数据。

如果只把两个开关改成 1，按当前 SQL 现场计算会得到：

| 显示项 | 当前缓存路线 | 切实时后的 test 计算值 |
|---|---:|---:|
| 钢材 | 23350 万元 | 2 万元 |
| 润滑剂 | 902 万元 | 0 万元 |
| 电线电缆 | 8887 万元 | 0 万元 |
| 轴承及备件 | 2132 万元 | 0 万元 |
| 机电公司 | 433562 万元 | 2 万元 |

这不是说实时 SQL 一定错，而是 test 台账目前主要是少量演示/接口测试数据，和旧驾驶舱缓存的历史业务数据不在一个量级。现在直接开开关，大屏数字会断崖式变化。因此不能为了“验证代码生效”就随手改共享 test 开关，必须先准备完整数据并确认业务口径。

台账里还有一条 1502 水泥数据，但驾驶舱 SQL 只认 1501/1701/2302/2502，所以这条不会进入上述五个新统计分支。SQL 按 `category_code` 判断，`category_name` 写成“钢材-接口测试修改”仍会计入 1501；这说明编码是统计依据，名称只是显示快照。

### 9.13 在 IDEA 中一步步跟读这条链路

以下按 Windows 默认快捷键写；如果你改过 Keymap，以 IDEA 菜单显示为准。

#### 第 1 步：从前端请求看“页面要什么”

1. 连按两次 `Shift`，搜索 `procurementCatalogMgt/index.vue`。
2. `Ctrl+F` 搜 `created()`，先看页面加载了哪些板块。
3. 再搜 `getCategoryAmountData`，看到 URL 末尾是 `categoryAmount`。
4. 再搜 `getSituAData`，看到 URL 末尾是 `situA`。
5. 看 `.map(...)`，确认前端实际显示的是 `dataDesc` 和 `dataValue`。

这一轮只回答两个问题：页面发了什么请求？返回的哪个字段显示在屏幕上？先不要钻 SQL。

#### 第 2 步：用全局搜索找到后端入口

1. 按 `Ctrl+Shift+F`，全项目搜索 `cockpit_collection_data_`。
2. 打开 `SourceQueryController#cockpitCollectionData`。
3. 把光标放在 `queryCollectionData` 上按 `Ctrl+B`，先到 Service 接口。
4. 再按 `Ctrl+Alt+B` 看实现，进入 `SourceCollectionDataServiceImpl`。

注意：`Ctrl+B` 偏向“声明在哪里”，`Ctrl+Alt+B` 偏向“谁实现了它”。这正适合阅读 Java 的接口 + 实现类结构。

#### 第 3 步：手动画出 Service 的二选一

在纸上只写：

```text
typeCode 是什么？
collectionShow 对应值是不是 1？
是 → Mapper 实时算
否 → sc_collection_data
```

然后用 IDEA 的 `Ctrl+鼠标左键` 分别点：

- `CollectionDataTypeEnum.CATEGOTY`
- `dictFeignService.getDictByType`
- `sourceCollectionMapper.queryCategoryAmount`
- `sourceCollectionDataMapper.selectList`

这样你会亲眼看到四个角色：类型常量、跨服务查开关、实时 SQL、缓存表查询。

#### 第 4 步：在 Git 里只看你动过的 10 行

1. 按 `Alt+9` 打开 Git 工具窗口。
2. 切到 Log，搜索提交 `2f33fa77f`。
3. 点开 `SourceCollectionMapper.java` 的 Diff。
4. 左边是原 SQL，右边是最终 SQL；重点比较 `FROM`、金额字段和 `WHERE`。

你会看到改动模式非常统一：

```text
sc_source_collection.tax_total
supplier/purchase_company 条件
        ↓ 替换为
sc_collection_daily_amount_ledger.tax_amount
category_code + delete_sign 条件
```

#### 第 5 步：在 Database 窗口验证，不靠脑补

在 IDEA 菜单 `View → Tool Windows → Database` 打开已有的 test 数据源，只执行 SELECT：

```sql
SELECT category_code,
       SUM(tax_amount) AS amount_yuan,
       ROUND(SUM(tax_amount) / 10000, 0) AS cockpit_wanyuan
FROM sc_collection_daily_amount_ledger
WHERE delete_sign = 0
  AND category_code IN ('1501','1701','2302','2502')
GROUP BY category_code;
```

再查缓存答案：

```sql
SELECT data_type, data_code, data_desc, data_value
FROM sc_collection_data
WHERE data_type IN ('categoryAmount','situA');
```

对比两次 SELECT，你就能直观看懂“实时明细汇总”和“读取预存答案”的差别。不要在共享 test 库执行 UPDATE，也不要为了看效果自行修改 `collectionShow`。

### 9.14 你必须能向同事说清楚的版本

> “集采驾驶舱原来就是按 typeCode 分区域请求的，Service 会先查 UBM 的 collectionShow 开关。categoryAmount 和 situA 为 1 时走 SourceCollectionMapper 实时汇总，为 0 时读 sc_collection_data。我的台账1提交没有改前端、Controller 和 Service，只把实时 SQL 中 1501/1701/2302/2502 四个类目，以及 situA 的机电公司一行，换成汇总 sc_collection_daily_amount_ledger。当前 test 两个开关还是 0，所以实际还没走新 SQL；而且新 SQL 没带 statistic_date，会累计全部未删除历史台账。原来的 gatherData 定时采集是写 sc_source_collection，不是把台账写驾驶舱缓存。”

### 9.15 这块需要负责人确认的逐字话术

> “我把最终链路核对了一遍。需求原文写的是每天 24 点取前一日更新驾驶舱，但现在提交采用的是打开驾驶舱时实时汇总台账，没有新增定时任务，也没有写 sc_collection_data；SQL 还没有 statistic_date 条件，会累计全部历史。麻烦确认最终要哪种口径：只显示前一日、截至前一日累计，还是全部历史累计？另外台账金额目前只进入四个类目和机电公司行，不进入顶部累计/日/月/季/年金额，这个影响范围是否正确？”

这部分属于“改共享大屏口径”，风险高于普通 CRUD。确认前不要自行打开共享环境开关。

---

## 10. 从高层看：AI 当时为什么这样写

### 做对了的设计取舍

1. **独立建表**：人工台账不混进原有 `sc_source_collection`，避免污染 SAP/订单等自动数据源。
2. **五层标准分工**：Controller 只管 HTTP，ServiceImpl 管业务，Mapper 管库，和项目样板一致。
3. **服务器生成号码/操作人**：不信前端传入的审计字段。
4. **逻辑删除**：财务/业务台账需要可追溯。
5. **查询复用导出**：页面看到什么筛选结果，导出就应该是同一批，避免两套 SQL 口径漂移。
6. **编码+名称双存**：查询稳定，页面回显简单，也留下历史快照。

### 目前还要有意识地管的风险

1. **驾驶舱日期口径未在 SQL 体现**：开开关前必须确认要累计全历史、截至昨天，还是仅昨天。
2. **台账1的 add/modify 业务校验偏少**：当前代码未显式检查必填、金额非负、类目是否在字典、修改主键是否存在。前端可以做一层，但后端仍应是最后防线。
3. **组织搜索接口仍保留**：最终分页已支持直接名称模糊查询，前端查询框可以不调它；但它还可用于新增/修改弹窗的组织选择。要不要删不是纯技术问题，取决于前端表单是否仍使用。
4. **文档与代码可能分叉**：讨论过程有删除又恢复的提交，判断当前行为一律看 `origin/test` 最终文件和环境配置。

---

## 11. 你和负责人/同事可以怎么聊

### 30 秒版

> “台账1是在 source 服务新建了一张日金额台账表，后端已经有分页、新增、修改、逻辑删除、详情和通用导出。流水号是后端按天生成的 JCRJE 号，操作人和发布时间也由后端取当前登录人。驾驶舱四类目和机电公司行已经有读台账的 SQL，但 test 开关还是 0，而且当前 SQL 是汇总全部未删历史数据，开开关前需要再确认日期口径。”

### 同事问“为什么不直接存原集采表”

> “这份是人工维护台账，原表混有 SAP、订单等自动来源。独立表能把数据责任边界分开，驾驶舱只在明确的四个类目分支上切换数据源。”

### 同事问“为什么删除了库里还有”

> “台账采用 MyBatis-Plus 逻辑删除，接口删除是把 `delete_sign` 设为 1。业务查询看不到，但原记录可以审计和排查。”

### 你应该带去确认的话术

> “我核对了最终代码。驾驶舱分项和机电公司行开开关后，目前会累加新台账里该类目所有 `delete_sign=0` 的历史金额，没有限定统计日期。业务最终要的是全历史累计、截至昨天累计，还是只显示昨天？我按你确认的口径再收口。”

---

## 12. 跟读完的自测题

你不看文档能用大白话答出下面 8 题，就已经能和同事聊主干逻辑：

1. Controller、ServiceImpl、Mapper 分别负责什么？
2. DTO 和 Model 为什么不是同一个类？
3. JCRJE 流水号在哪生成，日期是哪个日期？
4. 修改接口为什么要把 `ledgerNo/create*/deleteSign` 设 null？
5. `deleteById` 为什么不是物理删除？
6. 为什么导出不单独写一个查询 Service？
7. 为什么组织要存 code+name，又要返回 shortName？
8. 驾驶舱什么条件下才会真正走新台账 SQL？当前 SQL 的日期口径是什么？

---

## 13. 证据索引

- 基础 CRUD：`aa4747310`
- 逻辑删除修复：`350e3f2cd`
- 驾驶舱 SQL：`2f33fa77f`
- 最终组织短名+分页名称模糊：`8af713b45`
- 代码主路径：`scm-source-source-api/.../CollectionDailyAmountLedgerDTO.java` 与 `scm-source-source/.../CollectionDailyAmountLedger*.java`
- 建表脚本：`docs/需求/台账/claude/sql/01_create_ledger_table.sql`
- 运行配置：`03zhaocai-start/scm-cloud-starters-web/scm-cloud-source/src/main/resources/bootstrap.yml:26`
- 启动装配：`SourceApp.java:48` 与 `SourceWebConfig.java:13`
- 数据库核对日期：2026-07-13；业务库 `scm_source_test`，字典/导出库 `scm_ubm_test`。
