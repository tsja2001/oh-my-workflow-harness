# Fastjson 升级与日期类型异常 · 代码复盘与学习手册

> 日期：2026-07-27  
> 工具：codex  
> 当前状态：已经确认今天供应商寻源列表异常的根因，但尚未修改任何公司代码、未提交、未发布。  
> 下一阶段：用户确认修复范围后，转开发；推荐优先修公共转换层，若必须紧急止血则先修 `scm-source-all`。  
> 深度：标准 ｜ 复盘范围：`scm-cloud-parent`、`scm-assemblies-all`、`scm-cloud-dependencies`、`scm-source-all` ｜ 最终基线：以本地现有代码、提交 `256a2be` / `80e24fa`、fastjson 1.2.83 与 2.0.62 实测为准

---

## 0. 建议阅读路线

第一次只看下面四部分就够：

1. 第 1 节：30 秒先知道发生了什么。
2. 第 3 节：用“闹钟和纸条”的比喻真正理解问题。
3. 第 5 节：看应该怎么修、哪些修法是错的。
4. 第 8 节：用三句话检查自己是不是真的听懂了。

以后需要自己跟代码时，再看第 4、6 节。

---

## 1. 先用 30 秒说清楚

### 1.1 这次到底发生了什么

数据库原本交给 Java 的是一个真正的日期对象，可以直接判断“是否超过截止时间”。

fastjson 1.x 时代，经过公司公共转换器以后，这个东西仍然是日期对象，所以老代码一直正常。

升级到 fastjson 2.x 后，公共转换器在执行下面这个动作时：

```java
一行JSONObject.toJavaObject(new TypeReference<Map<String, Object>>() {})
```

会先把整行数据写成 JSON 文本，再读成一个普通 Map。日期因此变成了下面这样的普通字符串：

```text
2026-06-10 22:00:00
```

业务代码却仍然把它当成真正的 `Date`：

```java
sourceSignEndTime = (Date) map.get("sourceSignEndTime");
```

所以程序相当于在说：

> “这张写着时间的纸条，就是一个能走动的闹钟。”

Java 不允许这样冒充，于是报错。

### 1.2 最重要的结论

这次问题：

- 不是数据库连接坏了。
- 不是 SQL 没查到数据。
- 不是日期显示得好不好看的问题。
- 不是你上次修改 `scm-assemblies-all` 写错了。
- 是 fastjson 2.x 改变了“`JSONObject` 转泛型 `Map`”时的日期类型。
- 真正的爆点位于 `scm-cloud-dependencies` 的 OAuth2 公共返回转换器。

### 1.3 当前五态

| 能力/交付面 | 预期 | 已实现 | 已配置 | 已部署 | 已验证 | 证据/未知项 |
|---|---|---|---|---|---|---|
| fastjson 升到 2.0.62 | 修复 1.x 安全漏洞 | 是 | parent 已配置 | 升级产物已发布；今天未直接检查问题环境容器 | 版本配置和历史记录已核实 | `scm-cloud-parent/pom.xml:65`、提交 `256a2be` |
| 删除 API 的兼容处理 | 不再调用 2.x 已删除的方法 | 是 | 不适用 | 公共 jar 历史记录显示已发布 | 已拆 jar 验证旧调用消失 | `scm-assemblies-all` 提交 `80e24fa` |
| 日期类型兼容 | 操作按钮计算继续拿到 `Date` | 否 | 不适用 | 否 | 根因已复现，修复尚未做 | 1.2.83/2.0.62 对照实验 |
| 供应商寻源列表恢复 | 页面按钮正常 | 否 | 不适用 | 否 | 否 | 当前停在方案确认阶段 |

> 代码里已经有修复方案，不等于已经开发；本地开发完成，也不等于 Nexus、Jenkins、K8s 已经生效。

---

## 2. 之前升级时到底改了什么

### 2.1 第一次修改：统一换版本

仓库：

