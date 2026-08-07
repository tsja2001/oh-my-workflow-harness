# Fastjson 2 升级 · 日期兼容问题 · 汇报版

> 日期：2026-07-28 ｜ 工具：cc
> 面向：技术负责人（懂 Java）+ 汇报人自用
> 当前状态：**根因已实测确认，修复方案已定，尚未改代码 / 未提交 / 未发布**，等拍板走哪条路。
> 一句话：升级 fastjson 2 后，底层公共代码把 `Date` 转成了 `String`，下游业务 `(Date)` 强转报 `ClassCastException`。

---

## 1. 一分钟讲清楚

为堵 fastjson 1.x 的安全漏洞，把它统一升级到 **2.0.62**（升级本身正确、必须做）。升级后暴露一个 **2.x 行为变化导致的兼容坑**：

- 一段**公共返回处理代码**在给列表每行"补操作按钮"时，会把整行数据 `JSONObject` 转成 `Map<String,Object>`；
- fastjson **1.x** 这一步转出来，日期字段还是 `java.util.Date`；
- fastjson **2.x** 同一步会走一次"序列化成 JSON 文本再反序列化"，**日期就变成了 `String`**；
- 下游寻源业务代码仍然 `(Date) map.get(...)` 强转，于是抛 `java.lang.String cannot be cast to java.util.Date`，**列表操作按钮补不上**。

**定性**：不是数据库问题、不是 SQL 没查到、不是配置漏项、不是升级本身写错、不是上次改的兼容代码错了——是 **fastjson 2.x 对"`JSONObject` → 泛型 `Map`"这一步的日期处理变了**。已用 1.2.83 与 2.0.62 两个真机版本对照复现确认。

---

## 2. 根因：就是这一行代码

**公共爆点**（把 Date 变成 String 的地方）
`01zhaocai-end/scm-cloud-dependencies/scm-cloud-dependencies-oauth2/.../datatransfer/service/impl/OperListResponseTransferServiceImpl.java`

```java
// 第 113 行（数组分支：给列表每一行补操作按钮）—— 今天报错走的就是这里
obj.put(v, operResolverService.resolverOperList(
        obj.toJavaObject(new TypeReference<Map<String, Object>>() {})   // ← 元凶
));

// 第 83 行（单对象分支）—— 同样写法，同样的坑
target.put(v, operResolverService.resolverOperList(
        target.toJavaObject(new TypeReference<Map<String, Object>>() {})
));
```

`obj` / `target` 本身就是 `JSONObject`（即 `Map`）。`toJavaObject(new TypeReference<Map<String,Object>>(){})` 在 fastjson **2.x** 下等价于做了一次 `JSON 文本序列化 + 反序列化`，`Date` 在序列化成文本后丢了类型，回来变成 `String`。

**业务报错点**（拿到 String 硬转 Date 的地方）
`01zhaocai-end/scm-source-all/scm-source-source/.../service/impl/OperSupplierSourcePageListImpl.java`

```java
// 第 216 行（堆栈第一个爆点）
sourceSignEndTime = (Date) map.get("sourceSignEndTime");   // ← String cannot be cast to Date
...
sourceSignEndTime.after(new Date());                        // 本意是判断有没有过截止时间
```

同一文件还有 **5 处**相同强转（第 81、86、221、252、267 行），所以**只改第 216 行是不够的**，后面接着崩。

**调用链**（数据库没问题，问题在"补按钮"这一步）：

```
前端请求 querySupplierSourcePageList
  → SourceQueryController（@DataResponseTransfer 触发补按钮）
  → MyBatis 查库：此时日期还是真正的 Date ✅
  → GlobalResponseHandler 把返回转成 JSONObject
  → OperListResponseTransferServiceImpl:113  JSONObject→Map  ← 2.x 在此把 Date 变 String ❌
  → OperSupplierSourcePageListImpl:216  (Date) 强转字符串  ← ClassCastException 抛出
```

> 注：`GlobalResponseHandler` 会 catch 住这个异常并记日志、继续返回，所以接口可能是 HTTP 200 / status=true，但**每行的 operList（操作按钮）没补上或只补了一半**——因此它不像普通 500，排查时容易被带偏。

---

## 3. 两个"看着对其实错"的方向（先挡回去）

| 说法 | 为什么不行 |
|---|---|
| "指定一下日期格式 `@JSONField(format=...)`" | 格式只决定字符串长什么样，改变不了"它已经是 String 不是 Date"，`(Date)` 强转照样崩。 |
| "把报错那行删了 / 去掉 `@DataResponseTransfer` 注解" | 注解是用来给列表"长出操作按钮"的，删了页面按钮全没；且同文件还有 5 处日期强转。 |
| "退回 fastjson 1.x" | 等于把已修复的安全漏洞重新带回来，方向错误。 |

---

## 4. 怎么修（两条路，请拍板）

### 方案 A · 根治公共层（推荐）
只改上面那个公共文件的**两处**，把"序列化转换"换成"浅拷贝"，日期不再经过 JSON 文本，类型原样保留：