```text
01zhaocai-end/scm-cloud-parent
```

提交：

```text
256a2be  fastjson升级到2.0.62
```

实际修改：

```xml
<fastjson.version>1.2.83</fastjson.version>
```

变成：

```xml
<fastjson.version>2.0.62</fastjson.version>
```

大白话：

> `scm-cloud-parent` 像公司的“统一软件采购清单”。这里写 fastjson 2.0.62，后续重新打包的服务都会按这份清单拿 2.0.62。

这个修改让所有下游服务从 1.x 跨到了 2.x，所以它是本次兼容问题出现的前提，但“升级版本”本身不是写错代码。

### 2.2 第二次修改：替换已经被删除的方法

仓库：

```text
01zhaocai-end/scm-assemblies-all
```

提交：

```text
80e24fa  处理fastjson2.x缺失方法问题
```

它解决的是另一种问题：

```text
fastjson 1.x 有 getClassFromMapping()
fastjson 2.x 把这个方法删除了
旧代码继续调用就会编译失败或运行时报 NoSuchMethodError
```

当时在两个公共类里改成了 Java 自己的类型判断：

- `scm-common-json/JsonTransferUtil.java`
- `scm-share-aim-spring/JsonServiceImpl.java`

这个修复方向是正确的。今天的日期异常不是因为这两处改错，而是因为：

> “方法还在，但方法内部的行为和以前不一样。”

找“被删除的方法”可以靠全工程搜索；这种“同一个方法返回的类型变了”通常必须靠运行回归才能发现。

### 2.3 今天发现的第三个兼容点

真正需要关注的仓库是：

```text
01zhaocai-end/scm-cloud-dependencies
```

具体文件：

```text
scm-cloud-dependencies-oauth2/src/main/java/com/pcitc/scm/web/oauth2/
datatransfer/service/impl/OperListResponseTransferServiceImpl.java
```

这里是 2023 年留下来的公司公共代码，上次 fastjson 升级没有修改它。

| 时间/版本 | 业务变化 | 当前是否保留 | 证据 |
|---|---|---|---|
| 2023 年 | 公共层增加返回数据转换和操作按钮注入 | 是 | `GlobalResponseHandler`、`OperListResponseTransferServiceImpl` |
| 2026-07-21 / `80e24fa` | 修复 fastjson2 删除旧 API | 是 | Git 提交 |
| 2026-07-21 / `256a2be` | fastjson 统一升级到 2.0.62 | 是 | parent POM |
| 2026-07-27 | 暴露日期从 Date 变成 String 的兼容问题 | 尚未修复 | 堆栈第 216 行、版本对照实验 |

---

## 3. 用“闹钟和纸条”理解 Date 与 String

### 3.1 长得像时间，不等于它就是日期对象

Java 里的 `Date` 可以理解成一个真的闹钟：

- 它知道内部时间。
- 可以判断在另一个时间之前还是之后。
- 可以调用 `before()`、`after()`。

下面这个只是纸条：

```text
2026-06-10 22:00:00
```

人看起来知道这是时间，但 Java 只认为它是一串文字。

| 东西 | Java 类型 | 能否直接判断截止时间 |
|---|---|---|
| 真闹钟 | `java.util.Date` | 可以 |
| 写着时间的纸条 | `java.lang.String` | 不可以，必须先解析成 Date |

### 3.2 “指定日期格式”为什么不能单独解决

同事说：

> “fastjson 2 版本时间格式可能需要指定一下。”

这个方向触碰到了日期，但还没有说到最准确的根因。

例如下面三种内容：

```text
2026-06-10 22:00:00
2026/06/10 22:00:00
2026-06-10T22:00:00+08:00
```

格式不同，但它们全都是字符串。

给字段加：

```java
@JSONField(format = "yyyy-MM-dd HH:mm:ss")
```

就像规定：

> “以后纸条上的时间统一这样写。”

它只能决定纸条上的字怎么排，不能把纸条变回闹钟。

这次业务代码需要的是一个真正的 `Date`，因为后面要执行：

```java
sourceSignEndTime.after(new Date())
```

所以正确方向只有两个：

1. 公共层不要把 Date 变成 String。
2. 如果已经变成 String，业务层拿出来时先解析回 Date。

### 3.3 用 Node 的方式类比

下面这段 Java 问题，和 Node 里这件事很像：

```js
const source = {
  sourceSignEndTime: new Date()
}

const copied = JSON.parse(JSON.stringify(source))
```

执行前：

```js
source.sourceSignEndTime instanceof Date // true
```

执行后：

```js
copied.sourceSignEndTime instanceof Date // false
typeof copied.sourceSignEndTime          // "string"
```

fastjson2 这次的泛型 Map 转换，效果就类似中间做了一次 `JSON.stringify()` + `JSON.parse()`。

类比边界：Java 的实际实现不是 Node，但“JSON 文本无法保留 Date 对象类型”这个结果相同。

---

## 4. 真实调用链：请求成功查库后，为什么还会报错

### 4.1 一张图看懂

```text
前端请求供应商寻源列表
        │
        ▼
SourceQueryController
调用 Service 查询数据库
        │
        ▼
MyBatis 查出 sc_supplier_source
时间字段此时是真正的 Date
        │
        ▼
Controller 返回 Result<PageList<SupplierSourceVO>>
数据库查询到这里已经成功
        │
        ▼
@DataResponseTransfer 开始工作
准备给每一行补“查看/报价/撤回”等按钮
        │
        ▼
OperListResponseTransferServiceImpl 第 113 行
JSONObject → TypeReference<Map<String,Object>>
        │
        ├─ fastjson 1.x：Date 仍是 Date
        │
        └─ fastjson 2.x：Date 变成 String
                              │
                              ▼
OperSupplierSourcePageListImpl 第 216 行
(Date) 字符串
                              │
                              ▼
ClassCastException
操作按钮没有正常补完
```

### 4.2 每个文件分别负责什么

#### 入口 Controller

```text
01zhaocai-end/scm-source-all/scm-source-source/src/main/java/com/pcitc/scm/
source/source/controller/SourceQueryController.java:154
```

接口：

```text
/e/business/source/source/querySupplierSourcePageList
```

这里的注解：

```java
@DataResponseTransfer(operValue = {
    @OperListTransfer(
        root = "data.root",
        key = "supplierSourcePageList",
        dataType = DataType.ARRAY
    )
})
```

大白话：

> 返回数据里的列表在 `data.root`；每一行要交给名叫 `supplierSourcePageList` 的按钮计算器处理。

它不是“日期转换注解”，而是“给返回列表补操作按钮”的开关。

#### 全局返回处理器

```text
01zhaocai-end/scm-cloud-dependencies/scm-cloud-dependencies-oauth2/src/main/java/
com/pcitc/scm/web/oauth2/global/GlobalResponseHandler.java:63
```

它会把 Controller 的返回对象转成 `JSONObject`，然后寻找 `@DataResponseTransfer`。

#### 公共操作按钮转换器

```text
01zhaocai-end/scm-cloud-dependencies/scm-cloud-dependencies-oauth2/src/main/java/
com/pcitc/scm/web/oauth2/datatransfer/service/impl/
OperListResponseTransferServiceImpl.java:113
```

问题代码：

```java
obj.toJavaObject(new TypeReference<Map<String,Object>>() {})
```

fastjson 1.2.83 对这个泛型转换直接做类型转换，日期仍是 Date。

fastjson 2.0.62 遇到这种带泛型的类型时，会：

```text
JSONObject → JSON 字符串 → Map<String,Object>
```

日期对象在写成 JSON 字符串时丢失了 Date 身份。

#### 业务按钮计算器