```java
// 第 113 行 改为：
obj.put(v, operResolverService.resolverOperList(new HashMap<>(obj)));
// 第 83 行 改为：
target.put(v, operResolverService.resolverOperList(new HashMap<>(target)));
// 顶部 import java.util.HashMap;（TypeReference 若无其它引用可移除）
```

`new HashMap<>(obj)` 是把 `JSONObject` 里每个键值**直接引用复制**过去，`Date` 还是 `Date`、`Integer` 还是 `Integer`，对 1.x / 2.x 都兼容。本地已实测：`2.x + TypeReference` → 日期变 String；`2.x + new HashMap<>(obj)` → 日期仍是 Date。

- **优点**：从源头根治，一劳永逸，不用逐个改业务文件。
- **顾虑**：这是公共组件，全项目扫到约 **140 处** `@OperListTransfer` 在用（都经过这个转换器）。改动虽只有两行，但发布后会随各服务重建逐步扩散，**发布前要挑几个代表性接口回归**（数组分支 + 单对象分支 + Integer/Boolean/String 不被改坏）。

### 方案 B · 只改寻源业务（紧急止血）
业务侧取日期时不再直接 `(Date)` 强转，改成"是 Date 就用、是字符串就解析回 Date"（如 `TypeUtils.castToDate(value)`），寻源相关共 **约 10 处**（集中在 4 个文件）一起改。

- **优点**：影响面只在寻源服务，发版范围小，能快速恢复页面。
- **缺点**：治标不治本，公共层的坑还在，别的服务以后可能再踩。

### 建议
优先 **A 根治**；若今天必须马上恢复页面、又暂时不便动公共组件，则先 **B 止血**（务必 10 处一起改，别只改 216 行），A 的根治另排一个独立提交。

---

## 5. 部署提醒（方案 A 特有，一句话）

公共库 `scm-cloud-dependencies` 没有独立 Jenkins 任务，走法是：**本地改 → 手动 `mvn deploy` 把新公共 jar 发到 Nexus → 重新构建 `scm-source-web-test` 镜像 → 重启 Pod 验证**。只改代码不发布、只发 jar 不重建 source-web，运行中的服务都还是旧代码。（发布前确认在最新主线分支，别用旧分支覆盖 Nexus——上次升级踩过这个坑。）

---

## 6. 当前状态一览

| 事项 | 状态 | 证据 |
|---|---|---|
| 升级到 fastjson 2.0.62（堵漏洞） | ✅ 已完成、已发布 | `scm-cloud-parent/pom.xml:65`，提交 `256a2be` |
| 上次"方法被删"兼容问题 | ✅ 已修 | `scm-assemblies-all` 提交 `80e24fa` |
| 本次"日期变 String"坑 | 🔴 根因已确认，**未修** | 1.2.83 / 2.0.62 对照实验 |
| 修复方案 | 已定，等拍板 A / B | 本文第 4 节 |

---

## 7. 汇报口径（可照读）

> "上次为修 fastjson 的安全漏洞，把它从 1.x 升到 2.0.62，这个必须做。升级后暴露一个 2.x 的兼容坑：OAuth2 公共返回处理里，把 `JSONObject` 转 `Map<String,Object>` 时，2.x 会多走一次 JSON 序列化，把 `Date` 变成了 `String`；下游寻源列表的 `OperSupplierSourcePageListImpl` 还 `(Date)` 强转，抛 `ClassCastException`，表现是列表操作按钮补不上。根因已用 1.2.83 和 2.0.62 对照复现确认，不是数据库、不是配置、也不是升级本身写错。
> 方案两个：A 改公共转换器两行，把 `toJavaObject(TypeReference<Map>)` 换成 `new HashMap<>(obj)` 浅拷贝根治，但它是公共组件、约 140 处在用，发布前要回归几个接口；B 只在寻源业务把约 10 处 `(Date)` 强转改成安全转换紧急止血。改动量都很小，主要成本在测试和发布验证。我建议走 A，请定一下走哪条、以及能不能动公共组件。"

---

## 8. 想自己核对时看这里

| 想确认 | 位置 |
|---|---|
| 统一版本已是 2.0.62 | `01zhaocai-end/scm-cloud-parent/pom.xml:65` |
| Date 变 String 的转换点 | `OperListResponseTransferServiceImpl.java:83`（单对象）、`:113`（数组） |
| 今天报错第一行 | `OperSupplierSourcePageListImpl.java:216` |
| 同文件其余日期强转 | 第 81、86、221、252、267 行 |
| 接口与注解 | `SourceQueryController.java` 的 `/e/business/source/source/querySupplierSourcePageList` + `@DataResponseTransfer` |
| 异常被吞、接口仍 200 的原因 | `GlobalResponseHandler`（catch 转换异常后继续返回） |

> 详细跟读与两版本对照实验见同目录 `50-代码复盘与学习-codex.md`；部署细节见 `90-临时-公共转换层修复与部署说明-codex.md`。