```text
01zhaocai-end/scm-source-all/scm-source-source/src/main/java/com/pcitc/scm/
source/source/service/impl/OperSupplierSourcePageListImpl.java:216
```

这里根据截止时间决定是否显示“报价、咨询、撤回”等按钮。

第 216 行只是第一个爆点，同一文件还有：

```text
81   sourceSignEndTime
86   defenceEndTime
216  sourceSignEndTime
221  sourceEndTime
252  defenceEndTime
267  qualApproveTime
```

所以只改第 216 行，程序还会在后面的日期上继续报同样的错。

### 4.3 为什么接口可能还是“成功”

`GlobalResponseHandler.java:91` 把返回转换期间的异常捕获并记日志，然后在第 138 行继续返回数据。

因此可能出现：

```text
HTTP 请求成功
status = true
列表数据也有
但 operList 没补上，页面按钮消失或只补了一部分
```

这就是为什么它看起来不像普通的 500 接口错误。

### 4.4 同事日志里的 JDBC 和 SELECT 是什么

日志中的：

```text
JDBC Connection [...] will not be managed by Spring
SELECT source_id, source_code, ...
```

不是这次日期异常的根因。

判断依据：

1. SQL 已经执行。
2. 堆栈随后进入 `OperListResponseTransferServiceImpl.transferArray()`。
3. 再进入 `OperSupplierSourcePageListImpl.wrapCommonList()`。
4. 最终停在第 216 行的 Date 强转。

也就是说：

> 厨房已经把菜做好了；出错发生在服务员给餐盘补刀叉的时候，不是厨房没开火。

### 4.5 数据库证据

对同事日志中的：

```text
source_id = 2064510445186265089
```

在 test 库做了只读查询，确实存在：

```text
source_code          = 10930000-JC-2026-0016
source_sign_end_time = 2026-06-10 22:00:00
source_end_time      = 2026-06-10 17:30:00
defence_end_time     = 2026-06-10 17:30:00
purchase_method      = 105
state                = 080
```

三个日期都不是空值，所以代码一定会尝试读取日期类型。

### 4.6 两个版本的真实对照实验

使用本机真实 jar，而不是凭记忆推断：

| 实验步骤 | fastjson 1.2.83 | fastjson 2.0.62 |
|---|---|---|
| `JSON.toJSON` 构造真实嵌套返回结构 | 日期是 Date | 日期是 Date |
| 经过 `JsonTransferUtil` 取 `data.root` | 日期是 Date | 日期是 Date |
| 单行 `JSONObject` 转 `Map<String,Object>` | 日期仍是 Date | 日期变成 String |
| 执行 `(Date) map.get(...)` | 成功 | `ClassCastException` |

这同时排除了两件事：

1. 不是 Controller 查询数据时就错了。
2. 不是上次修改的 `JsonTransferUtil` 把日期变成了字符串。

---

## 5. 应该怎么修

### 5.1 方案 A：修公共转换层，推荐

修改仓库：

```text
01zhaocai-end/scm-cloud-dependencies
```

修改文件：

```text
scm-cloud-dependencies-oauth2/.../OperListResponseTransferServiceImpl.java
```

当前做法：

```java
obj.toJavaObject(new TypeReference<Map<String,Object>>() {})
```

推荐思路：

```java
new HashMap<>(obj)
```

本地最小实验证明：

```text
fastjson2 + TypeReference<Map>  → 日期变 String
fastjson2 + HashMap 浅拷贝     → 日期仍是 Date
```

这个公共类里有两处同样写法：

- 第 83 行：处理单个对象。
- 第 113 行：处理数组中的每一行。

两处要一起修，否则一个场景好、另一个场景仍会坏。

### 优点

- 从类型丢失的源头解决。
- 不用逐个修业务文件。
- 能恢复 fastjson 1.x 时代既有的日期类型行为。
- 对 fastjson 1.x 和 2.x 都能兼容。

### 风险

这是公司公共组件，不只寻源服务使用。

本地现有代码扫描到：

- 110 个 `OperResolverService` 实现。
- 140 处 `@OperListTransfer` 使用。

虽然改动只有两处，但发布后会逐渐被其他重新构建的服务拿到。因此必须：

1. 单独提交，不能夹带业务改动。
2. 验证数组和单对象两条分支。
3. 验证 Date、Integer、Boolean、String 都保持原类型。
4. 先回归 `scm-source` 的已知接口。
5. 再决定是否让其他服务跟随重新构建。

### 5.2 方案 B：只修寻源业务，适合紧急止血

在业务代码取日期时，不再直接强转：

```java
(Date) value
```

改成能同时接受 Date 和字符串的安全转换，例如：

```java
TypeUtils.castToDate(value)
```

大白话：

> 拿到真闹钟就直接用；拿到纸条就先按纸条时间重新设置一个闹钟。

本地实测 fastjson2 的 `TypeUtils.castToDate()` 可以把：

```text
2026-07-27 11:37:36.789
```

正确转回 Date。

目前发现 10 处直接日期强转，集中在 `scm-source-all` 的 4 个文件：

| 文件 | 日期强转数量 |
|---|---:|
| `OperSupplierSourcePageListImpl.java` | 6 |
| `OperSourceCostPageListImpl.java` | 2 |
| `OperEnrollPageListImpl.java` | 1 |
| `OperSourcePageListImpl.java` | 1 |

它们对应至少 11 个已知列表接口。

### 优点

- 只影响寻源服务。
- 发版范围小，适合紧急恢复页面。
- 即使以后公共层修好，这种写法仍兼容 Date。

### 缺点

- 公共层仍会把 Date 变成 String。
- 将来新业务如果继续直接强转，还可能重踩。
- 其他仓库若有动态或尚未拉到本地的实现，不能一起得到修复。

### 5.3 我的建议

正常情况下推荐：

> 采用方案 A，修公共层根因；完整验证后，再发布公共 jar 和重建 source 服务。

如果今天必须尽快恢复、团队暂时不允许动公共组件：

> 先采用方案 B，把 `scm-source-all` 已找到的 10 处一起修掉；不要只改第 216 行。公共层根修另开一个独立提交。

### 5.4 这些做法不要采用

### 不要退回 fastjson 1.x

升级的原始目的就是修复安全漏洞。回退等于为了按钮恢复，把已知漏洞重新带回来。

### 不要只加日期格式注解

它只能改变字符串的样子，不能解决 String 强转 Date。

### 不要只修第 216 行

同一文件后面还有多个日期字段，其他三个操作按钮解析器也有相同问题。

### 不要删除 `@DataResponseTransfer`

删掉注解确实不会再执行报错代码，但页面会失去操作按钮计算能力，相当于“为了不让门锁报错，把整扇门拆掉”。

---

## 6. 四个仓库分别是什么角色

| 仓库 | 大白话角色 | 本次关系 |
|---|---|---|
| `scm-cloud-parent` | 全公司的版本采购清单 | 把 fastjson 统一从 1.2.83 换成 2.0.62 |
| `scm-assemblies-all` | 公司自己写的一批公共工具 | 上次修了 fastjson2 删除旧方法的问题 |
| `scm-cloud-dependencies` | Web/OAuth2 等公共运行框架 | 今天日期类型丢失的真正公共爆点 |
| `scm-source-all` | 寻源业务代码 | 第 216 行最先使用错误类型并报错 |

### 归属边界

| 归属 | 内容 | 为什么要区分 |
|---|---|---|
| 第三方依赖 | fastjson 2.0.62 | 它改变了泛型 Map 转换行为，但不会理解公司的按钮业务 |
| 公司公共能力 | `DataResponseTransfer`、`OperListResponseTransferServiceImpl` | 多个业务服务共用，改动要谨慎 |
| 寻源业务 | `OperSupplierSourcePageListImpl` | 决定具体显示报价、撤回、咨询等按钮 |
| 本次待开发 | 公共根修或业务止血 | 当前都还没实施 |

---

## 7. 风险、待确认和后续动作

| 类型 | 内容 | 证据 | 谁决定/下一步 |
|---|---|---|---|
| 已确认风险 | fastjson2 会让泛型 Map 中的 Date 变成 String | 两版本真实 jar 对照实验 | 开发修复 |
| 已确认风险 | 只修 216 行会在其他日期继续失败 | 同文件 6 处、全 source 10 处 | 修复时一次覆盖 |
| 已确认风险 | 公共层修复影响范围大 | 110 个解析器、140 处注解 | 用户/团队确认后单独开发 |
| 运行未知 | 今天出问题环境的最终大 jar 内 fastjson 版本未直接检查 | 尚未进入问题 Pod 查包 | 部署验证时补 |
| 运行未知 | 当前账号无法在接口中查到该供应商数据 | 只读接口返回空列表 | 需要对应供应商测试账号验收按钮 |

### 如果需要找同事确认公共修复，可直接发送

> “这次不是单个字段少配日期格式。已经用 fastjson 1.2.83 和 2.0.62 复现：OAuth2 公共返回转换器把 JSONObject 转 `Map<String,Object>` 时，2.x 会把 Date 变成 String，寻源按钮解析器再强转 Date 就报错。公共转换器有两处相同写法，本地扫描到 140 个操作列注解用点。建议公共层改成保留原值类型的 Map 浅拷贝，并先回归 source；这个公共修复范围可以做吗？”

### 用户批准开发时的明确话术

推荐方案：

> “同意按公共层根修开发，只做本地修改和验证，不提交、不发布。”

紧急止血方案：

> “先按 source 业务止血开发，10 处日期一起兼容，只做本地修改和验证，不提交、不发布。”

---

## 8. 所有权验收

### 8.1 30 秒复述

> “fastjson 2.x 没有把数据库日期查错。数据库和 Service 拿到的仍是 Date，但公司 OAuth2 公共返回转换器把每行 JSONObject 转泛型 Map 时，会经过一次 JSON 文本转换，Date 因此变成 String。寻源业务第 216 行还把它强转成 Date，所以报错。指定格式只能改变字符串长相，不能解决类型问题。推荐修公共转换层，紧急时才在 source 里把 10 处日期都做兼容。”

### 8.2 三个自测题

1. 为什么 `2026-06-10 22:00:00` 看起来是时间，却不能直接当 `Date`？
2. `scm-cloud-parent`、`scm-cloud-dependencies`、`scm-source-all` 在这次事情里分别是什么角色？
3. 为什么只给字段加 `yyyy-MM-dd HH:mm:ss` 格式，仍然不能解决第 216 行？

### 8.3 能回答到这个程度就算掌握

1. `Date` 是可比较的日期对象，String 只是文字。
2. parent 决定版本，dependencies 做公共转换，source 根据日期算按钮。
3. 格式只管文字长相；必须保留 Date 类型，或者把字符串解析回 Date。

---

## 9. 证据定位清单

| 想确认什么 | 去哪里看 |
|---|---|
| fastjson 当前统一版本 | `01zhaocai-end/scm-cloud-parent/pom.xml:65` |
| 上次修过什么 | `git -C 01zhaocai-end/scm-assemblies-all show 80e24fa` |
| 供应商列表接口和注解 | `SourceQueryController.java:153-169` |
| 返回数据第一次进入公共层 | `GlobalResponseHandler.java:53-75` |
| 日期变成字符串的转换点 | `OperListResponseTransferServiceImpl.java:113` |
| 今天报错的第一行 | `OperSupplierSourcePageListImpl.java:216` |
| 后续还可能报的日期 | 同文件第 81、86、221、252、267 行 |
| DTO 中原始日期字段 | `SupplierSourceVO.java:63-82` |
